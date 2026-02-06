
import TJLabsCommon
import TJLabsResource

protocol BuildingLevelChangerDelegate: AnyObject {
    func isBuildingLevelChanged(isChanged: Bool, newBuilding: String, newLevel: String, newCoord: [Float])
}

class BuildingLevelChanger {
    
    init(sectorId: Int) {
        self.sectorId = sectorId
        
        buildingLevelChangedTime = 0
        distAfterTagDetection = 0
        lastTag = 0
        buildingsAndLevels = [String: [String]]()
    }
    
    deinit { }
    
    weak var delegate: BuildingLevelChangerDelegate?
    
    let DEFAULT_TAG_DISTANCE: Float = 70
    
    var sectorId: Int
    var blChangerTagMap = [Int: [BuildingLevelTag]]()
    var buildingsAndLevelsMap = [String: [String]]()
    var levelChangeAreaMap = [String: [[Float]]]()
    var levelWardsMap = [String: [LevelWard]]()

    var buildingLevelChangedTime: Int
    
    private var distAfterTagDetection: Float
    private var lastTag: Int
    private var buildingsAndLevels = [String: [String]]()
    
    func toggleToOutdoor() {
        buildingLevelChangedTime = 0
        distAfterTagDetection = 0
        
        lastTag = 0
    }
    
    func setLevelWards(levelKey: String, levelWardsData: [LevelWard]) {
        levelWardsMap[levelKey] = levelWardsData
    }
    
    func setBuildingsData(buildingsData: [BuildingOutput]) {
        let buildingLevelData = makeBuildingLevelInfo(buildingsData: buildingsData)
        buildingsAndLevelsMap = buildingLevelData
    }
    
    func setLevelChangeArea(key: String, data: [[Float]]) {
        levelChangeAreaMap[key] = data
    }
    
    func getLevelChangeArea(key: String) -> [[Float]]? {
        return levelChangeAreaMap[key]
    }
    
    func setBuildingLevelTagData(key: Int, blChangerTagData: [BuildingLevelTag]) {
        blChangerTagMap[key] = blChangerTagData
        JupiterLogger.i(tag: "BuildingLevelChanger", message: "(setBuildingLevelTagData) - \(blChangerTagData)")
    }
    
    func accumulateDistance(uvd: UserVelocity, isGetFirstResponse: Bool, mode: UserMode, result: FineLocationTrackingOutput) {
        if (isGetFirstResponse && mode == .MODE_VEHICLE) {
            let lastResult = result
            if (lastResult.building_name != "" && lastResult.level_name != "") {
                self.distAfterTagDetection += Float(uvd.length)
            }
        }
    }
    
