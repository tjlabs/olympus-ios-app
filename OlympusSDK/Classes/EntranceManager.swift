
import Foundation
import TJLabsCommon
import TJLabsResource

class EntranceManager {
    init(sector_id: Int) {
        self.sector_id = sector_id
        
        self.curEntKey = ""
        self.checkStartEntTrackFlag = false
        self.checkStartEntTrackTimestamp = 0
        self.scaledDistance = 0
        self.isLastEntPos = false
        self.checkForcedStopEntTrackTimestamp = 0
        self.entTrackFinishedTimestamp = 0
    }
    
    deinit { }
    
    private var entRouteMap = [String: EntranceRouteData]()
    private var entVelocityScalesMap = [String: Float]()
    private var entOuterWardIdMap = [String: String]()
    private var entInnerWardIdMap = [String: String]()
    private var entInnerWardRssiMap = [String: Float]()
    private var entInnerWardCoordMap = [String: xyhs]()
    
    var sector_id: Int
    private var curEntKey: String
    private var checkStartEntTrackFlag: Bool
    private var checkStartEntTrackTimestamp: Int
    private var scaledDistance: Double
    private var isLastEntPos: Bool
    private var checkForcedStopEntTrackTimestamp: Int
    private var entTrackFinishedTimestamp: Int
    
    func toggleToOutdoor() {
        self.curEntKey = ""
        self.checkStartEntTrackFlag = false
        self.checkStartEntTrackTimestamp = 0
        self.scaledDistance = 0
        self.isLastEntPos = false
        self.checkForcedStopEntTrackTimestamp = 0
        self.entTrackFinishedTimestamp = 0
    }
    
    func setEntRouteData(key: String, data: EntranceRouteData) {
        self.entRouteMap[key] = data
    }
    
    func setEntData(key: String, data: EntranceData) {
        self.entVelocityScalesMap[key] = data.velocityScale
        self.entOuterWardIdMap[key] = data.outerWardId
        self.entInnerWardIdMap[key] = data.innerWardId
        self.entInnerWardRssiMap[key] = data.innerWardRssi
        self.entInnerWardCoordMap[key] = xyhs(x: data.innerWardCoord[0], y: data.innerWardCoord[1], heading: data.innerWardCoord[2])
    }
    
    func checkStartEntTrack(bleAvg: [String: Float], sec: Int) -> EntranceCheckerResult {
        var check: Bool = false
        if entRouteMap.isEmpty || bleAvg.isEmpty {
            curEntKey = ""
            checkStartEntTrackFlag = false
        }
        JupiterLogger.i(tag: "EntranceManager", message: "(checkStartEntTrack) - checkStartEntTrackFlag = \(checkStartEntTrackFlag) // bleAvg = \(bleAvg)")
        
        if !checkStartEntTrackFlag {
            for key in bleAvg.keys {
                if entOuterWardIdMap.values.contains(key) {
                    curEntKey = entOuterWardIdMap.first(where: { $0.value == key })?.key ?? ""
                    checkStartEntTrackFlag = true
                    checkStartEntTrackTimestamp = TJLabsUtilFunctions.shared.getCurrentTimeInMilliseconds(as: .int) as! Int
                }
            }
        }
        
        JupiterLogger.i(tag: "EntranceManager", message: "(checkStartEntTrack) - entering entrance... // key = \(curEntKey)")
        let timeDiff = TJLabsUtilFunctions.shared.getCurrentTimeInMilliseconds(as: .int) as! Int - checkStartEntTrackTimestamp
        JupiterLogger.i(tag: "EntranceManager", message: "(checkStartEntTrack) - timeDiff = \(timeDiff)")
        
        if (timeDiff >= sec * JupiterTime.SECONDS_TO_MILLIS && checkStartEntTrackFlag) {
            if (bleAvg.count >= 2) {
                var bleRssiConditionCount = 0
                for (_, value) in bleAvg {
                    if value >= -90 {
                        bleRssiConditionCount += 1
                    }
                    
                    if (bleRssiConditionCount >= 2) {
                        checkStartEntTrackFlag = false
                        check = true
                        break
                    }
                }
            }
        }
        
        return EntranceCheckerResult(is_entered: check, key: curEntKey)
    }
        
