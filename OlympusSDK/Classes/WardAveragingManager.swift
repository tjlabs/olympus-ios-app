

final class WardAveragingManager {

    private let bufferSize: Int
    private let missingRssi: Float

    // beaconId -> recent rssis (deque처럼 사용)
    private var buffers: [String: [Float]] = [:]

    // 지금까지 한 번이라도 등장한 비콘 목록(= 출력 대상의 기준)
    private var knownBeaconIds: Set<String> = []

    init(bufferSize: Int, missingRssi: Float = -100.0) {
        self.bufferSize = max(1, bufferSize)
        self.missingRssi = missingRssi
    }

    /// bleData: [beaconId: rssi] (이번 epoch에 관측된 것만 들어온다고 가정)
    /// return: [beaconId: avgOrMissing] (knownBeaconIds 전체에 대해 값 제공)
    func updateEpoch(bleData: [String: Float]) -> [String: Float] {
        // 1) 이번 epoch에 관측된 비콘은 버퍼에 append
        for (id, rssi) in bleData {
            knownBeaconIds.insert(id)

            var arr = buffers[id] ?? []
            arr.append(rssi)
            if arr.count > bufferSize {
                arr.removeFirst(arr.count - bufferSize)
            }
            buffers[id] = arr
        }

        // 2) knownBeaconIds 전체에 대해 이번 epoch 대표값 생성
        //    - 이번 epoch에 관측된 비콘: avg
        //    - 관측 안 된 비콘: -100 (버퍼는 그대로)
        var result: [String: Float] = [:]
        for id in knownBeaconIds {
            if let arr = buffers[id], !arr.isEmpty, bleData[id] != nil {
                // 관측된 경우에만 평균을 “이번 epoch 대표값”으로 사용
                let sum = arr.reduce(Float(0), +)
                result[id] = sum / Float(arr.count)
            } else {
                result[id] = missingRssi
            }
        }

        return result
    }

    func reset() {
        buffers.removeAll()
        knownBeaconIds.removeAll()
    }
}