    func determineTagDetection(time: Int, tag: BuildingLevelTag, buildingDestination: String, levelDestination: String, tagCoord: [Float], curResult: FineLocationTrackingOutput?) -> BuildingLevelTagResult? {
        guard let curResult = curResult else { return nil }
        let curBuilding = curResult.building_name
        let curLevel = curResult.level_name
        
        var tagDistance = Float(tag.distance)
        if (tagDistance == 0) {
            tagDistance = DEFAULT_TAG_DISTANCE
        }
        
        let levelArray: [String] = [tag.level_name, tag.linked_level_name]
        let TIME_CONDITION = levelArray.contains("B0") && levelArray.contains(where: { $0 != "B0" }) ? JupiterTime.MINIMUM_BUILDING_LEVEL_CHANGE_TIME*3 : JupiterTime.MINIMUM_BUILDING_LEVEL_CHANGE_TIME
        
        if (tag.id != lastTag) {
            // Different Tag Detected
            let resultLevelName: String = TJLabsUtilFunctions.shared.removeLevelDirectionString(levelName: levelDestination)
            if (buildingDestination != curBuilding || resultLevelName != curLevel) {
                if ((Double(time - self.buildingLevelChangedTime)) > TIME_CONDITION) {
                    // Building Level 이 바뀐지 7초 이상 지남 -> 서버 결과를 이용해 바뀌어야 한다고 판단
                    self.lastTag = tag.id
                    self.distAfterTagDetection = 0
                    setBuildingLevelChangedTime(value: time)
                    let detectionResult = BuildingLevelTagResult(building: buildingDestination, level: levelDestination, x: tagCoord[0], y: tagCoord[1])
                    JupiterLogger.i(tag: "BuildingLevelChanger", message: "(determineTagDetection) blTagResult: \(detectionResult)")
                    return detectionResult
//                    self.delegate?.isBuildingLevelChanged(isChanged: true, newBuilding: buildingDestination, newLevel: levelDestination, newCoord: tagCoord)
                }
            }
        } else {
            // Same Tag Detected
            if (self.distAfterTagDetection >= tagDistance) {
                let resultLevelName: String = TJLabsUtilFunctions.shared.removeLevelDirectionString(levelName: levelDestination)
                if (buildingDestination != curBuilding || resultLevelName != curLevel) {
                    if (Double(time - self.buildingLevelChangedTime) > TIME_CONDITION) {
                        // Building Level 이 바뀐지 7초 이상 지남 -> 서버 결과를 이용해 바뀌어야 한다고 판단
                        self.lastTag = tag.id
                        self.distAfterTagDetection = 0
                        setBuildingLevelChangedTime(value: time)
                        
                        let detectionResult = BuildingLevelTagResult(building: buildingDestination, level: levelDestination, x: tagCoord[0], y: tagCoord[1])
                        JupiterLogger.i(tag: "BuildingLevelChanger", message: "(determineTagDetection) blTagResult: \(detectionResult)")
                        return detectionResult
//                        self.delegate?.isBuildingLevelChanged(isChanged: true, newBuilding: buildingDestination, newLevel: levelDestination, newCoord: tagCoord)
                    }
                }
            }
        }
        
        return nil
    }
    
    func isBuildingLevelChangerTagged(userPeak: UserPeak, curResult: FineLocationTrackingOutput?, mode: UserMode) -> BuildingLevelTag? {
        let sectorKey = self.sectorId
        guard let sectorTagData = self.blChangerTagMap[sectorKey], let result = curResult else { return nil }
        
        if !checkInLevelChangeArea(sectorId: sectorId, building: result.building_name, level: result.level_name, x: result.x, y: result.y, mode: mode) {
//            JupiterLogger.i(tag: "BuildingLevelChanger", message: "(isBuildingLevelChangerTagged) - not in LevelChangeArea")
            return nil
        }
        
        let tagValues: [BuildingLevelTag] = sectorTagData
//        JupiterLogger.i(tag: "BuildingLevelChanger", message: "(isBuildingLevelChangerTagged) - UserPeak: \(userPeak.id)")
        for item in tagValues {
            let tagLevelList = [item.level_name, item.linked_level_name]
            if item.name == userPeak.id && tagLevelList.contains(result.level_name) {
//                JupiterLogger.i(tag: "BuildingLevelChanger", message: "(isBuildingLevelChangerTagged) - \(item.name) tagged with userPeak \(userPeak.id)")
                return item
            }
        }
        
        return nil
    }
    
    func getBuildingLevelDestination(tag: BuildingLevelTag, curResult: FineLocationTrackingOutput?) -> (buildingDestination: String, levelDestination: String)? {
        guard let curResult = curResult else { return nil }
        let curBuilding: String = curResult.building_name
        let curLevel: String = curResult.level_name
        
        let tagBuildingName = tag.building_name == "" ? curBuilding : tag.building_name
//        JupiterLogger.i(tag: "BuildingLevelChanger", message: "(getBuildingLevelDestination) - cur: [\(curBuilding),\(curLevel)] -> dest:[\(tagBuildingName), \(tag.level_name) & \(tag.linked_level_name)]")
        var buildingDestination: String = curBuilding
        var levelDestination: String = curLevel
        
        if curBuilding != tagBuildingName {
            // Building 바뀜
            buildingDestination = tagBuildingName
            levelDestination = tag.level_name
            
            return (buildingDestination, levelDestination)
        } else {
            // Level만 바뀜
            let linked_level_name = tag.linked_level_name
            let levelArray: [String] = [curLevel, linked_level_name]
            
            if (linked_level_name == "") {
                return nil
            } else {
                if (curLevel == linked_level_name) {
                    return nil
                }
                
                let levelNameCorrected: String = TJLabsUtilFunctions.shared.removeLevelDirectionString(levelName: curLevel)
                for i in 0..<levelArray.count {
                    if levelArray[i] != levelNameCorrected {
                        levelDestination = levelArray[i]
                    }
                }
                
                return (buildingDestination, levelDestination)
            }
        }
    }
    
