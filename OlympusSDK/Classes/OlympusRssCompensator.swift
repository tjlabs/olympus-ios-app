import Foundation

public class OlympusRssCompensator {
    var isScaleLoaded: Bool = false
    var isScaleConverged: Bool = false
    
    var entranceWardRssi = [String: Double]()
    var allEntranceWardRssi = [String: Double]()
    
    var wardMinRssi: [(timestamp: Int, rssi: Double)] = []
    var wardMaxRssi: [(timestamp: Int, rssi: Double)] = []
    
//    var wardMinRssi = [Double]()
//    var wardMaxRssi = [Double]()
    var deviceMinValue: Double = -99.0
    var updateMinArrayCount: Int = 0
    var updateMaxArrayCount: Int = 0
    let ARRAY_SIZE: Int = 3
    
    var timeAfterResponse: Double = 0
    var normalizationScale: Double = 1.0
    var preNormalizationScale: Double = 1.0
    var preSmoothedNormalizationScale: Double = 1.0
    var scaleQueue = [Double]()
    var validScaleQueue = [Double]()
    
    var timeStackEst: Double = 0
    
    public func initialize() {
        self.timeAfterResponse = 0
        self.timeStackEst = 0
    }
    
    public func setIsScaleLoaded(flag: Bool) {
        self.isScaleLoaded = flag
    }
    
    
    public func loadRssiCompensationParam(sector_id: Int, device_model: String, os_version: Int, completion: @escaping (Bool, Double, String) -> Void) {
        var loadedNormalizationScale: Double = 1.0
        
        // Check data in cache
        let loadedScale = loadNormalizationScale(sector_id: sector_id)
        
        if loadedScale.0 {
            // Scale is in cache
            loadedNormalizationScale = loadedScale.1
            let msg: String = getLocalTimeString() + " , (Olympus) Success : Load RssCompensation in cache"
            completion(true, loadedNormalizationScale, msg)
        } else {
            let rcInputDeviceOs = RcInputDeviceOs(sector_id: sector_id, device_model: device_model, os_version: os_version)
            OlympusNetworkManager.shared.getUserRssCompensation(url: USER_RC_URL, input: rcInputDeviceOs, isDeviceOs: true, completion: { statusCode, returnedString in
                if (statusCode == 200) {
                    let rcResult = jsonToRcInfoFromServer(jsonString: returnedString)
                    if (rcResult.0) {
                        if (rcResult.1.rss_compensations.isEmpty) {
                            let rcInputDevice = RcInputDevice(sector_id: sector_id, device_model: device_model)
                            OlympusNetworkManager.shared.getUserRssCompensation(url: USER_RC_URL, input: rcInputDevice, isDeviceOs: false, completion: { statusCode, returnedString in
                                if (statusCode == 200) {
                                    let rcDeviceResult = jsonToRcInfoFromServer(jsonString: returnedString)
                                    if (rcDeviceResult.0) {
                                        if (rcDeviceResult.1.rss_compensations.isEmpty) {
                                            // Need Normalization-scale Estimation
                                            print(getLocalTimeString() + " , (Olympus) Information : Need RssCompensation Estimation")
                                            let msg: String = getLocalTimeString() + " , (Olympus) Success : RssCompensation"
                                            completion(true, loadedNormalizationScale, msg)
                                        } else {
                                            // Succes Load Normalization-scale (Device)
                                            if let closest = self.findClosestOs(to: os_version, in: rcDeviceResult.1.rss_compensations) {
                                                // Find Closest OS
                                                let rcFromServer: RcInfo = closest
                                                loadedNormalizationScale = rcFromServer.normalization_scale
                                                
                                                print(getLocalTimeString() + " , (Olympus) Information : Load RssCompensation from server (\(device_model))")
                                                let msg: String = getLocalTimeString() + " , (Olympus) Success : RssCompensation"
                                                completion(true, loadedNormalizationScale, msg)
                                            } else {
                                                // Need Normalization-scale Estimation
                                                print(getLocalTimeString() + " , (Olympus) Information : Need RssCompensation Estimation")
                                                let msg: String = getLocalTimeString() + " , (Olympus) Success : RssCompensation"
                                                completion(true, loadedNormalizationScale, msg)
                                            }
                                        }
                                    } else {
                                        let msg: String = getLocalTimeString() + " , (Olympus) Error : Decode RssCompensation (\(device_model))"
                                        completion(false, loadedNormalizationScale, msg)
                                    }
                                } else {
                                    let msg: String = getLocalTimeString() + " , (Olympus) Error : Load RssCompensation (\(device_model)) from server \(statusCode)"
                                    completion(false, loadedNormalizationScale, msg)
                                }
                            })
                        } else {
                            // Succes Load Normalization-scale (Device & OS)
                            let rcFromServer: RcInfo = rcResult.1.rss_compensations[0]
                            loadedNormalizationScale = rcFromServer.normalization_scale
                            
                            print(getLocalTimeString() + " , (Olympus) Information : Load RssCompensation from server (\(device_model) & \(os_version))")
                            let msg: String = getLocalTimeString() + " , (Olympus) Success : RssCompensation"
                            completion(true, loadedNormalizationScale, msg)
                        }
                    } else {
                        let msg: String = getLocalTimeString() + " , (Olympus) Error : Decode RssCompensation (\(device_model) & \(os_version))"
                        completion(false, loadedNormalizationScale, msg)
                    }
                } else {
                    let msg: String = getLocalTimeString() + " , (Olympus) Error : Load RssCompensation (\(device_model) & \(os_version)) from server \(statusCode)"
                    
                    // Edit Here !!
                    completion(false, loadedNormalizationScale, msg)
                }
            })
        }
    }
    
