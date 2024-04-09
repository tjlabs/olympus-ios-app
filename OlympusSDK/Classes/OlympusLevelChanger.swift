public class OlympusLevelChanger {
    init() {
        
    }
    
    public var travelingOsrDistance: Double = 0
    
    public func accumulateOsrDistance(unitLength: Double, isGetFirstResponse: Bool, mode: String, result: FineLocationTrackingResult) {
        if (isGetFirstResponse && mode == OlympusConstants.MODE_DR) {
            let lastResult = result
            if (lastResult.building_name != "" && lastResult.level_name != "") {
                self.travelingOsrDistance += unitLength
            }
        }
    }
    
    public func estimateLevel(isGetFirstResponse: Bool, isInNetworkBadEntrance: Bool, mode: String, phase: Int) {
//        let currentTime = getCurrentTimeInMilliseconds()
//        var isRunOsr: Bool = true
//        if (isGetFirstResponse && !isInNetworkBadEntrance) {
//            if (mode != OlympusConstants.MODE_PDR) {
//                if (phase == 4) {
//                    let isInLevelChangeArea = self.checkInLevelChangeArea(result: self.jupiterResult, mode: mode)
//                    if (!isInLevelChangeArea) {
//                        isRunOsr = false
//                    }
//                }
//                
//                if (isRunOsr) {
//                    let input = OnSpotRecognition(user_id: self.user_id, mobile_time: currentTime, normalization_scale: self.normalizationScale, device_min_rss: Int(self.deviceMinRss), standard_min_rss: Int(self.standardMinRss))
//                    NetworkManager.shared.postOSR(url: OSR_URL, input: input, completion: { [self] statusCode, returnedString in
//                        if (statusCode == 200) {
//                            let result = decodeOSR(json: returnedString)
//                            if (result.building_name != "" && result.level_name != "") {
//                                let isOnSpot = isOnSpotRecognition(result: result, level: self.currentLevel)
//                                if (isOnSpot.isOn) {
//                                    let levelDestination = isOnSpot.levelDestination + isOnSpot.levelDirection
//                                    determineSpotDetect(result: result, lastSpotId: self.lastOsrId, levelDestination: levelDestination, currentTime: currentTime)
//                                }
//                            }
//                        }
//                    })
//                }
//            }
//        } else {
//            self.travelingOsrDistance = 0
//        }
    }
}