    func setBuildingLevelChangedTime(value: Int) {
        self.buildingLevelChangedTime = value
    }
    
    public func updateBuildingAndLevel(fltResult: FineLocationTrackingOutput, currentBuilding: String, currentLevel: String) -> (Bool, FineLocationTrackingOutput) {
        var result = fltResult
        
        let currentTime = TJLabsUtilFunctions.shared.getCurrentTimeInMilliseconds(as: .int) as! Int
        let resultLevelName = TJLabsUtilFunctions.shared.removeLevelDirectionString(levelName: fltResult.level_name)
        let currentLevelName = TJLabsUtilFunctions.shared.removeLevelDirectionString(levelName: currentLevel)
        
        let levelArray: [String] = [resultLevelName, currentLevelName]
        let TIME_CONDITION = levelArray.contains("B0") && levelArray.contains(where: { $0 != "B0" }) ? JupiterTime.MINIMUM_BUILDING_LEVEL_CHANGE_TIME*3 : JupiterTime.MINIMUM_BUILDING_LEVEL_CHANGE_TIME
        
        var isBuildingLevelChanged: Bool = false
        if (fltResult.building_name != currentBuilding || resultLevelName != currentLevelName) {
            if (Double(fltResult.mobile_time - buildingLevelChangedTime) > TIME_CONDITION) {
                if (currentBuilding != "" && currentLevel != "0F") {
                    setBuildingLevelChangedTime(value: currentTime)
                }
                // Building Level 이 바뀐지 10초 이상 지남 -> 서버 결과를 이용해 바뀌어야 한다고 판단
                result.building_name = fltResult.building_name
                result.level_name = resultLevelName
                isBuildingLevelChanged = true
            }
        }
        
        if (!isBuildingLevelChanged) {
            result.building_name = currentBuilding
            result.level_name = currentLevel
        }
        
        return (isBuildingLevelChanged, result)
    }
    
    private func makeBuildingLevelInfo(buildingsData: [BuildingOutput]) -> [String: [String]] {
        var infoBuildingLevel = [String: [String]]()
        for building in buildingsData {
            let buildingName = building.name
            for level in building.levels {
                let levelName = level.name
                if var levels = infoBuildingLevel[buildingName] {
                    levels.append(levelName)
                    infoBuildingLevel[buildingName] = levels.sorted(by: { lhs, rhs in
                        return compareFloorNames(lhs: lhs, rhs: rhs)
                    })
                } else {
                    let levels = [levelName]
                    infoBuildingLevel[buildingName] = levels
                }
            }
        }
        return infoBuildingLevel
    }
    
    private func compareFloorNames(lhs: String, rhs: String) -> Bool {
        func floorValue(_ floor: String) -> Int {
            if floor.starts(with: "B"), let number = Int(floor.dropFirst()) {
                return -number
            } else if floor.hasSuffix("F"), let number = Int(floor.dropLast()) {
                return number
            }
            return 0
        }
            
        return floorValue(lhs) > floorValue(rhs)
    }
    
