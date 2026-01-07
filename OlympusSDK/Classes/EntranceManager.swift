
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
    private var entVelocityScalesMap = [String: Float]()
    private var entOuterWardIdMap = [String: String]()
    private var entInnerWardIdMap = [String: String]()
    private var entInnerWardRssiMap = [String: Float]()
    private var entInnerWardCoordMap = [String: xyhs]()
    
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
        self.entVelocityScalesMap[key] = data.velocityScale
        self.entOuterWardIdMap[key] = data.outerWardId
        self.entInnerWardIdMap[key] = data.innerWardId
        self.entInnerWardRssiMap[key] = data.innerWardRssi
        self.entInnerWardCoordMap[key] = xyhs(x: data.innerWardCoord[0], y: data.innerWardCoord[1], heading: data.innerWardCoord[2])
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
        let scale = Double(entVelocityScalesMap[curEntKey] ?? 1.0)
        let scaledLength = length*scale
        scaledDistance += scaledLength
        var roundedIndex = Int(round(scaledDistance))
        JupiterLogger.i(tag: "EntranceManager", message: "(trackEntRoute) - uvd index = \(uvd.index) // length = \(length) // scale = \(scale) // scaledLength = \(scaledLength) // scaledDistance =\(scaledDistance)")
        
        guard let routeData = self.entRouteMap[curEntKey] else { return nil }
        let entRouteLevel = routeData.routeLevel
        let entRouteCoord = routeData.route
        
        if roundedIndex >= entRouteCoord.count-1 {
            roundedIndex = entRouteCoord.count-1
            isLastEntPos = true
        } else {
            isLastEntPos = false
        }
        JupiterLogger.i(tag: "EntranceManager", message: "(trackEntRoute) - roundedIndex = \(roundedIndex) // route size = \(entRouteCoord.count-1)")
        
        let result = FineLocationTrackingOutput(mobile_time: currentTime,
                                                index: uvd.index,
                                                building_name: entTrackBuilding,
                                                level_name: entRouteLevel[roundedIndex],
                                                scc: 1.0,
                                                x: entRouteCoord[roundedIndex][0],
                                                y: entRouteCoord[roundedIndex][1],
                                                absolute_heading: entRouteCoord[roundedIndex][2])
        JupiterLogger.i(tag: "EntranceManager", message: "(trackEntRoute) - entTrackResult : \(result.building_name) , \(result.level_name) , \(result.x) , \(result.y) , \(result.absolute_heading)")
        return result
    }
        
    func stopEntTrack(curResult: FineLocationTrackingOutput?, wardId: String) -> FineLocationTrackingOutput? {
        guard let curEntKey = self.curEntKey else { return nil }
        guard let curResult = curResult else { return nil }
        guard let innerWardId = entInnerWardIdMap[curEntKey] else { return nil }
        guard let wardCoord = entInnerWardCoordMap[curEntKey] else { return nil }
        
        if innerWardId == wardId {
            var result = curResult
            result.x = wardCoord.x
            result.y = wardCoord.y
            result.absolute_heading = wardCoord.heading
            result.level_name = getEntTrackEndLevel()
            
            return result
        } else {
            return nil
        }
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
}

