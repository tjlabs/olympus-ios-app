import Foundation
import UIKit

public class OlympusServiceManager: Observation, StateTrackingObserver, BuildingLevelChangeObserver {
    public static let sdkVersion: String = "0.0.5"
    var isSimulationMode: Bool = true
    var simulationBleData = [[String: Double]]()
    var simulationSensorData = [OlympusSensorData]()
    var bleLineCount: Int = 0
    var sensorLineCount: Int = 0
    
    func tracking(input: FineLocationTrackingResult) {
        for observer in observers {
            let result = input
            observer.update(result: result)
        }
    }
    
    func reporting(input: Int) {
        for observer in observers {
            if (input != -2) {
                self.pastReportTime = getCurrentTimeInMillisecondsDouble()
                self.pastReportFlag = input
            }
            observer.report(flag: input)
        }
    }
    
    var deviceModel: String
    var deviceOsVersion: Int
    
    var sensorManager = OlympusSensorManager()
    var bleManager = OlympusBluetoothManager()
    var rssCompensator = OlympusRssCompensator()
    var phaseController = OlympusPhaseController()
    var stateManager = OlympusStateManager()
    var routeTracker = OlympusRouteTracker()
    var rflowCorrelator = OlympusRflowCorrelator()
    var unitDRGenerator = OlympusUnitDRGenerator()
    var trajController = OlympusTrajectoryController()
    var sectionController = OlympusSectionController()
    var buildingLevelChanger = OlympusBuildingLevelChanger()
    var KF = OlympusKalmanFilter()
    
    // ----- Data ----- //
    var inputReceivedForce: [ReceivedForce] = []
    var inputUserVelocity: [UserVelocity] = []
    var inputUserMask: [UserMask] = []
    var unitDRInfo = UnitDRInfo()
    var isSaveMobileResult: Bool = false
    
    // ----- Sector Param ----- //
    var user_id: String = ""
    var sector_id: Int = 0
    var sector_id_origin: Int = 0
    var service: String = ""
    var mode: String = ""
    
    // ----- Timer ----- //
    var backgroundUpTimer: DispatchSourceTimer?
    var backgroundUvTimer: DispatchSourceTimer?
    var backgroundTaskIdentifier: UIBackgroundTaskIdentifier?
    
    var receivedForceTimer: DispatchSourceTimer?
    var userVelocityTimer: DispatchSourceTimer?
    var outputTimer: DispatchSourceTimer?
    var osrTimer: DispatchSourceTimer?    
    
    // RFD
    var bleTrimed = [String: [[Double]]]()
    var bleAvg = [String: Double]()
    
    // UVD
    var pastUvdTime: Int = 0
    var pastUvdHeading: Double = 0
    var unitDRInfoIndex: Int = 0
    var isPostUvdAnswered: Bool = false
    
    // ----- State Observer ----- //
    var runMode: String = OlympusConstants.MODE_DR
    var currentMode: String = OlympusConstants.MODE_DR
    var currentBuilding: String = ""
    var currentLevel: String = ""
    var indexPast: Int = 0
    var phase3RqIndex: Int = 0
    var phase2Range: [Int] = []
    var phase2Direction: [Int] = []
    var paddingValues = [Double] (repeating: OlympusConstants.PADDING_VALUE, count: 4)
    
    var isStartComplete: Bool = false
    var isPhaseBreak: Bool = false
    var isPhaseBreakInRouteTrack: Bool = false
    var isInNetworkBadEntrance: Bool = false
    var isStartRouteTrack: Bool = false
    var isInEntranceLevel: Bool = false
    var stableModeInitFlag: Bool = true
    var goodCaseCount: Int = 0
    var isBadCaseInStableMode: Bool = false
    var isInRecoveryProcess: Bool = false
    
    var pastReportTime: Double = 0
    var pastReportFlag: Int = 0
    
    var timeRequest: Double = 0
    var preServerResultMobileTime: Int = 0
    var serverResultBuffer: [FineLocationTrackingFromServer] = []
    var unitDRInfoBuffer: [UnitDRInfo] = []
    var userMaskBuffer: [UserMask] = []
    var userMaskBufferDisplay: [UserMask] = []
    
    var headingBufferForCorrection: [Double] = []
    var isPossibleHeadingCorrection: Bool = false
    
    var temporalResult =  FineLocationTrackingFromServer()
    var preTemporalResult = FineLocationTrackingFromServer()
    var preTemporalResultHeading: Double = 0
    var routeTrackResult = FineLocationTrackingFromServer()
    var phaseBreakResult = FineLocationTrackingFromServer()
    
    var currentTuResult = FineLocationTrackingFromServer()
    var olympusResult = FineLocationTrackingResult()
    var olympusVelocity: Double = 0
    
    // 임시
    public var displayOutput = ServiceResult()
    public var timeUpdateResult: [Double] = [0, 0, 0]
    
    public override init() {
        self.deviceModel = UIDevice.modelName
        let deviceOs = UIDevice.current.systemVersion
        let arr = deviceOs.components(separatedBy: ".")
        self.deviceOsVersion = Int(arr[0]) ?? 0
        
        super.init()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"
        dateFormatter.locale = Locale(identifier:"ko_KR")
        
        stateManager.addObserver(self)
    }
    
    deinit {
        stateManager.removeObserver(self)
    }
    
    func isStateDidChange(newValue: Int) {
        if (newValue == OUTDOOR_FLAG) {
            self.initialize(isStopService: false)
            
        }
        self.reporting(input: newValue)
    }
    
    func isBuildingLevelChanged(newBuilding: String, newLevel: String, newRange: [Int], newDirection: [Int]) {
        self.currentBuilding = newBuilding
        self.currentLevel = newLevel
        self.temporalResult.building_name = newBuilding
        self.temporalResult.level_name = newLevel
        
        self.phase2Range = newRange
        self.phase2Direction = newDirection
    }
    
    private func initialize(isStopService: Bool) {
        buildingLevelChanger.initialize()
        KF.initialize()
        OlympusPathMatchingCalculator.shared.initialize()
        phaseController.initialize()
        rflowCorrelator.initialize()
        routeTracker.initialize()
        rssCompensator.initialize()
        sectionController.initialize()
        stateManager.initialize(isStopService: isStopService)
        trajController.initialize()
        
        inputReceivedForce = []
        inputUserVelocity = []
        inputUserMask = []
        isSaveMobileResult = false
        
        bleTrimed = [String: [[Double]]]()
        bleAvg = [String: Double]()
        
        pastUvdTime = 0
        pastUvdHeading = 0
        isPostUvdAnswered = false
        
        currentBuilding = ""
        currentLevel = ""
        indexPast = 0
        phase3RqIndex = 0
        
        isStartComplete = false
        isPhaseBreak = false
        isPhaseBreakInRouteTrack = false
        isInNetworkBadEntrance = false
        isStartRouteTrack = false
        isInEntranceLevel = false
        stableModeInitFlag = true
        goodCaseCount = 0
        isBadCaseInStableMode = false
        
        pastReportTime = 0
        pastReportFlag = 0
        
        timeRequest = 0
        preServerResultMobileTime = 0
        serverResultBuffer = []
        unitDRInfoBuffer = []
        userMaskBuffer = []
        
        headingBufferForCorrection  = []
        isPossibleHeadingCorrection = false
        
        temporalResult =  FineLocationTrackingFromServer()
        preTemporalResult = FineLocationTrackingFromServer()
        routeTrackResult = FineLocationTrackingFromServer()
        phaseBreakResult = FineLocationTrackingFromServer()
        
        currentTuResult = FineLocationTrackingFromServer()
        olympusResult = FineLocationTrackingResult()
        olympusVelocity = 0
        
        // 임시
        displayOutput = ServiceResult()
        timeUpdateResult = [0, 0, 0]
    }
    
    public func startService(user_id: String, region: String, sector_id: Int, service: String, mode: String, completion: @escaping (Bool, String) -> Void) {
        let success_msg: String =  " , (Olympus) Success : OlympusService Start"
        if (user_id.isEmpty || user_id.contains(" ")) {
            let msg: String = getLocalTimeString() + " , (Olympus) Error : User ID(input = \(user_id)) cannot be empty or contain space"
            completion(false, msg)
        } else {
            let initService = initService(service: service, mode: mode)
            if (initService.0) {
                if (!OlympusNetworkChecker.shared.isConnectedToInternet()) {
                    let msg: String = getLocalTimeString() + " , (Olympus) Error : Network is not connected"
                    completion(false, msg)
                } else {
                    setServerURL(region: region)
                    let loginInput = LoginInput(user_id: user_id, device_model: self.deviceModel, os_version: self.deviceOsVersion, sdk_version: OlympusServiceManager.sdkVersion)
                    OlympusNetworkManager.shared.postUserLogin(url: USER_LOGIN_URL, input: loginInput, completion: { [self] statusCode, returnedString in
                        if (statusCode == 200) {
                            self.user_id = user_id
                            let sectorInput = SectorInput(sector_id: sector_id, operating_system: OlympusConstants.OPERATING_SYSTEM)
                            OlympusNetworkManager.shared.postUserSector(url: USER_SECTOR_URL, input: sectorInput, completion: { [self] statusCode, returnedString in
                                if (statusCode == 200) {
                                    let sectorInfoFromServer = jsonToSectorInfoFromServer(jsonString: returnedString)
                                    if (sectorInfoFromServer.0) {
                                        self.setSectorInfo(sector_id: sector_id, sector_info_from_server: sectorInfoFromServer.1)
                                        rssCompensator.loadRssiCompensationParam(sector_id: sector_id, device_model: deviceModel, os_version: deviceOsVersion, completion: { [self] isSuccess, loadedParam, returnedString in
                                            if (isSuccess) {
                                                OlympusConstants().setNormalizationScale(cur: loadedParam, pre: loadedParam)
                                                print(getLocalTimeString() + " , (Olmypus) Scale cur : \(OlympusConstants.NORMALIZATION_SCALE)")
                                                print(getLocalTimeString() + " , (Olmypus) Scale pre : \(OlympusConstants.PRE_NORMALIZATION_SCALE)")
                                                if (!bleManager.bluetoothReady) {
                                                    let msg: String = getLocalTimeString() + " , (Olympus) Error : Bluetooth is not enabled"
                                                    completion(false, msg)
                                                } else {
                                                    self.isStartComplete = true
                                                    self.startTimer()
                                                    NotificationCenter.default.post(name: .serviceStarted, object: nil, userInfo: nil)
                                                    
                                                    self.initSimulationMode()
                                                    completion(true, getLocalTimeString() + success_msg)
                                                }
                                            } else {
                                                completion(false, returnedString)
                                            }
                                        })
                                    } else {
                                        let msg: String = getLocalTimeString() + " , (Olympus) Error : Decode SectorInfo"
                                        completion(false, msg)
                                    }
                                } else {
                                    let msg: String = getLocalTimeString() + " , (Olympus) Error : Load Sector Info (id = \(sector_id))"
                                    completion(false, msg)
                                }
                            })
                        } else {
                            let msg: String = getLocalTimeString() + " , (Olympus) Error : User ID(input = \(user_id)) Login Error"
                            completion(false, msg)
                        }
                    })
                }
            } else {
                let msg: String = initService.1
                completion(false, msg)
            }
        }
    }
    
    private func initService(service: String, mode: String) -> (Bool, String) {
        let localTime = getLocalTimeString()
        var isSuccess: Bool = true
        var msg: String = ""
        
        if (!OlympusConstants.OLYMPUS_SERVICES.contains(service)) {
            msg = localTime + " , (Olympus) Error : Invalid Service Name"
            return (isSuccess, msg)
        } else {
            if (service.contains(OlympusConstants.SERVICE_FLT)) {
                self.service = service
                unitDRInfo = UnitDRInfo()
                unitDRGenerator.setMode(mode: mode)
                if (mode == OlympusConstants.MODE_AUTO) {
                    // Auto Mode (Default : DR)
                    self.runMode = OlympusConstants.MODE_DR
                    self.currentMode = OlympusConstants.MODE_DR
                } else if (mode == OlympusConstants.MODE_PDR) {
                    // PDR Mode
                    self.runMode =  OlympusConstants.MODE_PDR
                } else if (mode == OlympusConstants.MODE_DR) {
                    // DR Mode
                    self.runMode = OlympusConstants.MODE_DR
                } else {
                    isSuccess = false
                    msg = localTime + " , (Olympus) Error : Invalid Service Mode"
                    return (isSuccess, msg)
                }
                OlympusConstants().setModeParam(mode: self.runMode, phase: phaseController.PHASE)
            }
            
            // Init Sensors
            let initSensors = sensorManager.initSensors()
            if (!initSensors.0) {
                isSuccess = initSensors.0
                msg = initSensors.1
                return (isSuccess, msg)
            }
            
            // Init Bluetooth
            let initBle = bleManager.initBle()
            if (!initBle.0) {
                isSuccess = initBle.0
                msg = initBle.1
                return (isSuccess, msg)
            }
        }
        
        
        return (isSuccess, msg)
    }
    
    private func initSimulationMode() {
        OlympusFileManager.shared.createFiles(time: getCurrentTimeInMilliseconds())
        
        if (isSimulationMode) {
            let result = OlympusFileManager.shared.loadFilesForSimulation()
            simulationBleData = result.0
            simulationSensorData = result.1
//            print("(OlympusFileManager) : sensor = \(result.0)")
//            print("(OlympusFileManager) : ble = \(result.1)" )
        }
    }
    
    public func stopService() -> (Bool, String) {
        let localTime: String = getLocalTimeString()
        var message: String = localTime + " , (Olympus) Success : Stop Service"
        
        if (self.isStartComplete) {
            self.stopTimer()
            self.bleManager.stopScan()
            
            if (self.service.contains(OlympusConstants.SERVICE_FLT)) {
                self.initialize(isStopService: true)
//                paramEstimator.saveNormalizationScale(scale: self.normalizationScale, sector_id: self.sector_id)
//                self.postParam(sector_id: self.sector_id, normailzationScale: self.normalizationScale)
            }
            
            
            return (true, message)
        } else {
            message = localTime + " , (Olympus) Fail : After the service has fully started, it can be stop "
            return (false, message)
        }
    }
    
    public func saveSimulationFile() -> Bool {
        OlympusFileManager.shared.saveFilesForSimulation()
        return true
    }
    
