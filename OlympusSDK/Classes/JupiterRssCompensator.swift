
import Foundation
import TJLabsCommon

class JupiterRssCompensator {

    init() {
        normalizationScale = 1.0
        deviceMinRss = -99
        standardMinRss = -99
        standardMaxRss = -60
        
        isScaleLoaded = false
        isScaleSaved = false
        isScaleConverged = false
        
        wardMinRssi = [Float]()
        wardMaxRssi = [Float]()
        
        timeAfterResponse = 0
        preNormalizationScale = 1.0
        preSmoothedNormalizationScale = 1.0
        scaleQueue = [Float]()
        estRssCompenstaionTimestamp = 0
        timeStackEst = 0
    }
    
    deinit { }
    
    var normalizationScale: Float
    var deviceMinRss: Float
    var standardMinRss: Float
    var standardMaxRss: Float
    
    var isScaleLoaded: Bool
    var isScaleSaved: Bool
    var isScaleConverged: Bool
    
    private var wardMinRssi = [Float]()
    private var wardMaxRssi = [Float]()
    
    private var timeAfterResponse: Double
    private var preNormalizationScale: Float
    private var preSmoothedNormalizationScale: Float
    private var scaleQueue = [Float]()
    private var estRssCompenstaionTimestamp: Int
    private var timeStackEst: Double
    
    func toggleToOutdoor() {
        self.timeAfterResponse = 0
        self.timeStackEst = 0
    }
    
    func setStandardMinMax(minMax: [Int]) {
        standardMinRss = Float(minMax[0])
        standardMaxRss = Float(minMax[1])
    }
    
    func estimateNormalizationScale(isGetFirstResponse: Bool, isIndoor: Bool, currentLevel: String, diffMinMaxRssi: Float, minRssi: Float) {
        self.timeStackEst += JupiterTime.RFD_INTERVAL
        
        if (isGetFirstResponse && isIndoor && diffMinMaxRssi >= 25 && minRssi <= -97 && self.timeStackEst >= JupiterRssCompensation.EST_RC_INTERVAL) {
            self.timeStackEst = 0
            if (self.isScaleLoaded) {
                if (currentLevel != "B0") {
                    let normalizationScale = calNormalizationScale(standardMinRss: standardMinRss, standardMaxRss: standardMaxRss)
                    if (!self.isScaleConverged) {
                        if (normalizationScale.0) {
                            let smoothedScale: Float = smoothNormalizationScale(scale: normalizationScale.1)
                            self.normalizationScale = smoothedScale
                            let diffScale = abs(smoothedScale - self.preNormalizationScale)
                            if (diffScale < 1e-3 && self.timeAfterResponse >= JupiterRssCompensation.REQUIRED_RC_CONVERGENCE_TIME && (smoothedScale != self.preNormalizationScale)) {
                                self.isScaleConverged = true
                            }
                            self.preNormalizationScale = smoothedScale
                        } else {
                            let smoothedScale: Float = smoothNormalizationScale(scale: self.preNormalizationScale)
                            self.normalizationScale = smoothedScale
                        }
                    }
                }
            } else {
                if (!self.isScaleConverged) {
                    let normalizationScale = calNormalizationScale(standardMinRss: standardMinRss, standardMaxRss: standardMaxRss)
                    if (normalizationScale.0) {
                        let smoothedScale: Float = smoothNormalizationScale(scale: normalizationScale.1)
                        self.normalizationScale = smoothedScale
                        let diffScale = abs(smoothedScale - self.preNormalizationScale)
                        if (diffScale < 1e-3 && self.timeAfterResponse >= JupiterRssCompensation.REQUIRED_RC_CONVERGENCE_TIME && (smoothedScale != self.preNormalizationScale)) {
                            self.isScaleConverged = true
                        }
                        self.preNormalizationScale = smoothedScale
                    } else {
                        let smoothedScale: Float = smoothNormalizationScale(scale: self.preNormalizationScale)
                        self.normalizationScale = smoothedScale
                    }
                }
            }
        } else if diffMinMaxRssi < 25 {
            // RSSI의 Amplitude가 너무 낮다.
        }
    }
    
