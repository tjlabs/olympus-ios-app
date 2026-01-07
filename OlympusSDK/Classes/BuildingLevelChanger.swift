
import TJLabsCommon
import TJLabsResource

protocol BuildingLevelChangerDelegate: AnyObject {
    func isBuildingLevelChanged(isChanged: Bool, newBuilding: String, newLevel: String, newCoord: [Float])
}

class BuildingLevelChanger {
    
    init(sectorId: Int) {
        self.sectorId = sectorId
        
        buildingLevelChangedTime = 0
        isDetermineSpot = false
        distAfterSpotDetection = 0
        lastSpot = 0
        curSpot = 0
        preOutputMobileTime = 0
        buildingsAndLevels = [String: [String]]()
    }
    
    deinit { }
    
    weak var delegate: BuildingLevelChangerDelegate?
    
    let DEFAULT_SPOT_DISTANCE: Float = 70
    
    var sectorId: Int
    var blChangerTagMap = [Int: [BuildingLevelTag]]()
    var buildingsAndLevelsMap = [String: [String]]()
    var levelChangeAreaMap = [String: [[Float]]]()
    var levelWardsMap = [String: [String]]()

    var buildingLevelChangedTime: Int
    var isDetermineSpot: Bool
    
    private var distAfterSpotDetection: Float
    
    private var curSpot: Int
    private var lastSpot: Int
    private var preOutputMobileTime: Int
    private var buildingsAndLevels = [String: [String]]()
    
    func toggleToOutdoor() {
        buildingLevelChangedTime = 0
        isDetermineSpot = false
        distAfterSpotDetection = 0
        curSpot = 0
        lastSpot = 0
        preOutputMobileTime = 0
    }
    
