import Foundation


public class RssCompensator {
    var entranceWardRssi = [String: Double]()
    var allEntranceWardRssi = [String: Double]()
    
    var wardMinRssi = [Double]()
    var wardMaxRssi = [Double]()
    var deviceMinValue: Double = -99.0
    var updateMinArrayCount: Int = 0
    var updateMaxArrayCount: Int = 0
    let ARRAY_SIZE: Int = 3
    
    var preSmoothedNormalizationScale: Double = 1.0
    var scaleQueue = [Double]()
    
    public func clearEntranceWardRssi() {
        self.entranceWardRssi = [String: Double]()
        self.allEntranceWardRssi = [String: Double]()
    }
    
    public func getMaxRssi() -> Double {
        if (self.wardMaxRssi.isEmpty) {
            return -90.0
        } else {
            let avgMax = self.wardMaxRssi.average
            return avgMax
        }
    }
    
    public func getMinRssi() -> Double {
        if (self.wardMinRssi.isEmpty) {
            return -60.0
        } else {
            let avgMin = self.wardMinRssi.average
            return avgMin
        }
    }
    
    public func refreshWardMinRssi(bleData: [String: Double]) {
        for (_, value) in bleData {
            if (value > -100) {
                if (self.wardMinRssi.isEmpty) {
                    self.wardMinRssi.append(value)
                } else {
                    let newArray = appendAndKeepMin(inputArray: self.wardMinRssi, newValue: value, size: self.ARRAY_SIZE)
                    self.wardMinRssi = newArray
                }
            }
        }
    }
    
    public func refreshWardMaxRssi(bleData: [String: Double]) {
        for (_, value) in bleData {
            if (self.wardMaxRssi.isEmpty) {
                self.wardMaxRssi.append(value)
            } else {
                let newArray = appendAndKeepMax(inputArray: self.wardMaxRssi, newValue: value, size: self.ARRAY_SIZE)
                self.wardMaxRssi = newArray
            }
        }
    }
    
    public func calNormalizationScale(standardMin: Double, standardMax: Double) -> (Bool, Double) {
        let standardAmplitude: Double = abs(standardMax - standardMin)
        
        if (self.wardMaxRssi.isEmpty || self.wardMinRssi.isEmpty) {
            return (false, 1.0)
        } else {
            let avgMax = self.wardMaxRssi.average
            let avgMin = self.wardMinRssi.average
            self.deviceMinValue = avgMin
            
            let amplitude: Double = abs(avgMax - avgMin)
            
            let digit: Double = pow(10, 4)
            let normalizationScale: Double = round(((standardAmplitude/amplitude)*digit)/digit)
            
            updateScaleQueue(data: normalizationScale)
            return (true, normalizationScale)
        }
    }
    
    func updateScaleQueue(data: Double) {
        if (self.scaleQueue.count >= 20) {
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
        let currentTime = getCurrentTimeInMilliseconds()
        print(getLocalTimeString() + " , (Olympus) Save NormalizationScale : \(scale)")
        
        // Scale
        do {
            let key: String = "OlympusNormalizationScale_\(sector_id)"
            UserDefaults.standard.set(scale, forKey: key)
        } catch {
            print("(Olympus) Error : Fail to save NormalizattionScale")
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
}