    public func stackTimeAfterResponse(isGetFirstResponse: Bool, isIndoor: Bool) {
        if isGetFirstResponse && isIndoor {
            if (self.timeAfterResponse < OlympusConstants.REQUIRED_RC_CONVERGENCE_TIME) {
                self.timeAfterResponse += OlympusConstants.RFD_INTERVAL
            }
        }
    }
    
//    public func estimateNormalizationScale(isGetFirstResponse: Bool, isIndoor: Bool, currentLevel: String, diffMinMaxRssi: Double, minRssi: Double) {
//        self.timeStackEst += OlympusConstants.RFD_INTERVAL
//        
//        if (isGetFirstResponse && isIndoor && diffMinMaxRssi >= 25 && minRssi <= -97 && self.timeStackEst >= OlympusConstants.EST_RC_INTERVAL) {
////            print(getLocalTimeString() + " , (Olympus) RSS Compensator : timeStackEst = \(timeStackEst) // isScaleLoaded = \(isScaleLoaded)")
//            self.timeStackEst = 0
//            if (self.isScaleLoaded) {
//                if (currentLevel != "B0") {
//                    let normalizationScale = calNormalizationScale(standardMin: OlympusConstants.STANDARD_MIN_RSS, standardMax: OlympusConstants.STANDARD_MAX_RSS)
////                    print(getLocalTimeString() + " , (Olympus) RSS Compensator : isScaleConverged = \(isScaleConverged)")
//                    if (!self.isScaleConverged) {
//                        if (normalizationScale.0) {
//                            let smoothedScale: Double = smoothNormalizationScale(scale: normalizationScale.1)
////                            print(getLocalTimeString() + " , (Olympus) RSS Compensator : smoothedScale = \(smoothedScale)")
//                            self.normalizationScale = smoothedScale
//                            let diffScale = abs(smoothedScale - self.preNormalizationScale)
//                            if (diffScale < 1e-3 && self.timeAfterResponse >= OlympusConstants.REQUIRED_RC_CONVERGENCE_TIME && (smoothedScale != self.preNormalizationScale)) {
//                                self.isScaleConverged = true
//                            }
//                            self.preNormalizationScale = smoothedScale
////                            let estimatedScale = normalizationScale.1
////                            self.normalizationScale = normalizationScale.1
////                            let diffScale = abs(estimatedScale - self.preNormalizationScale)
////                            if (diffScale < 1e-3 && self.timeAfterResponse >= OlympusConstants.REQUIRED_RC_CONVERGENCE_TIME && (estimatedScale != self.preNormalizationScale)) {
////                                self.isScaleConverged = true
////                            }
////                            self.preNormalizationScale = estimatedScale
//                        }
//                    }
//                }
//            } else {
//                if (!self.isScaleConverged) {
//                    let normalizationScale = calNormalizationScale(standardMin: OlympusConstants.STANDARD_MIN_RSS, standardMax: OlympusConstants.STANDARD_MAX_RSS)
////                    print(getLocalTimeString() + " , (Olympus) RSS Compensator : normalizationScale = \(normalizationScale)")
//                    if (normalizationScale.0) {
//                        let smoothedScale: Double = smoothNormalizationScale(scale: normalizationScale.1)
////                        print(getLocalTimeString() + " , (Olympus) RSS Compensator : smoothedScale = \(smoothedScale)")
//                        self.normalizationScale = smoothedScale
//                        let diffScale = abs(smoothedScale - self.preNormalizationScale)
//                        if (diffScale < 1e-3 && self.timeAfterResponse >= OlympusConstants.REQUIRED_RC_CONVERGENCE_TIME && (smoothedScale != self.preNormalizationScale)) {
//                            self.isScaleConverged = true
//                        }
//                        self.preNormalizationScale = smoothedScale
//                    } else {
//                        let smoothedScale: Double = smoothNormalizationScale(scale: self.preNormalizationScale)
//                        self.normalizationScale = smoothedScale
//                    }
//                }
//            }
//            
//            if (isScaleConverged) {
//                OlympusConstants().setNormalizationScale(cur: self.normalizationScale, pre: self.preNormalizationScale)
//            }
//        } else if (isGetFirstResponse && isIndoor && self.isScaleLoaded && !self.isScaleConverged) {
//            if validScaleQueue.count > 4 {
//                let scale = validScaleQueue[validScaleQueue.count-1]
//                OlympusConstants().setNormalizationScale(cur: scale, pre: scale)
//                isScaleConverged = true
//            }
//        }
//    }
    
//    public func stackValidNormalizationScale(scale: Double) {
//        if !isScaleConverged {
//            validScaleQueue.append(scale)
//        }
//    }
    
//    public func getMaxRssi() -> Double {
//        if (self.wardMaxRssi.isEmpty) {
//            return -55.0
//        } else {
//            let avgMax = self.wardMaxRssi.average
//            return avgMax
//        }
//    }
//    
//    public func getMinRssi() -> Double {
//        if (self.wardMinRssi.isEmpty) {
//            return -99.0
//        } else {
//            let avgMin = self.wardMinRssi.average
//            return avgMin
//        }
//    }
//    
//    public func refreshWardMinRssi(bleTime: Int, bleData: [String: Double]) {
//        for (_, value) in bleData {
//            if (value > -100) {
//                if (self.wardMinRssi.isEmpty) {
//                    self.wardMinRssi.append(value)
//                } else {
//                    let newArray = appendAndKeepMin(inputArray: self.wardMinRssi, newValue: value, size: self.ARRAY_SIZE)
//                    self.wardMinRssi = newArray
//                }
//            }
//        }
//    }
//    
//    public func refreshWardMaxRssi(bleTime: Int, bleData: [String: Double]) {
//        for (_, value) in bleData {
//            if (self.wardMaxRssi.isEmpty) {
//                self.wardMaxRssi.append(value)
//            } else {
//                let newArray = appendAndKeepMax(inputArray: self.wardMaxRssi, newValue: value, size: self.ARRAY_SIZE)
//                self.wardMaxRssi = newArray
//            }
//        }
//    }
//    
//    public func calNormalizationScale(standardMin: Double, standardMax: Double) -> (Bool, Double) {
//        let standardAmplitude: Double = abs(standardMax - standardMin)
//        if (self.wardMaxRssi.isEmpty || self.wardMinRssi.isEmpty) {
//            return (false, 1.0)
//        } else {
//            let avgMax = self.wardMaxRssi.average
//            let avgMin = self.wardMinRssi.average
//            self.deviceMinValue = avgMin
//            let amplitude: Double = abs(avgMax - avgMin)
//            
//            let digit: Double = pow(10, 4)
//            var normalizationScale: Double = (standardAmplitude/amplitude)*digit/digit
//            if normalizationScale > 1.2 {
//                normalizationScale = 1.2
//            } else if normalizationScale < 0.8 {
//                normalizationScale = 0.8
//            }
//            updateScaleQueue(data: normalizationScale)
//            return (true, normalizationScale)
//        }
//    }
    