    private func setSectorInfo(sector_id: Int, sector_info_from_server: SectorInfoFromServer) {
        self.sector_id = sector_id
        self.sector_id_origin = sector_id
        let sector_param: SectorInfoParam = sector_info_from_server.parameter
        self.isSaveMobileResult = sector_param.debug
        let stadard_rss: [Int] = sector_param.standard_rss
        
        let sector_info = SectorInfo(standard_min_rss: Double(stadard_rss[0]), standard_max_rss: Double(stadard_rss[1]), user_traj_length: Double(sector_param.trajectory_length + OlympusConstants.DR_LENGTH_MARGIN), user_traj_length_dr: Double(sector_param.trajectory_length + OlympusConstants.DR_LENGTH_MARGIN), user_traj_length_pdr:  Double(sector_param.trajectory_diagonal + OlympusConstants.PDR_LENGTH_MARGIN), num_straight_idx_dr: Int(ceil(OlympusConstants.USER_TRAJECTORY_LENGTH_DR/6)), num_straight_idx_pdr: Int(ceil(OlympusConstants.USER_TRAJECTORY_LENGTH_PDR/6)))
        OlympusConstants().setSectorInfoConstants(sector_info: sector_info)
        self.phaseController.setPhaseLengthParam(lengthConditionPdr: Double(sector_param.trajectory_diagonal), lengthConditionDr: Double(sector_param.trajectory_length))
        print(getLocalTimeString() + " , (Olympus) Information : User Trajectory Param \(OlympusConstants.USER_TRAJECTORY_LENGTH_DR) // \(OlympusConstants.USER_TRAJECTORY_LENGTH_PDR) // \(OlympusConstants.NUM_STRAIGHT_IDX_DR)")
        
        let sectorLevelList = sector_info_from_server.level_list
        var infoBuildingLevel = [String:[String]]()
        
        for element in sectorLevelList {
            let buildingName = element.building_name
            let levelName = element.level_name
            
            if let value = infoBuildingLevel[buildingName] {
                var levels:[String] = value
                levels.append(levelName)
                infoBuildingLevel[buildingName] = levels
            } else {
                let levels:[String] = [levelName]
                infoBuildingLevel[buildingName] = levels
            }
            
            if !levelName.contains("_D") {
                let key = "\(buildingName)_\(levelName)"
                let entranceArea = element.geofence.entrance_area
                let entranceMatcingArea = element.geofence.entrance_matching_area
                let levelChangeArea = element.geofence.level_change_area
                
                if !entranceArea.isEmpty { OlympusPathMatchingCalculator.shared.EntranceArea[key] = entranceArea }
                if !entranceMatcingArea.isEmpty { OlympusPathMatchingCalculator.shared.EntranceMatchingArea[key] = entranceMatcingArea }
                if !levelChangeArea.isEmpty { OlympusPathMatchingCalculator.shared.LevelChangeArea[key] = levelChangeArea }
                
                if (levelName == "B0") {
                    routeTracker.EntranceNumbers = element.entrance_list.count
                    var entranceOuterWards: [String] = []
                    for entrance in element.entrance_list {
                        let entranceKey = "\(key)_\(entrance.spot_number)"
                        routeTracker.EntranceNetworkStatus[entranceKey] = entrance.network_status
                        routeTracker.EntranceVelocityScales[entranceKey] = entrance.scale
                        routeTracker.EntranceRouteVersion[entranceKey] = entrance.route_version
                        entranceOuterWards.append(entrance.outermost_ward_id)
                    }
                    stateManager.EntranceOuterWards = entranceOuterWards
                }
                if (!element.path_pixel_version.isEmpty) {
                    OlympusPathMatchingCalculator.shared.PpVersion[key] = element.path_pixel_version
                }
            }
        }
        buildingLevelChanger.buildingsAndLevels = infoBuildingLevel
        // Entrance Route 버전 확인
        routeTracker.loadEntranceRoute(sector_id: sector_id, RouteVersion: routeTracker.EntranceRouteVersion)
        // Path-Pixel 버전 확인
        OlympusPathMatchingCalculator.shared.loadPathPixel(sector_id: sector_id, PathPixelVersion: OlympusPathMatchingCalculator.shared.PpVersion)
    }
    
    
    public func setMinimumTimeForIndoorReport(time: Double) {
        OlympusConstants.TIME_INIT_THRESHOLD = time
        stateManager.timeForInit = time + 1
    }
    
    func startTimer() {
        if (self.receivedForceTimer == nil) {
            let queueRFD = DispatchQueue(label: Bundle.main.bundleIdentifier! + ".receivedForceTimer")
            self.receivedForceTimer = DispatchSource.makeTimerSource(queue: queueRFD)
            self.receivedForceTimer!.schedule(deadline: .now(), repeating: OlympusConstants.RFD_INTERVAL)
            self.receivedForceTimer!.setEventHandler(handler: self.receivedForceTimerUpdate)
            self.receivedForceTimer!.resume()
        }
        
        if (self.userVelocityTimer == nil) {
            let queueUVD = DispatchQueue(label: Bundle.main.bundleIdentifier! + ".userVelocityTimer")
            self.userVelocityTimer = DispatchSource.makeTimerSource(queue: queueUVD)
            self.userVelocityTimer!.schedule(deadline: .now(), repeating: OlympusConstants.UVD_INTERVAL)
            self.userVelocityTimer!.setEventHandler(handler: self.userVelocityTimerUpdate)
            self.userVelocityTimer!.resume()
        }
        
        
        if (self.outputTimer == nil) {
            let queue = DispatchQueue(label: Bundle.main.bundleIdentifier! + ".updateTimer")
            self.outputTimer = DispatchSource.makeTimerSource(queue: queue)
            self.outputTimer!.schedule(deadline: .now(), repeating: OlympusConstants.OUTPUT_INTERVAL)
            self.outputTimer!.setEventHandler(handler: self.outputTimerUpdate)
            self.outputTimer!.resume()
        }
        
        
        if (self.osrTimer == nil) {
            let queueOSR = DispatchQueue(label: Bundle.main.bundleIdentifier! + ".osrTimer")
            self.osrTimer = DispatchSource.makeTimerSource(queue: queueOSR)
            self.osrTimer!.schedule(deadline: .now(), repeating: OlympusConstants.OSR_INTERVAL)
            self.osrTimer!.setEventHandler(handler: self.osrTimerUpdate)
            self.osrTimer!.resume()
        }
    }
    
    func stopTimer() {
        self.receivedForceTimer?.cancel()
        self.userVelocityTimer?.cancel()
        self.osrTimer?.cancel()
        self.outputTimer?.cancel()
        self.backgroundUpTimer?.cancel()
        
        self.receivedForceTimer = nil
        self.userVelocityTimer = nil
        self.osrTimer = nil
        self.outputTimer = nil
        self.backgroundUvTimer = nil
    }
    
    @objc func receivedForceTimerUpdate() {
        handleRfd()
    }
    
    private func handleRfd() {
        let localTime: String = getLocalTimeString()
        if (isSimulationMode) {
            stateManager.updateTimeForInit()
            let validTime = OlympusConstants.BLE_VALID_TIME
            let currentTime = getCurrentTimeInMilliseconds() - (Int(validTime)/2)
            
            if (bleLineCount < simulationBleData.count-1) {
                let bleData = simulationBleData[bleLineCount]
                self.bleAvg = bleData
                stateManager.getLastScannedEntranceOuterWardTime(bleAvg: self.bleAvg, entranceOuterWards: stateManager.EntranceOuterWards)
                let enterInNetworkBadEntrance = stateManager.checkEnterInNetworkBadEntrance(bleAvg: self.bleAvg)
                if (enterInNetworkBadEntrance.0) {
                    let isOn = routeTracker.startRouteTracking(result: enterInNetworkBadEntrance.1, isStartRouteTrack: self.isStartRouteTrack)
                    unitDRGenerator.setIsStartRouteTrack(isStartRoutTrack: isOn.0)
                    isStartRouteTrack = isOn.0
                    isInNetworkBadEntrance = isOn.1
                    NotificationCenter.default.post(name: .phaseChanged, object: nil, userInfo: ["phase": OlympusConstants.PHASE_3])
                }
                
                rssCompensator.refreshWardMinRssi(bleData: self.bleAvg)
                rssCompensator.refreshWardMaxRssi(bleData: self.bleAvg)
                let maxRssi = rssCompensator.getMaxRssi()
                let minRssi = rssCompensator.getMinRssi()
                let diffMinMaxRssi = abs(maxRssi - minRssi)
                if (minRssi <= OlympusConstants.DEVICE_MIN_UPDATE_THRESHOLD) {
                    let deviceMin: Double = rssCompensator.getDeviceMinRss()
                    OlympusConstants.DEVICE_MIN_RSSI = deviceMin
                }
                rssCompensator.stackTimeAfterResponse(isGetFirstResponse: stateManager.isGetFirstResponse, isIndoor: stateManager.isIndoor)
                rssCompensator.estimateNormalizationScale(isGetFirstResponse: stateManager.isGetFirstResponse, isIndoor: stateManager.isIndoor, currentLevel: self.currentLevel, diffMinMaxRssi: diffMinMaxRssi, minRssi: minRssi)
                
                if (!stateManager.isBackground) {
                    let isSufficientRfdBuffer = rflowCorrelator.accumulateRfdBuffer(bleData: self.bleAvg)
                    let isSufficientRfdVelocityBuffer = rflowCorrelator.accumulateRfdVelocityBuffer(bleData: self.bleAvg)
                    let isSufficientRfdAutoMode = rflowCorrelator.accumulateRfdAutoModeBuffer(bleData: self.bleAvg)
                    if(!self.isStartRouteTrack) {
                        unitDRGenerator.setRflow(rflow: rflowCorrelator.getRflow(), rflowForVelocity: rflowCorrelator.getRflowForVelocityScale(), rflowForAutoMode: rflowCorrelator.getRflowForAutoMode(), isSufficient: isSufficientRfdBuffer, isSufficientForVelocity: isSufficientRfdVelocityBuffer, isSufficientForAutoMode: isSufficientRfdAutoMode)
                    }
                }
                
                if (!self.bleAvg.isEmpty) {
                    stateManager.setVariblesWhenBleIsNotEmpty()
                    let data = ReceivedForce(user_id: self.user_id, mobile_time: currentTime, ble: self.bleAvg, pressure: self.sensorManager.pressure)
                    self.inputReceivedForce.append(data)
                    if ((inputReceivedForce.count) >= OlympusConstants.RFD_INPUT_NUM) {
                        OlympusNetworkManager.shared.postReceivedForce(url: REC_RFD_URL, input: inputReceivedForce, completion: { [self] statusCode, returnedString, inputRfd in
                            if (statusCode != 200) {
        //                        let localTime = getLocalTimeString()
        //                        let msg: String = localTime + " , (Olympus) Error : RFD \(statusCode) // " + returnedString
                                if (stateManager.isIndoor && stateManager.isGetFirstResponse && !stateManager.isBackground) { NotificationCenter.default.post(name: .errorSendRfd, object: nil, userInfo: nil) }
                            }
                        })
                        inputReceivedForce = []
                    }
                    
                } else if (!stateManager.isBackground) {
                    stateManager.checkOutdoorBleEmpty(lastBleDiscoveredTime: bleManager.bleDiscoveredTime, olympusResult: self.olympusResult)
                    stateManager.checkEnterSleepMode(service: self.service, type: 0)
                }
                bleLineCount += 1
            }
        } else {
            stateManager.checkBleOff(bluetoothReady: bleManager.bluetoothReady, bleLastScannedTime: bleManager.bleLastScannedTime)
            stateManager.updateTimeForInit()
            
            let validTime = OlympusConstants.BLE_VALID_TIME
            let currentTime = getCurrentTimeInMilliseconds() - (Int(validTime)/2)
//            let currentTime = getCurrentTimeInMilliseconds() - (Int(validTime)/2)
            let bleDictionary: [String: [[Double]]]? = bleManager.bleDictionary
            if let bleData = bleDictionary {
                let trimmedResult = OlympusRFDFunctions.shared.trimBleData(bleInput: bleData, nowTime: getCurrentTimeInMillisecondsDouble(), validTime: validTime)
                switch trimmedResult {
                case .success(let trimmedData):
                    self.bleAvg = OlympusRFDFunctions.shared.avgBleData(bleDictionary: trimmedData)
                    stateManager.getLastScannedEntranceOuterWardTime(bleAvg: self.bleAvg, entranceOuterWards: stateManager.EntranceOuterWards)
                    let enterInNetworkBadEntrance = stateManager.checkEnterInNetworkBadEntrance(bleAvg: self.bleAvg)
                    if (enterInNetworkBadEntrance.0) {
                        let isOn = routeTracker.startRouteTracking(result: enterInNetworkBadEntrance.1, isStartRouteTrack: self.isStartRouteTrack)
                        unitDRGenerator.setIsStartRouteTrack(isStartRoutTrack: isOn.0)
                        isStartRouteTrack = isOn.0
                        isInNetworkBadEntrance = isOn.1
                        NotificationCenter.default.post(name: .phaseChanged, object: nil, userInfo: ["phase": OlympusConstants.PHASE_3])
                    }
                case .failure(_):
                    print("Trim Fail")
                    let isNeedClearBle = stateManager.checkBleError(olympusResult: self.olympusResult)
                    if (isNeedClearBle) {
                        self.bleAvg = [String: Double]()
                    }
                }
                
                rssCompensator.refreshWardMinRssi(bleData: self.bleAvg)
                rssCompensator.refreshWardMaxRssi(bleData: self.bleAvg)
                let maxRssi = rssCompensator.getMaxRssi()
                let minRssi = rssCompensator.getMinRssi()
                let diffMinMaxRssi = abs(maxRssi - minRssi)
                if (minRssi <= OlympusConstants.DEVICE_MIN_UPDATE_THRESHOLD) {
                    let deviceMin: Double = rssCompensator.getDeviceMinRss()
                    OlympusConstants.DEVICE_MIN_RSSI = deviceMin
                }
                rssCompensator.stackTimeAfterResponse(isGetFirstResponse: stateManager.isGetFirstResponse, isIndoor: stateManager.isIndoor)
                rssCompensator.estimateNormalizationScale(isGetFirstResponse: stateManager.isGetFirstResponse, isIndoor: stateManager.isIndoor, currentLevel: self.currentLevel, diffMinMaxRssi: diffMinMaxRssi, minRssi: minRssi)
            } else {
                let msg: String = localTime + " , (Olympus) Warnings : Fail to get recent BLE"
                print(msg)
            }
            
            OlympusFileManager.shared.writeBleData(time: currentTime, data: bleAvg)
            
            if (!stateManager.isBackground) {
                let isSufficientRfdBuffer = rflowCorrelator.accumulateRfdBuffer(bleData: self.bleAvg)
                let isSufficientRfdVelocityBuffer = rflowCorrelator.accumulateRfdVelocityBuffer(bleData: self.bleAvg)
                let isSufficientRfdAutoMode = rflowCorrelator.accumulateRfdAutoModeBuffer(bleData: self.bleAvg)
                if(!self.isStartRouteTrack) {
                    unitDRGenerator.setRflow(rflow: rflowCorrelator.getRflow(), rflowForVelocity: rflowCorrelator.getRflowForVelocityScale(), rflowForAutoMode: rflowCorrelator.getRflowForAutoMode(), isSufficient: isSufficientRfdBuffer, isSufficientForVelocity: isSufficientRfdVelocityBuffer, isSufficientForAutoMode: isSufficientRfdAutoMode)
                }
            }
            
            if (!self.bleAvg.isEmpty) {
                stateManager.setVariblesWhenBleIsNotEmpty()
                let data = ReceivedForce(user_id: self.user_id, mobile_time: currentTime, ble: self.bleAvg, pressure: self.sensorManager.pressure)
                self.inputReceivedForce.append(data)
                if ((inputReceivedForce.count) >= OlympusConstants.RFD_INPUT_NUM) {
                    OlympusNetworkManager.shared.postReceivedForce(url: REC_RFD_URL, input: inputReceivedForce, completion: { [self] statusCode, returnedString, inputRfd in
                        if (statusCode != 200) {
    //                        let localTime = getLocalTimeString()
    //                        let msg: String = localTime + " , (Olympus) Error : RFD \(statusCode) // " + returnedString
                            if (stateManager.isIndoor && stateManager.isGetFirstResponse && !stateManager.isBackground) { NotificationCenter.default.post(name: .errorSendRfd, object: nil, userInfo: nil) }
                        }
                    })
                    inputReceivedForce = []
                }
                
            } else if (!stateManager.isBackground) {
                stateManager.checkOutdoorBleEmpty(lastBleDiscoveredTime: bleManager.bleDiscoveredTime, olympusResult: self.olympusResult)
                stateManager.checkEnterSleepMode(service: self.service, type: 0)
            }
        }
    }
    