    func startEntTrack(uvd: UserVelocity, curResult: FineLocationTrackingOutput) -> FineLocationTrackingOutput {
        var result = curResult
            
        if curEntKey != "" {
            let length = uvd.length
            let scale = Double(entVelocityScalesMap[curEntKey] ?? 1.0)
            let scaledLength = length*scale
            scaledDistance += scaledLength
            var roundedIndex = Int(round(scaledDistance))
            JupiterLogger.i(tag: "EntranceManager", message: "(trackEntRoute) - uvd index = \(uvd.index) // length = \(length) // scale = \(scale) // scaledLength = \(scaledLength) // scaledDistance =\(scaledDistance)")
            
            guard let routeData = self.entRouteMap[curEntKey] else { return result }
            let entRouteLevel = routeData.routeLevel
            let entRouteCoord = routeData.route
            
            if roundedIndex >= entRouteCoord.count-1 {
                roundedIndex = entRouteCoord.count-1
                isLastEntPos = true
            } else {
                isLastEntPos = false
            }
            JupiterLogger.i(tag: "EntranceManager", message: "(trackEntRoute) - roundedIndex = \(roundedIndex) // route size = \(entRouteCoord.count-1)")
            
            result.level_name = entRouteLevel[roundedIndex]
            result.x = entRouteCoord[roundedIndex][0]
            result.y = entRouteCoord[roundedIndex][1]
            result.absolute_heading = entRouteCoord[roundedIndex][2]
            JupiterLogger.i(tag: "EntranceManager", message: "(trackEntRoute) - entTrackResult : \(result.building_name) , \(result.level_name) , \(result.x) , \(result.y) , \(result.absolute_heading)")
            return result
        } else {
            return result
        }
    }
        
    func stopEntTrack(curResult: FineLocationTrackingOutput, bleAvg: [String: Float], normalizationScale: Float, deviceMinRss: Float, standardMinRss: Float) -> (Bool, FineLocationTrackingOutput) {
        var result = curResult
            
        if let bleID = entInnerWardIdMap[curEntKey] {
            if let scannedRSSI = bleAvg[bleID] {
                if let thresholdRSSI = entInnerWardRssiMap[curEntKey] {
                    if let wardCoord = entInnerWardCoordMap[curEntKey] {
                        let normalizedRSSI = (scannedRSSI - deviceMinRss)*normalizationScale + standardMinRss
                        result.x = wardCoord.x
                        result.y = wardCoord.y
                        result.absolute_heading = wardCoord.heading
                        result.level_name = getEntTrackEndLevel()
                        return normalizedRSSI >= thresholdRSSI ? (true, result) : (false, result)
                    } else {
                        return (false, result)
                    }
                } else {
                    return (false, result)
                }
            } else {
                return (false, result)
            }
        } else {
            return (false, result)
        }
    }
    
    func forcedStopEntTrack(bleAvg: [String: Float], sec: Int) -> Bool {
        let currentTime = TJLabsUtilFunctions.shared.getCurrentTimeInMilliseconds(as: .int) as! Int
        JupiterLogger.i(tag: "EntranceManager", message: "(forcedStopEntTrack) - start & stop : stop -> forcedStopEntTrack // time = \(currentTime), isLastEntrancePosition = \(isLastEntPos)")

        if isLastEntPos && curEntKey != "" {
            if let bleID = entInnerWardIdMap[curEntKey] {
                let scannedRSSI = bleAvg[bleID]
                if scannedRSSI == nil && checkForcedStopEntTrackTimestamp != 0 {
                    let timeDiff = currentTime - checkForcedStopEntTrackTimestamp
                    if timeDiff >= sec*1000 {
                        return true
                    }
                } else {
                    checkForcedStopEntTrackTimestamp = TJLabsUtilFunctions.shared.getCurrentTimeInMilliseconds(as: .int) as! Int
                }
            }
        }
        return false
    }
    
    private func getEntTrackEndLevel() -> String {
        if let entRouteData = entRouteMap[curEntKey] {
            let entRouteLevel = entRouteData.routeLevel
            if !entRouteLevel.isEmpty {
                let levelName = entRouteLevel[entRouteLevel.count-1]
                return levelName
            }
        }
        return ""
    }
    
    func setEntTrackFinishedTimestamp(time: Int) {
        self.entTrackFinishedTimestamp = time
    }
}