    func updateScaleQueue(data: Double) {
        if (self.scaleQueue.count >= 5) {
            self.scaleQueue.remove(at: 0)
        }
        self.scaleQueue.append(data)
    }
    
    public func smoothNormalizationScale(scale: Double) -> Double {
        var smoothedScale: Double = 1.0
        if (self.scaleQueue.count == 1) {
            smoothedScale = scale
        } else {
            smoothedScale = movingAverage(preMvalue: self.preSmoothedNormalizationScale, curValue: scale, windowSize: self.scaleQueue.count)
        }
        self.preSmoothedNormalizationScale = smoothedScale
        
        return smoothedScale
    }
    
    public func refreshEntranceWardRssi(entranceWard: [String: Int], bleData: [String: Double]) {
        let entranceWardIds: [String] = Array(entranceWard.keys)
        
        for (key, value) in bleData {
            if (entranceWardIds.contains(key)) {
                if (self.entranceWardRssi.keys.contains(key)) {
                    if let previousValue = self.entranceWardRssi[key] {
                        if (value > previousValue) {
                            self.entranceWardRssi[key] = value
                        }
                    }
                } else {
                    self.entranceWardRssi[key] = value
                }
            }
        }
    }
    
    public func refreshAllEntranceWardRssi(allEntranceWards: [String], bleData: [String: Double]) {
        let allEntranceWardIds: [String] = allEntranceWards
        
        for (key, value) in bleData {
            if (allEntranceWardIds.contains(key)) {
                if (self.allEntranceWardRssi.keys.contains(key)) {
                    if let previousValue = self.allEntranceWardRssi[key] {
                        if (value > previousValue) {
                            self.allEntranceWardRssi[key] = value
                        }
                    }
                } else {
                    self.allEntranceWardRssi[key] = value
                }
            }
        }
    }
    