    func setLevelWards(levelKey: String, levelWardsData: [String]) {
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
    
    func accumulateDistance(uvd: UserVelocity, isGetFirstResponse: Bool, mode: UserMode, result: FineLocationTrackingOutput) {
        if (isGetFirstResponse && mode == .MODE_VEHICLE) {
            let lastResult = result
            if (lastResult.building_name != "" && lastResult.level_name != "") {
                self.distAfterSpotDetection += Float(uvd.length)
            }
        }
    }
    
    func determineSpotDetect(time: Int, tag: BuildingLevelTag, lastSpotId: Int, buildingDestination: String, levelDestination: String, curBuilding: String, curLevel: String, spotCoord: [Float]) {
        var spotDistance = Float(tag.distance)
        if (spotDistance == 0) {
            spotDistance = DEFAULT_SPOT_DISTANCE
        }
        
        let levelArray: [String] = [tag.level_name, tag.linked_level_name]
        let TIME_CONDITION = levelArray.contains("B0") && levelArray.contains(where: { $0 != "B0" }) ? JupiterTime.MINIMUM_BUILDING_LEVEL_CHANGE_TIME*3 : JupiterTime.MINIMUM_BUILDING_LEVEL_CHANGE_TIME
        
        if (tag.id != lastSpotId) {
            // Different Spot Detected
            let resultLevelName: String = TJLabsUtilFunctions.shared.removeLevelDirectionString(levelName: levelDestination)
            if (buildingDestination != curBuilding || resultLevelName != curLevel) {
                if ((Double(time - self.buildingLevelChangedTime)) > TIME_CONDITION) {
                    // Building Level 이 바뀐지 7초 이상 지남 -> 서버 결과를 이용해 바뀌어야 한다고 판단
                    self.curSpot = tag.id
                    self.lastSpot = tag.id
                    self.distAfterSpotDetection = 0
                    setBuildingLevelChangedTime(value: time)
                    self.delegate?.isBuildingLevelChanged(isChanged: true, newBuilding: buildingDestination, newLevel: levelDestination, newCoord: spotCoord)
                    self.isDetermineSpot = true
                }
            }
            self.preOutputMobileTime = time
        } else {
            // Same Spot Detected
            if (self.distAfterSpotDetection >= spotDistance) {
                let resultLevelName: String = TJLabsUtilFunctions.shared.removeLevelDirectionString(levelName: levelDestination)
                if (buildingDestination != curBuilding || resultLevelName != curLevel) {
                    if (Double(time - self.buildingLevelChangedTime) > TIME_CONDITION) {
                        // Building Level 이 바뀐지 7초 이상 지남 -> 서버 결과를 이용해 바뀌어야 한다고 판단
                        self.curSpot = tag.id
                        self.lastSpot = tag.id
                        self.distAfterSpotDetection = 0
                        setBuildingLevelChangedTime(value: time)
                        self.delegate?.isBuildingLevelChanged(isChanged: true, newBuilding: buildingDestination, newLevel: levelDestination, newCoord: spotCoord)
                        self.isDetermineSpot = true
                    }
                }
                self.preOutputMobileTime = time
            }
        }
    }
    
    func estimateBuildingLevel(bleAvg: [String: Float], mode: UserMode, phase: Int, isGetFirstResponse: Bool, networkStatus: Bool, result: FineLocationTrackingOutput, curEnt: String) {
        let curTime = TJLabsUtilFunctions.shared.getCurrentTimeInMilliseconds(as: .int) as! Int
        let curBuilding = result.building_name
        let curLevel = result.level_name
        
        var isRunOsr: Bool = true
        if (isGetFirstResponse && networkStatus) {
            if (mode != .MODE_PEDESTRIAN) {
                if (isRunOsr) {
                    // OSR 와드 태깅 검사하기
                    guard let isTagged = self.isBuildingLevelChangerTagged(bleAvg: bleAvg, result: result) else { return }
                    
                    // 만약 태깅 했다면
                    guard let isOn = self.isOn(tag: isTagged, building: result.building_name, level: result.level_name) else { return }
                    
                    let buildingDestination = isOn.buildingDestination
                    let levelDestination = isOn.levelDestination
                    let spotCoord: [Float] = [Float(isTagged.x), Float(isTagged.y)]
//                    determineSpotDetect(time: <#T##Int#>, tag: <#T##BuildingLevelTag#>, lastSpotId: <#T##Int#>, buildingDestination: <#T##String#>, levelDestination: <#T##String#>, curBuilding: <#T##String#>, curLevel: <#T##String#>, spotCoord: <#T##[Float]#>)
                }
            }
        }
    }
    
    func isBuildingLevelChangerTagged(bleAvg: [String: Float], result: FineLocationTrackingOutput) -> BuildingLevelTag? {
        let sectorKey = self.sectorId
        guard let sectorTagData = self.blChangerTagMap[sectorKey] else { return nil }
        
        let tagValues: [BuildingLevelTag] = sectorTagData
        for item in tagValues {
            for (bleName, rssiValue) in bleAvg {
                if item.name == bleName && rssiValue >= Float(item.rssi) {
                    JupiterLogger.i(tag: "BuildingLevelChanger", message: "(isBuildingLevelChangerTagged) - \(bleName) tagged with \(rssiValue)")
                    return item
                }
            }
        }
        
        return nil
    }
    
    func isOn(tag: BuildingLevelTag, building: String, level: String) -> (buildingDestination: String, levelDestination: String)? {
        let curBuilding: String = building
        let curLevel: String = level
        
        var buildingDestination: String = ""
        var levelDestination: String = ""
        if curBuilding != tag.building_name {
            // Building 바뀜
            buildingDestination = tag.building_name
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
    
    func makeBuildingLevelInfo(buildingsData: [BuildingOutput]) -> [String: [String]] {
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
    
    func compareFloorNames(lhs: String, rhs: String) -> Bool {
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
    
    func makeLevelList(sectorId: Int, building: String, level: String, x: Float, y: Float, mode: UserMode) -> [String] {
        var levelArray = [level]
        let isInLevelChangeArea = checkInLevelChangeArea(sectorId: sectorId, building: building, level: level, x: x, y: y, mode: mode)
        
        if isInLevelChangeArea {
            levelArray = makeLevelChangeArray(buildingName: building, levelNameInput: level, buildingLevel: buildingsAndLevelsMap)
        }
        
        return levelArray
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

    func makeLevelChangeArray(buildingName: String, levelNameInput: String, buildingLevel: [String:[String]]) -> [String] {
        var levelArrayToReturn = [String]()
        
        if (!buildingLevel.isEmpty) {
            if (levelNameInput.contains("_D")) {
                let levelCandidate = levelNameInput.replacingOccurrences(of: "_D", with: "")
                levelArrayToReturn = [levelNameInput, levelCandidate]
            } else {
                let levelCandidate = levelNameInput + "_D"
                levelArrayToReturn = [levelNameInput, levelCandidate]
            }
            
            if let levelList: [String] = buildingLevel[buildingName] {
                var newArray = [String]()
                for i in 0..<levelArrayToReturn.count {
                    let levelName: String = levelArrayToReturn[i]
                    if levelList.contains(levelName) {
                        newArray.append(levelName)
                    }
                }
                
                if !newArray.isEmpty {
                    levelArrayToReturn = newArray
                } else {
                    levelArrayToReturn = [TJLabsUtilFunctions.shared.removeLevelDirectionString(levelName: levelNameInput)]
                }
            } else {
                levelArrayToReturn = [TJLabsUtilFunctions.shared.removeLevelDirectionString(levelName: levelNameInput)]
            }
        } else {
            levelArrayToReturn = [TJLabsUtilFunctions.shared.removeLevelDirectionString(levelName: levelNameInput)]
        }
        return levelArrayToReturn
    }
    
    func getLevelDirection(currentLevel: Int, destinationLevel: Int) -> String {
        var levelDirection: String = ""
        let diffLevel: Int = destinationLevel - currentLevel
        if (diffLevel > 0) {
            levelDirection = "_D"
        }
        return levelDirection
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
    
    func calculateLevelByBle(data: (Int, [(String, Float)], RssCompensationParam)) -> String {
        var result: String = "UNKNOWN"
        var strongestBleData: (String, String, Float)?
        
        var checker = [(String, String, Float)]()
        let bleData = data.1
        let param = data.2
        for (levelName, wardIds) in levelWardsMap {
            for (id, rssi) in bleData {
                if wardIds.contains(id) {
                    let normalized_rssi = (Float(rssi) - param.device_min_rss)*param.normalization_scale + param.standard_min_rss
                    if normalized_rssi >= -90 {
                        checker.append((levelName, id, normalized_rssi))
                    }
                    
                    if let stronggest = strongestBleData {
                        if stronggest.2 < normalized_rssi {
                            strongestBleData = (levelName, id, normalized_rssi)
                        }
                    } else {
                        strongestBleData = (levelName, id, normalized_rssi)
                    }
                }
            }
        }
        
        if let stronggest = strongestBleData {
            if stronggest.2 >= -55 {
                return getLevelInKey(key: stronggest.0)
            }
        }
        
        if checker.count >= 2 {
            let frequentLevel = mostFrequentCheckerValue(from: checker)
            result = frequentLevel
        } else if checker.count == 1 {
            if checker[0].2 >= -80 {
                result = checker[0].0
            }
        }
        
        return result != "UNKNOWN" ? getLevelInKey(key: result) : result
    }
    
    private func getLevelInKey(key: String) -> String {
        let splittedKey = key.split(separator: "_")
        return String(splittedKey[splittedKey.count-1])
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