    func checkInLevelChangeArea(sectorId: Int, building: String, level: String, x: Float, y: Float, mode: UserMode) -> Bool {
        if mode == .MODE_PEDESTRIAN { return false }
        
        let levelName = TJLabsUtilFunctions.shared.removeLevelDirectionString(levelName: level)
        let key = "\(sectorId)_\(building)_\(levelName)"
        guard let levelChangeArea: [[Float]] = levelChangeAreaMap[key] else { return false }
        
        for i in 0..<levelChangeArea.count {
            if (!levelChangeArea[i].isEmpty) {
                let xMin = levelChangeArea[i][0]
                let yMin = levelChangeArea[i][1]
                let xMax = levelChangeArea[i][2]
                let yMax = levelChangeArea[i][3]
                
                if (x >= xMin && x <= xMax) {
                    if (y >= yMin && y <= yMax) {
                        return true
                    }
                }
            }
        }
        return false
    }
    
    
    func getLevelNumber(levelName: String) -> Int {
        let levelNameCorrected: String = TJLabsUtilFunctions.shared.removeLevelDirectionString(levelName: levelName)
        if (levelNameCorrected[levelNameCorrected.startIndex] == "B") {
            // 지하
            let levelTemp = levelNameCorrected.substring(from: 1, to: levelNameCorrected.count-1)
            var levelNum = Int(levelTemp) ?? 0
            levelNum = (-1*levelNum)-1
            return levelNum
        } else {
            // 지상
            let levelTemp = levelNameCorrected.substring(from: 0, to: levelNameCorrected.count-2)
            var levelNum = Int(levelTemp) ?? 0
            levelNum = levelNum+1
            return levelNum
        }
    }
    
    func getMatchedBuildingLevelByUserPeak(userPeak: UserPeak) -> (building: String, level: String)? {
        let userPeakWardId = userPeak.id
        for (key, value) in levelWardsMap {
            let wardIds = value.map{$0.name}
            if wardIds.contains(userPeakWardId) {
                if let buildingLevel = getBuidlingLevelInKey(key: key) {
                    return buildingLevel
                }
            }
        }
        return nil
    }
    
    func isIndoorLevel(buildingLevelByPeakBuffer: [(String, String)]) -> Bool {
        JupiterLogger.i(tag: "BuildingLevelChanger", message: "(isIndoorLevel) buildingLevelByPeakBuffer: \(buildingLevelByPeakBuffer)")
        guard let first = buildingLevelByPeakBuffer.first else { return false }
        return first.1 != "B0" && buildingLevelByPeakBuffer.allSatisfy { $0.0 == first.0 && $0.1 == first.1 }
    }

//    func calculateLevelByBle(data: (Int, [(String, Float)])) -> String {
//        var result: String = "UNKNOWN"
//        var strongestBleData: (String, String, Float)?
//        
//        var checker = [(String, String, Float)]()
//        let bleData = data.1
//        for (levelName, wardIds) in levelWardsMap {
//            for (id, rssi) in bleData {
//                if wardIds.contains(id) {
//                    let normalized_rssi = Float(rssi)
//                    if normalized_rssi >= -90 {
//                        checker.append((levelName, id, normalized_rssi))
//                    }
//                    
//                    if let stronggest = strongestBleData {
//                        if stronggest.2 < normalized_rssi {
//                            strongestBleData = (levelName, id, normalized_rssi)
//                        }
//                    } else {
//                        strongestBleData = (levelName, id, normalized_rssi)
//                    }
//                }
//            }
//        }
//        
//        if let stronggest = strongestBleData {
//            if stronggest.2 >= -55 {
//                return getLevelInKey(key: stronggest.0)
//            }
//        }
//        
//        if checker.count >= 2 {
//            let frequentLevel = mostFrequentCheckerValue(from: checker)
//            result = frequentLevel
//        } else if checker.count == 1 {
//            if checker[0].2 >= -80 {
//                result = checker[0].0
//            }
//        }
//        
//        return result != "UNKNOWN" ? getLevelInKey(key: result) : result
//    }
    
    private func getLevelInKey(key: String) -> String {
        let splittedKey = key.split(separator: "_")
        return String(splittedKey[splittedKey.count-1])
    }
    
    private func getBuidlingLevelInKey(key: String) -> (building: String, level: String)? {
        let splittedKey = key.split(separator: "_")
        if splittedKey.count < 3 { return nil }
        let building = String(splittedKey[splittedKey.count-2])
        let level = String(splittedKey[splittedKey.count-1])
        return (building, level)
    }
    
    func mostFrequentCheckerValue(from checker: [(String, String, Float)]) -> String {
        var frequency: [String: Int] = [:]

        for (first, _, _) in checker {
            frequency[first, default: 0] += 1
        }

        let maxCount = frequency.values.max() ?? 0
        let mostFrequent = frequency.filter { $0.value == maxCount }

        return mostFrequent.count == 1 ? mostFrequent.first!.key : "UNKNOWN"
    }
}