    public func loadNormalizationScale(sector_id: Int) -> (Bool, Double) {
        var isLoadedFromCache: Bool = false
        var scale: Double = 1.0
        
        let keyScale: String = "OlympusNormalizationScale_\(sector_id)"
        if let loadedScale: Double = UserDefaults.standard.object(forKey: keyScale) as? Double {
            scale = loadedScale
            isLoadedFromCache = true
            if (scale >= 1.7) {
                scale = 1.0
            }
        }
        
        return (isLoadedFromCache, scale)
    }
    
    public func saveNormalizationScale(scale: Double, sector_id: Int) {
        print(getLocalTimeString() + " , (Olympus) Save NormalizationScale : \(scale)")
        
        do {
            let key: String = "OlympusNormalizationScale_\(sector_id)"
            UserDefaults.standard.set(scale, forKey: key)
        }
    }
    
    func excludeLargestAbsoluteValue(from array: [Double]) -> [Double] {
        guard !array.isEmpty else {
            return []
        }

        var largestAbsoluteValueFound = false
        let result = array.filter { element -> Bool in
            let isLargest = abs(element) == abs(array.max(by: { abs($0) < abs($1) })!)
            if isLargest && !largestAbsoluteValueFound {
                largestAbsoluteValueFound = true
                return false
            }
            return true
        }

        return result
    }
    
    func appendAndKeepMin(inputArray: [Double], newValue: Double, size: Int) -> [Double] {
        var array: [Double] = inputArray
        array.append(newValue)
        if array.count > size {
            if let maxValue = array.max() {
                if let index = array.firstIndex(of: maxValue) {
                    array.remove(at: index)
                }
            }
        }
        return array
    }
    
    func appendAndKeepMax(inputArray: [Double], newValue: Double, size: Int) -> [Double] {
        var array: [Double] = inputArray
        array.append(newValue)
        
        if array.count > size {
            if let minValue = array.min() {
                if let index = array.firstIndex(of: minValue) {
                    array.remove(at: index)
                }
            }
        }
        return array
    }
    
    func updateWardMinRss(inputArray: [Double], size: Int) -> [Double] {
        var array: [Double] = inputArray
        if array.count < size {
            return array
        } else {
            if let minValue = array.min() {
                if let index = array.firstIndex(of: minValue) {
                    array.remove(at: index)
                }
            }
        }
        return array
    }
    
    func updateWardMaxRss(inputArray: [Double], size: Int) -> [Double] {
        var array: [Double] = inputArray
        if array.count < size {
            return array
        } else {
            if let maxValue = array.max() {
                if let index = array.firstIndex(of: maxValue) {
                    array.remove(at: index)
                }
            }
        }
        return array
    }
    
    func movingAverage(preMvalue: Double, curValue: Double, windowSize: Int) -> Double {
        let windowSizeDouble: Double = Double(windowSize)
        return preMvalue*((windowSizeDouble - 1)/windowSizeDouble) + (curValue/windowSizeDouble)
    }
    
    public func getDeviceMinRss() -> Double {
        return self.deviceMinValue
    }
    
    private func findClosestOs(to myOsVersion: Int, in array: [RcInfo]) -> RcInfo? {
        guard let first = array.first else {
            return nil
        }
        var closest = first
        var closestDistance = closest.os_version - myOsVersion
        for d in array {
            let distance = d.os_version - myOsVersion
            if abs(distance) < abs(closestDistance) {
                closest = d
                closestDistance = distance
            }
        }
        return closest
    }
    
    // New
    func refreshWardMinRssiV2(bleTime: Int, bleData: [String: Double]) {
        for value in bleData.values {
            if value > -100 {
                wardMinRssi.append((bleTime, value))
                wardMinRssi = filterAndKeepMin(rssiList: wardMinRssi, arraySize: self.ARRAY_SIZE)
            }
        }
    }