    @objc func userVelocityTimerUpdate() {
        let currentTime = getCurrentTimeInMilliseconds()
        
        self.controlMode()
        OlympusConstants().setModeParam(mode: self.runMode, phase: phaseController.PHASE)
        var sensorData = OlympusSensorData()
        sensorData.time = Double(currentTime)

        if (service.contains(OlympusConstants.SERVICE_FLT)) {
            if (isSimulationMode) {
                if (sensorLineCount < simulationSensorData.count-1) {
                    sensorData = simulationSensorData[sensorLineCount]
                    sensorLineCount += 1
                }
            } else {
                sensorData = sensorManager.sensorData
            }
            unitDRInfo = unitDRGenerator.generateDRInfo(sensorData: sensorData)
            OlympusFileManager.shared.writeSensorData(data: sensorData)
        }
        
        var backgroundScale: Double = 1.0
        if (stateManager.isBackground && runMode == OlympusConstants.MODE_DR) {
            let diffTime = currentTime - self.pastUvdTime
            backgroundScale = Double(diffTime)/(1000/OlympusConstants.SAMPLE_HZ)
        }
        self.pastUvdTime = currentTime
        
        if (unitDRInfo.isIndexChanged && !stateManager.isVenusMode) {
            // 임시
            displayOutput.isIndexChanged = unitDRInfo.isIndexChanged
            displayOutput.length = unitDRInfo.length
            displayOutput.velocity = unitDRInfo.velocity * 3.6
            // 임시
            
            stateManager.setVariblesWhenIsIndexChanged()
            stackHeadingForCheckCorrection()
            isPossibleHeadingCorrection = checkHeadingCorrection(buffer: headingBufferForCorrection)
            stackUnitDRInfo()
            olympusVelocity = unitDRInfo.velocity * 3.6
            var unitUvdLength: Double = 0
            if (stateManager.isBackground) {
                unitUvdLength = unitDRInfo.length*backgroundScale
            } else {
                unitUvdLength = unitDRInfo.length
            }
            unitUvdLength = round(unitUvdLength*10000)/10000
            self.unitDRInfoIndex = unitDRInfo.index
            
            let data = UserVelocity(user_id: self.user_id, mobile_time: currentTime, index: unitDRInfo.index, length: unitUvdLength, heading: round(unitDRInfo.heading*100)/100, looking: unitDRInfo.lookingFlag)
            inputUserVelocity.append(data)
            
            trajController.checkPhase2To4(unitLength: unitUvdLength)
            buildingLevelChanger.accumulateOsrDistance(unitLength: unitUvdLength, isGetFirstResponse: stateManager.isGetFirstResponse, mode: self.runMode, result: self.olympusResult)
            
            let isInEntranceLevel = stateManager.checkInEntranceLevel(result: self.olympusResult, isStartRouteTrack: self.isStartRouteTrack)
            unitDRGenerator.setIsInEntranceLevel(flag: isInEntranceLevel)
            let entrancaeVelocityScale: Double = routeTracker.getEntranceVelocityScale(isGetFirstResponse: stateManager.isGetFirstResponse, isStartRouteTrack: self.isStartRouteTrack)
            unitDRGenerator.setEntranceVelocityScale(scale: entrancaeVelocityScale)
            let numBleChannels = OlympusRFDFunctions.shared.checkBleChannelNum(bleAvg: self.bleAvg)
            trajController.checkTrajectoryInfo(isPhaseBreak: self.isPhaseBreak, isBecomeForeground: stateManager.isBecomeForeground, isGetFirstResponse: stateManager.isGetFirstResponse, timeForInit: stateManager.timeForInit)
            let trajectoryInfo = trajController.getTrajectoryInfo(unitDRInfo: unitDRInfo, unitLength: unitUvdLength, olympusResult: self.olympusResult, isKF: KF.isRunning, tuResult: timeUpdateResult, isPmSuccess: false, numBleChannels: numBleChannels, mode: self.runMode, isDetermineSpot: buildingLevelChanger.isDetermineSpot, spotCutIndex: buildingLevelChanger.spotCutIndex)
            
            if ((inputUserVelocity.count) >= OlympusConstants.UVD_INPUT_NUM) {
                OlympusNetworkManager.shared.postUserVelocity(url: REC_UVD_URL, input: inputUserVelocity, completion: { [self] statusCode, returnedString, inputUvd in
                    if (statusCode == 200) {
                        KF.updateTuResultWhenUvdPosted(result: currentTuResult)
                        self.isPostUvdAnswered = true
                    } else {
//                        let localTime = getLocalTimeString()
//                        let msg: String = localTime + " , (Olympus) Error : UVD \(statusCode) // " + returnedString
                        if (stateManager.isIndoor && stateManager.isGetFirstResponse && !stateManager.isBackground) { NotificationCenter.default.post(name: .errorSendUvd, object: nil, userInfo: nil) }
                        trajController.stackPostUvdFailData(inputUvd: inputUvd)
                    }
                })
                inputUserVelocity = []
            }
            
            // Time Update
            let diffHeading = unitDRInfo.heading - pastUvdHeading
            pastUvdHeading = unitDRInfo.heading
            if (KF.isRunning && KF.tuFlag) {
                var tuResult = KF.timeUpdate(recentResult: olympusResult, length: unitUvdLength, diffHeading: diffHeading, isPossibleHeadingCorrection: isPossibleHeadingCorrection, unitDRInfoBuffer: unitDRInfoBuffer, mode: runMode)
                tuResult.mobile_time = currentTime
                currentTuResult = tuResult
                
                let sectionResult = sectionController.controlSection(userVelocity: data)
                if (sectionResult.0) {
                    displayOutput.indexTx = data.index
                    var nodeCandidates = [Int]()
                    var pathType: Int = 1
                    if (runMode == OlympusConstants.MODE_PDR) { pathType = 0 }
                    print(getLocalTimeString() + " , (Olympus) Request Phase 5 : isBadCaseInStableMode = \(self.isBadCaseInStableMode)")
                    nodeCandidates = OlympusPathMatchingCalculator.shared.getNodeCandidates(fltResult: tuResult, pathType: pathType, requestType: sectionResult.1, isBadCaseInStableMode: self.isBadCaseInStableMode)
                    
                    let anchorTailIndex = sectionController.getAnchorTailIndex()
                    let stableInfo = StableInfo(tail_index: anchorTailIndex, head_section_number: sectionController.rqSectionNumber, node_number_list: nodeCandidates)
                    
                    let userMaskForDisplay = getUserMaskFromIndex(from: self.userMaskBufferDisplay, index: anchorTailIndex)
                    let userTraj = convertUserMask2Trajectory(userMask: userMaskForDisplay)
                    displayOutput.trajectoryStartCoord = userTraj[0]
                    displayOutput.userTrajectory = userTraj
                    print(getLocalTimeString() + " , (Olympus) Request Phase 5 : \(data.index) // requestType : = \(sectionResult.1) // nodeCandidates = \(nodeCandidates)")
                    if (!self.isInRecoveryProcess) {
                        processPhase5(currentTime: getCurrentTimeInMilliseconds(), mode: runMode, trajectoryInfo: trajectoryInfo, stableInfo: stableInfo)
                    }
//                    processPhase5(currentTime: getCurrentTimeInMilliseconds(), mode: runMode, trajectoryInfo: trajectoryInfo, stableInfo: stableInfo)
                }
                
                
                // 임시
                timeUpdateResult[0] = tuResult.x
                timeUpdateResult[1] = tuResult.y
                timeUpdateResult[2] = tuResult.absolute_heading
                displayOutput.trajectoryOg = KF.inputTraj
                displayOutput.trajectoryPm = KF.matchedTraj
                // 임시
                
                KF.updateTuResultNow(result: currentTuResult)
                KF.updateTuInformation(unitDRInfo: unitDRInfo)
                makeTemporalResult(input: tuResult, isStableMode: true)
            }
            
            
            // Route Tracking
            if (isStartRouteTrack) {
                let routeTrackResult = routeTracker.getRouteTrackResult(temporalResult: self.temporalResult, currentLevel: currentLevel, isVenusMode: stateManager.isVenusMode, isKF: KF.isRunning, isPhaseBreakInRouteTrack: isPhaseBreakInRouteTrack)
                if (routeTrackResult.isRouteTrackFinished) {
                    isStartRouteTrack = false
                    unitDRGenerator.setIsStartRouteTrack(isStartRoutTrack: false)
                    isPhaseBreakInRouteTrack = false
                    isInNetworkBadEntrance = false
                    
                    self.currentBuilding = routeTrackResult.1.building_name
                    self.currentLevel = routeTrackResult.1.level_name
                } else {
                    self.routeTrackResult = routeTrackResult.1
                }
            }
            
            requestOlympusResult(trajectoryInfo: trajectoryInfo, mode: self.runMode)
        } else {
            if (!unitDRInfo.isIndexChanged) {
                let isStop = stateManager.checkStopWhenIsIndexNotChanage()
                if (isStop) {
                    olympusVelocity = 0
                }
                stateManager.checkEnterSleepMode(service: self.service, type: 1)
            }
            requestOlympusResultInStop(trajectoryInfo: trajController.pastTrajectoryInfo, mode: self.runMode)
        }
    }
    
    func requestOlympusResult(trajectoryInfo: [TrajectoryInfo], mode: String) {
        let currentTime = getCurrentTimeInMilliseconds()
        
        // Phase 4
        let diffIdx = unitDRInfoIndex - phase3RqIndex
        if (isPostUvdAnswered && phaseController.PHASE == OlympusConstants.PHASE_4 && diffIdx > OlympusConstants.INIT_INPUT_NUM) {
            isPostUvdAnswered = false
            let phase4Trajectory = trajectoryInfo
            if (!stateManager.isBackground) {
                let searchInfo = trajController.makeSearchInfo(trajectoryInfo: phase4Trajectory, serverResultBuffer: serverResultBuffer, unitDRInfoBuffer: unitDRInfoBuffer, isKF: KF.isRunning, mode: mode, PHASE: phaseController.PHASE, isPhaseBreak: isPhaseBreak, phaseBreakResult: phaseBreakResult)
                
                // 임시
                let displaySearchType: Int = trajTypeConverter(trajType: searchInfo.trajType)
                displayOutput.searchArea = searchInfo.searchArea
                displayOutput.searchType = displaySearchType
                displayOutput.userTrajectory = searchInfo.trajShape
                displayOutput.trajectoryStartCoord = searchInfo.trajStartCoord
                // 임시
                
                if (searchInfo.trajType != TrajType.DR_UNKNOWN) {
//                    processPhase4(currentTime: currentTime, mode: mode, trajectoryInfo: phase4Trajectory, searchInfo: searchInfo)
                }
            }
        }
        
        if ((self.unitDRInfoIndex % OlympusConstants.RQ_IDX) == 0 && !stateManager.isBackground) {
            if (phaseController.PHASE == OlympusConstants.PHASE_2) {
                let phase2Trajectory = trajectoryInfo
//                let trajLength = trajController.calculateTrajectoryLength(trajectoryInfo: phase2Trajectory)
//                let searchInfo = trajController.makeSearchInfo(trajectoryInfo: phase2Trajectory, serverResultBuffer: serverResultBuffer, unitDRInfoBuffer: unitDRInfoBuffer, isKF: KF.isRunning, mode: mode, PHASE: phaseController.PHASE, isPhaseBreak: isPhaseBreak, phaseBreakResult: phaseBreakResult)
//                if (trajLength >= OlympusConstants.REQUIRED_LENGTH_PHASE2) {
//                    let phase2SearchInfo = trajController.controlPhase2SearchRange(searchInfo: searchInfo, trajLength: trajLength)
//                    processPhase2(currentTime: currentTime, mode: mode, trajectoryInfo: phase2Trajectory, searchInfo: phase2SearchInfo)
//                }
                let searchInfo = trajController.makeSearchInfoInPhase2(trajectoryInfo: phase2Trajectory, unitDRInfoBuffer: unitDRInfoBuffer, phase2Range: phase2Range, phase2Direction: phase2Direction)
                if (searchInfo.trajType == .DR_RQ_IN_PHASE2) {
                    processPhase2(currentTime: currentTime, mode: mode, trajectoryInfo: phase2Trajectory, searchInfo: searchInfo)
                }
            } else if (phaseController.PHASE == OlympusConstants.PHASE_1 || phaseController.PHASE == OlympusConstants.PHASE_3) {
                // Phase 1 ~ 3
                let phase3Trajectory = trajectoryInfo
                let searchInfo = trajController.makeSearchInfo(trajectoryInfo: phase3Trajectory, serverResultBuffer: serverResultBuffer, unitDRInfoBuffer: unitDRInfoBuffer, isKF: KF.isRunning, mode: mode, PHASE: phaseController.PHASE, isPhaseBreak: isPhaseBreak, phaseBreakResult: phaseBreakResult)
                
                // 임시
                let displaySearchType: Int = trajTypeConverter(trajType: searchInfo.trajType)
                displayOutput.searchArea = searchInfo.searchArea
                displayOutput.searchType = displaySearchType
                displayOutput.userTrajectory = searchInfo.trajShape
                displayOutput.trajectoryStartCoord = searchInfo.trajStartCoord
                // 임시
                
                if (!isStartRouteTrack || isPhaseBreakInRouteTrack) {
                    processPhase3(currentTime: currentTime, mode: mode, trajectoryInfo: phase3Trajectory, searchInfo: searchInfo)
                }
            }
        }
    }
    
