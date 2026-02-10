
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
        
        self.setEntPeakData()
    }
    
    deinit { }
    
    private var entRouteMap = [String: EntranceRouteData]()
//    private var entVelocityScalesMap = [String: Float]()
    private var entOuterWardIdMap = [String: String]()
    private var entInnerWardIdMap = [String: String]()
    private var entInnerWardCoordMap = [String: ixyhs]()
    private var entInnerWardIds = [String]()
    
    //temp
    private var entPeakMap = [String: EntrancePeakData]()
    
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
//        self.entVelocityScalesMap[key] = data.velocityScale
        self.entOuterWardIdMap[key] = data.outerWardId
//        self.entInnerWardIdMap[key] = data.innerWardId
//        self.entInnerWardRssiMap[key] = data.innerWardRssi
        self.entInnerWardCoordMap[key] = ixyhs(x: data.innerWardCoord[0], y: data.innerWardCoord[1], heading: data.innerWardCoord[2])
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
        var scale = 1.0
        if let entPeak = entPeakMap[curEntKey] {
            scale = Double(entPeak.velocityScale)
        }
//        let scale = Double(entVelocityScalesMap[curEntKey] ?? 1.0)
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
    
    // Temp
    func setEntPeakData() {
        let ent1 = EntrancePeakData(number: 1,
                                    velocityScale: 1.25,
                                    inner_ward: InnerWardData(type: 1, wardId: "TJ-00CB-00000320-0000", building: "COEX", level: "B2", x: 252, y: 95, direction: [90]),
                                    outerWardId: "TJ-00CB-000003F8-0000")
        let ent2 = EntrancePeakData(number: 2,
                                    velocityScale: 0.68,
                                    inner_ward: InnerWardData(type: 0, wardId: "TJ-00CB-00000323-0000", building: "COEX", level: "B2", x: 250, y: 182, direction: [90]),
                                    outerWardId: "TJ-00CB-00000324-0000")
        let ent3 = EntrancePeakData(number: 3,
                                    velocityScale: 0.68,
                                    inner_ward: InnerWardData(type: 0, wardId: "TJ-00CB-00000344-0000", building: "COEX", level: "B2", x: 291, y: 292, direction: [90]),
                                    outerWardId: "TJ-00CB-000003FA-0000")
        let ent4 = EntrancePeakData(number: 4,
                                    velocityScale: 0.82,
                                    inner_ward: InnerWardData(type: 0, wardId: "TJ-00CB-0000026B-0000", building: "COEX", level: "B2", x: 250, y: 442, direction: [180]),
                                    outerWardId: "TJ-00CB-00000221-0000")
        let ent5 = EntrancePeakData(number: 5,
                                    velocityScale: 0.75,
                                    inner_ward: InnerWardData(type: 1, wardId: "TJ-00CB-000002B1-0000", building: "COEX", level: "B2", x: 59, y: 335, direction: [270]),
                                    outerWardId: "TJ-00CB-00000369-0000")
        self.entPeakMap["6_COEX_B0_1"] = ent1
        self.entPeakMap["6_COEX_B0_2"] = ent2
        self.entPeakMap["6_COEX_B0_3"] = ent3
        self.entPeakMap["6_COEX_B0_4"] = ent4
        self.entPeakMap["6_COEX_B0_5"] = ent5
        
        self.entInnerWardIdMap["6_COEX_B0_1"] = ent1.inner_ward.wardId
        self.entInnerWardIdMap["6_COEX_B0_2"] = ent2.inner_ward.wardId
        self.entInnerWardIdMap["6_COEX_B0_3"] = ent3.inner_ward.wardId
        self.entInnerWardIdMap["6_COEX_B0_4"] = ent4.inner_ward.wardId
        self.entInnerWardIdMap["6_COEX_B0_5"] = ent5.inner_ward.wardId
        
        for (key, value) in self.entInnerWardIdMap {
            self.entInnerWardIds.append(value)
        }
    }
    
    func getEntPeakInnerCoord(key: String) -> [Float]? {
        guard let entPeak = entPeakMap[key] else { return nil }
        let coord: [Float] = [entPeak.inner_ward.x, entPeak.inner_ward.y]
        return coord
    }
    
    func getEntInnerWardIds() -> [String] {
        return self.entInnerWardIds
    }
    
    func stopEntTrack_v2(wardId: String) -> EntrancePeakData? {
        guard let curEntKey = self.curEntKey,
              let innerWardId = entInnerWardIdMap[curEntKey],
              let entPeak = entPeakMap[curEntKey] else { return nil }
        
        if innerWardId == wardId {
            return entPeak
        } else {
            return nil
        }
    }
}