    func loadRssiCompensationParam(sector_id: Int, device_model: String, os_version: Int, completion: @escaping (Bool, Float, String) -> Void) {
        var loadedNormalizationScale: Float = 1.0
        
        // Check data in cache
        let loadedScale = loadNormalizationScaleFromCache(sector_id: sector_id)
        
        if loadedScale.0 {
            // Scale is in cache
            loadedNormalizationScale = loadedScale.1
            let msg: String = "(JupiterRssCompensator) Success : Load RssCompensation in cache"
            completion(true, loadedNormalizationScale, msg)
        } else {
            let rcDeviceOsInput = RcDeviceOsInput(sector_id: sector_id, device_model: device_model, os_version: os_version)
            JupiterNetworkManager.shared.getUserRssCompensation(url: JupiterNetworkConstants.getUserRcURL(), input: rcDeviceOsInput, isDeviceOs: true, completion: { [self] statusCode, returnedString in
                if (statusCode == 200) {
                    let rcResult = jsonToRcInfoFromServer(jsonString: returnedString)
                    if (rcResult.0) {
                        if (rcResult.1.rss_compensations.isEmpty) {
                            let rcDeviceInput = RcDeviceInput(sector_id: sector_id, device_model: device_model)
                            JupiterNetworkManager.shared.getUserRssCompensation(url: JupiterNetworkConstants.getUserRcURL(), input: rcDeviceInput, isDeviceOs: false, completion: { [self] statusCode, returnedString in
                                if (statusCode == 200) {
                                    let rcDeviceResult = jsonToRcInfoFromServer(jsonString: returnedString)
                                    if (rcDeviceResult.0) {
                                        if (rcDeviceResult.1.rss_compensations.isEmpty) {
                                            // Need Normalization-scale Estimation
                                            JupiterLogger.i(tag: "JupiterRssCompensator", message: "(loadRssiCompensationParam) - Need RssCompensation Estimation")
                                            let msg: String = "(JupiterRssCompensator) Success : RssCompensation"
                                            completion(true, loadedNormalizationScale, msg)
                                        } else {
                                            // Succes Load Normalization-scale (Device)
                                            if let closest = self.findClosestOs(to: os_version, in: rcDeviceResult.1.rss_compensations) {
                                                // Find Closest OS
                                                let rcFromServer: RcInfo = closest
                                                loadedNormalizationScale = rcFromServer.normalization_scale
                                                JupiterLogger.i(tag: "JupiterRssCompensator", message: "(loadRssiCompensationParam) - Load RssCompensation from server (\(device_model))")
                                                let msg: String = "(JupiterRssCompensator) Success : RssCompensation"
                                                completion(true, loadedNormalizationScale, msg)
                                            } else {
                                                // Need Normalization-scale Estimation
                                                JupiterLogger.i(tag: "JupiterRssCompensator", message: "(loadRssiCompensationParam) - Need RssCompensation Estimation")
                                                let msg: String = "(JupiterRssCompensator) Success : RssCompensation"
                                                completion(true, loadedNormalizationScale, msg)
                                            }
                                        }
                                    } else {
                                        let msg: String = "(JupiterRssCompensator) Error : Decode RssCompensation (\(device_model))"
                                        completion(false, loadedNormalizationScale, msg)
                                    }
                                } else {
                                    let msg: String = "(JupiterRssCompensator) Error : Load RssCompensation (\(device_model)) from server \(statusCode)"
                                    completion(false, loadedNormalizationScale, msg)
                                }
                            })
                        } else {
                            // Succes Load Normalization-scale (Device & OS)
                            let rcFromServer: RcInfo = rcResult.1.rss_compensations[0]
                            loadedNormalizationScale = rcFromServer.normalization_scale
                            JupiterLogger.i(tag: "JupiterRssCompensator", message: "(loadRssiCompensationParam) - Load RssCompensation from server (\(device_model) & \(os_version))")
                            let msg: String = "(JupiterRssCompensator) Success : RssCompensation"
                            completion(true, loadedNormalizationScale, msg)
                        }
                    } else {
                        let msg: String = "(JupiterRssCompensator) Error : Decode RssCompensation (\(device_model) & \(os_version))"
                        completion(false, loadedNormalizationScale, msg)
                    }
                } else {
                    let msg: String = "(JupiterRssCompensator) Error : Load RssCompensation (\(device_model) & \(os_version)) from server \(statusCode)"
                    completion(false, loadedNormalizationScale, msg)
                }
            })
        }
    }
    
    func getRssCompensationParam() -> RssCompensationParam {
        let param: RssCompensationParam = RssCompensationParam(device_min_rss: self.deviceMinRss, standard_min_rss: self.standardMinRss, normalization_scale: self.normalizationScale)
        return param
    }
    