    func requestOlympusResultInStop(trajectoryInfo: [TrajectoryInfo], mode: String) {
        let currentTime = getCurrentTimeInMilliseconds()
        self.timeRequest += OlympusConstants.UVD_INTERVAL
        if (stateManager.isVenusMode && self.timeRequest >= OlympusConstants.MINIMUM_RQ_TIME) {
            self.timeRequest = 0
            let phase3Trajectory = trajectoryInfo
            let searchInfo = trajController.makeSearchInfo(trajectoryInfo: phase3Trajectory, serverResultBuffer: serverResultBuffer, unitDRInfoBuffer: unitDRInfoBuffer, isKF: KF.isRunning, mode: mode, PHASE: phaseController.PHASE, isPhaseBreak: isPhaseBreak, phaseBreakResult: phaseBreakResult)
            processPhase3(currentTime: currentTime, mode: mode, trajectoryInfo: phase3Trajectory, searchInfo: searchInfo)
        } else {
            if (!stateManager.isGetFirstResponse && self.timeRequest >= OlympusConstants.MINIMUM_RQ_TIME) {
                self.timeRequest = 0
                let phase3Trajectory = trajectoryInfo
                let searchInfo = trajController.makeSearchInfo(trajectoryInfo: phase3Trajectory, serverResultBuffer: serverResultBuffer, unitDRInfoBuffer: unitDRInfoBuffer, isKF: KF.isRunning, mode: mode, PHASE: phaseController.PHASE, isPhaseBreak: isPhaseBreak, phaseBreakResult: phaseBreakResult)
                processPhase3(currentTime: currentTime, mode: mode, trajectoryInfo: phase3Trajectory, searchInfo: searchInfo)
            }
        }
    }
    
    private func processPhase2(currentTime: Int, mode: String, trajectoryInfo: [TrajectoryInfo], searchInfo: SearchInfo) {
        let trajCompensationArray = trajController.getTrajCompensationArray(currentTime: currentTime, trajLength: searchInfo.trajLength)
        
        var input = FineLocationTracking(user_id: self.user_id, mobile_time: currentTime, sector_id: self.sector_id, operating_system: OlympusConstants.OPERATING_SYSTEM, building_name: self.currentBuilding, level_name_list: [self.currentLevel], phase: OlympusConstants.PHASE_2, search_range: searchInfo.searchRange, search_direction_list: searchInfo.searchDirection, normalization_scale: OlympusConstants.NORMALIZATION_SCALE, device_min_rss: Int(OlympusConstants.DEVICE_MIN_RSSI), sc_compensation_list: trajCompensationArray, tail_index: searchInfo.tailIndex, head_section_number: 0, node_number_list: [])
        stateManager.setNetworkCount(value: stateManager.networkCount+1)
        if (REGION_NAME != "Korea" && self.deviceModel == "iPhone SE (2nd generation)") { input.normalization_scale = 1.01 }
        OlympusNetworkManager.shared.postFLT(url: CALC_FLT_URL, input: input, userTraj: trajectoryInfo, searchInfo: searchInfo, completion: { [self] statusCode, returnedString, fltInput, inputTraj, inputSearchInfo in
//            print("Code = \(statusCode) // Result = \(returnedString)")
            if (!returnedString.contains("timed out")) {
                stateManager.setNetworkCount(value: 0)
            }
            if (statusCode == 200 && (phaseController.PHASE == OlympusConstants.PHASE_2)) {
                let result = jsonToFineLocatoinTrackingResultFromServer(jsonString: returnedString)
                let fltResult = result.1
                if (result.0 && fltResult.x != 0 && fltResult.y != 0) {
                    trajController.updateTrajCompensationArray(result: fltResult)
                    if (fltResult.mobile_time > self.preServerResultMobileTime) {
                        stackServerResult(serverResult: fltResult)
                        let resultPhase = phaseController.controlPhase(serverResultArray: serverResultBuffer, drBuffer: unitDRInfoBuffer, UVD_INTERVAL: OlympusConstants.UVD_INPUT_NUM, TRAJ_LENGTH: OlympusConstants.USER_TRAJECTORY_LENGTH, inputPhase: fltInput.phase, mode: runMode, isVenusMode: stateManager.isVenusMode)
                        // 임시
                        displayOutput.phase = String(resultPhase.0)
                        // 임시
                        let buildingName = fltResult.building_name
                        let levelName = fltResult.level_name
                        trajController.setPastInfo(trajInfo: inputTraj, searchInfo: inputSearchInfo, matchedDirection: fltResult.search_direction)
                        let resultHeading = compensateHeading(heading: fltResult.absolute_heading)
                        var resultCorrected = (true, [fltResult.x, fltResult.y, resultHeading, 1.0])
                        let pathMatchingResult = OlympusPathMatchingCalculator.shared.pathMatching(building: buildingName, level: levelName, x: fltResult.x, y: fltResult.y, heading: fltResult.absolute_heading, HEADING_RANGE: OlympusConstants.HEADING_RANGE, isUseHeading: true, pathType: 1, PADDING_VALUES: paddingValues)
                        resultCorrected.0 = pathMatchingResult.isSuccess
                        resultCorrected.1 = pathMatchingResult.xyhs
                        
                        let isResultStraight = isResultHeadingStraight(unitDRInfoBuffer: self.unitDRInfoBuffer, fltResult: fltResult)
                        if (!isResultStraight) { resultCorrected.1[2] = fltResult.absolute_heading }
                        resultCorrected.1[2] = compensateHeading(heading: resultCorrected.1[2])
                        if (resultPhase.0 == OlympusConstants.PHASE_2 && fltResult.scc < OlympusConstants.SCC_FOR_PHASE_BREAK_IN_PHASE2) {
                            phaseBreakInPhase2()
                        } else if (resultPhase.0 == OlympusConstants.PHASE_2) {
                            phaseController.setPhase2BadCount(value: phaseController.phase2count + 1)
                            if (phaseController.phase2BadCount > OlympusConstants.COUNT_FOR_PHASE_BREAK_IN_PHASE2) {
                                phaseBreakInPhase2()
                            }
                        } else if (resultPhase.0 == OlympusConstants.PHASE_4) {
                            var isUpdateResult: Bool = false
                            
                            let inputTrajLength = trajController.calculateTrajectoryLength(trajectoryInfo: inputTraj)
                            var copiedResult: FineLocationTrackingFromServer = fltResult
                            let propagationResult = propagateUsingUvd(unitDRInfoBuffer: unitDRInfoBuffer, fltResult: fltResult)
                            let propagationValues: [Double] = propagationResult.1
                            var propagatedResult: [Double] = [resultCorrected.1[0]+propagationValues[0] , resultCorrected.1[1]+propagationValues[1], resultCorrected.1[2]+propagationValues[2]]
                            if (propagationResult.0) {
                                let pathMatchingResult = OlympusPathMatchingCalculator.shared.pathMatching(building: buildingName, level: levelName, x: propagatedResult[0], y: propagatedResult[1], heading: propagatedResult[2], HEADING_RANGE: OlympusConstants.HEADING_RANGE, isUseHeading: true, pathType: 1, PADDING_VALUES: paddingValues)
                                propagatedResult = pathMatchingResult.xyhs
                                if (pathMatchingResult.isSuccess) {
                                    if (KF.isRunning) {
                                        if (fltResult.scc > OlympusConstants.SCC_FOR_PHASE2_RESULT_USE) {
                                            isUpdateResult = true
                                        }
                                    } else {
                                        isUpdateResult = true
                                    }
                                }
                            }
                            
                            if (isUpdateResult) {
                                copiedResult.x = pathMatchingResult.xyhs[0]
                                copiedResult.y = pathMatchingResult.xyhs[1]
                                if (inputTrajLength > OlympusConstants.USER_TRAJECTORY_LENGTH_DR*0.4 && fltInput.phase != OlympusConstants.PHASE_1) {
                                    copiedResult.absolute_heading = pathMatchingResult.xyhs[2]
                                }
                                let updatedResult = buildingLevelChanger.updateBuildingAndLevel(fltResult: copiedResult, currentBuilding: currentBuilding, currentLevel: currentLevel)
                                currentBuilding = updatedResult.building_name
                                currentLevel = updatedResult.level_name
                                makeTemporalResult(input: updatedResult, isStableMode: false)
                                
                                if (KF.isRunning) {
                                    KF.refreshTuResult(xyh: [copiedResult.x, copiedResult.y, copiedResult.absolute_heading], inputPhase: fltInput.phase, inputTrajLength: inputTrajLength, mode: runMode)
                                } else {
                                    KF.activateKalmanFilter(fltResult: updatedResult)
                                }
                            }
                            
                            
//                            if (KF.isRunning) {
//                                let inputTrajLength = trajController.calculateTrajectoryLength(trajectoryInfo: inputTraj)
//                                if (resultPhase.0 == OlympusConstants.PHASE_3 || resultPhase.0 == OlympusConstants.PHASE_4) {
//                                    // Phase 3 --> 3 or 4 && KF is Running
//                                    if (pathMatchingResult.isSuccess) {
//                                        copiedResult.x = pathMatchingResult.xyhs[0]
//                                        copiedResult.y = pathMatchingResult.xyhs[1]
//                                        if (inputTrajLength > OlympusConstants.USER_TRAJECTORY_LENGTH_DR*0.4 && inputPhase != OlympusConstants.PHASE_1) {
//                                            copiedResult.absolute_heading = pathMatchingResult.xyhs[2]
//                                        }
//                                        let updatedResult = buildingLevelChanger.updateBuildingAndLevel(fltResult: copiedResult, currentBuilding: currentBuilding, currentLevel: currentLevel)
//                                        currentBuilding = updatedResult.building_name
//                                        currentLevel = updatedResult.level_name
//                                        makeTemporalResult(input: updatedResult, isStableMode: false)
//                                        
//                                        KF.refreshTuResult(xyh: [copiedResult.x, copiedResult.y, copiedResult.absolute_heading], inputPhase: inputPhase, inputTrajLength: inputTrajLength, mode: runMode)
//                                    }
//                                }
//                                
//                                if (fltResult.scc > OlympusConstants.SCC_FOR_PHASE2_RESULT_USE) {
//                                    copiedResult.x = propagatedResult[0]
//                                    copiedResult.y = propagatedResult[1]
//                                    copiedResult.absolute_heading = propagatedResult[2]
//                                    
//                                    let updatedResult = buildingLevelChanger.updateBuildingAndLevel(fltResult: copiedResult, currentBuilding: currentBuilding, currentLevel: currentLevel)
//                                    currentBuilding = updatedResult.building_name
//                                    currentLevel = updatedResult.level_name
//                                    makeTemporalResult(input: updatedResult, isStableMode: false)
//                                    KF.activateKalmanFilter(fltResult: updatedResult)
//                                }
//                            } else {
//                                copiedResult.x = propagatedResult[0]
//                                copiedResult.y = propagatedResult[1]
//                                copiedResult.absolute_heading = propagatedResult[2]
//                                
//                                let updatedResult = buildingLevelChanger.updateBuildingAndLevel(fltResult: copiedResult, currentBuilding: currentBuilding, currentLevel: currentLevel)
//                                currentBuilding = updatedResult.building_name
//                                currentLevel = updatedResult.level_name
//                                makeTemporalResult(input: updatedResult, isStableMode: false)
//                                KF.activateKalmanFilter(fltResult: updatedResult)
//                            }
                        }
                        self.preServerResultMobileTime = fltResult.mobile_time
                    }
                } else {
                    phaseBreakInPhase2()
                }
            } else {
                let msg: String = getLocalTimeString() + " , (Olympus) Error : \(statusCode) Fail to request indoor position in Phase 2"
                print(msg)
            }
        })
    }
    
