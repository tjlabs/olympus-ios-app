import Foundation

final class PeakDetector {

    private struct PeakPlateauState {
        var lastPlateauMax: Float? = nil
        var lastPeakIndex: Int? = nil
        var inMaxPlateau: Bool = false
    }

    
    // MARK: - Config
    private(set) var BUFFER_SIZE: Int = 50
    
    private let MISSING_FLOOR_RSSI: Float = -100.0

    private var minPeakRssi: Float = -90.0
    private let TOPK_FOR_REF = 10
    private var globalTopkRssi: [Float] = []
    private let REF_RSSI_CAP: Float = -65.0
    private let THRESHOLD_AT_CAP: Float = -82.0
    
    private var maxConsecutiveMissing: Int = 60

    // MARK: - State
    private var indexHistory: [WardId: [Int]] = [:]
    private var rssiHistory: [WardId: [Float]] = [:]
    private var missingCount: [WardId: Int] = [:]

    private var plateauState: [WardId: PeakPlateauState] = [:]
    private let PLATEAU_EPS: Float = 1e-6
    
    init() { }

    // MARK: - Public APIs
    func setBufferSize(size: Int) {
        BUFFER_SIZE = max(3, size)
        for (id, arr) in rssiHistory {
            if arr.count > BUFFER_SIZE {
                rssiHistory[id] = Array(arr.suffix(BUFFER_SIZE))
            }
        }
        
        for (id, arr) in indexHistory {
            if arr.count > BUFFER_SIZE {
               indexHistory[id] = Array(arr.suffix(BUFFER_SIZE))
            }
        }
    }

    func setPeakParams(minPeakRssi: Float = -90.0,
                       maxConsecutiveMissing: Int = 60) {
        self.minPeakRssi = minPeakRssi
        self.maxConsecutiveMissing = max(1, maxConsecutiveMissing)
    }

    func updateEpoch(uvdIndex: Int, bleAvg: [WardId: Float], windowSize: Int) -> UserPeak? {
        // 1) Append current values for seen IDs
        for (id, rssi) in bleAvg {
            appendIndex(id: id, index: uvdIndex)
            appendRssi(id: id, rssi: rssi)
            missingCount[id] = 0
        }

        // 2) Append missing-floor for tracked IDs not seen this epoch
        let seen = Set(bleAvg.keys)
        for id in rssiHistory.keys where !seen.contains(id) {
            appendIndex(id: id, index: uvdIndex)
            appendRssi(id: id, rssi: MISSING_FLOOR_RSSI)
            missingCount[id, default: 0] += 1
        }

        // 3) Drop long-missing IDs (prevents unbounded growth)
        if !missingCount.isEmpty {
            let toRemove = missingCount.filter { $0.value >= maxConsecutiveMissing }.map { $0.key }
            for id in toRemove {
                indexHistory.removeValue(forKey: id)
                rssiHistory.removeValue(forKey: id)
                missingCount.removeValue(forKey: id)
                plateauState.removeValue(forKey: id)
            }
        }

        // Adaptive minPeakRssi update (based on global strongest TOP-K RSSI)
        computeAdpativeMinPeakRssi(bleAvg: bleAvg)

        // 4) Peak decision (buffer-center max rule)
        var best: UserPeak? = nil
        let win = max(3, windowSize)

        for (id, fullArr) in rssiHistory {
            // Use the most-recent `win` samples for peak decision

            guard fullArr.count >= win else { continue }
            let arr = Array(fullArr.suffix(win))

            let n = arr.count
            let mid = n / 2
            let left = max(0, mid - 1)
            let right = min(n - 1, mid + 1)

            // Find global max (value + index) within the window
            var maxIdx = 0
            var maxVal = arr[0]
            for i in 1..<n {
                if arr[i] > maxVal {
                    maxVal = arr[i]
                    maxIdx = i
                }
            }

            // Peak must be near the window center (same rule as before)
            if !(left...right).contains(maxIdx) {
                var st = plateauState[id] ?? PeakPlateauState()
                st.inMaxPlateau = false
                st.lastPeakIndex = nil
                plateauState[id] = st
                continue
            }

            guard maxVal >= minPeakRssi else { continue }

            // Build peak info using the same window for indexHistory + rssi buffer (needed for plateau suppression)
            guard let fullIdxArr = indexHistory[id], fullIdxArr.count >= win else { continue }
            let idxArr = Array(fullIdxArr.suffix(win))

            let startIndex = idxArr[0]
            let endIndex = idxArr[n - 1]
            let peakIndex = idxArr[maxIdx]

            let startRssi = arr[0]
            let endRssi = arr[n - 1]

            var st = plateauState[id] ?? PeakPlateauState()
            if st.inMaxPlateau,
               let lastMax = st.lastPlateauMax,
               abs(maxVal - lastMax) <= PLATEAU_EPS,
               let lastPeakIdx = st.lastPeakIndex,
               lastPeakIdx == peakIndex {
                continue
            }
            st.inMaxPlateau = true
            st.lastPlateauMax = maxVal
            st.lastPeakIndex = peakIndex
            plateauState[id] = st

            let candidate = UserPeak(id: id,
                                     start_index: startIndex,
                                     end_index: endIndex,
                                     peak_index: peakIndex,
                                     start_rssi: startRssi,
                                     end_rssi: endRssi,
                                     peak_rssi: maxVal,
                                     threshold: minPeakRssi)

            if let b = best {
                if candidate.peak_rssi > b.peak_rssi {
                    best = candidate
                }
            } else {
                best = candidate
            }
        }
        
        if let bb = best {
            JupiterLogger.i(tag: "PeakDetector", message: "(updateEpoch) - peak detected: windowSize = \(max(3, windowSize)), storedBufferSize = \(BUFFER_SIZE), TH = \(minPeakRssi)")
        }
        
        return best
    }