    func refreshWardMaxRssiV2(bleTime: Int, bleData: [String: Double]) {
        for value in bleData.values {
            wardMaxRssi.append((bleTime, value))
            wardMaxRssi = filterAndKeepMax(rssiList: wardMaxRssi, arraySize: self.ARRAY_SIZE)
        }
    }

    private func filterAndKeepMin(rssiList: [(timestamp: Int, rssi: Double)], arraySize: Int) -> [(timestamp: Int, rssi: Double)] {
        let currentTime = getCurrentTimeInMilliseconds()
        var filtered = rssiList.filter { currentTime - $0.timestamp <= 60*1000 }

        if filtered.count < 3 {
            filtered = rssiList
        }

        let sorted = filtered.sorted { $0.rssi < $1.rssi }
        let result = Array(sorted.prefix(arraySize))
        return result
    }

    private func filterAndKeepMax(rssiList: [(timestamp: Int, rssi: Double)], arraySize: Int) -> [(timestamp: Int, rssi: Double)] {
        let currentTime = getCurrentTimeInMilliseconds()
        var filtered = rssiList.filter { currentTime - $0.timestamp <= 60*1000 }

        if filtered.count < 3 {
            filtered = rssiList
        }

        let sorted = filtered.sorted { $0.rssi > $1.rssi }
        let result = Array(sorted.prefix(arraySize))
        return result
    }
    
    func getMinRssiV2() -> Double {
        guard !wardMinRssi.isEmpty else { return -99 }
        let values = wardMinRssi.map { Double($0.rssi) }
        return values.reduce(0, +) / Double(values.count)
    }

    func getMaxRssiV2() -> Double {
        guard !wardMaxRssi.isEmpty else { return -55 }
        let values = wardMaxRssi.map { Double($0.rssi) }
        return values.reduce(0, +) / Double(values.count)
    }
    
    public func estimateNormalizationScaleV2(isGetFirstResponse: Bool, isIndoor: Bool, currentLevel: String, diffMinMaxRssi: Double, minRssi: Double) {
        self.timeStackEst += OlympusConstants.RFD_INTERVAL
        
        if (isGetFirstResponse && isIndoor && diffMinMaxRssi >= 10 && minRssi <= -97 && self.timeStackEst >= OlympusConstants.EST_RC_INTERVAL && self.timeAfterResponse >= 15) {
            self.timeStackEst = 0

            let normalizationScale = calNormalizationScaleV2(standardMin: OlympusConstants.STANDARD_MIN_RSS, standardMax: OlympusConstants.STANDARD_MAX_RSS)
            if (normalizationScale.0) {
                let smoothedScale: Double = smoothNormalizationScale(scale: normalizationScale.1)
                self.normalizationScale = smoothedScale
                self.preNormalizationScale = smoothedScale
            }
//            else {
//                let smoothedScale: Double = smoothNormalizationScale(scale: self.preNormalizationScale)
//                self.normalizationScale = smoothedScale
//            }
            
//            print(getLocalTimeString() + " , (Olympus) RssCompensator : smoothed scale = \(self.normalizationScale) // est scale = \(normalizationScale)")
            OlympusConstants().setNormalizationScale(cur: self.normalizationScale, pre: self.preNormalizationScale)
        }
    }
    
    func calNormalizationScaleV2(standardMin: Double, standardMax: Double) -> (Bool, Double) {
        let standardAmplitude = abs(standardMax - standardMin)
        if (self.wardMaxRssi.isEmpty || self.wardMinRssi.isEmpty) {
            return (false, 1.0)
        }
        
        let avgMax = getMaxRssiV2()
        let avgMin = getMinRssiV2()
        
//        print(getLocalTimeString() + " , (Olympus) RssCompensator : wardMaxRssi = \(self.wardMaxRssi) // avgMax = \(avgMax)")
//        print(getLocalTimeString() + " , (Olympus) RssCompensator : wardMinRssi = \(self.wardMinRssi) // avgMin = \(avgMin)")
        
        deviceMinValue = avgMin
        let amplitude = abs(avgMax - avgMin)
        
        guard amplitude != 0 else {
            updateScaleQueue(data: 1.0)
            return (false, 1.0)
        }

        var normalizationScale = standardAmplitude / amplitude
        normalizationScale = min(max(normalizationScale, 0.5), 2.0)

        updateScaleQueue(data: normalizationScale)
        return (true, normalizationScale)
    }
}