    private func processPhase3(currentTime: Int, mode: String, trajectoryInfo: [TrajectoryInfo], searchInfo: SearchInfo) {
        if (mode == OlympusConstants.MODE_PDR) {
            self.currentLevel = removeLevelDirectionString(levelName: self.currentLevel)
        }
        var levelArray = [self.currentLevel]
        let isInLevelChangeArea = buildingLevelChanger.checkInLevelChangeArea(result: self.olympusResult, mode: mode)
        if (isInLevelChangeArea) {
            levelArray = buildingLevelChanger.makeLevelChangeArray(buildingName: self.currentBuilding, levelName: self.currentLevel, buildingLevel: buildingLevelChanger.buildingsAndLevels)
        }
        displayOutput.phase = String(phaseController.PHASE)
        displayOutput.searchDirection = searchInfo.searchDirection
        displayOutput.indexTx = unitDRInfoIndex
        phase3RqIndex = unitDRInfoIndex
        var input = FineLocationTracking(user_id: self.user_id, mobile_time: currentTime, sector_id: self.sector_id, operating_system: OlympusConstants.OPERATING_SYSTEM, building_name: self.currentBuilding, level_name_list: levelArray, phase: phaseController.PHASE, search_range: searchInfo.searchRange, search_direction_list: searchInfo.searchDirection, normalization_scale: OlympusConstants.NORMALIZATION_SCALE, device_min_rss: Int(OlympusConstants.DEVICE_MIN_RSSI), sc_compensation_list: [1.0], tail_index: searchInfo.tailIndex, head_section_number: 0, node_number_list: [])
        stateManager.setNetworkCount(value: stateManager.networkCount+1)
//        print(getLocalTimeString() + " , (Olympus) Request Phase3 : \(input)")
        if (REGION_NAME != "Korea" && self.deviceModel == "iPhone SE (2nd generation)") { input.normalization_scale = 1.01 }
        OlympusNetworkManager.shared.postFLT(url: CALC_FLT_URL, input: input, userTraj: trajectoryInfo, searchInfo: searchInfo, completion: { [self] statusCode, returnedString, fltInput, inputTraj, inputSearchInfo in
//            print("Code = \(statusCode) // Result = \(returnedString)")
            if (!returnedString.contains("timed out")) { stateManager.setNetworkCount(value: 0) }
            if (statusCode == 200) {
                let result = jsonToFineLocatoinTrackingResultFromServer(jsonString: returnedString)
                let fltResult = result.1
                if (result.0 && fltResult.x != 0 && fltResult.y != 0) {
                    // 임시
                    displayOutput.indexRx = fltResult.index
                    displayOutput.scc = fltResult.scc
                    // 임시
                    if (fltResult.mobile_time > self.preServerResultMobileTime) {
                        // 임시
                        displayOutput.indexRx = fltResult.index
                        displayOutput.scc = fltResult.scc
                        displayOutput.resultDirection = fltResult.search_direction
                        displayOutput.serverResult[0] = fltResult.x
                        displayOutput.serverResult[1] = fltResult.y
                        displayOutput.serverResult[2] = fltResult.absolute_heading
                        // 임시
                        stackServerResult(serverResult: fltResult)
                        phaseBreakResult = fltResult
                        let resultPhase = phaseController.controlPhase(serverResultArray: serverResultBuffer, drBuffer: unitDRInfoBuffer, UVD_INTERVAL: OlympusConstants.UVD_INPUT_NUM, TRAJ_LENGTH: OlympusConstants.USER_TRAJECTORY_LENGTH, inputPhase: fltInput.phase, mode: runMode, isVenusMode: stateManager.isVenusMode)
                        // 임시
                        displayOutput.phase = String(resultPhase.0)
                        // 임시
                        if (resultPhase.1) {
                            trajController.setIsNeedTrajCheck(flag: true)
                        }
                        
                        let buildingName = fltResult.building_name
                        let levelName = fltResult.level_name
                        
                        if (!stateManager.isGetFirstResponse) {
                            if (!stateManager.isIndoor && (stateManager.timeForInit >= OlympusConstants.TIME_INIT_THRESHOLD)) {
                                if (levelName != "B0") {
                                    stateManager.setIsGetFirstResponse(isGetFirstResponse: true)
                                    stateManager.setIsIndoor(isIndoor: true)
                                } else {
                                    let isOn = routeTracker.startRouteTracking(result: fltResult, isStartRouteTrack: isStartRouteTrack)
                                    unitDRGenerator.setIsStartRouteTrack(isStartRoutTrack: isOn.0)
                                    isStartRouteTrack = isOn.0
                                    isInNetworkBadEntrance = isOn.1
                                    if (isOn.0) {
                                        stateManager.setIsGetFirstResponse(isGetFirstResponse: true)
                                        stateManager.setIsIndoor(isIndoor: true)
                                    }
                                }
                            }
                        }
                        
                        trajController.setPastInfo(trajInfo: inputTraj, searchInfo: inputSearchInfo, matchedDirection: fltResult.search_direction)
                        var pmResult: FineLocationTrackingFromServer = fltResult
                        if (runMode == OlympusConstants.MODE_PDR) {
                            let pathMatchingResult = OlympusPathMatchingCalculator.shared.pathMatching(building: buildingName, level: levelName, x: fltResult.x, y: fltResult.y, heading: fltResult.absolute_heading, HEADING_RANGE: OlympusConstants.HEADING_RANGE, isUseHeading: false, pathType: 0, PADDING_VALUES: paddingValues)
                            pmResult.x = pathMatchingResult.xyhs[0]
                            pmResult.y = pathMatchingResult.xyhs[1]
                            pmResult.absolute_heading = pathMatchingResult.xyhs[2]
                        } else {
                            let pathMatchingResult = OlympusPathMatchingCalculator.shared.pathMatching(building: buildingName, level: levelName, x: fltResult.x, y: fltResult.y, heading: fltResult.absolute_heading, HEADING_RANGE: OlympusConstants.HEADING_RANGE, isUseHeading: true, pathType: 1, PADDING_VALUES: paddingValues)
                            pmResult.x = pathMatchingResult.xyhs[0]
                            pmResult.y = pathMatchingResult.xyhs[1]
                            pmResult.absolute_heading = pathMatchingResult.xyhs[2]
                            
                            let isResultStraight = isResultHeadingStraight(unitDRInfoBuffer: self.unitDRInfoBuffer, fltResult: fltResult)
                            if (!isResultStraight) { pmResult.absolute_heading = compensateHeading(heading: fltResult.absolute_heading) }
                        }
                        
                        if (KF.isRunning) {
                            var copiedResult: FineLocationTrackingFromServer = fltResult
                            let propagationResult = propagateUsingUvd(unitDRInfoBuffer: unitDRInfoBuffer, fltResult: fltResult)
                            let propagationValues: [Double] = propagationResult.1
                            let propagatedResult: [Double] = [pmResult.x+propagationValues[0] , pmResult.y+propagationValues[1], pmResult.absolute_heading+propagationValues[2]]
                            let pathMatchingResult = OlympusPathMatchingCalculator.shared.pathMatching(building: fltResult.building_name, level: fltResult.level_name, x: propagatedResult[0], y: propagatedResult[1], heading: propagatedResult[2], HEADING_RANGE: OlympusConstants.HEADING_RANGE, isUseHeading: true, pathType: 1, PADDING_VALUES: paddingValues)
                            let inputTrajLength = trajController.calculateTrajectoryLength(trajectoryInfo: inputTraj)
                            if (resultPhase.0 == OlympusConstants.PHASE_3 || resultPhase.0 == OlympusConstants.PHASE_4) {
                                if (resultPhase.0 == OlympusConstants.PHASE_4 && isPhaseBreak) {
                                    KF.resetKalmanR()
                                    OlympusConstants.PADDING_VALUE = OlympusConstants.PADDING_VALUE_SMALL
                                    isPhaseBreak = false
                                }
                                // Phase 3 --> 3 or 4 && KF is Running
                                if (pathMatchingResult.isSuccess) {
                                    copiedResult.x = pathMatchingResult.xyhs[0]
                                    copiedResult.y = pathMatchingResult.xyhs[1]
                                    if (inputTrajLength > OlympusConstants.USER_TRAJECTORY_LENGTH_DR*0.4 && fltInput.phase != OlympusConstants.PHASE_1) {
                                        copiedResult.absolute_heading = pathMatchingResult.xyhs[2]
                                    }
                                    let updatedResult = buildingLevelChanger.updateBuildingAndLevel(fltResult: copiedResult, currentBuilding: currentBuilding, currentLevel: currentLevel)
                                    currentBuilding = updatedResult.building_name
                                    currentLevel = updatedResult.level_name
                                    makeTemporalResult(input: updatedResult, isStableMode: false)
                                    
                                    print("Anchor : setAnchorTainIndex Phase3->4 // index = \(fltResult.index)")
                                    sectionController.setInitialAnchorTailIndex(value: fltResult.index)
                                    KF.refreshTuResult(xyh: [copiedResult.x, copiedResult.y, copiedResult.absolute_heading], inputPhase: fltInput.phase, inputTrajLength: inputTrajLength, mode: runMode)
                                }
                            }
                        } else {
                            if (resultPhase.0 == OlympusConstants.PHASE_4 && !stateManager.isVenusMode) {
                                // Phase 3 --> 4 && KF start
                                var copiedResult: FineLocationTrackingFromServer = fltResult
                                let propagationResult = propagateUsingUvd(unitDRInfoBuffer: unitDRInfoBuffer, fltResult: fltResult)
                                let propagationValues: [Double] = propagationResult.1
                                var propagatedResult: [Double] = [pmResult.x+propagationValues[0] , pmResult.y+propagationValues[1], pmResult.absolute_heading+propagationValues[2]]
                                if (propagationResult.0) {
                                    if (runMode == OlympusConstants.MODE_PDR) {
                                        let pathMatchingResult = OlympusPathMatchingCalculator.shared.pathMatching(building: buildingName, level: levelName, x: propagatedResult[0], y: propagatedResult[1], heading: propagatedResult[2], HEADING_RANGE: OlympusConstants.HEADING_RANGE, isUseHeading: false, pathType: 0, PADDING_VALUES: paddingValues)
                                        propagatedResult = pathMatchingResult.xyhs
                                    } else {
                                        let pathMatchingResult = OlympusPathMatchingCalculator.shared.pathMatching(building: buildingName, level: levelName, x: propagatedResult[0], y: propagatedResult[1], heading: propagatedResult[2], HEADING_RANGE: OlympusConstants.HEADING_RANGE, isUseHeading: true, pathType: 1, PADDING_VALUES: paddingValues)
                                        propagatedResult = pathMatchingResult.xyhs
                                    }
                                }
                                copiedResult.x = propagatedResult[0]
                                copiedResult.y = propagatedResult[1]
                                copiedResult.absolute_heading = propagatedResult[2]
                                
                                let updatedResult = buildingLevelChanger.updateBuildingAndLevel(fltResult: copiedResult, currentBuilding: currentBuilding, currentLevel: currentLevel)
                                currentBuilding = updatedResult.building_name
                                currentLevel = updatedResult.level_name
                                makeTemporalResult(input: updatedResult, isStableMode: false)
                                KF.activateKalmanFilter(fltResult: updatedResult)
                            } else {
                                // KF is not running && Phase 1 ~ 3
                                let updatedResult = buildingLevelChanger.updateBuildingAndLevel(fltResult: fltResult, currentBuilding: currentBuilding, currentLevel: currentLevel)
                                currentBuilding = updatedResult.building_name
                                currentLevel = updatedResult.level_name
                                makeTemporalResult(input: updatedResult, isStableMode: false)
                            }
                        }
                        self.preServerResultMobileTime = fltResult.mobile_time
                    }
                } else {
                    trajController.setIsNeedTrajCheck(flag: true)
                    NotificationCenter.default.post(name: .phaseChanged, object: nil, userInfo: ["phase": OlympusConstants.PHASE_1])
                }
            } else {
                let msg: String = getLocalTimeString() + " , (Olympus) Error : \(statusCode) Fail to request indoor position in Phase 3"
                print(msg)
            }
        })
    }
    
    private func processPhase4(currentTime: Int, mode: String, trajectoryInfo: [TrajectoryInfo], searchInfo: SearchInfo) {
        let trajCompensationArray = trajController.getTrajCompensationArray(currentTime: currentTime, trajLength: searchInfo.trajLength)
        if (mode == OlympusConstants.MODE_PDR) {
            self.currentLevel = removeLevelDirectionString(levelName: self.currentLevel)
        }
        var levelArray = [self.currentLevel]
        let isInLevelChangeArea = buildingLevelChanger.checkInLevelChangeArea(result: self.olympusResult, mode: mode)
        if (isInLevelChangeArea) {
            levelArray = buildingLevelChanger.makeLevelChangeArray(buildingName: self.currentBuilding, levelName: self.currentLevel, buildingLevel: buildingLevelChanger.buildingsAndLevels)
        }
        displayOutput.indexTx = unitDRInfoIndex
        displayOutput.searchDirection = searchInfo.searchDirection
        var input = FineLocationTracking(user_id: self.user_id, mobile_time: currentTime, sector_id: self.sector_id, operating_system: OlympusConstants.OPERATING_SYSTEM, building_name: self.currentBuilding, level_name_list: levelArray, phase: phaseController.PHASE, search_range: searchInfo.searchRange, search_direction_list: searchInfo.searchDirection, normalization_scale: OlympusConstants.NORMALIZATION_SCALE, device_min_rss: Int(OlympusConstants.DEVICE_MIN_RSSI), sc_compensation_list: trajCompensationArray, tail_index: searchInfo.tailIndex, head_section_number: 0, node_number_list: [])
        stateManager.setNetworkCount(value: stateManager.networkCount+1)
        if (REGION_NAME != "Korea" && self.deviceModel == "iPhone SE (2nd generation)") { input.normalization_scale = 1.01 }
        OlympusNetworkManager.shared.postFLT(url: CALC_FLT_URL, input: input, userTraj: trajectoryInfo, searchInfo: searchInfo, completion: { [self] statusCode, returnedString, fltInput, inputTraj, inputSearchInfo in
            if (!returnedString.contains("timed out")) { stateManager.setNetworkCount(value: 0) }
            if (statusCode == 200) {
                let result = jsonToFineLocatoinTrackingResultFromServer(jsonString: returnedString)
                let fltResult = result.1
                trajController.updateTrajCompensationArray(result: fltResult)
                trajController.setPastInfo(trajInfo: inputTraj, searchInfo: inputSearchInfo, matchedDirection: fltResult.search_direction)
                if (fltResult.index > indexPast) {
                    // 임시
                    displayOutput.serverResult[0] = fltResult.x
                    displayOutput.serverResult[1] = fltResult.y
                    displayOutput.serverResult[2] = fltResult.absolute_heading
                    // 임시
                    
                    stackServerResult(serverResult: fltResult)
                    let resultPhase = phaseController.controlPhase(serverResultArray: serverResultBuffer, drBuffer: unitDRInfoBuffer, UVD_INTERVAL: OlympusConstants.UVD_INPUT_NUM, TRAJ_LENGTH: OlympusConstants.USER_TRAJECTORY_LENGTH, inputPhase: fltInput.phase, mode: runMode, isVenusMode: stateManager.isVenusMode)
                    // 임시
                    displayOutput.phase = String(resultPhase.0)
                    // 임시
                    
                    if (KF.isRunning && resultPhase.0 == OlympusConstants.PHASE_4) {
                        if (!(fltResult.x == 0 && fltResult.y == 0) && !buildingLevelChanger.isDetermineSpot && phaseController.PHASE != OlympusConstants.PHASE_2) {
                            // 임시
                            displayOutput.indexRx = fltResult.index
                            displayOutput.scc = fltResult.scc
                            displayOutput.resultDirection = fltResult.search_direction
                            // 임시
                            
                            if (isPhaseBreak) {
                                KF.resetKalmanR()
                                OlympusConstants.PADDING_VALUE = OlympusConstants.PADDING_VALUE_SMALL
                                isPhaseBreak = false
                            }
                            
                            var pmFltRsult = fltResult
                            var propagatedPmFltRsult = fltResult
                            if (KF.muFlag) {
                                var isNeedCalDhFromUvd: Bool = false
                                let isResultStraight = isResultHeadingStraight(unitDRInfoBuffer: unitDRInfoBuffer, fltResult: fltResult)
                                if (runMode == OlympusConstants.MODE_PDR) {
                                    let pathMatchingResult = OlympusPathMatchingCalculator.shared.pathMatching(building: fltResult.building_name, level: fltResult.level_name, x: fltResult.x, y: fltResult.y, heading: fltResult.absolute_heading, HEADING_RANGE: OlympusConstants.HEADING_RANGE, isUseHeading: isResultStraight, pathType: 0, PADDING_VALUES: paddingValues)
                                    pmFltRsult.x = pathMatchingResult.xyhs[0]
                                    pmFltRsult.y = pathMatchingResult.xyhs[1]
                                    pmFltRsult.absolute_heading = pathMatchingResult.xyhs[2]
                                } else {
                                    let pathMatchingResult = OlympusPathMatchingCalculator.shared.pathMatching(building: fltResult.building_name, level: fltResult.level_name, x: fltResult.x, y: fltResult.y, heading: fltResult.absolute_heading, HEADING_RANGE: OlympusConstants.HEADING_RANGE, isUseHeading: true, pathType: 1, PADDING_VALUES: paddingValues)
                                    pmFltRsult.x = pathMatchingResult.xyhs[0]
                                    pmFltRsult.y = pathMatchingResult.xyhs[1]
                                    if (inputSearchInfo.trajType == .DR_TAIL_STRAIGHT && !isResultStraight) {
                                        isNeedCalDhFromUvd = true
                                        pmFltRsult.absolute_heading = fltResult.absolute_heading
                                    }
                                }
                                
                                let dxdydh = KF.preProcessForMeasurementUpdate(fltResult: pmFltRsult, unitDRInfoBuffer: unitDRInfoBuffer, mode: runMode, isNeedCalDhFromUvd: isNeedCalDhFromUvd)
                                propagatedPmFltRsult.x = pmFltRsult.x + dxdydh[0]
                                propagatedPmFltRsult.y = pmFltRsult.y + dxdydh[1]
                                if (isPossibleHeadingCorrection) {
                                    propagatedPmFltRsult.absolute_heading = pmFltRsult.absolute_heading + dxdydh[2]
                                } else {
                                    propagatedPmFltRsult.absolute_heading = propagatedPmFltRsult.absolute_heading + dxdydh[2]
                                }
                                propagatedPmFltRsult.absolute_heading = compensateHeading(heading: propagatedPmFltRsult.absolute_heading)
                                
                                let muResult = KF.measurementUpdate(fltResult: fltResult, pmFltResult: pmFltRsult, propagatedPmFltResult: propagatedPmFltRsult, unitDRInfoBuffer: unitDRInfoBuffer, isPossibleHeadingCorrection: isPossibleHeadingCorrection, mode: runMode)
                                let updatedResult = buildingLevelChanger.updateBuildingAndLevel(fltResult: muResult, currentBuilding: currentBuilding, currentLevel: currentLevel)
                                currentBuilding = updatedResult.building_name
                                currentLevel = updatedResult.level_name
                                makeTemporalResult(input: updatedResult, isStableMode: false)
                            }
                        } else if (fltResult.x == 0 && fltResult.y == 0) {
                            phaseBreakInPhase4(fltResult: fltResult, isUpdatePhaseBreakResult: false)
                        }
                    } else {
                        phaseBreakInPhase4(fltResult: fltResult, isUpdatePhaseBreakResult: true)
                    }
                    indexPast = fltResult.index
                }
                preServerResultMobileTime = fltResult.mobile_time
            } else{
                
            }
        })
    }
    
