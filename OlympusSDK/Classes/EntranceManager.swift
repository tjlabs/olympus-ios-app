
import Foundation
import TJLabsCommon
import TJLabsResource

class EntranceManager {
    init(sectorId: Int) {
        self.sectorId = sectorId
        
        self.curEntKey = nil
        self.checkStartEntTrackFlag = false
        self.checkStartEntTrackTimestamp = 0
        self.scaledDistance = 0
        self.isLastEntPos = false
        self.checkForcedStopEntTrackTimestamp = 0
        self.entTrackFinishedTimestamp = 0
    }
    
    deinit { }
    
    private var entRouteMap = [String: EntranceRouteData]()
    private var entDataMap = [String: EntranceData]()
    private var entOuterWardIdMap = [String: String]()
    private var entInnerWardIdMap = [String: String]()
    
//    private var entVelocityScalesMap = [String: Float]()
//    private var entInnerWardIdMap = [String: String]()
//    private var entInnerWardCoordMap = [String: ixyhs]()
//    private var entInnerWardIds = [String]()
    
    var sectorId: Int
    private var curEntKey: String?
    private var checkStartEntTrackFlag: Bool
    private var checkStartEntTrackTimestamp: Int
    private var scaledDistance: Double
    private var isLastEntPos: Bool
    private var checkForcedStopEntTrackTimestamp: Int
    private var entTrackFinishedTimestamp: Int
    
    func toggleToOutdoor() {
        self.curEntKey = nil
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
        self.entDataMap[key] = data
        
        if let outermostWard = data.outermostWard {
            self.entOuterWardIdMap[key] = outermostWard.name
        }
        
        if let innermostWard = data.innermostWard {
            self.entInnerWardIdMap[key] = innermostWard.name
        }
        
//        self.entVelocityScalesMap[key] = data.velocityScale
//        self.entOuterWardIdMap[key] = data.outerWardId
//        self.entInnerWardIdMap[key] = data.innerWardId
//        self.entInnerWardRssiMap[key] = data.innerWardRssi
//        self.entInnerWardCoordMap[key] = ixyhs(x: data.innerWardCoord[0], y: data.innerWardCoord[1], heading: data.innerWardCoord[2])
    }
    
    func checkStartEntTrack(wardId: String, sec: Int) -> String? {
        if entRouteMap.isEmpty {
            curEntKey = nil
            checkStartEntTrackFlag = false
        }
        JupiterLogger.i(tag: "EntranceManager", message: "(checkStartEntTrack) - checkStartEntTrackFlag = \(checkStartEntTrackFlag) // wardId = \(wardId)")
        
        if !checkStartEntTrackFlag {
            JupiterLogger.i(tag: "EntranceManager", message: "(checkStartEntTrack) - entOuterWardIdMap = \(entOuterWardIdMap)")
            if entOuterWardIdMap.values.contains(wardId) {
                curEntKey = entOuterWardIdMap.first(where: { $0.value == wardId })?.key ?? nil
                checkStartEntTrackFlag = true
                checkStartEntTrackTimestamp = TJLabsUtilFunctions.shared.getCurrentTimeInMilliseconds(as: .int) as! Int
            }
        }
        
        JupiterLogger.i(tag: "EntranceManager", message: "(checkStartEntTrack) - entering entrance... // key = \(curEntKey)")
        let timeDiff = TJLabsUtilFunctions.shared.getCurrentTimeInMilliseconds(as: .int) as! Int - checkStartEntTrackTimestamp
        JupiterLogger.i(tag: "EntranceManager", message: "(checkStartEntTrack) - timeDiff = \(timeDiff)")
        
        if (timeDiff >= sec * JupiterTime.SECONDS_TO_MILLIS && checkStartEntTrackFlag) {
            checkStartEntTrackFlag = false
        }
        
        return curEntKey
    }
        
    func startEntTrack(currentTime: Int, uvd: UserVelocity) -> FineLocationTrackingOutput? {
        guard let curEntKey = self.curEntKey else { return nil }
        let entTrackData = curEntKey.split(separator: "_")
        let entTrackBuilding = String(entTrackData[1])
        
        let length = uvd.length
        
        guard let entData = entDataMap[curEntKey] else { return nil }
        let scale = Double(entData.velocityScale)
  
        let scaledLength = length*scale
        scaledDistance += scaledLength
        var roundedIndex = Int(round(scaledDistance))
//        JupiterLogger.i(tag: "EntranceManager", message: "(trackEntRoute) - uvd index = \(uvd.index) // length = \(length) // scale = \(scale) // scaledLength = \(scaledLength) // scaledDistance =\(scaledDistance)")
        
        guard let routeData = self.entRouteMap[curEntKey] else { return nil }
        let entRouteLevel = routeData.routeLevel
        let entRouteCoord = routeData.route
        
        if roundedIndex >= entRouteCoord.count-1 {
            roundedIndex = entRouteCoord.count-1
            isLastEntPos = true
        } else {
            isLastEntPos = false
        }
//        JupiterLogger.i(tag: "EntranceManager", message: "(trackEntRoute) - roundedIndex = \(roundedIndex) // route size = \(entRouteCoord.count-1)")
        
        let result = FineLocationTrackingOutput(mobile_time: currentTime,
                                                index: uvd.index,
                                                building_name: entTrackBuilding,
                                                level_name: entRouteLevel[roundedIndex],
                                                scc: 1.0,
                                                x: entRouteCoord[roundedIndex][0],
                                                y: entRouteCoord[roundedIndex][1],
                                                absolute_heading: entRouteCoord[roundedIndex][2])
//        JupiterLogger.i(tag: "EntranceManager", message: "(trackEntRoute) - entTrackResult : \(result.building_name) , \(result.level_name) , \(result.x) , \(result.y) , \(result.absolute_heading)")
        return result
    }
            
    func forcedStopEntTrack(bleAvg: [String: Float], sec: Int) -> Bool {
        guard let curEntKey = self.curEntKey else { return false }
        let currentTime = TJLabsUtilFunctions.shared.getCurrentTimeInMilliseconds(as: .int) as! Int
        
//        JupiterLogger.i(tag: "EntranceManager", message: "(forcedStopEntTrack) - start & stop : stop -> forcedStopEntTrack // time = \(currentTime), isLastEntrancePosition = \(isLastEntPos)")

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
    
    func getEntTrackEndBuilding() -> String {
        guard let curEntKey = self.curEntKey else { return "" }
        
        let keyString = curEntKey.split(separator: "_")
        if keyString.isEmpty || keyString.count < 4 {
            return ""
        } else {
            return String(keyString[1])
        }
    }
    
    private func getEntTrackEndLevel() -> String {
        guard let curEntKey = self.curEntKey else { return "" }

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
    
    func getEntInnermostWardCoord(key: String) -> [Float]? {
        guard let entData = entDataMap[key], let innermostWard = entData.innermostWard else { return nil }
        let coord: [Float] = [Float(innermostWard.x), Float(innermostWard.y)]
        return coord
    }
    
    func getEntInnermostWardIds() -> [String] {
        return Array(self.entInnerWardIdMap.values)
    }
    
    func stopEntTrack(wardId: String) -> InnermostWard? {
        guard let curEntKey = self.curEntKey,
              let innerWardId = entInnerWardIdMap[curEntKey],
              let entData = entDataMap[curEntKey],
              let innermostWard = entData.innermostWard else { return nil }
        
        if innerWardId == wardId {
            return innermostWard
        } else {
            return nil
        }
    }
}

