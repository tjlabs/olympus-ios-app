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
    
    private func notifyObservers(building: String, level: String) {
        observers.forEach { $0.isBuildingLevelChanged(newBuilding: building, newLevel: level)}
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
    }
    
    func accumulateOsrDistance(unitLength: Double, isGetFirstResponse: Bool, mode: String, result: FineLocationTrackingResult) {
        if (isGetFirstResponse && mode == OlympusConstants.MODE_DR) {
            let lastResult = result
            if (lastResult.building_name != "" && lastResult.level_name != "") {
                self.travelingOsrDistance += unitLength
            }
        }
    }
    
    func estimateBuildingLevel(user_id: String, mode: String, phase: Int, isGetFirstResponse: Bool, isInNetworkBadEntrance: Bool, result: FineLocationTrackingResult, currentBuilding: String, currentLevel: String, currentEntrance: String) {
        let currentTime = getCurrentTimeInMilliseconds()
        var isRunOsr: Bool = true
        if (isGetFirstResponse && !isInNetworkBadEntrance) {
            if (mode != OlympusConstants.MODE_PDR) {
                if (phase == OlympusConstants.PHASE_4) {
                    let isInLevelChangeArea = self.checkInLevelChangeArea(result: result, mode: mode)
                    if (!isInLevelChangeArea) {
                        isRunOsr = false
                    }
                }
                
                if (isRunOsr) {
                    let input = OnSpotRecognition(operating_system: OlympusConstants.OPERATING_SYSTEM, user_id: user_id, mobile_time: currentTime, normalization_scale: OlympusConstants.NORMALIZATION_SCALE, device_min_rss: Int(OlympusConstants.DEVICE_MIN_RSSI), standard_min_rss: Int(OlympusConstants.STANDARD_MIN_RSS))
                    OlympusNetworkManager.shared.postOSR(url: CALC_OSR_URL, input: input, completion: { [self] statusCode, returnedString in
                        if (statusCode == 200) {
                            let result = jsonToOnSpotRecognitionResult(jsonString: returnedString)
                            let decodedOsr = result.1
                            if (result.0 && decodedOsr.building_name != "" && decodedOsr.level_name != "") {
                                let isOnSpot = isOnSpotRecognition(result: decodedOsr, level: currentLevel)
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
                    self.notifyObservers(building: result.building_name, level: levelDestination)
                    
//                    self.timeUpdateOutput.building_name = result.building_name
//                    self.timeUpdateOutput.level_name = levelDestination
//                    self.measurementOutput.building_name = result.building_name
//                    self.measurementOutput.level_name = levelDestination
//                    self.outputResult.level_name = levelDestination

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
                    
                    self.isDetermineSpot = true
                    self.spotCutIndex = self.determineSpotCutIndex(entranceString: currentEntrance)
                }
            }
            self.preOutputMobileTime = currentTime
        } else {
            // Same Spot Detected
            if (self.travelingOsrDistance >= spotDistance) {
                let resultLevelName: String = removeLevelDirectionString(levelName: levelDestination)
                if (result.building_name != currentBuilding || resultLevelName != currentLevel) {
                    if ((result.mobile_time - self.buildingLevelChangedTime) > TIME_CONDITION) {
                        // Building Level 이 바뀐지 7초 이상 지남 -> 서버 결과를 이용해 바뀌어야 한다고 판단
                        self.notifyObservers(building: result.building_name, level: levelDestination)
                        
//                        self.timeUpdateOutput.building_name = result.building_name
//                        self.timeUpdateOutput.level_name = levelDestination
//                        self.measurementOutput.building_name = result.building_name
//                        self.measurementOutput.level_name = levelDestination
//                        self.outputResult.level_name = levelDestination
                        
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
                        
                        self.isDetermineSpot = true
                        self.spotCutIndex = self.determineSpotCutIndex(entranceString: currentEntrance)
                    }
                }
                self.preOutputMobileTime = currentTime
            }
        }
    }
    
    func isOnSpotRecognition(result: OnSpotRecognitionResult, level: String) -> (isOn: Bool, levelDestination: String, levelDirection: String) {
        let localTime = getLocalTimeString()
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