    private func processPhase5(currentTime: Int, mode: String, trajectoryInfo: [TrajectoryInfo], stableInfo: StableInfo) {
        if (mode == OlympusConstants.MODE_PDR) {
            self.currentLevel = removeLevelDirectionString(levelName: self.currentLevel)
        }
        var levelArray = [self.currentLevel]
        let isInLevelChangeArea = buildingLevelChanger.checkInLevelChangeArea(result: self.olympusResult, mode: mode)
        if (isInLevelChangeArea) {
            levelArray = buildingLevelChanger.makeLevelChangeArray(buildingName: self.currentBuilding, levelName: self.currentLevel, buildingLevel: buildingLevelChanger.buildingsAndLevels)
        }
        displayOutput.phase = "5"
        displayOutput.indexTx = unitDRInfoIndex
        displayOutput.searchDirection = []
        var input = FineLocationTracking(user_id: self.user_id, mobile_time: currentTime, sector_id: self.sector_id, operating_system: OlympusConstants.OPERATING_SYSTEM, building_name: self.currentBuilding, level_name_list: levelArray, phase: 5, search_range: [], search_direction_list: [], normalization_scale: OlympusConstants.NORMALIZATION_SCALE, device_min_rss: Int(OlympusConstants.DEVICE_MIN_RSSI), sc_compensation_list: [1.01], tail_index: stableInfo.tail_index, head_section_number: stableInfo.head_section_number, node_number_list: stableInfo.node_number_list)
//        print(getLocalTimeString() + " , (Olympus) Request Phase 5 : input = \(input)")
        stateManager.setNetworkCount(value: stateManager.networkCount+1)
        if (REGION_NAME != "Korea" && self.deviceModel == "iPhone SE (2nd generation)") { input.normalization_scale = 1.01 }
        OlympusNetworkManager.shared.postFLT(url: CALC_FLT_URL, input: input, userTraj: trajectoryInfo, searchInfo: SearchInfo(), completion: { [self] statusCode, returnedString, fltInput, inputTraj, inputSearchInfo in
            if (!returnedString.contains("timed out")) { stateManager.setNetworkCount(value: 0) }
            if (statusCode == 200) {
                let result = jsonToFineLocatoinTrackingResultFromServer(jsonString: returnedString)
                let fltResult = result.1
                trajController.updateTrajCompensationArray(result: fltResult)
                trajController.setPastInfo(trajInfo: inputTraj, searchInfo: inputSearchInfo, matchedDirection: fltResult.search_direction)
                if (fltResult.index > indexPast) {
                    // 임시
                    displayOutput.serverResult[0] = fltResult.x
                    displayOutput.serverResult[1] = fltResult.y
                    displayOutput.serverResult[2] = fltResult.absolute_heading
                    // 임시
                    
                    stackServerResult(serverResult: fltResult)
                    let resultPhase = phaseController.controlPhase(serverResultArray: serverResultBuffer, drBuffer: unitDRInfoBuffer, UVD_INTERVAL: OlympusConstants.UVD_INPUT_NUM, TRAJ_LENGTH: OlympusConstants.USER_TRAJECTORY_LENGTH, inputPhase: fltInput.phase, mode: runMode, isVenusMode: stateManager.isVenusMode)
                    // 임시
                    displayOutput.phase = String(resultPhase.0)
                    // 임시
                    
                    if (KF.isRunning && resultPhase.0 == OlympusConstants.PHASE_5) {
                        if (!(fltResult.x == 0 && fltResult.y == 0) && !buildingLevelChanger.isDetermineSpot && phaseController.PHASE != OlympusConstants.PHASE_2) {
                            // 임시
                            displayOutput.indexRx = fltResult.index
                            displayOutput.scc = fltResult.scc
                            displayOutput.resultDirection = fltResult.search_direction
                            // 임시
                            
                            if (isPhaseBreak) {
                                KF.resetKalmanR()
                                OlympusConstants.PADDING_VALUE = OlympusConstants.PADDING_VALUE_SMALL
                                isPhaseBreak = false
                            }
                            
//                            if (fltResult.scc < OlympusConstants.PHASE5_RECOVERY_SCC) {
//                                isInRecoveryProcess = true
//                                processRecovery(currentTime: getCurrentTimeInMilliseconds(), mode: mode, trajectoryInfo: trajectoryInfo, input: fltInput)
//                            } else {
//                                var pmFltRsult = fltResult
//                                var propagatedPmFltRsult = fltResult
//                                if (KF.muFlag) {
//                                    var isNeedCalDhFromUvd: Bool = false
//                                    let isResultStraight = isResultHeadingStraight(unitDRInfoBuffer: unitDRInfoBuffer, fltResult: fltResult)
//                                    if (runMode == OlympusConstants.MODE_PDR) {
//                                        let pathMatchingResult = OlympusPathMatchingCalculator.shared.pathMatching(building: fltResult.building_name, level: fltResult.level_name, x: fltResult.x, y: fltResult.y, heading: fltResult.absolute_heading, HEADING_RANGE: OlympusConstants.HEADING_RANGE, isUseHeading: isResultStraight, pathType: 0, PADDING_VALUES: paddingValues)
//                                        pmFltRsult.x = pathMatchingResult.xyhs[0]
//                                        pmFltRsult.y = pathMatchingResult.xyhs[1]
//                                        pmFltRsult.absolute_heading = pathMatchingResult.xyhs[2]
//                                    } else {
//                                        let pathMatchingResult = OlympusPathMatchingCalculator.shared.pathMatching(building: fltResult.building_name, level: fltResult.level_name, x: fltResult.x, y: fltResult.y, heading: fltResult.absolute_heading, HEADING_RANGE: OlympusConstants.HEADING_RANGE, isUseHeading: true, pathType: 1, PADDING_VALUES: paddingValues)
//                                        pmFltRsult.x = pathMatchingResult.xyhs[0]
//                                        pmFltRsult.y = pathMatchingResult.xyhs[1]
//                                        if (inputSearchInfo.trajType == .DR_TAIL_STRAIGHT && !isResultStraight) {
//                                            isNeedCalDhFromUvd = true
//                                            pmFltRsult.absolute_heading = fltResult.absolute_heading
//                                        }
//                                    }
//                                    
//                                    let dxdydh = KF.preProcessForMeasurementUpdate(fltResult: pmFltRsult, unitDRInfoBuffer: unitDRInfoBuffer, mode: runMode, isNeedCalDhFromUvd: isNeedCalDhFromUvd)
//                                    propagatedPmFltRsult.x = pmFltRsult.x + dxdydh[0]
//                                    propagatedPmFltRsult.y = pmFltRsult.y + dxdydh[1]
//                                    if (isPossibleHeadingCorrection) {
//                                        propagatedPmFltRsult.absolute_heading = pmFltRsult.absolute_heading + dxdydh[2]
//                                    } else {
//                                        propagatedPmFltRsult.absolute_heading = propagatedPmFltRsult.absolute_heading + dxdydh[2]
//                                    }
//                                    propagatedPmFltRsult.absolute_heading = compensateHeading(heading: propagatedPmFltRsult.absolute_heading)
//                                    
//                                    let muResult = KF.measurementUpdate(fltResult: fltResult, pmFltResult: pmFltRsult, propagatedPmFltResult: propagatedPmFltRsult, unitDRInfoBuffer: unitDRInfoBuffer, isPossibleHeadingCorrection: isPossibleHeadingCorrection, mode: runMode)
//                                    let updatedResult = buildingLevelChanger.updateBuildingAndLevel(fltResult: muResult, currentBuilding: currentBuilding, currentLevel: currentLevel)
//                                    currentBuilding = updatedResult.building_name
//                                    currentLevel = updatedResult.level_name
//                                    makeTemporalResult(input: updatedResult, isStableMode: false)
//                                }
//                            }
                            
                            var pmFltRsult = fltResult
                            var propagatedPmFltRsult = fltResult
                            if (KF.muFlag) {
                                var isNeedCalDhFromUvd: Bool = false
                                let isResultStraight = isResultHeadingStraight(unitDRInfoBuffer: unitDRInfoBuffer, fltResult: fltResult)
                                if (runMode == OlympusConstants.MODE_PDR) {
                                    let pathMatchingResult = OlympusPathMatchingCalculator.shared.pathMatching(building: fltResult.building_name, level: fltResult.level_name, x: fltResult.x, y: fltResult.y, heading: fltResult.absolute_heading, HEADING_RANGE: OlympusConstants.HEADING_RANGE, isUseHeading: isResultStraight, pathType: 0, PADDING_VALUES: paddingValues)
                                    pmFltRsult.x = pathMatchingResult.xyhs[0]
                                    pmFltRsult.y = pathMatchingResult.xyhs[1]
                                    pmFltRsult.absolute_heading = pathMatchingResult.xyhs[2]
                                } else {
                                    let pathMatchingResult = OlympusPathMatchingCalculator.shared.pathMatching(building: fltResult.building_name, level: fltResult.level_name, x: fltResult.x, y: fltResult.y, heading: fltResult.absolute_heading, HEADING_RANGE: OlympusConstants.HEADING_RANGE, isUseHeading: true, pathType: 1, PADDING_VALUES: paddingValues)
                                    pmFltRsult.x = pathMatchingResult.xyhs[0]
                                    pmFltRsult.y = pathMatchingResult.xyhs[1]
                                    if (inputSearchInfo.trajType == .DR_TAIL_STRAIGHT && !isResultStraight) {
                                        isNeedCalDhFromUvd = true
                                        pmFltRsult.absolute_heading = fltResult.absolute_heading
                                    }
                                }
                                
                                let dxdydh = KF.preProcessForMeasurementUpdate(fltResult: pmFltRsult, unitDRInfoBuffer: unitDRInfoBuffer, mode: runMode, isNeedCalDhFromUvd: isNeedCalDhFromUvd)
                                propagatedPmFltRsult.x = pmFltRsult.x + dxdydh[0]
                                propagatedPmFltRsult.y = pmFltRsult.y + dxdydh[1]
                                if (isPossibleHeadingCorrection) {
                                    propagatedPmFltRsult.absolute_heading = pmFltRsult.absolute_heading + dxdydh[2]
                                } else {
                                    propagatedPmFltRsult.absolute_heading = propagatedPmFltRsult.absolute_heading + dxdydh[2]
                                }
                                propagatedPmFltRsult.absolute_heading = compensateHeading(heading: propagatedPmFltRsult.absolute_heading)
                                
                                let muResult = KF.measurementUpdate(fltResult: fltResult, pmFltResult: pmFltRsult, propagatedPmFltResult: propagatedPmFltRsult, unitDRInfoBuffer: unitDRInfoBuffer, isPossibleHeadingCorrection: isPossibleHeadingCorrection, mode: runMode)
                                let updatedResult = buildingLevelChanger.updateBuildingAndLevel(fltResult: muResult, currentBuilding: currentBuilding, currentLevel: currentLevel)
                                currentBuilding = updatedResult.building_name
                                currentLevel = updatedResult.level_name
                                makeTemporalResult(input: updatedResult, isStableMode: false)
                            }
                        } else if (fltResult.x == 0 && fltResult.y == 0) {
                            phaseBreakInPhase4(fltResult: fltResult, isUpdatePhaseBreakResult: false)
                        }
                    } else {
                        phaseBreakInPhase4(fltResult: fltResult, isUpdatePhaseBreakResult: true)
                    }
                    indexPast = fltResult.index
                }
                preServerResultMobileTime = fltResult.mobile_time
                self.isInRecoveryProcess = false
            } else{
                let msg: String = getLocalTimeString() + " , (Olympus) Error : \(statusCode) Fail to request indoor position in Phase 5"
                print(msg)
            }
        })
    }
    
