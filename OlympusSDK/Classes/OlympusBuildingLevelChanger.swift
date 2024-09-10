public class OlympusBuildingLevelChanger {
    
    init() {
        notificationCenterAddObserver()
    }
    
    deinit {
        notificationCenterRemoveObserver()
    }
    
    private var observers = [BuildingLevelChangeObserver]()
    func addObserver(_ observer: BuildingLevelChangeObserver) {
            observers.append(observer)
    }
        
    func removeObserver(_ observer: BuildingLevelChangeObserver) {
        observers = observers.filter { $0 !== observer }
    }
    
    private func notifyObservers(building: String, level: String, range: [Int], direction: [Int]) {
        observers.forEach { $0.isBuildingLevelChanged(newBuilding: building, newLevel: level, newRange: range, newDirection: direction)}
    }
    
    public var isDetermineSpot: Bool = false
    public var travelingOsrDistance: Double = 0
    public var lastSpotId: Int = 0
    public var currentSpot: Int = 0
    public var spotCutIndex: Int = 0
    public var buildingLevelChangedTime: Int = 0
    public var buildingsAndLevels = [String:[String]]()
    public var phase2Range: [Int] = []
    public var phase2Direction: [Int] = []
    public var preOutputMobileTime: Int = 0
    
    public var sectorDRModeArea = [String: SectorDRModeArea]()
    public var currentDRModeArea = SectorDRModeArea(number: -1, range: [], direction: 0, nodes: [])
    public var currentDRModeAreaNodeNumber: Int = -1
    
    var trajEditedObserver: Any!
    
    public func initialize() {
        self.isDetermineSpot = false
        self.travelingOsrDistance = 0
        self.lastSpotId = 0
        self.currentSpot = 0
        self.spotCutIndex = 0
        self.buildingLevelChangedTime = 0
        self.buildingsAndLevels = [String:[String]]()
        self.phase2Range = []
        self.phase2Direction = []
        self.preOutputMobileTime = 0
        
        self.sectorDRModeArea = [String: SectorDRModeArea]()
        self.currentDRModeArea = SectorDRModeArea(number: -1, range: [], direction: 0, nodes: [])
        self.currentDRModeAreaNodeNumber = -1
    }
    
    func accumulateOsrDistance(unitLength: Double, isGetFirstResponse: Bool, mode: String, result: FineLocationTrackingResult) {
        if (isGetFirstResponse && mode == OlympusConstants.MODE_DR) {
            let lastResult = result
            if (lastResult.building_name != "" && lastResult.level_name != "") {
                self.travelingOsrDistance += unitLength
            }
        }
    }
    
    func estimateBuildingLevel(user_id: String, mode: String, phase: Int, isGetFirstResponse: Bool, networkStatus: Bool, result: FineLocationTrackingResult, currentBuilding: String, currentLevel: String, currentEntrance: String) {
        let currentTime = getCurrentTimeInMilliseconds()
        var isRunOsr: Bool = true
        if (isGetFirstResponse && networkStatus) {
            if (mode != OlympusConstants.MODE_PDR) {
                if (phase >= OlympusConstants.PHASE_4) {
                    let isInLevelChangeArea = self.checkInLevelChangeArea(result: result, mode: mode)
                    if (!isInLevelChangeArea) {
                        isRunOsr = false
                    }
                }
                
                if (isRunOsr) {
                    let input = OnSpotRecognition(operating_system: OlympusConstants.OPERATING_SYSTEM, user_id: user_id, mobile_time: currentTime, normalization_scale: OlympusConstants.NORMALIZATION_SCALE, device_min_rss: Int(OlympusConstants.DEVICE_MIN_RSSI), standard_min_rss: Int(OlympusConstants.STANDARD_MIN_RSS))
//                    print(getLocalTimeString() + " , (Olympus) Run OSR : input = \(input)")
                    OlympusNetworkManager.shared.postOSR(url: CALC_OSR_URL, input: input, completion: { [self] statusCode, returnedString in
//                        print(getLocalTimeString() + " , (Olympus) Run OSR : result = \(returnedString)")
                        if (statusCode == 200) {
                            let result = jsonToOnSpotRecognitionResult(jsonString: returnedString)
                            let decodedOsr = result.1
                            if (result.0 && decodedOsr.building_name != "" && decodedOsr.level_name != "") {
                                let isOnSpot = isOnSpotRecognition(result: decodedOsr, level: currentLevel)
//                                print(getLocalTimeString() + " , (Olympus) Run OSR : isOnSpot = \(isOnSpot)")
                                if (isOnSpot.isOn) {
                                    let levelDestination = isOnSpot.levelDestination + isOnSpot.levelDirection
                                    determineSpotDetect(result: decodedOsr, lastSpotId: self.lastSpotId, levelDestination: levelDestination, currentBuilding: currentBuilding, currentLevel: currentLevel, currentEntrance: currentEntrance, currentTime: currentTime)
                                }
                            }
                        }
                    })
                }
            }
        } else {
            self.travelingOsrDistance = 0
        }
    }
    
    func determineSpotDetect(result: OnSpotRecognitionResult, lastSpotId: Int, levelDestination: String, currentBuilding: String, currentLevel: String, currentEntrance: String, currentTime: Int) {
        var spotDistance = result.spot_distance
        if (spotDistance == 0) {
            spotDistance = OlympusConstants.DEFAULT_SPOT_DISTANCE
        }
        
        let levelArray: [String] = [result.level_name, result.linked_level_name]
        var TIME_CONDITION = OlympusConstants.MINIMUM_BUILDING_LEVEL_CHANGE_TIME
        if (levelArray.contains("B0") && levelArray.contains("B2")) {
            TIME_CONDITION = OlympusConstants.MINIMUM_BUILDING_LEVEL_CHANGE_TIME*3
        }
        
        if (result.spot_id != lastSpotId) {
            // Different Spot Detected
            let resultLevelName: String = removeLevelDirectionString(levelName: levelDestination)
            if (result.building_name != currentBuilding || resultLevelName != currentLevel) {
                if ((result.mobile_time - self.buildingLevelChangedTime) > TIME_CONDITION) {
                    // Building Level 이 바뀐지 7초 이상 지남 -> 서버 결과를 이용해 바뀌어야 한다고 판단
                    self.phase2Range = result.spot_range
                    if (levelDestination.contains("_D")) {
                        self.phase2Direction = result.spot_direction_up
                    } else {
                        self.phase2Direction = result.spot_direction_down
                    }
                    
                    self.currentSpot = result.spot_id
                    self.lastSpotId = result.spot_id
                    self.travelingOsrDistance = 0
                    self.buildingLevelChangedTime = currentTime
//                    print(getLocalTimeString() + " , (Olympus) Run OSR (1) : levelDestination = \(levelDestination)")
//                    print(getLocalTimeString() + " , (Olympus) Run OSR (1) : phase2Range = \(phase2Range) // phase2Direction = \(phase2Direction)")
                    self.notifyObservers(building: result.building_name, level: levelDestination, range: self.phase2Range, direction: self.phase2Direction)
                    self.isDetermineSpot = true
                    self.spotCutIndex = self.determineSpotCutIndex(entranceString: currentEntrance)
                }
            }
            self.preOutputMobileTime = currentTime
        } else {
            // Same Spot Detected
//            print(getLocalTimeString() + " , (Olympus) Run OSR : travelingOsrDistance = \(travelingOsrDistance)")
            if (self.travelingOsrDistance >= spotDistance) {
                let resultLevelName: String = removeLevelDirectionString(levelName: levelDestination)
                if (result.building_name != currentBuilding || resultLevelName != currentLevel) {
                    if ((result.mobile_time - self.buildingLevelChangedTime) > TIME_CONDITION) {
                        // Building Level 이 바뀐지 7초 이상 지남 -> 서버 결과를 이용해 바뀌어야 한다고 판단
                        self.phase2Range = result.spot_range
                        if (levelDestination.contains("_D")) {
                            self.phase2Direction = result.spot_direction_up
                        } else {
                            self.phase2Direction = result.spot_direction_down
                        }
                        
                        self.currentSpot = result.spot_id
                        self.lastSpotId = result.spot_id
                        self.travelingOsrDistance = 0
                        self.buildingLevelChangedTime = currentTime
//                        print(getLocalTimeString() + " , (Olympus) Run OSR (2) : levelDestination = \(levelDestination)")
//                        print(getLocalTimeString() + " , (Olympus) Run OSR (2) : phase2Range = \(phase2Range) // phase2Direction = \(phase2Direction)")
                        self.notifyObservers(building: result.building_name, level: levelDestination, range: self.phase2Range, direction: self.phase2Direction)
                        self.isDetermineSpot = true
                        self.spotCutIndex = self.determineSpotCutIndex(entranceString: currentEntrance)
                    }
                }
                self.preOutputMobileTime = currentTime
            }
        }
    }
    
    func isOnSpotRecognition(result: OnSpotRecognitionResult, level: String) -> (isOn: Bool, levelDestination: String, levelDirection: String) {
        var isOn: Bool = false
        let building_name = result.building_name
        let level_name = result.level_name
        let linked_level_name = result.linked_level_name
        
        let levelArray: [String] = [level_name, linked_level_name]
        var levelDestination: String = ""

        if (linked_level_name == "") {
            isOn = false
            return (isOn, levelDestination, "")
        } else {
            if (level_name == linked_level_name) {
                isOn = false
                return (isOn, "", "")
            }
            
            // Normal OSR
            let currentLevel: String = level
            let levelNameCorrected: String = removeLevelDirectionString(levelName: currentLevel)
            for i in 0..<levelArray.count {
                if levelArray[i] != levelNameCorrected {
                    levelDestination = levelArray[i]
                    isOn = true
                }
            }
            
            // Up or Down Direction
            let currentLevelNum: Int = getLevelNumber(levelName: currentLevel)
            let destinationLevelNum: Int = getLevelNumber(levelName: levelDestination)
            let levelDirection: String = getLevelDirection(currentLevel: currentLevelNum, destinationLevel: destinationLevelNum)
            
            return (isOn, levelDestination, levelDirection)
        }
    }
    
    func checkInLevelChangeArea(result: FineLocationTrackingResult, mode: String) -> Bool {
        if (mode == OlympusConstants.MODE_PDR) {
            return false
        }
        
        let lastResult = result
        
        let buildingName = lastResult.building_name
        let levelName = removeLevelDirectionString(levelName: result.level_name)

        let key = "\(buildingName)_\(levelName)"
        guard let levelChangeArea: [[Double]] = OlympusPathMatchingCalculator.shared.LevelChangeArea[key] else {
            return false
        }
        
        for i in 0..<levelChangeArea.count {
            if (!levelChangeArea[i].isEmpty) {
                let xMin = levelChangeArea[i][0]
                let yMin = levelChangeArea[i][1]
                let xMax = levelChangeArea[i][2]
                let yMax = levelChangeArea[i][3]
                
                if (lastResult.x >= xMin && lastResult.x <= xMax) {
                    if (lastResult.y >= yMin && lastResult.y <= yMax) {
                        return true
                    }
                }
            }
        }

        return false
    }
    
    public func makeLevelChangeArray(buildingName: String, levelName: String, buildingLevel: [String:[String]]) -> [String] {
        let inputLevel = levelName
        var levelArrayToReturn: [String] = [levelName]
        
        if (inputLevel.contains("_D")) {
            let levelCandidate = inputLevel.replacingOccurrences(of: "_D", with: "")
            levelArrayToReturn = [inputLevel, levelCandidate]
        } else {
            let levelCandidate = inputLevel + "_D"
            levelArrayToReturn = [inputLevel, levelCandidate]
        }
        
        if (!buildingLevel.isEmpty) {
            guard let levelList: [String] = buildingLevel[buildingName] else {
                return levelArrayToReturn
            }
            
            var newArray = [String]()
            for i in 0..<levelArrayToReturn.count {
                let levelName: String = levelArrayToReturn[i]
                if (levelList.contains(levelName)) {
                    newArray.append(levelName)
                }
            }
            levelArrayToReturn = newArray
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
        let levelNameCorrected: String = removeLevelDirectionString(levelName: levelName)
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
    
    func determineSpotCutIndex(entranceString: String) -> Int {
        var cutIndex: Int = 15
        if (entranceString == "COEX_B0_3" || entranceString == "COEX_B0_4") {
            cutIndex = 1
        }
        return cutIndex
    }
    
    private func setBuildingLevelChangedTime(value: Int) {
        self.buildingLevelChangedTime = value
    }
    
    public func updateBuildingAndLevel(fltResult: FineLocationTrackingFromServer, currentBuilding: String, currentLevel: String) -> FineLocationTrackingFromServer{
        var result = fltResult
        
        let currentTime = getCurrentTimeInMilliseconds()
        let resultLevelName = removeLevelDirectionString(levelName: fltResult.level_name)
        let currentLevelName = removeLevelDirectionString(levelName: currentLevel)
        
        let levelArray: [String] = [resultLevelName, currentLevelName]
        var TIME_CONDITION = OlympusConstants.MINIMUM_BUILDING_LEVEL_CHANGE_TIME
        if (levelArray.contains("B0") && levelArray.contains("B2")) {
            TIME_CONDITION = OlympusConstants.MINIMUM_BUILDING_LEVEL_CHANGE_TIME*4
        }
        
        var isBuildingLevelChanged: Bool = false
        if (fltResult.building_name != currentBuilding || resultLevelName != currentLevelName) {
            if ((fltResult.mobile_time - buildingLevelChangedTime) > TIME_CONDITION) {
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
        
        return result
    }
    
    public func setSectorDRModeArea(building: String, level: String, drModeAreaList: [SectorDRModeArea]) {
        for info in drModeAreaList {
            let key = "\(building)_\(level)_\(info.number)"
            self.sectorDRModeArea[key] = SectorDRModeArea(number: info.number, range: info.range, direction: info.direction, nodes: info.nodes)
//            print(getLocalTimeString() + " , (Olympus) setSectorDRModeArea : key = \(key) , value = \(self.sectorDRModeArea[key])")
        }
    }
    
    public func checkInSectorDRModeArea(fltResult: FineLocationTrackingFromServer, passedNodeInfo: PassedNodeInfo) -> Bool {
        let currentLevel = "_\(fltResult.level_name)_"
        for (key, value) in self.sectorDRModeArea {
            if key.contains(currentLevel) {
//                print(getLocalTimeString() + " , (Olympus) isInSectorLevelChange (In) : coord = \(fltResult.x) , \(fltResult.y) , \(fltResult.absolute_heading)")
                if (value.range[0] <= fltResult.x && fltResult.x <= value.range[2]) && (value.range[1] <= fltResult.y && fltResult.y <= value.range[3]) {
                    // 사용자 좌표가 영역 안에 존재
                    if value.direction == fltResult.absolute_heading {
                        // 사용자 방향이 일치함
                        for n in value.nodes {
                            // passedNode와 매칭 검사
                            if n.number == passedNodeInfo.nodeNumber {
                                // OSR 동작 시작
                                // 방향 결정 "U" or "D" or "N"
                                self.currentDRModeArea = value
                                self.currentDRModeAreaNodeNumber = n.number
                                return true
                            }
                        }
                    }
                }
            }
        }
        return false
    }
    
    public func checkOutSectorDRModeArea(fltResult: FineLocationTrackingFromServer, anchorNodeInfo: PassedNodeInfo) -> Bool {
        if fltResult.level_name == "B0" {
            return true
        }
        
        var isInArea: Bool = false
        var isAnchorNodeInArea: Bool = false
        
        let currentLevel = "_\(fltResult.level_name)_"
        for (key, value) in self.sectorDRModeArea {
            if key.contains(currentLevel) {
                if (value.range[0] <= fltResult.x && fltResult.x <= value.range[2]) && (value.range[1] <= fltResult.y && fltResult.y <= value.range[3]) {
                    isInArea = true
                }
                
                if anchorNodeInfo.nodeCoord.isEmpty {
                    return false
                } else {
                    if (value.range[0] <= anchorNodeInfo.nodeCoord[0] && anchorNodeInfo.nodeCoord[0] <= value.range[2]) && (value.range[1] <= anchorNodeInfo.nodeCoord[1] && anchorNodeInfo.nodeCoord[1] <= value.range[3]) {
                        isAnchorNodeInArea = true
                    }
                }
            }
        }

        if !isInArea {
            if isAnchorNodeInArea {
               isInArea = true
            } else {
                self.currentDRModeArea = SectorDRModeArea(number: -1, range: [], direction: 0, nodes: [])
                self.currentDRModeAreaNodeNumber = -1
            }
        }
        
        return isInArea
    }
    
    func notificationCenterAddObserver() {
        self.trajEditedObserver = NotificationCenter.default.addObserver(self, selector: #selector(onDidReceiveNotification), name: .trajEditedAfterOsr, object: nil)
    }
    
    func notificationCenterRemoveObserver() {
        NotificationCenter.default.removeObserver(self.trajEditedObserver)
    }
    
    @objc func onDidReceiveNotification(_ notification: Notification) {
        if notification.name == .trajEditedAfterOsr {
            self.isDetermineSpot = false
        }
    }
}