    func findClosestOs(to myOsVersion: Int, in array: [RcInfo]) -> RcInfo? {
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
    
    func isPossibleToSaveToCache() -> Bool {
        return isScaleConverged && !isScaleConverged ? true : false
    }
    
    func saveNormalizationScaleToCache(sector_id: Int) {
        let scale = normalizationScale
        JupiterLogger.i(tag: "JupiterRssCompensator", message: "(saveNormalizationScaleToCache) - Save NormalizationScale : \(scale)")
        do {
            let key: String = "JupiterNormalizationScale_\(sector_id)"
            UserDefaults.standard.set(scale, forKey: key)
        }
    }
    
    func loadNormalizationScaleFromCache(sector_id: Int) -> (Bool, Float) {
        var isLoadedFromCache: Bool = false
        var scale: Float = 1.0
        
        let keyScale: String = "JupiterNormalizationScale_\(sector_id)"
        if let loadedScale: Float = UserDefaults.standard.object(forKey: keyScale) as? Float {
            scale = loadedScale
            isLoadedFromCache = true
            if (scale >= 1.7) {
                scale = 1.0
            }
        }
        
        return (isLoadedFromCache, scale)
    }
    
    func getMinRssi() -> Float {
        if (self.wardMinRssi.isEmpty) {
            return -60.0
        } else {
            let avgMin = self.wardMinRssi.average
            return Float(avgMin)
        }
    }
    
    func getMaxRssi() -> Float {
        if (self.wardMaxRssi.isEmpty) {
            return -90.0
        } else {
            let avgMax = self.wardMaxRssi.average
            return Float(avgMax)
        }
    }
    
    func refreshWardMinRssi(bleData: [String: Float]) {
        for (_, value) in bleData {
            if (value > -100) {
                if (self.wardMinRssi.isEmpty) {
                    self.wardMinRssi.append(value)
                } else {
                    let newArray = appendAndKeepMin(inputArray: self.wardMinRssi, newValue: value)
                    self.wardMinRssi = newArray
                }
            }
        }
    }
    
    func refreshWardMaxRssi(bleData: [String: Float]) {
        for (_, value) in bleData {
            if (self.wardMaxRssi.isEmpty) {
                self.wardMaxRssi.append(value)
            } else {
                let newArray = appendAndKeepMax(inputArray: self.wardMaxRssi, newValue: value)
                self.wardMaxRssi = newArray
            }
        }
    }
    
    func calNormalizationScale(standardMinRss: Float, standardMaxRss: Float) -> (Bool, Float) {
        let standardAmplitude: Float = abs(standardMaxRss - standardMinRss)
        if (wardMaxRssi.isEmpty || wardMinRssi.isEmpty) {
            return (false, 1.0)
        } else {
            let avgMax = Float(wardMaxRssi.average)
            let avgMin = Float(wardMinRssi.average)
            
            deviceMinRss = avgMax
            let amplitude: Float = abs(avgMax - avgMin)
            
            let digit: Float = pow(10, 4)
            var normalizationScale: Float = (standardAmplitude/amplitude)*digit/digit
            
            if normalizationScale > 1.2 {
                normalizationScale = 1.2
            } else if normalizationScale < 0.8 {
                normalizationScale = 0.8
            }
            updateScaleQueue(data: normalizationScale)
            JupiterLogger.i(tag: "JupiterRssCompensator", message: "(calNormalizationScale) - wardMaxRssi = \(wardMaxRssi) // wardMinRssi = \(wardMinRssi) // standardMax = \(standardMaxRss) // standardMin = \(standardMinRss) // normalizationScale = \(normalizationScale)")
            return (true, normalizationScale)
        }
    }
    
    func updateScaleQueue(data: Float) {
        if (self.scaleQueue.count >= 10) {
            self.scaleQueue.remove(at: 0)
        }
        self.scaleQueue.append(data)
    }
    
    func smoothNormalizationScale(scale: Float) -> Float {
        var smoothedScale: Float = 1.0
        if (self.scaleQueue.count == 1) {
            smoothedScale = scale
        } else {
            smoothedScale = Float(movingAverage(preMvalue: Double(self.preSmoothedNormalizationScale), curValue: Double(scale), windowSize: self.scaleQueue.count))
        }
        self.preSmoothedNormalizationScale = smoothedScale
        
        return smoothedScale
    }
    
    func appendAndKeepMin(inputArray: [Float], newValue: Float) -> [Float] {
        var array: [Float] = inputArray
        array.append(newValue)
        if array.count > JupiterRssCompensation.ARRAY_SIZE {
            if let maxValue = array.max() {
                if let index = array.firstIndex(of: maxValue) {
                    array.remove(at: index)
                }
            }
        }
        return array
    }
    
    func appendAndKeepMax(inputArray: [Float], newValue: Float) -> [Float] {
        var array: [Float] = inputArray
        array.append(newValue)
        
        if array.count > JupiterRssCompensation.ARRAY_SIZE {
            if let minValue = array.min() {
                if let index = array.firstIndex(of: minValue) {
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
    
    func stackTimeAfterResponse() {
        if (self.timeAfterResponse < JupiterRssCompensation.REQUIRED_RC_CONVERGENCE_TIME) {
            self.timeAfterResponse += JupiterTime.RFD_INTERVAL
        }
    }
    
    func jsonToRcInfoFromServer(jsonString: String) -> (Bool, RcInfoOutputList) {
        let result = RcInfoOutputList(rss_compensations: [])
        
        if let jsonData = jsonString.data(using: .utf8) {
            do {
                let decodedData: RcInfoOutputList = try JSONDecoder().decode(RcInfoOutputList.self, from: jsonData)
                return (true, decodedData)
            } catch {
                JupiterLogger.e(tag: "JupiterRssCompensator", message: "(jsonToRcInfoFromServer) - Error decoding JSON: \(error)")
                return (false, result)
            }
        } else {
            return (false, result)
        }
    }
}