    private func processRecovery(currentTime: Int, mode: String, trajectoryInfo: [TrajectoryInfo], input: FineLocationTracking) {
        var pathType: Int = 1
        if (mode == OlympusConstants.MODE_PDR) { pathType = 0 }
        var recoveryInput = input
        recoveryInput.node_number_list = OlympusPathMatchingCalculator.shared.getNodeCandidatesForRecovery(pathType: pathType)
        
        displayOutput.phase = "5 // Recovery"
        displayOutput.indexTx = unitDRInfoIndex
        displayOutput.searchDirection = []
        stateManager.setNetworkCount(value: stateManager.networkCount+1)
        if (REGION_NAME != "Korea" && self.deviceModel == "iPhone SE (2nd generation)") { recoveryInput.normalization_scale = 1.01 }
        OlympusNetworkManager.shared.postFLT(url: CALC_FLT_URL, input: recoveryInput, userTraj: trajectoryInfo, searchInfo: SearchInfo(), completion: { [self] statusCode, returnedString, fltInput, inputTraj, inputSearchInfo in
            if (!returnedString.contains("timed out")) { stateManager.setNetworkCount(value: 0) }
            if (statusCode == 200) {
                let result = jsonToFineLocatoinTrackingResultFromServer(jsonString: returnedString)
                let fltResult = result.1
                trajController.setPastInfo(trajInfo: inputTraj, searchInfo: inputSearchInfo, matchedDirection: fltResult.search_direction)
                if (fltResult.index > indexPast) {
                    // 임시
                    displayOutput.serverResult[0] = fltResult.x
                    displayOutput.serverResult[1] = fltResult.y
                    displayOutput.serverResult[2] = fltResult.absolute_heading
                    // 임시
                    
                    stackServerResult(serverResult: fltResult)
                    let resultPhase = phaseController.controlPhase(serverResultArray: serverResultBuffer, drBuffer: unitDRInfoBuffer, UVD_INTERVAL: OlympusConstants.UVD_INPUT_NUM, TRAJ_LENGTH: OlympusConstants.USER_TRAJECTORY_LENGTH, inputPhase: fltInput.phase, mode: runMode, isVenusMode: stateManager.isVenusMode)
                    // 임시
                    displayOutput.phase = String(resultPhase.0)
                    // 임시
                    
                    if (KF.isRunning && resultPhase.0 == OlympusConstants.PHASE_5) {
                        if (!(fltResult.x == 0 && fltResult.y == 0) && !buildingLevelChanger.isDetermineSpot && phaseController.PHASE != OlympusConstants.PHASE_2) {
                            // 임시
                            displayOutput.indexRx = fltResult.index
                            displayOutput.scc = fltResult.scc
                            displayOutput.resultDirection = fltResult.search_direction
                            // 임시
                            
                            if (isPhaseBreak) {
                                KF.resetKalmanR()
                                OlympusConstants.PADDING_VALUE = OlympusConstants.PADDING_VALUE_SMALL
                                isPhaseBreak = false
                            }
                            
                            var pmFltRsult = fltResult
                            var propagatedPmFltRsult = fltResult
                            if (KF.muFlag) {
                                var isNeedCalDhFromUvd: Bool = false
                                let isResultStraight = isResultHeadingStraight(unitDRInfoBuffer: unitDRInfoBuffer, fltResult: fltResult)
                                if (runMode == OlympusConstants.MODE_PDR) {
                                    let pathMatchingResult = OlympusPathMatchingCalculator.shared.pathMatching(building: fltResult.building_name, level: fltResult.level_name, x: fltResult.x, y: fltResult.y, heading: fltResult.absolute_heading, HEADING_RANGE: OlympusConstants.HEADING_RANGE, isUseHeading: isResultStraight, pathType: 0, PADDING_VALUES: paddingValues)
                                    pmFltRsult.x = pathMatchingResult.xyhs[0]
                                    pmFltRsult.y = pathMatchingResult.xyhs[1]
                                    pmFltRsult.absolute_heading = pathMatchingResult.xyhs[2]
                                } else {
                                    let pathMatchingResult = OlympusPathMatchingCalculator.shared.pathMatching(building: fltResult.building_name, level: fltResult.level_name, x: fltResult.x, y: fltResult.y, heading: fltResult.absolute_heading, HEADING_RANGE: OlympusConstants.HEADING_RANGE, isUseHeading: true, pathType: 1, PADDING_VALUES: paddingValues)
                                    pmFltRsult.x = pathMatchingResult.xyhs[0]
                                    pmFltRsult.y = pathMatchingResult.xyhs[1]
                                    if (inputSearchInfo.trajType == .DR_TAIL_STRAIGHT && !isResultStraight) {
                                        isNeedCalDhFromUvd = true
                                        pmFltRsult.absolute_heading = fltResult.absolute_heading
                                    }
                                }
                                
                                let dxdydh = KF.preProcessForMeasurementUpdate(fltResult: pmFltRsult, unitDRInfoBuffer: unitDRInfoBuffer, mode: runMode, isNeedCalDhFromUvd: isNeedCalDhFromUvd)
                                propagatedPmFltRsult.x = pmFltRsult.x + dxdydh[0]
                                propagatedPmFltRsult.y = pmFltRsult.y + dxdydh[1]
                                if (isPossibleHeadingCorrection) {
                                    propagatedPmFltRsult.absolute_heading = pmFltRsult.absolute_heading + dxdydh[2]
                                } else {
                                    propagatedPmFltRsult.absolute_heading = propagatedPmFltRsult.absolute_heading + dxdydh[2]
                                }
                                propagatedPmFltRsult.absolute_heading = compensateHeading(heading: propagatedPmFltRsult.absolute_heading)
                                
                                let muResult = KF.measurementUpdate(fltResult: fltResult, pmFltResult: pmFltRsult, propagatedPmFltResult: propagatedPmFltRsult, unitDRInfoBuffer: unitDRInfoBuffer, isPossibleHeadingCorrection: isPossibleHeadingCorrection, mode: runMode)
                                let updatedResult = buildingLevelChanger.updateBuildingAndLevel(fltResult: muResult, currentBuilding: currentBuilding, currentLevel: currentLevel)
                                currentBuilding = updatedResult.building_name
                                currentLevel = updatedResult.level_name
                                makeTemporalResult(input: updatedResult, isStableMode: false)
                            }
                        } else if (fltResult.x == 0 && fltResult.y == 0) {
                            phaseBreakInPhase4(fltResult: fltResult, isUpdatePhaseBreakResult: false)
                        }
                    } else {
                        phaseBreakInPhase4(fltResult: fltResult, isUpdatePhaseBreakResult: true)
                    }
                    indexPast = fltResult.index
                }
                preServerResultMobileTime = fltResult.mobile_time
                
            } else {
                let msg: String = getLocalTimeString() + " , (Olympus) Error : \(statusCode) Fail to request indoor position in Phase 5 recovery"
                print(msg)
            }
        })
    }
    
    @objc func outputTimerUpdate() {
        // Run every 0.2s
        let validInfo = checkSolutionValidity(reportFlag: self.pastReportFlag, reportTime: self.pastReportTime, isIndoor: stateManager.isIndoor)
        if (isStartRouteTrack) {
            olympusResult = temporalToOlympus(fromServer: routeTrackResult, phase: phaseController.PHASE, velocity: olympusVelocity, mode: runMode, ble_only_position: stateManager.isVenusMode, isIndoor: stateManager.isIndoor, validity: validInfo.0, validity_flag: validInfo.1)
        } else {
            olympusResult = temporalToOlympus(fromServer: temporalResult, phase: phaseController.PHASE, velocity: olympusVelocity, mode: runMode, ble_only_position: stateManager.isVenusMode, isIndoor: stateManager.isIndoor, validity: validInfo.0, validity_flag: validInfo.1)
        }
        self.olympusResult.mobile_time = getCurrentTimeInMilliseconds()
        self.tracking(input: self.olympusResult)
    }
    
    func makeTemporalResult(input: FineLocationTrackingFromServer, isStableMode: Bool) {
        var result = input
        result.index = unitDRInfoIndex
        if (result.x != 0 && result.y != 0 && result.building_name != "" && result.level_name != "") {
            let buildingName: String = result.building_name
            let levelName: String = removeLevelDirectionString(levelName: result.level_name)
            result.level_name = levelName
            
            var temporalResultHeading: Double = result.absolute_heading
            var pathTypeForNodeAndLink = 0
            var isPmFailed: Bool = false
            if (runMode == OlympusConstants.MODE_PDR) {
                pathTypeForNodeAndLink = 0
                let isUseHeading: Bool = false
                let correctResult = OlympusPathMatchingCalculator.shared.pathMatching(building: buildingName, level: levelName, x: result.x, y: result.y, heading: result.absolute_heading, HEADING_RANGE: OlympusConstants.HEADING_RANGE, isUseHeading: isUseHeading, pathType: 0, PADDING_VALUES: paddingValues)
                if (correctResult.isSuccess) {
                    result.x = correctResult.xyhs[0]
                    result.y = correctResult.xyhs[1]
                    result.absolute_heading = correctResult.xyhs[2]
                    temporalResultHeading = correctResult.bestHeading
                } else {
                    let key: String = "\(buildingName)_\(levelName)"
                    
                    var ppIsLoaded: Bool = true
                    if let isLoaded: Bool = OlympusPathMatchingCalculator.shared.PpIsLoaded[key] { ppIsLoaded = isLoaded }
                    if let _ = OlympusPathMatchingCalculator.shared.PpCoord[key] {
                        OlympusPathMatchingCalculator.shared.PpIsLoaded[key] = true
                    } else {
                        if (!ppIsLoaded) {
                            OlympusPathMatchingCalculator.shared.loadPathPixel(sector_id: sector_id, PathPixelVersion: OlympusPathMatchingCalculator.shared.PpVersion)
                        }
                    }
                    isPmFailed = true
                }
            } else {
                pathTypeForNodeAndLink = 1
                var isUseHeading: Bool = true
                if (stateManager.isVenusMode) {
                    isUseHeading = false
                }
                let correctedResult = OlympusPathMatchingCalculator.shared.pathMatching(building: buildingName, level: levelName, x: result.x, y: result.y, heading: result.absolute_heading, HEADING_RANGE: OlympusConstants.HEADING_RANGE, isUseHeading: isUseHeading, pathType: 1, PADDING_VALUES: paddingValues)
                if (correctedResult.isSuccess) {
                    unitDRGenerator.setVelocityScale(scale: correctedResult.xyhs[3])
                    
                    result.x = correctedResult.xyhs[0]
                    result.y = correctedResult.xyhs[1]
                    result.absolute_heading = correctedResult.xyhs[2]
                    temporalResultHeading = correctedResult.bestHeading
                } else {
                    let key: String = "\(buildingName)_\(levelName)"
                    var ppIsLoaded: Bool = true
                    if let isLoaded: Bool = OlympusPathMatchingCalculator.shared.PpIsLoaded[key] { ppIsLoaded = isLoaded }
                    if let _ = OlympusPathMatchingCalculator.shared.PpCoord[key] {
                        OlympusPathMatchingCalculator.shared.PpIsLoaded[key] = true
                    } else {
                        if (!ppIsLoaded) {
                            OlympusPathMatchingCalculator.shared.loadPathPixel(sector_id: sector_id, PathPixelVersion: OlympusPathMatchingCalculator.shared.PpVersion)
                        }
                    }
                    isPmFailed = true
                }
            }
            
            if (isPmFailed) {
                if (KF.isRunning) {
                    result = self.preTemporalResult
                } else {
                    // Path-Matching 실패
                }
            }
            
            if (KF.isRunning) {
                OlympusPathMatchingCalculator.shared.updateNodeAndLinkInfo(currentResult: result, currentResultHeading: temporalResultHeading, pastResult: preTemporalResult, pastResultHeading: preTemporalResultHeading, pathType: pathTypeForNodeAndLink)
                self.paddingValues = OlympusPathMatchingCalculator.shared.getPaddingValues(mode: runMode, isPhaseBreak: isPhaseBreak)
            }
            
            if (isStableMode) {
                if (stableModeInitFlag) {
                    sectionController.setInitialAnchorTailIndex(value: result.index)
                    stableModeInitFlag = false
                }
                
                let data = UserMask(user_id: self.user_id, mobile_time: result.mobile_time, section_number: sectionController.sectionNumber, index: result.index, x: Int(result.x), y: Int(result.y), absolute_heading: result.absolute_heading)
                self.inputUserMask.append(data)
                if ((self.inputUserMask.count) >= OlympusConstants.USER_MASK_INPUT_NUM) {
                    OlympusNetworkManager.shared.postUserMask(url: REC_UMD_URL, input: self.inputUserMask, completion: { statusCode, returnedString, inputUserMask in
                        if (statusCode != 200) {
                            let localTime = getLocalTimeString()
                            let msg: String = localTime + " , (Olympus) Error : UserMask \(statusCode) // " + returnedString
                            print(msg)
                        }
                    })
                    inputUserMask = []
                }
                stackUserMask(data: data)
                stackUserMaskForDisplay(data: data)
                self.isBadCaseInStableMode = checkBadCase(unitDRInfoBuffer: self.unitDRInfoBuffer, userMaskBuffer: self.userMaskBuffer, mode: self.runMode)
            }
            
            self.temporalResult = result
            self.preTemporalResult = result
            self.preTemporalResultHeading = temporalResultHeading
        }
    }
    
    @objc func osrTimerUpdate() {
//        buildingLevelChanger.estimateBuildingLevel(user_id: self.user_id, mode: self.runMode, phase: phaseController.PHASE, isGetFirstResponse: stateManager.isGetFirstResponse, isInNetworkBadEntrance: self.isInNetworkBadEntrance, result: self.olympusResult, currentBuilding: self.currentBuilding, currentLevel: self.currentLevel, currentEntrance: routeTracker.currentEntrance)
    }
    
    private func controlMode() {
        if (self.mode == OlympusConstants.MODE_AUTO) {
            let autoMode = unitDRInfo.autoMode
            if (autoMode == 0) {
                self.runMode = OlympusConstants.MODE_PDR
                self.sector_id = self.sector_id_origin - 1
            } else {
                self.runMode = OlympusConstants.MODE_DR
                self.sector_id = self.sector_id_origin
            }
            
            if (self.runMode != self.currentMode) {
                NotificationCenter.default.post(name: .phaseChanged, object: nil, userInfo: ["phase": OlympusConstants.PHASE_1])
                trajController.setIsNeedTrajCheck(flag: true)
            }
            self.currentMode = self.runMode
        }
        sensorManager.setRunMode(mode: self.runMode)
    }
    
    private func stackUnitDRInfo() {
        self.unitDRInfoBuffer.append(self.unitDRInfo)
        if (self.unitDRInfoBuffer.count > OlympusConstants.DR_INFO_BUFFER_SIZE) {
            self.unitDRInfoBuffer.remove(at: 0)
        }
    }
    
    private func stackUserMask(data: UserMask) {
        self.userMaskBuffer.append(data)
        if (self.userMaskBuffer.count > OlympusConstants.DR_INFO_BUFFER_SIZE) {
            self.userMaskBuffer.remove(at: 0)
        }
    }
    
    private func stackUserMaskForDisplay(data: UserMask) {
        self.userMaskBufferDisplay.append(data)
        if (self.userMaskBufferDisplay.count > 300) {
            self.userMaskBufferDisplay.remove(at: 0)
        }
    }
    
    private func checkBadCase(unitDRInfoBuffer: [UnitDRInfo], userMaskBuffer: [UserMask], mode: String) -> Bool {
        var isBadCase = false
        
        if (unitDRInfoBuffer.count >= OlympusConstants.REQUIRED_BAD_CASE_CHECK_IDX && userMaskBuffer.count >= OlympusConstants.REQUIRED_BAD_CASE_CHECK_IDX) {
            let recentUnitDRInfoBuffer = getUnitDRInfoFromLast(from: unitDRInfoBuffer, N: OlympusConstants.REQUIRED_BAD_CASE_CHECK_IDX)
            let recentUserMaskBuffer = getUserMaskFromLast(from: userMaskBuffer, N: OlympusConstants.REQUIRED_BAD_CASE_CHECK_IDX)
            
            let lastUserMask = recentUserMaskBuffer[recentUserMaskBuffer.count-1]
            let headInfo = lastUserMask
            
            var xyFromHead: [Double] = [Double(headInfo.x), Double(headInfo.y)]
            var trajectoryFromHead = [[Double]]()
            trajectoryFromHead.append(xyFromHead)
            
            var compensateUvdHeading = [Double] (repeating: 0, count: recentUnitDRInfoBuffer.count)
            for i in 0..<recentUnitDRInfoBuffer.count {
                compensateUvdHeading[i] = compensateHeading(heading: recentUnitDRInfoBuffer[i].heading - recentUnitDRInfoBuffer[recentUnitDRInfoBuffer.count-1].heading + lastUserMask.absolute_heading - 180)
            }
            
            for i in (1..<recentUnitDRInfoBuffer.count).reversed() {
                let headAngle = compensateUvdHeading[i]
                xyFromHead[0] = xyFromHead[0] + recentUnitDRInfoBuffer[i].length * cos(headAngle * OlympusConstants.D2R)
                xyFromHead[1] = xyFromHead[1] + recentUnitDRInfoBuffer[i].length * sin(headAngle * OlympusConstants.D2R)
                trajectoryFromHead.append(xyFromHead)
            }
            
            let userMaskPositionXBuffer: [Double] = recentUserMaskBuffer.map({ Double($0.x) }).reversed()
            let userMaskPositionYBuffer: [Double] = recentUserMaskBuffer.map({ Double($0.y) }).reversed()

            var sum = 0.0
            for i in 0..<recentUserMaskBuffer.count {
                let diffX = trajectoryFromHead[i][0] - userMaskPositionXBuffer[i]
                let diffY = trajectoryFromHead[i][1] - userMaskPositionYBuffer[i]
                let distance = sqrt(diffX * diffX + diffY * diffY)
                sum += distance
            }

            let avgDistanceError = sum / Double(recentUserMaskBuffer.count)

            var DISTANCE_THRESHOLD: Double = 3
            if (mode == OlympusConstants.MODE_PDR) {
                DISTANCE_THRESHOLD = 3
            } else {
                DISTANCE_THRESHOLD = 3
            }
            if (avgDistanceError >= DISTANCE_THRESHOLD){isBadCase = true}
//            print("Check Bad Case : sum = \(sum) // count = \(recentUserMaskBuffer.count) // avgDistanceError = \(avgDistanceError) // isBadCase = \(isBadCase)")
        }
        
        return isBadCase
    }
    