    func reset() {
        indexHistory.removeAll()
        rssiHistory.removeAll()
        missingCount.removeAll()
        plateauState.removeAll()
    }

    // MARK: - Internals
    private func appendIndex(id: WardId, index: Int) {
        var arr = indexHistory[id] ?? []
        arr.append(index)
        if arr.count > BUFFER_SIZE {
            arr.removeFirst(arr.count - BUFFER_SIZE)
        }
        indexHistory[id] = arr
    }
    
    private func appendRssi(id: WardId, rssi: Float) {
        var arr = rssiHistory[id] ?? []
        arr.append(rssi)
        if arr.count > BUFFER_SIZE {
            arr.removeFirst(arr.count - BUFFER_SIZE)
        }
        rssiHistory[id] = arr
    }
    
    func computeAdpativeMinPeakRssi(bleAvg: [WardId: Float]) {
        let newValues: [Float] = bleAvg.values.compactMap { v in
            guard v.isFinite, !v.isNaN else { return nil }
            return v
        }

        globalTopkRssi = updateGlobalTopkRssi(globalTopkRssi, newValues: newValues, k: TOPK_FOR_REF)
        let epochRefRssi: Float? = {
            guard !globalTopkRssi.isEmpty else { return nil }
            let sum = globalTopkRssi.reduce(0.0 as Float, +)
            return sum / Float(globalTopkRssi.count)
        }()

        let thr = computeAdaptiveRssiThreshold(epochRefRssi: epochRefRssi,
                                               refCap: REF_RSSI_CAP,
                                               thresholdAtCap: THRESHOLD_AT_CAP,
                                               extraMarginMax: 12.0,
                                               extraMarginScale: 15.0,
                                               minThreshold: -130.0,
                                               maxThreshold: -60.0)

        minPeakRssi = thr
    }

    private func updateGlobalTopkRssi(_ globalTopk: [Float], newValues: [Float], k: Int) -> [Float] {
        let kk = max(1, k)

        var topk = globalTopk.filter { $0.isFinite && !$0.isNaN }
        if topk.count > 1 {
            if topk != topk.sorted(by: >) {
                topk.sort(by: >)
            }
        }
        if topk.count > kk {
            topk = Array(topk.prefix(kk))
        }

        for v in newValues {
            guard v.isFinite, !v.isNaN else { continue }

            if topk.count < kk {
                let idx = insertionIndexDesc(in: topk, value: v)
                topk.insert(v, at: idx)
            } else {
                guard let weakest = topk.last, v > weakest else { continue }
                let idx = insertionIndexDesc(in: topk, value: v)
                topk.insert(v, at: idx)
                if topk.count > kk {
                    topk.removeLast(topk.count - kk)
                }
            }
        }

        if topk.count > kk {
            topk.removeLast(topk.count - kk)
        }
        return topk
    }

    private func insertionIndexDesc(in arr: [Float], value: Float) -> Int {
        var lo = 0
        var hi = arr.count
        while lo < hi {
            let mid = (lo + hi) / 2
            if value > arr[mid] {
                hi = mid
            } else {
                lo = mid + 1
            }
        }
        return lo
    }

    private func computeAdaptiveRssiThreshold(epochRefRssi: Float?,
                                              refCap: Float,
                                              thresholdAtCap: Float,
                                              extraMarginMax: Float,
                                              extraMarginScale: Float,
                                              minThreshold: Float,
                                              maxThreshold: Float) -> Float {
        let baseMargin: Float = refCap - thresholdAtCap  // e.g., (-65) - (-82) = 17

        guard let refRaw = epochRefRssi, refRaw.isFinite, !refRaw.isNaN else {
            let thr = refCap - baseMargin
            return clamp(thr, minThreshold, maxThreshold)
        }

        var ref = refRaw
        if ref > refCap { ref = refCap }

        let delta = max(0.0, refCap - ref)

        // Saturating extra margin: extra = extraMarginMax * (1 - exp(-delta/scale))
        let scale = max(1e-6 as Float, extraMarginScale)
        let extra = extraMarginMax * (1.0 - expf(-delta / scale))

        let margin = baseMargin + extra
        let thr = ref - margin

        return clamp(thr, minThreshold, maxThreshold)
    }

    private func clamp(_ x: Float, _ lo: Float, _ hi: Float) -> Float {
        return min(max(x, lo), hi)
    }
}