    private func getUnitDRInfoFromLast(from unitDRInfoBuffer: [UnitDRInfo], N: Int) -> [UnitDRInfo] {
        let size = unitDRInfoBuffer.count
        guard size >= N else {
            return unitDRInfoBuffer
        }
        
        let startIndex = size - N
        let endIndex = size
        
        var result: [UnitDRInfo] = []
        for i in startIndex..<endIndex {
            result.append(unitDRInfoBuffer[i])
        }

        return result
    }
    
    private func getUserMaskFromLast(from userMaskBuffer: [UserMask], N: Int) -> [UserMask] {
        let size = userMaskBuffer.count
        guard size >= N else {
            return userMaskBuffer
        }
        
        let startIndex = size - N
        let endIndex = size
        
        var result: [UserMask] = []
        for i in startIndex..<endIndex {
            result.append(userMaskBuffer[i])
        }

        return result
    }
    
    private func stackServerResult(serverResult: FineLocationTrackingFromServer) {
        self.serverResultBuffer.append(serverResult)
        if (self.serverResultBuffer.count > 10) {
            self.serverResultBuffer.remove(at: 0)
        }
    }
    
    private func stackHeadingForCheckCorrection() {
        self.headingBufferForCorrection.append(self.unitDRInfo.heading)
        if (self.headingBufferForCorrection.count > OlympusConstants.HEADING_BUFFER_SIZE) {
            self.headingBufferForCorrection.remove(at: 0)
        }
    }
    
    private func phaseBreakInPhase2() {
        trajController.setIsNeedTrajCheck(flag: true)
        NotificationCenter.default.post(name: .phaseChanged, object: nil, userInfo: ["phase": OlympusConstants.PHASE_1])
        phaseController.setPhase2BadCount(value: 0)
        isPhaseBreakInRouteTrack = isStartRouteTrack
        isPhaseBreak = KF.isRunning
    }
    
    private func phaseBreakInPhase4(fltResult: FineLocationTrackingFromServer, isUpdatePhaseBreakResult: Bool) {
        if (KF.isRunning) {
            KF.minimizeKalmanR()
            OlympusConstants.PADDING_VALUE = OlympusConstants.PADDING_VALUE_LARGE
            if (isUpdatePhaseBreakResult) {
                phaseBreakResult = fltResult
            }
        }
        trajController.setIsNeedTrajCheck(flag: true)
        NotificationCenter.default.post(name: .phaseChanged, object: nil, userInfo: ["phase": OlympusConstants.PHASE_1])
        isPhaseBreak = true
    }
    
    // 임시
    private func trajTypeConverter(trajType: TrajType) -> Int {
        var convertedValue: Int = -3
        switch (trajType) {
        case .DR_IN_PHASE3:
            convertedValue = -2
        case .DR_UNKNOWN:
            convertedValue = 0
        case .DR_ALL_STRAIGHT:
            convertedValue = 1
        case .DR_HEAD_STRAIGHT:
            convertedValue = 2
        case .DR_TAIL_STRAIGHT:
            convertedValue = 3
        case .DR_RQ_IN_PHASE2:
            convertedValue = 4
        case .DR_NO_RQ_IN_PHASE2:
            convertedValue = -1
        case .PDR_IN_PHASE3_HAS_MAJOR_DIR:
            convertedValue = 5
        case .PDR_IN_PHASE3_NO_MAJOR_DIR:
            convertedValue = -1
        case .PDR_IN_PHASE4_HAS_MAJOR_DIR:
            convertedValue = 4
        case .PDR_IN_PHASE4_NO_MAJOR_DIR:
            convertedValue = 6
        case .PDR_IN_PHASE4_ABNORMAL:
            convertedValue = 7
        default:
            convertedValue = -3
        }
        
        return convertedValue
    }
    // 임시
    
    private func temporalToOlympus(fromServer: FineLocationTrackingFromServer, phase: Int, velocity: Double, mode: String, ble_only_position: Bool, isIndoor: Bool, validity: Bool, validity_flag: Int) -> FineLocationTrackingResult {
        var result = FineLocationTrackingResult()
        
        result.mobile_time = fromServer.mobile_time
        result.building_name = fromServer.building_name
        result.level_name = fromServer.level_name
        result.scc = fromServer.scc
        result.x = fromServer.x
        result.y = fromServer.y
        result.absolute_heading = fromServer.absolute_heading
        result.phase = phase
        result.calculated_time = fromServer.calculated_time
        result.index = fromServer.index
        result.velocity = velocity
        result.mode = mode
        result.ble_only_position = ble_only_position
        result.isIndoor = isIndoor
        result.validity = validity
        result.validity_flag = validity_flag
        
        return result
    }
    
    private func getUserMaskFromIndex(from userMask: [UserMask], index: Int) -> [UserMask] {
        var result: [UserMask] = []
        
        for i in 0..<userMask.count {
            if (userMask[i].index >= index) {
                result.append(userMask[i])
            }
        }

        return result
    }
    
    private func convertUserMask2Trajectory(userMask: [UserMask]) -> [[Double]] {
        var trajectory = [[Double]]()
        for i in 0..<userMask.count {
            let xy = [Double(userMask[i].x), Double(userMask[i].y)]
            trajectory.append(xy)
        }
        
        return trajectory
    }
    
    private func checkSolutionValidity(reportFlag: Int, reportTime: Double, isIndoor: Bool) -> (Bool, Int, String) {
        var isValid: Bool = false
        var validFlag: Int = 0
        var validMessage: String = "Valid"
        let currentTime = getCurrentTimeInMillisecondsDouble()
        
        if (isIndoor) {
            let diffTime = (currentTime - reportTime)*1e-3
            if (OlympusNetworkChecker.shared.isConnectedToInternet()) {
                switch (reportFlag) {
                case -1:
                    isValid = true
                    validFlag = OlympusConstants.VALID_SOLUTION
                    validMessage = "Valid"
                case 2:
                    // 1. 시간 체크
                    // 2. 3초 지났으면 BLE 꺼진거 체크
                    // 3. BLE 여전히 꺼져 있으며 pastReportTime 값 업데이트
                    // 4. 아니면 valid하다고 바꿈
                    if (diffTime > 3) {
                        if (bleManager.bluetoothReady) {
                            isValid = true
                            validFlag = OlympusConstants.VALID_SOLUTION
                            validMessage = "Valid"
                            self.pastReportFlag = -1
                        } else {
                            validFlag = OlympusConstants.INVALID_BLE
                            validMessage = "BLE is off"
                            self.pastReportTime = currentTime
                        }
                    } else {
                        validFlag = OlympusConstants.INVALID_BLE
                        validMessage = "BLE is off"
                    }
                case 3:
                    validFlag = OlympusConstants.INVALID_VENUS
                    validMessage = "Providing BLE only mode solution"
                case 4:
                    // 1. 시간 체크
                    // 2. 3초 지났으면 Valid로 수정
                    if (diffTime > 3) {
                        isValid = true
                        validFlag = OlympusConstants.VALID_SOLUTION
                        validMessage = "Valid"
                        self.pastReportFlag = -1
                    } else {
                        validFlag = OlympusConstants.RECOVERING_SOLUTION
                        validMessage = "Recently start to provide jupiter mode solution"
                    }
                case 5:
                    // 1. 시간 체크
                    // 2. 10초 지났으면 Valid로 수정
                    if (diffTime > 5) {
                        if (stateManager.networkCount > 1) {
                            validFlag = OlympusConstants.INVALID_NETWORK
                            validMessage = "Newtwork status is bad"
                        } else {
                            isValid = true
                            validFlag = OlympusConstants.VALID_SOLUTION
                            validMessage = "Valid"
                            self.pastReportFlag = -1
                        }
                    } else {
                        validFlag = OlympusConstants.INVALID_NETWORK
                        validMessage = "Newtwork status is bad"
                    }
                case 6:
                    // 1. 시간 체크
                    // 2. 3초 지났으면 네트워크 끊긴거 체크
                    // 3. 네트워크 여전히 꺼져 있으며 pastReportTime 값 업데이트
                    // 4. 아니면 valid하다고 바꿈
                    if (diffTime > 3) {
                        if (OlympusNetworkChecker.shared.isConnectedToInternet()) {
                            isValid = true
                            validFlag = OlympusConstants.VALID_SOLUTION
                            validMessage = "Valid"
                            self.pastReportFlag = -1
                        } else {
                            validFlag = OlympusConstants.INVALID_NETWORK
                            validMessage = "Newtwork connection lost"
                            self.pastReportTime = currentTime
                        }
                    } else {
                        validFlag = OlympusConstants.INVALID_NETWORK
                        validMessage = "Newtwork connection lost"
                    }
                case 7:
                    validFlag = OlympusConstants.INVALID_STATE
                    validMessage = "Solution in background is invalid"
                case 8:
                    // 1. 시간 체크
                    // 2. 3초 지났으면 Valid로 수정
                    if (bleManager.bluetoothReady) {
                        if (diffTime > 3) {
                            isValid = true
                            validFlag = OlympusConstants.VALID_SOLUTION
                            validMessage = "Valid"
                            self.pastReportFlag = -1
                        } else {
                            validFlag = OlympusConstants.RECOVERING_SOLUTION
                            validMessage = "Recently in foreground"
                        }
                    } else {
                        validFlag = OlympusConstants.INVALID_BLE
                        validMessage = "BLE is off"
                        self.pastReportFlag = 2
                        self.pastReportTime = currentTime
                    }
                case 9:
                    if (bleManager.bluetoothReady) {
                        if (diffTime > 5) {
                            isValid = true
                            validFlag = OlympusConstants.VALID_SOLUTION
                            validMessage = "Valid"
                            self.pastReportFlag = -1
                        } else {
                            validFlag = OlympusConstants.RECOVERING_SOLUTION
                            validMessage = "Recently BLE is on"
                        }
                    } else {
                        validFlag = OlympusConstants.INVALID_BLE
                        validMessage = "BLE is off"
                        self.pastReportFlag = 2
                        self.pastReportTime = currentTime
                    }
                case 11:
                    // BLE_SCAN_STOP
                    if (bleManager.bluetoothReady) {
                        if (diffTime > 5) {
                            isValid = true
                            validFlag = OlympusConstants.VALID_SOLUTION
                            validMessage = "Valid"
                            self.pastReportFlag = -1
                        } else {
                            validFlag = OlympusConstants.INVALID_BLE
                            validMessage = "BLE scanning has problem"
                        }
                    } else {
                        validFlag = OlympusConstants.INVALID_BLE
                        validMessage = "BLE is off"
                        self.pastReportFlag = 2
                        self.pastReportTime = currentTime
                    }
                case 12:
                    // BLE_ERROR_FLAG
                    if (bleManager.bluetoothReady) {
                        if (diffTime > 5) {
                            isValid = true
                            validFlag = OlympusConstants.VALID_SOLUTION
                            validMessage = "Valid"
                            self.pastReportFlag = -1
                        } else {
                            validFlag = OlympusConstants.INVALID_BLE
                            validMessage = "BLE trimming has problem"
                        }
                    } else {
                        validFlag = OlympusConstants.INVALID_BLE
                        validMessage = "BLE is off"
                        self.pastReportFlag = 2
                        self.pastReportTime = currentTime
                    }
                default:
                    isValid = true
                    validFlag = OlympusConstants.VALID_SOLUTION
                    validMessage = "Valid"
                }
            } else {
                validFlag = OlympusConstants.INVALID_NETWORK
                validMessage = "Newtwork connection lost"
                self.pastReportFlag = 6
                self.pastReportTime = currentTime
            }
        } else {
            validFlag = OlympusConstants.INVALID_OUTDOOR
            validMessage = "Solution in outdoor is invalid"
        }
        
        return (isValid, validFlag, validMessage)
    }
    
    public func setBackgroundMode(flag: Bool) {
        if (flag) {
            self.runBackgroundMode()
        } else {
            self.runForegroundMode()
        }
    }
    
    private func runBackgroundMode() {
        self.stateManager.setIsBackground(isBackground: true)
        self.unitDRGenerator.setIsBackground(isBackground: true)
        self.bleManager.stopScan()
        self.stopTimer()
            
        if let existingTaskIdentifier = self.backgroundTaskIdentifier {
            UIApplication.shared.endBackgroundTask(existingTaskIdentifier)
            self.backgroundTaskIdentifier = .invalid
        }

        self.backgroundTaskIdentifier = UIApplication.shared.beginBackgroundTask(withName: "BackgroundOutputTimer") {
            UIApplication.shared.endBackgroundTask(self.backgroundTaskIdentifier!)
            self.backgroundTaskIdentifier = .invalid
        }
            
        if (self.backgroundUpTimer == nil) {
            self.backgroundUpTimer = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .background))
            self.backgroundUpTimer!.schedule(deadline: .now(), repeating: OlympusConstants.OUTPUT_INTERVAL)
            self.backgroundUpTimer!.setEventHandler(handler: self.outputTimerUpdate)
            self.backgroundUpTimer!.resume()
        }
            
        if (self.backgroundUvTimer == nil) {
            self.backgroundUvTimer = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .background))
            self.backgroundUvTimer!.schedule(deadline: .now(), repeating: OlympusConstants.UVD_INTERVAL)
            self.backgroundUvTimer!.setEventHandler(handler: self.userVelocityTimerUpdate)
            self.backgroundUvTimer!.resume()
        }
        
        self.bleTrimed = [String: [[Double]]]()
        self.bleAvg = [String: Double]()
    }
    
    private func runForegroundMode() {
        if let existingTaskIdentifier = self.backgroundTaskIdentifier {
            UIApplication.shared.endBackgroundTask(existingTaskIdentifier)
            self.backgroundTaskIdentifier = .invalid
        }
            
        self.backgroundUpTimer?.cancel()
        self.backgroundUvTimer?.cancel()
        self.backgroundUpTimer = nil
        self.backgroundUvTimer = nil
            
        self.bleManager.startScan(option: .Foreground)
        self.startTimer()
            
        self.stateManager.setIsBackground(isBackground: false)
        self.unitDRGenerator.setIsBackground(isBackground: false)
        self.stateManager.setBecomeForeground(isBecomeForeground: true, time: getCurrentTimeInMillisecondsDouble())
    }
}
