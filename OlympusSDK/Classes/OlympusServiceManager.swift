import Foundation
import UIKit

public class OlympusServiceManager: Observation, StateTrackingObserver, BuildingLevelChangeObserver {
    public static let sdkVersion: String = "0.2.20"
    var isSimulationMode: Bool = false
    var isDeadReckoningMode: Bool = false
    var bleFileName: String = ""
    var sensorFileName: String = ""
    
    var simulationBleData = [[String: Double]]()
    var simulationSensorData = [OlympusSensorData]()
    var simulationTime: Double = 0
    var bleLineCount: Int = 0
    var sensorLineCount: Int = 0
    
    func tracking(input: FineLocationTrackingResult) {
        for observer in observers {
            let result = input
            observer.update(result: result)
            
            if (self.isSaveMobileResult) {
                let data = MobileResult(user_id: self.user_id, mobile_time: result.mobile_time, sector_id: self.sector_id, building_name: result.building_name, level_name: result.level_name, scc: result.scc, x: result.x, y: result.y, absolute_heading: result.absolute_heading, phase: result.phase, calculated_time: result.calculated_time, index: result.index, velocity: result.velocity, ble_only_position: result.ble_only_position, normalization_scale: OlympusConstants.NORMALIZATION_SCALE, device_min_rss: Int(OlympusConstants.DEVICE_MIN_RSSI), sc_compensation: self.scCompensation, is_indoor: result.isIndoor)
                inputMobileResult.append(data)
                if (inputMobileResult.count >= OlympusConstants.MR_INPUT_NUM) {
                    OlympusNetworkManager.shared.postMobileResult(url: REC_RESULT_URL, input: inputMobileResult, completion: { statusCode, returnedStrig in
                        if (statusCode != 200) {
                            let localTime = getLocalTimeString()
                            let log: String = localTime + " , (Olympus) Error \(statusCode) : Fail to send mobile result"
                            print(log)
                        }
                    })
                    inputMobileResult = []
                }
            }
        }
    }
    
    func reporting(input: Int) {
        for observer in observers {
            if (input != -2 || input != -1) {
                self.pastReportTime = getCurrentTimeInMillisecondsDouble()
                self.pastReportFlag = input
            }
            self.postReport(report: input)
            observer.report(flag: input)
        }
    }
    
    func postReport(report: Int) {
        if (self.isSaveMobileResult) {
            let reportInput = MobileReport(user_id: self.user_id, mobile_time: getCurrentTimeInMilliseconds(), report: report)
            OlympusNetworkManager.shared.postMobileReport(url: REC_REPORT_URL, input: reportInput, completion: { statusCode, returnedStrig in
                if (statusCode != 200) {
                    let localTime = getLocalTimeString()
                    let log: String = localTime + " , (Olympus) Error : Record Mobile Report \(report)"
                    print(log)
                }
            })
        }
    }
    
    var deviceModel: String
    var deviceIdentifier: String
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
    var ambiguitySolver = OlympusAmbiguitySolver()
    
    // ----- Data ----- //
    var inputReceivedForce: [ReceivedForce] = []
    var inputUserVelocity: [UserVelocity] = []
    var inputUserMask: [UserMask] = []
    var unitDRInfo = UnitDRInfo()
    var isSaveMobileResult: Bool = false
    var inputMobileResult: [MobileResult] = []
    
    // ----- Sector Param ----- //
    var user_id: String = ""
    var sector_id: Int = 0
    var sector_id_origin: Int = 0
    var service: String = ""
    var mode: String = ""
    
    var RQ_IDX = OlympusConstants.RQ_IDX_PDR
    var USER_TRAJECTORY_LENGTH = OlympusConstants.USER_TRAJECTORY_LENGTH_PDR
    var INIT_INPUT_NUM = 4
    var VALUE_INPUT_NUM = 6
    var PADDING_VALUE = OlympusConstants.PADDING_VALUE_SMALL
    var PADDING_VALUES = [Double] (repeating: OlympusConstants.PADDING_VALUE, count: 4)
    var UVD_INPUT_NUM = OlympusConstants.VALUE_INPUT_NUM
    var INDEX_THRESHOLD = 11
    
    
    // ----- Timer ----- //
    var backgroundUpTimer: DispatchSourceTimer?
    var backgroundUvTimer: DispatchSourceTimer?
    var backgroundTaskIdentifier: UIBackgroundTaskIdentifier?
    var receivedForceTimer: DispatchSourceTimer?
    var userVelocityTimer: DispatchSourceTimer?
    var outputTimer: DispatchSourceTimer?
    var osrTimer: DispatchSourceTimer?
    var collectTimer: DispatchSourceTimer?
    
    // RFD
    var bleTrimed = [String: [[Double]]]()
    var bleAvg = [String: Double]()
    
    // UVD
    var pastUvdTime: Int = 0
    var pastUvdHeading: Double = 0
    var unitDRInfoIndex: Int = 0
    var isPostUvdAnswered: Bool = false
    
    // Collect
    public var collectData = OlympusCollectData()
    var isStartCollect: Bool = false
    
    // ----- State Observer ----- //
    var runMode: String = OlympusConstants.MODE_DR
    var currentMode: String = OlympusConstants.MODE_DR
    var currentBuilding: String = ""
    var currentLevel: String = ""
    var indexPast: Int = 0
    var paddingValues = [Double] (repeating: OlympusConstants.PADDING_VALUE, count: 4)
    
    var isStartComplete: Bool = false
    var isPhaseBreak: Bool = false
    var isPhaseBreakInRouteTrack: Bool = false
    var networkStatus: Bool = true
    var isStartRouteTrack: Bool = false
    var isInEntranceLevel: Bool = false
    var isDRMode: Bool = false
    var isDRModeRqInfoSaved: Bool = false
    var drModeRequestInfo = DRModeRequestInfo(trajectoryInfo: [], stableInfo: StableInfo(tail_index: -1, head_section_number: 0, node_number_list: []), nodeCandidatesInfo: NodeCandidateInfo(isPhaseBreak: false, nodeCandidatesInfo: []), prevNodeInfo: PassedNodeInfo(nodeNumber: -1, nodeCoord: [], nodeHeadings: [], matchedIndex: 0, userHeading: 0))
    var stableModeInitFlag: Bool = true
    var goodCaseCount: Int = 0
    var isNeedPathTrajMatching = IsNeedPathTrajMatching(turn: false, straight: false)
    var isInRecoveryProcess: Bool = false
    var recoveryIndex: Int = 0
    
    var pastReportTime: Double = 0
    var pastReportFlag: Int = 0
    
    var timeRequest: Double = 0
    var preServerResultMobileTime: Int = 0
    var serverResultBuffer: [FineLocationTrackingFromServer] = []
    var unitDRInfoBuffer: [UnitDRInfo] = []
    var diffHeadingBuffer = [Double]()
    var unitDRInfoBufferForPhase4: [UnitDRInfo] = []
    var isNeedClearBuffer: Bool = false
    var userMaskBufferPathTrajMatching: [UserMask] = []
    var userMaskBuffer: [UserMask] = []
    var userMaskBufferDisplay: [UserMask] = []
    var userMaskSendCount: Int = 0
    
    var headingBufferForCorrection: [Double] = []
    var isPossibleHeadingCorrection: Bool = false
    var scCompensation: Double = 1.0
    var isInMapEnd: Bool = false
    
    var temporalResult =  FineLocationTrackingFromServer()
    var preTemporalResult = FineLocationTrackingFromServer()
    var curTemporalResultHeading: Double = 0
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
        self.deviceIdentifier = UIDevice.modelIdentifier
        self.deviceModel = UIDevice.modelName
        let deviceOs = UIDevice.current.systemVersion
        let arr = deviceOs.components(separatedBy: ".")
        self.deviceOsVersion = Int(arr[0]) ?? 0
        
        super.init()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"
        dateFormatter.locale = Locale(identifier:"ko_KR")
        
        stateManager.addObserver(self)
        buildingLevelChanger.addObserver(self)
    }
    
    deinit {
        stateManager.removeObserver(self)
        buildingLevelChanger.removeObserver(self)
    }
    
    func isStateDidChange(newValue: Int) {
        if (newValue == OUTDOOR_FLAG) {
            self.initialize(isStopService: false)
        }
        self.reporting(input: newValue)
    }
    
    func isBuildingLevelChanged(newBuilding: String, newLevel: String, newCoord: [Double]) {
//        print(getLocalTimeString() + " , (Olympus) Building Level Changed : \(currentLevel) -> \(newLevel)")
        self.currentBuilding = newBuilding
        self.currentLevel = newLevel
        KF.updateTuBuildingLevel(building: newBuilding, level: newLevel)
        if !newCoord.isEmpty {
            print(getLocalTimeString() + " , (Olympus) Building Level Changed : spot coord = \(newCoord)")
            self.setTemporalResult(coord: newCoord)
            self.isDRMode = true
            KF.updateTuResult(x: newCoord[0], y: newCoord[1])
            KF.setLinkInfo(coord: newCoord, directions: OlympusPathMatchingCalculator.shared.getPathMatchingHeadings(building: newBuilding, level: newLevel, x: newCoord[0], y: newCoord[1], PADDING_VALUE: 0.0, mode: self.runMode))
            OlympusPathMatchingCalculator.shared.setBuildingLevelChangedCoord(coord: newCoord)
        } else {
            OlympusPathMatchingCalculator.shared.setBuildingLevelChangedCoord(coord: [self.olympusResult.x, self.olympusResult.y])
        }
        
        ambiguitySolver.setIsAmbiguous(value: false)
        OlympusPathMatchingCalculator.shared.initPassedNodeInfo()
        sectionController.setInitialAnchorTailIndex(value: unitDRInfoIndex)
    }
    
    private func initialize(isStopService: Bool) {
        print(getLocalTimeString() + " , (Olympus) Initialize")
        if !self.isDeadReckoningMode {
            KF.initialize()
            phaseController.initialize()
            currentBuilding = ""
            currentLevel = ""
            stateManager.initialize(isStopService: isStopService)
        }
        
        buildingLevelChanger.initialize()
        OlympusPathMatchingCalculator.shared.initialize()
        rflowCorrelator.initialize()
        routeTracker.initialize()
        rssCompensator.initialize()
        sectionController.initialize()
        trajController.initialize()
        OlympusFileManager.shared.initalize()
        ambiguitySolver.initialize()
        
        inputReceivedForce = []
        inputUserVelocity = []
        inputUserMask = []
        inputMobileResult = []
        
        bleTrimed = [String: [[Double]]]()
        bleAvg = [String: Double]()
        
        pastUvdTime = 0
        pastUvdHeading = 0
        isPostUvdAnswered = false
        
        isStartCollect = false
        collectData = OlympusCollectData()
        
        indexPast = 0
        isPhaseBreak = false
        isPhaseBreakInRouteTrack = false
        networkStatus = true
        isStartRouteTrack = false
        isInEntranceLevel = false
        isDRMode = false
        isDRModeRqInfoSaved = false
        drModeRequestInfo = DRModeRequestInfo(trajectoryInfo: [], stableInfo: StableInfo(tail_index: -1, head_section_number: 0, node_number_list: []), nodeCandidatesInfo: NodeCandidateInfo(isPhaseBreak: false, nodeCandidatesInfo: []), prevNodeInfo: PassedNodeInfo(nodeNumber: -1, nodeCoord: [], nodeHeadings: [], matchedIndex: 0, userHeading: 0))
        stableModeInitFlag = true
        goodCaseCount = 0
        isNeedPathTrajMatching = IsNeedPathTrajMatching(turn: false, straight: false)
        isInRecoveryProcess = false
        recoveryIndex = 0
        
        pastReportTime = 0
        pastReportFlag = 0
        
        timeRequest = 0
        preServerResultMobileTime = 0
        serverResultBuffer = []
        unitDRInfoBuffer = []
        unitDRInfoBufferForPhase4 = []
        isNeedClearBuffer = false
        userMaskBufferPathTrajMatching = []
        userMaskBuffer = []
        userMaskBufferDisplay = []
        userMaskSendCount = 0
        
        headingBufferForCorrection  = []
        isPossibleHeadingCorrection = false
        scCompensation = 1.0
        isInMapEnd = false
        
        if isStopService {
            isStartComplete = false
            isSaveMobileResult = false
            currentTuResult = FineLocationTrackingFromServer()
            if !isDeadReckoningMode {
                temporalResult =  FineLocationTrackingFromServer()
                preTemporalResult = FineLocationTrackingFromServer()
                olympusResult = FineLocationTrackingResult()
                olympusVelocity = 0
            }
            timeUpdateResult = [0, 0, 0]
            
            // 임시
            displayOutput = ServiceResult()
        }
        routeTrackResult = FineLocationTrackingFromServer()
        phaseBreakResult = FineLocationTrackingFromServer()
    }
    
    public func setUseFixedStep(flag: Bool) {
        OlympusPDRDistanceEstimator.useFixedStep = flag
    }
    
    public func setFixedStepLength(value: Double) {
        OlympusPDRDistanceEstimator.fixedStepLength = value
    }
    
    public func startService(user_id: String, region: String, sector_id: Int, service: String, mode: String, completion: @escaping (Bool, String) -> Void) {
        self.initialize(isStopService: true)
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
                            OlympusPathMatchingCalculator.shared.setSectorID(sector_id: sector_id)
                            buildingLevelChanger.setSectorID(sector_id: sector_id)
                            routeTracker.setSectorID(sector_id: sector_id)
                            stateManager.setSectorID(sector_id: sector_id)
                            loadSectorInfo(sector_id: sector_id, completion: { [self] isSuccess, message in
                                if isSuccess {
                                    rssCompensator.loadRssiCompensationParam(sector_id: sector_id, device_model: deviceModel, os_version: deviceOsVersion, completion: { [self] isSuccess, loadedParam, returnedString in
                                        if (isSuccess) {
                                            rssCompensator.setIsScaleLoaded(flag: isSuccess)
                                            OlympusConstants().setNormalizationScale(cur: loadedParam, pre: loadedParam)
                                            print(returnedString)
                                            print(getLocalTimeString() + " , (Olympus) Scale : \(OlympusConstants.NORMALIZATION_SCALE), \(OlympusConstants.PRE_NORMALIZATION_SCALE)")
                                            
                                            if (!bleManager.bluetoothReady) {
                                                let msg: String = getLocalTimeString() + " , (Olympus) Error : Bluetooth is not enabled"
                                                completion(false, msg)
                                            } else {
                                                if (!self.isSimulationMode) {
                                                    OlympusFileManager.shared.setRegion(region: region)
                                                    OlympusFileManager.shared.createFiles(region: region, sector_id: sector_id, deviceModel: deviceModel, osVersion: deviceOsVersion)
                                                }
                                                
                                                
                                                self.isStartComplete = true
                                                self.startTimer()
                                                NotificationCenter.default.post(name: .serviceStarted, object: nil, userInfo: nil)
                                                print(getLocalTimeString() + " , (Olympus) Service Start")
                                                completion(true, getLocalTimeString() + success_msg)
                                            }
                                        } else {
                                            completion(false, returnedString)
                                        }
                                    })
                                } else {
                                    completion(false, message)
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
            self.mode = mode
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
                self.setModeParam(mode: self.runMode, phase: phaseController.PHASE)
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
    
    public func setSimulationMode(flag: Bool, bleFileName: String, sensorFileName: String) {
        self.isSimulationMode = flag
        self.bleFileName = bleFileName
        self.sensorFileName = sensorFileName
        
        if (self.isSimulationMode) {
            print(getLocalTimeString() + " , (Olympus) Simulation Mode : flag = \(self.isSimulationMode)")
            let result = OlympusFileManager.shared.loadFilesForSimulation(bleFile: self.bleFileName, sensorFile: self.sensorFileName)
            simulationBleData = result.0
            simulationSensorData = result.1
            simulationTime = getCurrentTimeInMillisecondsDouble()
        }
    }
    
    public func setDeadReckoningMode(flag: Bool, buildingName: String, levelName: String, x: Int, y: Int, heading: Double) {
        self.isDeadReckoningMode = flag
        
        var fltResult = FineLocationTrackingFromServer()
        fltResult.mobile_time = getCurrentTimeInMilliseconds()
        fltResult.building_name = buildingName
        fltResult.level_name = levelName
        fltResult.x = Double(x)
        fltResult.y = Double(y)
        fltResult.absolute_heading = heading
        stateManager.setIsGetFirstResponse(isGetFirstResponse: true)
        stateManager.setIsIndoor(isIndoor: true)
        stackServerResult(serverResult: fltResult)
        phaseBreakResult = fltResult
        
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
        curTemporalResultHeading = updatedResult.absolute_heading
        makeTemporalResult(input: updatedResult, isStableMode: true, mustInSameLink: false, updateType: .NONE, pathMatchingType: .WIDE)
        sectionController.setSectionUserHeading(value: updatedResult.absolute_heading)
        KF.activateKalmanFilter(fltResult: updatedResult)
        NotificationCenter.default.post(name: .phaseChanged, object: nil, userInfo: ["phase": OlympusConstants.PHASE_6])
    }
    
    public func stopService() -> (Bool, String) {
        print(getLocalTimeString() + " , (Olympus) Information : Stop Service")
        let localTime: String = getLocalTimeString()
        var message: String = localTime + " , (Olympus) Success : Stop Service"
        
        if (self.isStartComplete) {
            self.stopTimer()
            self.bleManager.stopScan()
            
            if (self.service.contains(OlympusConstants.SERVICE_FLT) && !isSimulationMode) {
                self.initialize(isStopService: true)
                rssCompensator.saveNormalizationScale(scale: rssCompensator.normalizationScale, sector_id: self.sector_id)
                let rcInfoSave =  RcInfoSave(sector_id: self.sector_id, device_model: self.deviceModel, os_version: self.deviceOsVersion, normalization_scale: rssCompensator.normalizationScale)
                OlympusNetworkManager.shared.postParam(url: REC_RC_URL, input: rcInfoSave, completion: { statusCode, returnedString in
                    if statusCode == 200 {
                        print(getLocalTimeString() + " , (Olympus) Success : save RSS Compensation parameter \(rcInfoSave.normalization_scale)")
                    } else {
                        print(getLocalTimeString() + " , (Olympus) Fail : save RSS Compensation parameter")
                    }
                })
            }
            rssCompensator.setIsScaleLoaded(flag: false)
            
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
    
    private func loadSectorInfo(sector_id: Int, completion: @escaping (Bool, String) -> Void) {
        self.sector_id = sector_id
        self.sector_id_origin = sector_id
        let inputSectorID = InputSectorID(sector_id: sector_id)
        let inputSectorIDnOS = InputSectorIDnOS(sector_id: sector_id, operating_system: OlympusConstants.OPERATING_SYSTEM)
        loadUserLevel(input: inputSectorID, completion: { [self] isSuccess, message in
            if isSuccess {
                loadUserParam(input: inputSectorIDnOS, completion: { [self] isSuccess, message in
                    if isSuccess {
                        loadUserPath(input: inputSectorIDnOS, completion: { [self] isSuccess, message in
                            if isSuccess {
                                loadUserGeo(input: inputSectorIDnOS, completion: { [self] isSuccess, message in
                                    if isSuccess {
                                        loadUserEntrance(input: inputSectorIDnOS, completion: { isSuccess, message in
                                            if isSuccess {
                                                completion(isSuccess, message)
                                            } else {
                                                completion(isSuccess, message)
                                            }
                                        })
                                    } else {
                                        completion(isSuccess, message)
                                    }
                                })
                            } else {
                                completion(isSuccess, message)
                            }
                        })
                    } else {
                        completion(isSuccess, message)
                    }
                })
            } else {
                completion(isSuccess, message)
            }
        })
    }
    
    private func loadUserLevel(input: InputSectorID, completion: @escaping (Bool, String) -> Void) {
        OlympusNetworkManager.shared.postSectorID(url: USER_LEVEL_URL, input: input, completion: { [self] statusCode, returnedString in
            if statusCode == 200 {
                let outputLevel = jsonToLevelFromServer(jsonString: returnedString)
                if outputLevel.0 {
                    //MARK: - Level
                    var infoBuildingLevel = [String:[String]]()
                    for element in outputLevel.1.level_list {
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
                    }
                    buildingLevelChanger.buildingsAndLevels = infoBuildingLevel
                    let msg = getLocalTimeString() + " , (Olympus) Success : Load Sector Info // Level"
                    completion(true, msg)
                } else {
                    let msg = getLocalTimeString() + " , (Olympus) Error : Load Sector Info // Level \(statusCode)"
                    completion(false, msg)
                }
            } else {
                let msg = getLocalTimeString() + " , (Olympus) Error : Load Sector Info // Level \(statusCode)"
                completion(false, msg)
            }
        })
    }
    
    private func loadUserParam(input: InputSectorIDnOS, completion: @escaping (Bool, String) -> Void) {
        OlympusNetworkManager.shared.postSectorIDnOS(url: USER_PARAM_URL, input: input, completion: { [self] statusCode, returnedString in
            if statusCode == 200 {
                let outputParam = jsonToParamFromServer(jsonString: returnedString)
                if outputParam.0 {
                    //MARK: - Param
                    let paramInfo = outputParam.1
                    self.isSaveMobileResult = paramInfo.debug
                    let stadard_rss: [Int] = paramInfo.standard_rss
                    let sector_info = SectorInfo(standard_min_rss: Double(stadard_rss[0]), standard_max_rss: Double(stadard_rss[1]), user_traj_length: Double(paramInfo.trajectory_length + OlympusConstants.DR_LENGTH_MARGIN), user_traj_length_dr: Double(paramInfo.trajectory_length + OlympusConstants.DR_LENGTH_MARGIN), user_traj_length_pdr:  Double(paramInfo.trajectory_diagonal + OlympusConstants.PDR_LENGTH_MARGIN), num_straight_idx_dr: Int(ceil(OlympusConstants.USER_TRAJECTORY_LENGTH_DR/6)), num_straight_idx_pdr: Int(ceil(OlympusConstants.USER_TRAJECTORY_LENGTH_PDR/6)))
                    OlympusConstants().setSectorInfoConstants(sector_info: sector_info)
                    self.phaseController.setPhaseLengthParam(lengthConditionPdr: Double(paramInfo.trajectory_diagonal), lengthConditionDr: Double(paramInfo.trajectory_length))
                    print(getLocalTimeString() + " , (Olympus) Information : User Trajectory Param \(OlympusConstants.USER_TRAJECTORY_LENGTH_DR) // \(OlympusConstants.USER_TRAJECTORY_LENGTH_PDR) // \(OlympusConstants.NUM_STRAIGHT_IDX_DR)")
                    let msg = getLocalTimeString() + " , (Olympus) Success : Load Sector Info // Param"
                    completion(true, msg)
                } else {
                    let msg = getLocalTimeString() + " , (Olympus) Error : Load Sector Info // Param \(statusCode)"
                    print(msg)
                    completion(false, msg)
                }
            } else {
                let msg = getLocalTimeString() + " , (Olympus) Error : Load Sector Info // Param \(statusCode)"
                print(msg)
                completion(false, msg)
            }
        })
    }
    
    private func loadUserPath(input: InputSectorIDnOS, completion: @escaping (Bool, String) -> Void) {
        OlympusNetworkManager.shared.postSectorIDnOS(url: USER_PATH_URL, input: input, completion: { [self] statusCode, returnedString in
            if statusCode == 200 {
                let outputPath = jsonToPathFromServer(jsonString: returnedString)
                if outputPath.0 {
                    //MARK: - Path
                    let pathInfo = outputPath.1
                    for element in pathInfo.path_pixel_list {
                        let buildingName = element.building_name
                        let levelName = element.level_name
                        let key = "\(input.sector_id)_\(buildingName)_\(levelName)"
                        let ppURL = element.url
                        // Path-Pixel URL 확인
                        OlympusPathMatchingCalculator.shared.PpURL[key] = ppURL
//                        print(getLocalTimeString() + " , (Olympus) Sector Info : \(key) PP URL = \(ppURL)")
                    }
                    OlympusPathMatchingCalculator.shared.loadPathPixel(sector_id: sector_id, PathPixelURL: OlympusPathMatchingCalculator.shared.PpURL)
                    let msg = getLocalTimeString() + " , (Olympus) Success : Load Sector Info // Path"
                    completion(true, msg)
                } else {
                    let msg = getLocalTimeString() + " , (Olympus) Error : Load Sector Info // Path \(statusCode)"
                    completion(false, msg)
                }
            } else {
                let msg = getLocalTimeString() + " , (Olympus) Error : Load Sector Info // Path \(statusCode)"
                completion(false, msg)
            }
        })
    }
    
    private func loadUserGeo(input: InputSectorIDnOS, completion: @escaping (Bool, String) -> Void) {
        OlympusNetworkManager.shared.postSectorIDnOS(url: USER_GEO_URL, input: input, completion: { [self] statusCode, returnedString in
            if statusCode == 200 {
                let outputGeo = jsonToGeofenceFromServer(jsonString: returnedString)
                if outputGeo.0 {
                    //MARK: - Geo
                    let geoInfo = outputGeo.1
                    for element in geoInfo.geofence_list {
                        let buildingName = element.building_name
                        let levelName = element.level_name
                        let key = "\(input.sector_id)_\(buildingName)_\(levelName)"
                        
                        let entranceArea = element.entrance_area
                        let entranceMatcingArea = element.entrance_matching_area
                        let levelChangeArea = element.level_change_area
                        let drModeAreas = element.dr_mode_areas
                        
                        if !entranceArea.isEmpty { OlympusPathMatchingCalculator.shared.EntranceArea[key] = entranceArea }
                        if !entranceMatcingArea.isEmpty { OlympusPathMatchingCalculator.shared.EntranceMatchingArea[key] = entranceMatcingArea }
                        if !levelChangeArea.isEmpty { OlympusPathMatchingCalculator.shared.LevelChangeArea[key] = levelChangeArea }
                        if !drModeAreas.isEmpty { buildingLevelChanger.setSectorDRModeArea(building: buildingName, level: levelName, drModeAreaList: drModeAreas) }
                    }
                    let msg = getLocalTimeString() + " , (Olympus) Success : Load Sector Info // Geo"
                    completion(true, msg)
                } else {
                    let msg = getLocalTimeString() + " , (Olympus) Error : Load Sector Info // Geo \(statusCode)"
                    completion(false, msg)
                }
            } else {
                let msg = getLocalTimeString() + " , (Olympus) Error : Load Sector Info // Geo \(statusCode)"
                completion(false, msg)
            }
        })
    }
    
    private func loadUserEntrance(input: InputSectorIDnOS, completion: @escaping (Bool, String) -> Void) {
        OlympusNetworkManager.shared.postSectorIDnOS(url: USER_ENTRANCE_URL, input: input, completion: { [self] statusCode, returnedString in
            if statusCode == 200 {
                let outputEntrance = jsonToEntranceFromServer(jsonString: returnedString)
                if outputEntrance.0 {
                    //MARK: - Entrance
                    let entranceInfo = outputEntrance.1
                    var entranceOuterWards: [String] = []
                    var entranceNumbers: Int = 0
                    for element in entranceInfo.entrance_list {
                        let buildingName = element.building_name
                        let levelName = element.level_name
                        let key = "\(input.sector_id)_\(buildingName)_\(levelName)"
                        
                        let entrances = element.entrances
                        entranceNumbers += entrances.count
                        for ent in entrances {
                            let entranceKey = "\(key)_\(ent.spot_number)"
                            routeTracker.EntranceNetworkStatus[entranceKey] = ent.network_status
                            routeTracker.EntranceVelocityScales[entranceKey] = ent.scale
                            routeTracker.EntranceRouteURL[entranceKey] = ent.url
                            routeTracker.setEntranceInnerWardInfo(key: entranceKey, entranceRF: ent.innermost_ward)
                            entranceOuterWards.append(ent.outermost_ward_id)
                        }
                    }
                    routeTracker.EntranceNumbers = entranceNumbers
                    stateManager.EntranceOuterWards = entranceOuterWards
                    routeTracker.loadEntranceRoute(sector_id: sector_id, RouteURL: routeTracker.EntranceRouteURL)
                    let msg = getLocalTimeString() + " , (Olympus) Success : Load Sector Info // Entrance"
                    completion(true, msg)
                } else {
                    let msg = getLocalTimeString() + " , (Olympus) Error : Load Sector Info // Entrance \(statusCode)"
                    completion(false, msg)
                }
            } else {
                let msg = getLocalTimeString() + " , (Olympus) Error : Load Sector Info // Entrance \(statusCode)"
                completion(false, msg)
            }
        })
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
            self.receivedForceTimer!.setEventHandler { [weak self] in
                guard let self = self else { return }
                self.receivedForceTimerUpdate()
            }
            self.receivedForceTimer!.resume()
        }
        
        if (self.userVelocityTimer == nil) {
            let queueUVD = DispatchQueue(label: Bundle.main.bundleIdentifier! + ".userVelocityTimer")
            self.userVelocityTimer = DispatchSource.makeTimerSource(queue: queueUVD)
            self.userVelocityTimer!.schedule(deadline: .now(), repeating: OlympusConstants.UVD_INTERVAL)
            
            self.userVelocityTimer!.setEventHandler { [weak self] in
                guard let self = self else { return }
                self.userVelocityTimerUpdate()
            }
            self.userVelocityTimer!.resume()
        }
        
        
        if (self.outputTimer == nil) {
            let queue = DispatchQueue(label: Bundle.main.bundleIdentifier! + ".updateTimer")
            self.outputTimer = DispatchSource.makeTimerSource(queue: queue)
            self.outputTimer!.schedule(deadline: .now(), repeating: OlympusConstants.OUTPUT_INTERVAL)
            self.outputTimer!.setEventHandler { [weak self] in
                guard let self = self else { return }
                self.outputTimerUpdate()
            }
            self.outputTimer!.resume()
        }
        
        
        if (self.osrTimer == nil) {
            let queueOSR = DispatchQueue(label: Bundle.main.bundleIdentifier! + ".osrTimer")
            self.osrTimer = DispatchSource.makeTimerSource(queue: queueOSR)
            self.osrTimer!.schedule(deadline: .now(), repeating: OlympusConstants.OSR_INTERVAL)
            self.osrTimer!.setEventHandler { [weak self] in
                guard let self = self else { return }
                self.osrTimerUpdate()
            }
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
    
    func receivedForceTimerUpdate() {
        handleRfd()
    }
    
    private func handleRfd() {
        let localTime: String = getLocalTimeString()
        if (isSimulationMode) {
            stateManager.updateTimeForInit()
            let validTime = OlympusConstants.BLE_VALID_TIME_INT
            let currentTime = getCurrentTimeInMilliseconds() - validTime
            
            if (bleLineCount < simulationBleData.count-1) {
                self.simulationTime = getCurrentTimeInMillisecondsDouble()
                let bleData = simulationBleData[bleLineCount]
                self.bleAvg = bleData
                OlympusFileManager.shared.writeBleData(time: currentTime, data: bleAvg)
                stateManager.getLastScannedEntranceOuterWardTime(bleAvg: self.bleAvg, entranceOuterWards: stateManager.EntranceOuterWards)
                if (!stateManager.isGetFirstResponse) {
                    let enterInNetworkBadEntrance = stateManager.checkEnterInNetworkBadEntrance(bleAvg: self.bleAvg)
                    if (enterInNetworkBadEntrance.0) {
//                        print(getLocalTimeString() + " , (Olympus) Start Route Tracker : Network Bad Entrance")
//                        print(getLocalTimeString() + " , (Olympus) Start Route Tracker : Network Bad Entrance Result = \(enterInNetworkBadEntrance.1)")
                        stateManager.setIsGetFirstResponse(isGetFirstResponse: true)
                        let isOn = routeTracker.startRouteTracking(result: enterInNetworkBadEntrance.1, isStartRouteTrack: self.isStartRouteTrack)
                        stackServerResult(serverResult: enterInNetworkBadEntrance.1)
                        makeTemporalResult(input: enterInNetworkBadEntrance.1, isStableMode: true, mustInSameLink: false, updateType: .NONE, pathMatchingType: .WIDE)
                        unitDRGenerator.setIsStartRouteTrack(isStartRoutTrack: isOn.0)
                        isStartRouteTrack = isOn.0
                        networkStatus = isOn.1
                        NotificationCenter.default.post(name: .phaseChanged, object: nil, userInfo: ["phase": OlympusConstants.PHASE_3])
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
//                    print(getLocalTimeString() + " , (Olympus) RSS Compensator : Set deviceMin = \(OlympusConstants.DEVICE_MIN_RSSI)")
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
                bleLineCount += 1
            } else {
                self.bleAvg = [String: Double]()
                
                // Connect Simulation
//                if stateManager.timeForInit >= OlympusConstants.TIME_INIT_THRESHOLD+1 && !stateManager.isIndoor {
//                    self.bleLineCount = 0
//                    self.sensorLineCount = 0
//                    setSimulationMode(flag: true, bleFileName: "ble_coex_04_05_1007.csv", sensorFileName: "sensor_coex_04_05_1007.csv")
//                }
            }
            
            if (!self.bleAvg.isEmpty) {
                stateManager.setVariblesWhenBleIsNotEmpty()
                let data = ReceivedForce(user_id: self.user_id, mobile_time: currentTime, ble: self.bleAvg, pressure: self.sensorManager.pressure)
                self.inputReceivedForce.append(data)
                if ((inputReceivedForce.count) >= OlympusConstants.RFD_INPUT_NUM) {
                    OlympusNetworkManager.shared.postReceivedForce(url: REC_RFD_URL, input: inputReceivedForce, completion: { [self] statusCode, returnedString, inputRfd in
                        if (statusCode != 200) {
                            print(getLocalTimeString() + " , (Olympus) Error : RFD \(statusCode) // " + returnedString)
                            if (stateManager.isIndoor && stateManager.isGetFirstResponse && !stateManager.isBackground) { NotificationCenter.default.post(name: .errorSendRfd, object: nil, userInfo: nil) }
                        }
                    })
                    inputReceivedForce = []
                }
            } else if (!stateManager.isBackground) {
                stateManager.checkOutdoorBleEmpty(lastBleDiscoveredTime: self.simulationTime, olympusResult: self.olympusResult)
                stateManager.checkEnterSleepMode(service: self.service, type: 0)
            }
        } else {
            stateManager.checkBleOff(bluetoothReady: bleManager.bluetoothReady, bleLastScannedTime: bleManager.bleLastScannedTime)
            stateManager.updateTimeForInit()
            
            let validTime = OlympusConstants.BLE_VALID_TIME_INT
            let currentTime = getCurrentTimeInMilliseconds() - validTime
            let bleDictionary: [String: [[Double]]]? = bleManager.getBLEData()
            if let bleData = bleDictionary {
                let trimmedResult = OlympusRFDFunctions.shared.trimBleData(bleInput: bleData, nowTime: getCurrentTimeInMillisecondsDouble(), validTime: Double(validTime))
                switch trimmedResult {
                case .success(let trimmedData):
                    self.bleAvg = OlympusRFDFunctions.shared.avgBleData(bleDictionary: trimmedData)
                    stateManager.getLastScannedEntranceOuterWardTime(bleAvg: self.bleAvg, entranceOuterWards: stateManager.EntranceOuterWards)
                    if (!stateManager.isGetFirstResponse) {
                        let enterInNetworkBadEntrance = stateManager.checkEnterInNetworkBadEntrance(bleAvg: self.bleAvg)
                        if (enterInNetworkBadEntrance.0) {
                            stateManager.setIsGetFirstResponse(isGetFirstResponse: true)
                            let isOn = routeTracker.startRouteTracking(result: enterInNetworkBadEntrance.1, isStartRouteTrack: self.isStartRouteTrack)
                            stackServerResult(serverResult: enterInNetworkBadEntrance.1)
                            makeTemporalResult(input: enterInNetworkBadEntrance.1, isStableMode: true, mustInSameLink: false, updateType: .NONE, pathMatchingType: .WIDE)
                            unitDRGenerator.setIsStartRouteTrack(isStartRoutTrack: isOn.0)
                            isStartRouteTrack = isOn.0
                            networkStatus = isOn.1
                            NotificationCenter.default.post(name: .phaseChanged, object: nil, userInfo: ["phase": OlympusConstants.PHASE_3])
                        }
                    }
                case .failure(_):
                    print(getLocalTimeString() + " , (Olympus) Warning : Fail RFD Trimming")
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
            
//            self.bleAvg = ["TJ-00CB-0000033B-0000":-62.0] // DS 3F
//            self.bleAvg = ["TJ-00CB-00000389-0000":-62.0] // G2 2F
//            self.bleAvg = ["TJ-00CB-000003E7-0000":-76.0] // PG
            
            if (!self.bleAvg.isEmpty) {
                stateManager.setVariblesWhenBleIsNotEmpty()
                let data = ReceivedForce(user_id: self.user_id, mobile_time: currentTime, ble: self.bleAvg, pressure: self.sensorManager.pressure)
                self.inputReceivedForce.append(data)
                if ((inputReceivedForce.count) >= OlympusConstants.RFD_INPUT_NUM) {
                    OlympusNetworkManager.shared.postReceivedForce(url: REC_RFD_URL, input: inputReceivedForce, completion: { [self] statusCode, returnedString, inputRfd in
                        if (statusCode != 200) {
                            print(getLocalTimeString() + " , (Olympus) Error : RFD \(statusCode) // " + returnedString)
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
    
    func userVelocityTimerUpdate() {
        let currentTime = getCurrentTimeInMilliseconds()
        
        self.controlMode()
        self.setModeParam(mode: self.runMode, phase: phaseController.PHASE)
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
            OlympusFileManager.shared.writeSensorData(currentTime: getCurrentTimeInMillisecondsDouble(), data: sensorData)
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
            displayOutput.indexTx = unitDRInfo.index
            // 임시
            print("\(unitDRInfo.index) // \(unitDRInfo.length)")
            stateManager.setVariblesWhenIsIndexChanged()
            stackHeadingForCheckCorrection()
            isPossibleHeadingCorrection = checkHeadingCorrection(buffer: headingBufferForCorrection)
            olympusVelocity = unitDRInfo.velocity * 3.6
            var unitUvdLength: Double = 0
            if (stateManager.isBackground) {
                unitUvdLength = unitDRInfo.length*backgroundScale
            } else {
                unitUvdLength = unitDRInfo.length
            }
            unitUvdLength = round(unitUvdLength*10000)/10000
            let diffHeading = unitDRInfo.heading - pastUvdHeading
            stackDiffHeadingBuffer(diffHeading: diffHeading)
            unitDRInfo.length = unitUvdLength
            stackUnitDRInfo()
            stackUnitDRInfoForPhase4(isNeedClear: isNeedClearBuffer)
            self.unitDRInfoIndex = unitDRInfo.index
            
//            OlympusPathMatchingCalculator.shared.controlUVDforAccBias(unitDRInfo: unitDRInfo)
            let data = UserVelocity(user_id: self.user_id, mobile_time: currentTime, index: unitDRInfo.index, length: unitUvdLength, heading: round(unitDRInfo.heading*100)/100, looking: unitDRInfo.lookingFlag)
            inputUserVelocity.append(data)
            
            trajController.checkPhase2To4(unitLength: unitUvdLength, LENGTH_THRESHOLD: USER_TRAJECTORY_LENGTH)
            buildingLevelChanger.accumulateOsrDistance(unitLength: unitUvdLength, isGetFirstResponse: stateManager.isGetFirstResponse, mode: self.runMode, result: self.olympusResult)
            
            let isInEntranceLevel = stateManager.checkInEntranceLevel(result: self.olympusResult, isStartRouteTrack: self.isStartRouteTrack)
            unitDRGenerator.setIsInEntranceLevel(flag: isInEntranceLevel)
            let entrancaeVelocityScale: Double = routeTracker.getEntranceVelocityScale(isGetFirstResponse: stateManager.isGetFirstResponse, isStartRouteTrack: self.isStartRouteTrack)
            unitDRGenerator.setEntranceVelocityScale(scale: entrancaeVelocityScale)
            let numBleChannels = OlympusRFDFunctions.shared.checkBleChannelNum(bleAvg: self.bleAvg)
            trajController.checkTrajectoryInfo(isPhaseBreak: self.isPhaseBreak, isBecomeForeground: stateManager.isBecomeForeground, isGetFirstResponse: stateManager.isGetFirstResponse, timeForInit: stateManager.timeForInit, LENGTH_THRESHOLD: USER_TRAJECTORY_LENGTH)
            let trajectoryInfo = trajController.getTrajectoryInfo(unitDRInfo: unitDRInfo, unitLength: unitUvdLength, olympusResult: self.olympusResult, isKF: KF.isRunning, tuResult: timeUpdateResult, isPmSuccess: false, numBleChannels: numBleChannels, mode: self.runMode, isDetermineSpot: buildingLevelChanger.isDetermineSpot, spotCutIndex: buildingLevelChanger.spotCutIndex, LENGTH_THRESHOLD: USER_TRAJECTORY_LENGTH)
            
            if ((inputUserVelocity.count) >= UVD_INPUT_NUM) {
                OlympusNetworkManager.shared.postUserVelocity(url: REC_UVD_URL, input: inputUserVelocity, completion: { [self] statusCode, returnedString, inputUvd in
                    if (statusCode == 200) {
                        KF.updateTuResultWhenUvdPosted(result: currentTuResult)
                        self.isPostUvdAnswered = true
                    } else {
                        if (stateManager.isIndoor && stateManager.isGetFirstResponse && !stateManager.isBackground) { NotificationCenter.default.post(name: .errorSendUvd, object: nil, userInfo: nil) }
                        trajController.stackPostUvdFailData(inputUvd: inputUvd)
                    }
                })
                inputUserVelocity = []
            }
            
            // Time Update
            pastUvdHeading = unitDRInfo.heading
            if (KF.isRunning && KF.tuFlag && !self.isInRecoveryProcess) {
                var pathType: Int = 1
                if (runMode == OlympusConstants.MODE_PDR) { pathType = 0 }
//                print(getLocalTimeString() + " , (Olympus) Path-Matching : Check Bad Case : isNeedPathTrajMatching = \(isNeedPathTrajMatching) // index = \(unitDRInfoIndex)")
                let kfTimeUpdate = KF.timeUpdate(currentTime: currentTime, recentResult: olympusResult, length: unitUvdLength, diffHeading: diffHeading, isPossibleHeadingCorrection: isPossibleHeadingCorrection, unitDRInfoBuffer: unitDRInfoBuffer, userMaskBuffer: userMaskBufferPathTrajMatching, isNeedPathTrajMatching: isNeedPathTrajMatching, PADDING_VALUES: PADDING_VALUES, mode: runMode)
                var tuResult = kfTimeUpdate.0
                let isDidPathTrajMatching: Bool = kfTimeUpdate.1
                var updateType: UpdateNodeLinkType = .NONE
                var mustInSameLink: Bool = true
                let isNeedRqPhase4: Bool = self.isDeadReckoningMode ? false : kfTimeUpdate.2
                
                let pathMatchingArea = OlympusPathMatchingCalculator.shared.checkInEntranceMatchingArea(x: tuResult.x, y: tuResult.y, building: tuResult.building_name, level: tuResult.level_name)
//                print(getLocalTimeString() + " , (Olympus) Check Map End : pathMatchingArea = \(pathMatchingArea.0)")
                
                // Path-Traj 매칭 했으면 anchor node 업데이트하는 과정 필요
                if (isDidPathTrajMatching) {
                    let pathTrajMatchingNode: PassedNodeInfo = KF.getPathTrajMatchingNode()
                    OlympusPathMatchingCalculator.shared.updateAnchorNodeAfterPathTrajMatching(nodeInfo: pathTrajMatchingNode, sectionNumber: sectionController.getSectionNumber())
                    print(getLocalTimeString() + " , (Olympus) Path-Matching : Result After Path Traj Matching // xyh = [\(tuResult.x) , \(tuResult.y) , \(tuResult.absolute_heading)]")
                    updateType = .PATH_TRAJ_MATCHING
                    mustInSameLink = false
                } else if (OlympusPathMatchingCalculator.shared.isInNode || pathMatchingArea.0) {
                    mustInSameLink = false
                    // 길 끝에 있는지 확인해야 한다
                    self.isInMapEnd = OlympusPathMatchingCalculator.shared.checkIsInMapEnd(resultStandard: self.temporalResult, tuResult: tuResult, pathType: pathType)
                    if (self.isInMapEnd) {
                        tuResult.x = self.temporalResult.x
                        tuResult.y = self.temporalResult.y
                        KF.updateTuResult(x: tuResult.x, y: tuResult.y)
                    }
                } else {
                    self.isInMapEnd = false
                }
                
//                print(getLocalTimeString() + " , (Olympus) Check Map End : isInNode = \(OlympusPathMatchingCalculator.shared.isInNode) , isInMapEnd = \(isInMapEnd)")
                let isNeedAnchorNodeUpdate = sectionController.extendedCheckIsNeedAnchorNodeUpdate(userVelocity: data, userHeading: self.temporalResult.absolute_heading)
                if (isNeedAnchorNodeUpdate) {
                    OlympusPathMatchingCalculator.shared.updateAnchorNode(fltResult: tuResult, pathType: pathType, sectionNumber: sectionController.getSectionNumber())
                }
                
                currentTuResult = tuResult
                KF.updateTuResultNow(result: currentTuResult)
                KF.updateTuInformation(unitDRInfo: unitDRInfo)
                makeTemporalResult(input: tuResult, isStableMode: true, mustInSameLink: mustInSameLink, updateType: updateType, pathMatchingType: .NARROW)
                
                timeUpdateResult[0] = currentTuResult.x
                timeUpdateResult[1] = currentTuResult.y
                timeUpdateResult[2] = currentTuResult.absolute_heading
                displayOutput.trajectoryOg = KF.inputTraj
                displayOutput.trajectoryPm = KF.matchedTraj
                // 임시
                displayOutput.searchArea = OlympusPathMatchingCalculator.shared.pathTrajMatchingArea
                if (!isPhaseBreak) {
                    if !self.isDRMode {
                        if (isNeedRqPhase4) {
                            // Anchor를 바꿔서 Phase4 요청 보내기
                            let badCaseNodeCandidatesResult = OlympusPathMatchingCalculator.shared.getAnchorNodeCandidatesForBadCase(fltResult: tuResult, pathType: pathType)
                            if (badCaseNodeCandidatesResult.isPhaseBreak) {
                                print(getLocalTimeString() + " , (Olympus) Request Phase 4 : phaseBreak (badCaseNodeCandidatesResult Empty)")
                                phaseBreakInPhase4(fltResult: tuResult, isUpdatePhaseBreakResult: false)
                            } else {
                                let nodeCandidatesInfo = badCaseNodeCandidatesResult.nodeCandidatesInfo
                                if (nodeCandidatesInfo.isEmpty) {
                                    print(getLocalTimeString() + " , (Olympus) Request Phase 4 : phaseBreak (nodeCandidatesInfo Empty)")
                                    phaseBreakInPhase4(fltResult: tuResult, isUpdatePhaseBreakResult: false)
                                } else {
                                    var nodeNumberCandidates = [Int]()
                                    var nodeHeadings = [Double]()
                                    for item in nodeCandidatesInfo {
                                        nodeNumberCandidates.append(item.nodeNumber)
                                        nodeHeadings += item.nodeHeadings
                                    }
                                    
                                    let nodeCandidatesDirections = nodeHeadings
                                    let ppHeadings: [Double] = Array(Set(nodeCandidatesDirections))
                                    let passedNodeMatchedIndex: Int = nodeCandidatesInfo[0].matchedIndex
                                    let uvdBuffer: [UnitDRInfo] = getUnitDRInfoFromUvdIndex(from: unitDRInfoBufferForPhase4, uvdIndex: passedNodeMatchedIndex)
                                    self.isNeedClearBuffer = true
                                    if (uvdBuffer.isEmpty) {
//                                        print(getLocalTimeString() + " , (Olympus) Request Phase 4 : phaseBreak (uvd Empty)")
                                        phaseBreakInPhase4(fltResult: tuResult, isUpdatePhaseBreakResult: false)
                                    } else {
                                        var uvRawHeading = [Double]()
                                        for value in uvdBuffer {
                                            uvRawHeading.append(value.heading)
                                        }
                                        
                                        var searchHeadings = [Double]()
                                        var hasMajorDirection: Bool = false
                                        let headingLeastChangeSection = trajController.extractSectionWithLeastChange(inputArray: uvRawHeading, requiredSize: 8)
//                                        print(getLocalTimeString() + " , (Olympus) Request Phase 4 : uvRawHeading = \(uvRawHeading)")
//                                        print(getLocalTimeString() + " , (Olympus) Request Phase 4 : headingLeastChangeSection = \(headingLeastChangeSection)")
//                                        print(getLocalTimeString() + " , (Olympus) Request Phase 4 : ppHeadings = \(ppHeadings)")
                                        if (headingLeastChangeSection.isEmpty) {
                                            hasMajorDirection = false
                                        } else {
                                            var diffHeading = [Double]()
                                            var bestPpHeading: Double = 0
                                            let heading = nodeCandidatesInfo[0].userHeading
                                            for ppHeading in ppHeadings {
                                                var diffValue: Double = 0
                                                if (heading > 270 && (ppHeading >= 0 && ppHeading < 90)) {
                                                    diffValue = abs(heading - (ppHeading+360))
                                                } else if (ppHeading > 270 && (heading >= 0 && heading < 90)) {
                                                    diffValue = abs(ppHeading - (heading+360))
                                                } else {
                                                    diffValue = abs(heading - ppHeading)
                                                }
                                                diffHeading.append(diffValue)
                                            }
                                            if let minIndex = diffHeading.firstIndex(of: diffHeading.min()!) {
                                                bestPpHeading = ppHeadings[minIndex]
                                                
                                                let headingForCompensation = headingLeastChangeSection.average - uvRawHeading[0]
                                                let tailHeading = bestPpHeading - headingForCompensation
                                                searchHeadings.append(compensateHeading(heading: tailHeading))
                                                hasMajorDirection = true
                                            }
                                        }
                                        
                                        if (!hasMajorDirection) {
                                            searchHeadings = [0, 90, 180, 270]
                                        }
                                        
                                        let searchDirections = searchHeadings.map { Int($0) }
                                        let stableInfo = StableInfo(tail_index: passedNodeMatchedIndex, head_section_number: sectionController.getSectionNumber(), node_number_list: nodeNumberCandidates)
                                        self.isInRecoveryProcess = true
                                        processPhase4(currentTime: getCurrentTimeInMilliseconds(), mode: runMode, trajectoryInfo: trajectoryInfo, stableInfo: stableInfo, nodeCandidatesInfo: badCaseNodeCandidatesResult, node_index: passedNodeMatchedIndex, search_direction_list: searchDirections)
                                    }
                                }
                                
                            }
                        } else if (!isNeedPathTrajMatching.straight) {
                            // Phase 6 요청 보내야하는 상황이면 요쳥 보내기
                            let isNeedRq = sectionController.checkIsNeedRequestFlt(isAmbiguous: ambiguitySolver.getIsAmbiguous())
                            if (isNeedRq.0 && phaseController.PHASE == OlympusConstants.PHASE_6) {
                                let goodCaseNodeCandidates = OlympusPathMatchingCalculator.shared.getAnchorNodeCandidatesForGoodCase(fltResult: tuResult, pathType: pathType)
                                var inputNodeCandidates = goodCaseNodeCandidates
                                let nodeCandidatesInfo = goodCaseNodeCandidates.nodeCandidatesInfo
                                if (nodeCandidatesInfo.isEmpty) {
                                    let reCheckMapEnd = OlympusPathMatchingCalculator.shared.checkIsInMapEnd(resultStandard: self.temporalResult, tuResult: tuResult, pathType: pathType)
//                                    print(getLocalTimeString() + " , (Olympus) Check Map End : reCheckMapEnd (1) = \(reCheckMapEnd)")
                                    if !reCheckMapEnd {
                                        let stableInfo = StableInfo(tail_index: sectionController.getAnchorTailIndex(), head_section_number: sectionController.sectionNumber, node_number_list: [])
                                        processPhase6(currentTime: getCurrentTimeInMilliseconds(), mode: runMode, trajectoryInfo: trajectoryInfo, stableInfo: stableInfo, nodeCandidatesInfo: goodCaseNodeCandidates)
                                    }
                                } else {
                                    var nodeNumberCandidates = [Int]()
                                    if runMode == OlympusConstants.MODE_PDR {
                                        for item in nodeCandidatesInfo {
                                            nodeNumberCandidates.append(item.nodeNumber)
                                        }
                                    } else {
                                        let isSectionChanged = isNeedRq.1
//                                        print(getLocalTimeString() + " , (Olympus) Node Find : checkSectionChanged = \(isSectionChanged) // isAmbiguious = \(ambiguitySolver.getIsAmbiguous())")
                                        let multipleNodeCandidates = OlympusPathMatchingCalculator.shared.getMultipleAnchorNodeCandidates(fltResult: tuResult, pathType: 1)
                                        var prevPassedNodeInfo = OlympusPathMatchingCalculator.shared.getPreviousPassedNode(nodeCandidateInfo: multipleNodeCandidates)
                                        
                                        if isSectionChanged {
                                            inputNodeCandidates = multipleNodeCandidates
                                            for item in multipleNodeCandidates.nodeCandidatesInfo {
                                                nodeNumberCandidates.append(item.nodeNumber)
                                            }
                                            let stableInfo = StableInfo(tail_index: nodeCandidatesInfo[0].matchedIndex, head_section_number: sectionController.getSectionNumber(), node_number_list: nodeNumberCandidates)
                                            
                                            if nodeNumberCandidates.count > 1 {
                                                if prevPassedNodeInfo.nodeNumber == -1 {
                                                    prevPassedNodeInfo.matchedIndex = sectionController.getAnchorTailIndex()
                                                }
                                                processPhase5(currentTime: getCurrentTimeInMilliseconds(), mode: runMode, trajectoryInfo: trajectoryInfo, stableInfo: stableInfo, nodeCandidatesInfo: inputNodeCandidates, prevNodeInfo: prevPassedNodeInfo)
                                            } else {
                                                processPhase6(currentTime: getCurrentTimeInMilliseconds(), mode: runMode, trajectoryInfo: trajectoryInfo, stableInfo: stableInfo, nodeCandidatesInfo: inputNodeCandidates)
                                            }
                                        } else if !self.isInMapEnd {
                                            let reCheckMapEnd = OlympusPathMatchingCalculator.shared.checkIsInMapEnd(resultStandard: self.temporalResult, tuResult: tuResult, pathType: pathType)
                                            if !reCheckMapEnd {
                                                for item in nodeCandidatesInfo {
                                                    nodeNumberCandidates.append(item.nodeNumber)
                                                }
                                                let stableInfo = StableInfo(tail_index: nodeCandidatesInfo[0].matchedIndex, head_section_number: sectionController.getSectionNumber(), node_number_list: nodeNumberCandidates)
                                                
                                                if (ambiguitySolver.getIsAmbiguous()){
                                                    processPhase5(currentTime: getCurrentTimeInMilliseconds(), mode: runMode, trajectoryInfo: trajectoryInfo, stableInfo: stableInfo, nodeCandidatesInfo: inputNodeCandidates, prevNodeInfo: prevPassedNodeInfo)
                                                } else {
                                                    processPhase6(currentTime: getCurrentTimeInMilliseconds(), mode: runMode, trajectoryInfo: trajectoryInfo, stableInfo: stableInfo, nodeCandidatesInfo: inputNodeCandidates)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    } else {
//                        print(getLocalTimeString() + " , (Olympus) isDRMode : index = \(unitDRInfoIndex) // DR Mode Anchor = \(buildingLevelChanger.currentDRModeAreaNodeNumber) , Current Anchor = \(OlympusPathMatchingCalculator.shared.anchorNode.nodeNumber)")
                        // DR 모드인 경우 위치 요청을 지속적으로 보내면서 확실히 그 영역에 진입했는지를 확인한다
                        if buildingLevelChanger.currentDRModeAreaNodeNumber == OlympusPathMatchingCalculator.shared.anchorNode.nodeNumber && buildingLevelChanger.currentDRModeAreaNodeNumber != -1 {
                            if !self.isDRModeRqInfoSaved {
                                self.isDRModeRqInfoSaved = true
                                ambiguitySolver.setIsAmbiguousInDRMode(value: true)
                                let goodCaseNodeCandidates = OlympusPathMatchingCalculator.shared.getAnchorNodeCandidatesForGoodCase(fltResult: tuResult, pathType: pathType)
                                var inputNodeCandidates = goodCaseNodeCandidates
                                let nodeCandidatesInfo = goodCaseNodeCandidates.nodeCandidatesInfo
                                
                                var nodeNumberCandidates = [Int]()
                                let multipleNodeCandidates = OlympusPathMatchingCalculator.shared.getMultipleAnchorNodeCandidates(fltResult: tuResult, pathType: 1)
                                var prevPassedNodeInfo = OlympusPathMatchingCalculator.shared.getPreviousPassedNode(nodeCandidateInfo: multipleNodeCandidates)
                                if prevPassedNodeInfo.nodeNumber == -1 {
                                    prevPassedNodeInfo.matchedIndex = sectionController.getAnchorTailIndex()
                                }
                                inputNodeCandidates = multipleNodeCandidates
                                for item in multipleNodeCandidates.nodeCandidatesInfo {
                                    nodeNumberCandidates.append(item.nodeNumber)
                                }
                                let stableInfo = StableInfo(tail_index: nodeCandidatesInfo[0].matchedIndex, head_section_number: sectionController.getSectionNumber(), node_number_list: nodeNumberCandidates)
                                drModeRequestInfo = DRModeRequestInfo(trajectoryInfo: trajectoryInfo, stableInfo: stableInfo, nodeCandidatesInfo: inputNodeCandidates, prevNodeInfo: prevPassedNodeInfo)
                                sectionController.setDRModeRequestSectionNumber()
                            }
                            
                            if ambiguitySolver.isAmbiguousInDRMode {
                                let isNeedRqInDRMode = sectionController.checkIsNeedRequestFltInDRMode()
                                if isNeedRqInDRMode.0 {
                                    processPhase5InDRMode(currentTime: getCurrentTimeInMilliseconds(), mode: runMode, trajectoryInfo: drModeRequestInfo.trajectoryInfo, stableInfo: drModeRequestInfo.stableInfo, nodeCandidatesInfo: drModeRequestInfo.nodeCandidatesInfo, prevNodeInfo: drModeRequestInfo.prevNodeInfo)
                                }
                            }
                        }
                    }
                }
            } else if (isInRecoveryProcess) {
//                print(getLocalTimeString() + " , (Olmypus) Request : isInRecoveryProcess")
            }
            
            // Route Tracking
            if (isStartRouteTrack) {
                let routeTrackResult = routeTracker.getRouteTrackResult(temporalResult: self.temporalResult, currentLevel: currentLevel, isVenusMode: stateManager.isVenusMode, isKF: KF.isRunning, isPhaseBreakInRouteTrack: isPhaseBreakInRouteTrack)
                if (routeTrackResult.isRouteTrackFinished) {
                    buildingLevelChanger.setBuildingLevelChangedTime(value: getCurrentTimeInMilliseconds())
                    unitDRGenerator.setRouteTrackFinishedTime(value: getCurrentTimeInMillisecondsDouble())
                    unitDRGenerator.setIsStartRouteTrack(isStartRoutTrack: false)
                    isStartRouteTrack = false
                    isPhaseBreakInRouteTrack = false
                    if (routeTrackResult.1 != RouteTrackFinishType.STABLE) {
                        self.temporalResult = self.routeTrackResult
                    }
                    networkStatus = true
                    self.currentBuilding = routeTrackResult.2.building_name
                    self.currentLevel = routeTrackResult.2.level_name
                } else {
                    self.routeTrackResult = routeTrackResult.2
                    self.routeTrackResult.index = self.unitDRInfoIndex
                }
            }
            
            if (abs(getCurrentTimeInMillisecondsDouble() - bleManager.bleDiscoveredTime) < 1000*10) || isSimulationMode {
                requestOlympusResult(trajectoryInfo: trajectoryInfo, trueHeading: sensorData.trueHeading, mode: self.runMode)
            }
        } else {
            if (!unitDRInfo.isIndexChanged) {
                let isStop = stateManager.checkStopWhenIsIndexNotChanaged()
                if (isStop) {
                    olympusVelocity = 0
                    if (abs(getCurrentTimeInMillisecondsDouble() - bleManager.bleDiscoveredTime) < 1000*10) || isSimulationMode {
                        requestOlympusResultInStop(trajectoryInfo: trajController.pastTrajectoryInfo, trueHeading: sensorData.trueHeading, mode: self.runMode)
                    }
                }
                stateManager.checkEnterSleepMode(service: self.service, type: 1)
            }
        }
    }
    
    func requestOlympusResult(trajectoryInfo: [TrajectoryInfo], trueHeading: Double, mode: String) {
        let currentTime = getCurrentTimeInMilliseconds()
        if (!stateManager.isBackground && isStartRouteTrack) {
            let isCorrelation = routeTracker.checkIsEntranceFinished(bleData: self.bleAvg, normalization_scale: OlympusConstants.NORMALIZATION_SCALE, device_min_rss: OlympusConstants.DEVICE_MIN_RSSI, standard_min_rss: OlympusConstants.STANDARD_MIN_RSS)
            if isCorrelation.0 {
                buildingLevelChanger.setBuildingLevelChangedTime(value: getCurrentTimeInMilliseconds())
                unitDRGenerator.setRouteTrackFinishedTime(value: getCurrentTimeInMillisecondsDouble())
                
                let correlationInfo = isCorrelation.1
                var lastServerResult = serverResultBuffer[serverResultBuffer.count-1]
                
                unitDRGenerator.setIsStartRouteTrack(isStartRoutTrack: false)
                isStartRouteTrack = false
                isPhaseBreakInRouteTrack = false
                networkStatus = true
                
                self.currentBuilding = lastServerResult.building_name
                self.currentLevel = routeTracker.getRouteTrackEndLevel()
                lastServerResult.level_name = routeTracker.getRouteTrackEndLevel()
                lastServerResult.x = correlationInfo[0]
                lastServerResult.y = correlationInfo[1]
                lastServerResult.absolute_heading = correlationInfo[2]
                
//                print(getLocalTimeString() + " , (Olympus) Route Tracker : correlationInfo = \(correlationInfo)")
                
                let newCoord: [Double] = [lastServerResult.x, lastServerResult.y]
                self.setTemporalResult(coord: newCoord)
                KF.updateTuResult(x: newCoord[0], y: newCoord[1])
                KF.setLinkInfo(coord: newCoord, directions: OlympusPathMatchingCalculator.shared.getPathMatchingHeadings(building: lastServerResult.building_name, level: lastServerResult.level_name, x: newCoord[0], y: newCoord[1], PADDING_VALUE: 0.0, mode: self.runMode))
                OlympusPathMatchingCalculator.shared.setBuildingLevelChangedCoord(coord: newCoord)
                
                makeTemporalResult(input: lastServerResult, isStableMode: false, mustInSameLink: false, updateType: .NONE, pathMatchingType: .WIDE)
                NotificationCenter.default.post(name: .phaseChanged, object: nil, userInfo: ["phase": OlympusConstants.PHASE_6])
                displayOutput.phase = String(phaseController.PHASE)
                displayOutput.indexRx = unitDRInfoIndex
                sectionController.setSectionUserHeading(value: lastServerResult.absolute_heading)
                KF.activateKalmanFilter(fltResult: lastServerResult)
            }
        }
        
        if ((self.unitDRInfoIndex % RQ_IDX) == 0 && !stateManager.isBackground) {
            if (phaseController.PHASE == OlympusConstants.PHASE_1 || phaseController.PHASE == OlympusConstants.PHASE_3) {
                // Phase 1 ~ 3
                if KF.isRunning && !self.isPhaseBreak {
                    self.isPhaseBreak = true
                }
                let phase3Trajectory = trajectoryInfo
                let searchInfo = trajController.makeSearchInfo(trajectoryInfo: phase3Trajectory, serverResultBuffer: serverResultBuffer, unitDRInfoBuffer: unitDRInfoBuffer, isKF: KF.isRunning, mode: mode, PHASE: phaseController.PHASE, isPhaseBreak: isPhaseBreak, phaseBreakResult: phaseBreakResult, LENGTH_THRESHOLD: USER_TRAJECTORY_LENGTH)
                let displaySearchType: Int = trajTypeConverter(trajType: searchInfo.trajType)
                displayOutput.searchArea = searchInfo.searchArea
                displayOutput.searchType = displaySearchType
                displayOutput.userTrajectory = searchInfo.trajShape
                displayOutput.trajectoryStartCoord = searchInfo.trajStartCoord
                if (!isStartRouteTrack || isPhaseBreakInRouteTrack) {
                    processPhase3(currentTime: currentTime, mode: mode, trajectoryInfo: phase3Trajectory, searchInfo: searchInfo)
                }
            }
        }
    }
    
    func requestOlympusResultInStop(trajectoryInfo: [TrajectoryInfo], trueHeading: Double, mode: String) {
        let currentTime = getCurrentTimeInMilliseconds()
        let currentTimeDouble = Double(currentTime)
        if (stateManager.isVenusMode && (currentTimeDouble-self.timeRequest)*1e-3 >= OlympusConstants.MINIMUM_RQ_TIME) {
            self.timeRequest = currentTimeDouble
            let phase3Trajectory = trajectoryInfo
            let searchInfo = trajController.makeSearchInfo(trajectoryInfo: phase3Trajectory, serverResultBuffer: serverResultBuffer, unitDRInfoBuffer: unitDRInfoBuffer, isKF: KF.isRunning, mode: mode, PHASE: phaseController.PHASE, isPhaseBreak: isPhaseBreak, phaseBreakResult: phaseBreakResult, LENGTH_THRESHOLD: USER_TRAJECTORY_LENGTH)
//            print(getLocalTimeString() + " , (Olympus) Request Phase 3 in Stop State")
            processPhase3(currentTime: currentTime, mode: mode, trajectoryInfo: phase3Trajectory, searchInfo: searchInfo)
        } else {
            if (!stateManager.isGetFirstResponse && (currentTimeDouble-self.timeRequest)*1e-3 >= OlympusConstants.MINIMUM_RQ_TIME) {
                self.timeRequest = currentTimeDouble
                let phase3Trajectory = trajectoryInfo
                let searchInfo = trajController.makeSearchInfo(trajectoryInfo: phase3Trajectory, serverResultBuffer: serverResultBuffer, unitDRInfoBuffer: unitDRInfoBuffer, isKF: KF.isRunning, mode: mode, PHASE: phaseController.PHASE, isPhaseBreak: isPhaseBreak, phaseBreakResult: phaseBreakResult, LENGTH_THRESHOLD: USER_TRAJECTORY_LENGTH)
//                print(getLocalTimeString() + " , (Olympus) Request Phase 3 in Stop State (2)")
                processPhase3(currentTime: currentTime, mode: mode, trajectoryInfo: phase3Trajectory, searchInfo: searchInfo)
            }
        }
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
        displayOutput.phase = "3"
        displayOutput.searchDirection = searchInfo.searchDirection
//        displayOutput.indexTx = unitDRInfoIndex
        var input = FineLocationTracking(user_id: self.user_id, mobile_time: currentTime, sector_id: self.sector_id, operating_system: OlympusConstants.OPERATING_SYSTEM, building_name: self.currentBuilding, level_name_list: levelArray, phase: phaseController.PHASE, search_range: searchInfo.searchRange, search_direction_list: searchInfo.searchDirection, normalization_scale: OlympusConstants.NORMALIZATION_SCALE, device_min_rss: Int(OlympusConstants.DEVICE_MIN_RSSI), sc_compensation_list: [1.0], tail_index: searchInfo.tailIndex, head_section_number: 0, node_number_list: [], node_index: 0, retry: false)
        stateManager.setNetworkCount(value: stateManager.networkCount+1)
//        print(getLocalTimeString() + " , (Olympus) Request Phase 1 ~ 3 : \(input)")
        if (REGION_NAME != "Korea" && self.deviceModel == "iPhone SE (2nd generation)") { input.normalization_scale = 1.01 }
        OlympusNetworkManager.shared.postFLT(url: CALC_FLT_URL, input: input, userTraj: trajectoryInfo, searchInfo: searchInfo, completion: { [self] statusCode, returnedString, fltInput, inputTraj, inputSearchInfo in
//            print(getLocalTimeString() + " , (Olympus) Phase 3 Result : \(statusCode) // \(returnedString)")
            if (!returnedString.contains("timed out")) { stateManager.setNetworkCount(value: 0) }
            if (statusCode == 200) {
                let results = jsonToFineLocatoinTrackingResultFromServerList(jsonString: returnedString)
                let result = results.1.flt_outputs
                let fltResult = result.isEmpty ? FineLocationTrackingFromServer() : result[0]
                if (results.0 && (fltResult.x != 0 || fltResult.y != 0)) {
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
                        let resultPhase = phaseController.controlPhase(serverResultArray: serverResultBuffer, drBuffer: unitDRInfoBuffer, UVD_INTERVAL: UVD_INPUT_NUM, TRAJ_LENGTH: USER_TRAJECTORY_LENGTH, INDEX_THRESHOLD: RQ_IDX, inputPhase: fltInput.phase, inputTrajType: inputSearchInfo.trajType, mode: runMode, isVenusMode: stateManager.isVenusMode)
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
                                    stateManager.setIsIndoor(isIndoor: true)
                                    stateManager.setIsGetFirstResponse(isGetFirstResponse: true)
                                } else {
                                    let isOn = routeTracker.startRouteTracking(result: fltResult, isStartRouteTrack: isStartRouteTrack)
                                    if (isOn.0) {
                                        stateManager.setIsIndoor(isIndoor: true)
                                        stateManager.setIsGetFirstResponse(isGetFirstResponse: true)
                                    }
                                    unitDRGenerator.setIsStartRouteTrack(isStartRoutTrack: isOn.0)
                                    isStartRouteTrack = isOn.0
                                    networkStatus = isOn.1
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
                            let inputTrajLength = trajController.calculateTrajectoryLength(trajectoryInfo: inputTraj)
                            if (inputTrajLength >= OlympusConstants.STABLE_ENTER_LENGTH) {
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
                                
                                if (resultPhase.0 == OlympusConstants.PHASE_3) {
                                    let updatedResult = buildingLevelChanger.updateBuildingAndLevel(fltResult: copiedResult, currentBuilding: currentBuilding, currentLevel: currentLevel)
                                    currentBuilding = updatedResult.building_name
                                    currentLevel = updatedResult.level_name
                                    self.isBuildingLevelChanged(newBuilding: updatedResult.building_name, newLevel: updatedResult.level_name, newCoord: [])
                                } else if (resultPhase.0 == OlympusConstants.PHASE_6) {
                                    sectionController.setInitialAnchorTailIndex(value: unitDRInfoIndex)
                                    copiedResult.absolute_heading = propagatedResult[2]
                                    let updatedResult = buildingLevelChanger.updateBuildingAndLevel(fltResult: copiedResult, currentBuilding: currentBuilding, currentLevel: currentLevel)
                                    currentBuilding = updatedResult.building_name
                                    currentLevel = updatedResult.level_name
                                    
                                    makeTemporalResult(input: updatedResult, isStableMode: true, mustInSameLink: false, updateType: .NONE, pathMatchingType: .WIDE)
                                    self.isBuildingLevelChanged(newBuilding: updatedResult.building_name, newLevel: updatedResult.level_name, newCoord: [])
                                    sectionController.setSectionUserHeading(value: updatedResult.absolute_heading)
                                    KF.refreshTuResult(xyh: [copiedResult.x, copiedResult.y, copiedResult.absolute_heading], inputPhase: fltInput.phase, inputTrajLength: inputTrajLength, mode: runMode)
                                    
                                    if isPhaseBreak {
                                        KF.resetKalmanR()
                                        PADDING_VALUE = OlympusConstants.PADDING_VALUE_SMALL
                                        userMaskSendCount = 0
                                        OlympusPathMatchingCalculator.shared.initPassedNodeInfo()
                                        isPhaseBreak = false
                                    }
                                }
                            } else {
                                let updatedResult = buildingLevelChanger.updateBuildingAndLevel(fltResult: fltResult, currentBuilding: currentBuilding, currentLevel: currentLevel)
                                currentBuilding = updatedResult.building_name
                                currentLevel = updatedResult.level_name
                                self.isBuildingLevelChanged(newBuilding: updatedResult.building_name, newLevel: updatedResult.level_name, newCoord: [])
                            }
                        } else {
                            if (resultPhase.0 == OlympusConstants.PHASE_6 && !stateManager.isVenusMode) {
                                // Phase 3 --> 5 && KF start
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
                                curTemporalResultHeading = updatedResult.absolute_heading
                                makeTemporalResult(input: updatedResult, isStableMode: true, mustInSameLink: false, updateType: .NONE, pathMatchingType: .WIDE)
                                sectionController.setSectionUserHeading(value: updatedResult.absolute_heading)
                                KF.activateKalmanFilter(fltResult: updatedResult)
                            } else {
                                // KF is not running && Phase 1 ~ 3
                                let updatedResult = buildingLevelChanger.updateBuildingAndLevel(fltResult: fltResult, currentBuilding: currentBuilding, currentLevel: currentLevel)
                                currentBuilding = updatedResult.building_name
                                currentLevel = updatedResult.level_name
                                makeTemporalResult(input: updatedResult, isStableMode: false, mustInSameLink: false, updateType: .NONE, pathMatchingType: .WIDE)
                            }
                        }
                    }
                    self.preServerResultMobileTime = fltResult.mobile_time
                } else {
                    trajController.setIsNeedTrajCheck(flag: true)
                    NotificationCenter.default.post(name: .phaseChanged, object: nil, userInfo: ["phase": OlympusConstants.PHASE_1])
                }
            } else {
//                let msg: String = getLocalTimeString() + " , (Olympus) Error : \(statusCode) Fail to request indoor position in Phase 3"
//                print(msg)
            }
        })
    }
    
    private func processPhase4(currentTime: Int, mode: String, trajectoryInfo: [TrajectoryInfo], stableInfo: StableInfo, nodeCandidatesInfo: NodeCandidateInfo, node_index: Int, search_direction_list: [Int]) {
        if (mode == OlympusConstants.MODE_PDR) {
            self.currentLevel = removeLevelDirectionString(levelName: self.currentLevel)
        }
        var levelArray = [self.currentLevel]
        let isInLevelChangeArea = buildingLevelChanger.checkInLevelChangeArea(result: self.olympusResult, mode: mode)
        if (isInLevelChangeArea) {
            levelArray = buildingLevelChanger.makeLevelChangeArray(buildingName: self.currentBuilding, levelName: self.currentLevel, buildingLevel: buildingLevelChanger.buildingsAndLevels)
        }
        displayOutput.phase = String(OlympusConstants.PHASE_4)
        displayOutput.searchDirection = []
        var input = FineLocationTracking(user_id: self.user_id, mobile_time: currentTime, sector_id: self.sector_id, operating_system: OlympusConstants.OPERATING_SYSTEM, building_name: self.currentBuilding, level_name_list: levelArray, phase: 4, search_range: [], search_direction_list: search_direction_list, normalization_scale: OlympusConstants.NORMALIZATION_SCALE, device_min_rss: Int(OlympusConstants.DEVICE_MIN_RSSI), sc_compensation_list: [1.01], tail_index: stableInfo.tail_index, head_section_number: stableInfo.head_section_number, node_number_list: stableInfo.node_number_list, node_index: node_index, retry: false)
        stateManager.setNetworkCount(value: stateManager.networkCount+1)
        if (REGION_NAME != "Korea" && self.deviceModel == "iPhone SE (2nd generation)") { input.normalization_scale = 1.01 }
        OlympusNetworkManager.shared.postStableFLT(url: CALC_FLT_URL, input: input, userTraj: trajectoryInfo, nodeCandidateInfo: nodeCandidatesInfo, completion: { [self] statusCode, returnedString, fltInput, inputTraj, inputNodeCandidatesInfo in
            if (!returnedString.contains("timed out")) { stateManager.setNetworkCount(value: 0) }
            if (statusCode == 200) {
                let results = jsonToFineLocatoinTrackingResultFromServerList(jsonString: returnedString)
                let result = results.1.flt_outputs
                let (useResult, fltResult) = ambiguitySolver.selectResult(results: results.1, nodeCandidatesInfo: inputNodeCandidatesInfo)
//                print(getLocalTimeString() + " , (Olympus) Request Phase 4 : result = \(fltResult)")
                trajController.updateTrajCompensationArray(result: fltResult)
                trajController.setPastInfo(trajInfo: inputTraj, searchInfo: SearchInfo(), matchedDirection: fltResult.search_direction)
                if (fltResult.index > indexPast && useResult) {
                    stackServerResult(serverResult: fltResult)
                    let resultPhase = phaseController.controlPhase(serverResultArray: serverResultBuffer, drBuffer: unitDRInfoBuffer, UVD_INTERVAL: UVD_INPUT_NUM, TRAJ_LENGTH: USER_TRAJECTORY_LENGTH, INDEX_THRESHOLD: RQ_IDX, inputPhase: fltInput.phase, inputTrajType: TrajType.DR_UNKNOWN, mode: runMode, isVenusMode: stateManager.isVenusMode)
                    // 임시
                    displayOutput.phase = String(resultPhase.0)
                    // 임시
                    
                    if (KF.isRunning && resultPhase.0 == OlympusConstants.PHASE_6) {
                        if (!(fltResult.x == 0 && fltResult.y == 0) && !buildingLevelChanger.isDetermineSpot && phaseController.PHASE != OlympusConstants.PHASE_2) {
                            // 임시
                            displayOutput.indexRx = fltResult.index
                            displayOutput.scc = fltResult.scc
                            displayOutput.resultDirection = fltResult.search_direction
                            // 임시
                            
                            if (isPhaseBreak) {
                                KF.resetKalmanR()
                                PADDING_VALUE = OlympusConstants.PADDING_VALUE_SMALL
                                userMaskSendCount = 0
                                isPhaseBreak = false
                            }
                            
                            var pmFltRsult = fltResult
                            var propagatedPmFltRsult = fltResult
                            if (KF.muFlag) {
                                let isNeedCalDhFromUvd: Bool = true
                                let isResultStraight = isResultHeadingStraight(unitDRInfoBuffer: unitDRInfoBuffer, fltResult: fltResult)
                                if (runMode == OlympusConstants.MODE_PDR) {
                                    let pathMatchingResult = OlympusPathMatchingCalculator.shared.pathMatching(building: fltResult.building_name, level: fltResult.level_name, x: fltResult.x, y: fltResult.y, heading: fltResult.absolute_heading, HEADING_RANGE: OlympusConstants.HEADING_RANGE, isUseHeading: isResultStraight, pathType: 0, PADDING_VALUES: paddingValues)
//                                    print(getLocalTimeString() + " , (Olympus) Request Phase 4 : paddingValues = \(paddingValues)")
                                    pmFltRsult.x = pathMatchingResult.xyhs[0]
                                    pmFltRsult.y = pathMatchingResult.xyhs[1]
                                    pmFltRsult.absolute_heading = pathMatchingResult.xyhs[2]
                                } else {
                                    let pathMatchingResult = OlympusPathMatchingCalculator.shared.pathMatching(building: fltResult.building_name, level: fltResult.level_name, x: fltResult.x, y: fltResult.y, heading: fltResult.absolute_heading, HEADING_RANGE: OlympusConstants.HEADING_RANGE, isUseHeading: true, pathType: 1, PADDING_VALUES: paddingValues)
                                    pmFltRsult.x = pathMatchingResult.xyhs[0]
                                    pmFltRsult.y = pathMatchingResult.xyhs[1]
                                }
                                // 임시
                                displayOutput.serverResult[0] = pmFltRsult.x
                                displayOutput.serverResult[1] = pmFltRsult.y
                                displayOutput.serverResult[2] = pmFltRsult.absolute_heading
                                
                                let dxdydh = KF.preProcessForMeasurementUpdate(fltResult: pmFltRsult, unitDRInfoBuffer: unitDRInfoBuffer, mode: runMode, isNeedCalDhFromUvd: isNeedCalDhFromUvd, isResultStraight: isResultStraight)
                                propagatedPmFltRsult.x = pmFltRsult.x + dxdydh[0]
                                propagatedPmFltRsult.y = pmFltRsult.y + dxdydh[1]
                                if (isPossibleHeadingCorrection) {
                                    propagatedPmFltRsult.absolute_heading = pmFltRsult.absolute_heading + dxdydh[2]
                                } else {
                                    propagatedPmFltRsult.absolute_heading = propagatedPmFltRsult.absolute_heading + dxdydh[2]
                                }
                                propagatedPmFltRsult.absolute_heading = compensateHeading(heading: propagatedPmFltRsult.absolute_heading)
                                
                                let muResult = KF.measurementUpdate(fltResult: fltResult, pmFltResult: pmFltRsult, propagatedPmFltResult: propagatedPmFltRsult, unitDRInfoBuffer: unitDRInfoBuffer, isPossibleHeadingCorrection: isPossibleHeadingCorrection, PADDING_VALUES: PADDING_VALUES, mode: runMode)
                                let updatedResult = buildingLevelChanger.updateBuildingAndLevel(fltResult: muResult, currentBuilding: currentBuilding, currentLevel: currentLevel)
                                currentBuilding = updatedResult.building_name
                                currentLevel = updatedResult.level_name
                                
                                // 서버에서 전달해주는 파라미터 하나 추가 필요! 결정한 노드 관련
                                OlympusPathMatchingCalculator.shared.updateAnchorNodeAfterRecovery(badCaseNodeInfo: inputNodeCandidatesInfo, nodeNumber: fltResult.node_number)
                                makeTemporalResult(input: updatedResult, isStableMode: false, mustInSameLink: false, updateType: .NONE, pathMatchingType: .WIDE)
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
                self.isInRecoveryProcess = false
                let msg: String = getLocalTimeString() + " , (Olympus) Error : \(statusCode) Fail to request indoor position in Phase 4"
                print(msg)
            }
        })
    }
    
    private func processPhase5(currentTime: Int, mode: String, trajectoryInfo: [TrajectoryInfo], stableInfo: StableInfo, nodeCandidatesInfo: NodeCandidateInfo, prevNodeInfo: PassedNodeInfo) {
        if (mode == OlympusConstants.MODE_PDR) {
            self.currentLevel = removeLevelDirectionString(levelName: self.currentLevel)
        }
        var levelArray = [self.currentLevel]
        let isInLevelChangeArea = buildingLevelChanger.checkInLevelChangeArea(result: self.olympusResult, mode: mode)
        if (isInLevelChangeArea) {
            levelArray = buildingLevelChanger.makeLevelChangeArray(buildingName: self.currentBuilding, levelName: self.currentLevel, buildingLevel: buildingLevelChanger.buildingsAndLevels)
        }
        displayOutput.phase = String(OlympusConstants.PHASE_5)
        displayOutput.searchDirection = []
        var input = FineLocationTracking(user_id: self.user_id, mobile_time: currentTime, sector_id: self.sector_id, operating_system: OlympusConstants.OPERATING_SYSTEM, building_name: self.currentBuilding, level_name_list: levelArray, phase: 5, search_range: [], search_direction_list: [], normalization_scale: OlympusConstants.NORMALIZATION_SCALE, device_min_rss: Int(OlympusConstants.DEVICE_MIN_RSSI), sc_compensation_list: [1.01], tail_index: prevNodeInfo.matchedIndex, head_section_number: stableInfo.head_section_number, node_number_list: stableInfo.node_number_list, node_index: stableInfo.tail_index, retry: false)
//        print(getLocalTimeString() + " , (Olympus) Request Phase 5 : input = \(input)")
        stateManager.setNetworkCount(value: stateManager.networkCount+1)
        
        if (ambiguitySolver.getIsAmbiguous() && ambiguitySolver.retryFltInput.head_section_number == input.head_section_number) {
            input = ambiguitySolver.getRetryInput()
        }
        
        if (REGION_NAME != "Korea" && self.deviceModel == "iPhone SE (2nd generation)") { input.normalization_scale = 1.01 }
        OlympusNetworkManager.shared.postStableFLT(url: CALC_FLT_URL, input: input, userTraj: trajectoryInfo, nodeCandidateInfo: nodeCandidatesInfo, completion: { [self] statusCode, returnedString, fltInput, inputTraj, inputNodeCandidatesInfo in
            if (!returnedString.contains("timed out")) { stateManager.setNetworkCount(value: 0) }
            if (statusCode == 200) {
                let results = jsonToFineLocatoinTrackingResultFromServerList(jsonString: returnedString)
//                print(getLocalTimeString() + " , (Olympus) Request Phase 5 : results = \(results)")
                let (useResult, fltResult) = ambiguitySolver.selectResult(results: results.1, nodeCandidatesInfo: inputNodeCandidatesInfo)
                ambiguitySolver.setIsAmbiguous(value: !useResult)
                ambiguitySolver.setRetryInput(input: fltInput)
                
//                print(getLocalTimeString() + " , (Olympus) Request Phase 5 : fltResult = \(fltResult)")
                trajController.updateTrajCompensationArray(result: fltResult)
                trajController.setPastInfo(trajInfo: inputTraj, searchInfo: SearchInfo(), matchedDirection: fltResult.search_direction)
                if (fltResult.index > indexPast) {
                    // 임시
                    displayOutput.serverResult[0] = fltResult.x
                    displayOutput.serverResult[1] = fltResult.y
                    displayOutput.serverResult[2] = fltResult.absolute_heading
                    // 임시
                    
                    stackServerResult(serverResult: fltResult)
                    let resultPhase = phaseController.controlPhase(serverResultArray: serverResultBuffer, drBuffer: unitDRInfoBuffer, UVD_INTERVAL: UVD_INPUT_NUM, TRAJ_LENGTH: USER_TRAJECTORY_LENGTH, INDEX_THRESHOLD: RQ_IDX, inputPhase: fltInput.phase, inputTrajType: TrajType.DR_UNKNOWN, mode: runMode, isVenusMode: stateManager.isVenusMode)
                    
                    // 임시
                    displayOutput.phase = useResult ? String(resultPhase.0) : String(OlympusConstants.PHASE_5)
                    displayOutput.indexRx = fltResult.index
                    displayOutput.scc = fltResult.scc
                    displayOutput.resultDirection = fltResult.search_direction
                    // 임시
                    
                    if !useResult && !results.1.flt_outputs.isEmpty {
                        // Phase Break
                        let bestResult = ambiguitySolver.selectBestResult(results: results.1)
                        if bestResult.scc < OlympusConstants.PHASE_BREAK_SCC_DR {
                            phaseBreakInPhase4(fltResult: bestResult, isUpdatePhaseBreakResult: true)
                        }
                    }
                    
                    if (KF.isRunning && resultPhase.0 == OlympusConstants.PHASE_6) {
                        if (!(fltResult.x == 0 && fltResult.y == 0) && !buildingLevelChanger.isDetermineSpot && phaseController.PHASE != OlympusConstants.PHASE_2) {
                            scCompensation = fltResult.sc_compensation
                            unitDRGenerator.setScCompensation(value: fltResult.sc_compensation)
                            if (isPhaseBreak) {
                                KF.resetKalmanR()
                                PADDING_VALUE = OlympusConstants.PADDING_VALUE_SMALL
                                userMaskSendCount = 0
                                isPhaseBreak = false
                            }
                            
                            var pmFltRsult = fltResult
                            var propagatedPmFltRsult = fltResult
//                            unitDRGenerator.calAccBias(unitDRInfoBuffer: OlympusPathMatchingCalculator.shared.getUnitDRInfoBuffer(), resultIndex: fltResult.index, scCompensation: fltResult.sc_compensation)
                            if (KF.muFlag) {
                                let isNeedCalDhFromUvd: Bool = false
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
                                }
                                
                                let dxdydh = KF.preProcessForMeasurementUpdate(fltResult: pmFltRsult, unitDRInfoBuffer: unitDRInfoBuffer, mode: runMode, isNeedCalDhFromUvd: isNeedCalDhFromUvd, isResultStraight: isResultStraight)
                                propagatedPmFltRsult.x = pmFltRsult.x + dxdydh[0]
                                propagatedPmFltRsult.y = pmFltRsult.y + dxdydh[1]
                                if (isPossibleHeadingCorrection) {
                                    propagatedPmFltRsult.absolute_heading = pmFltRsult.absolute_heading + dxdydh[2]
                                } else {
                                    propagatedPmFltRsult.absolute_heading = propagatedPmFltRsult.absolute_heading + dxdydh[2]
                                }
                                propagatedPmFltRsult.absolute_heading = compensateHeading(heading: propagatedPmFltRsult.absolute_heading)
                                
                                let muResult = KF.measurementUpdate(fltResult: fltResult, pmFltResult: pmFltRsult, propagatedPmFltResult: propagatedPmFltRsult, unitDRInfoBuffer: unitDRInfoBuffer, isPossibleHeadingCorrection: isPossibleHeadingCorrection, PADDING_VALUES: PADDING_VALUES, mode: runMode)
                                let updatedResult = buildingLevelChanger.updateBuildingAndLevel(fltResult: muResult, currentBuilding: currentBuilding, currentLevel: currentLevel)
                                currentBuilding = updatedResult.building_name
                                currentLevel = updatedResult.level_name
//                                print(getLocalTimeString() + " , (Olympus) Process Phase 5 : muResult = \(muResult)")
                                OlympusPathMatchingCalculator.shared.updateAnchorNodeAfterRecovery(badCaseNodeInfo: inputNodeCandidatesInfo, nodeNumber: fltResult.node_number)
                                makeTemporalResult(input: updatedResult, isStableMode: false, mustInSameLink: false, updateType: .STABLE, pathMatchingType: .WIDE)
                            }
                        } else if (fltResult.x == 0 && fltResult.y == 0) {
                            phaseBreakInPhase4(fltResult: fltResult, isUpdatePhaseBreakResult: false)
                        }
                    } else {
                        phaseBreakInPhase4(fltResult: fltResult, isUpdatePhaseBreakResult: true)
                    }
                    indexPast = fltResult.index
                } else {
                    if (fltResult.x == 0 && fltResult.y == 0) {
                        phaseBreakInPhase4(fltResult: fltResult, isUpdatePhaseBreakResult: false)
                    }
                }
                preServerResultMobileTime = fltResult.mobile_time
                self.isInRecoveryProcess = false
            } else {
                self.isInRecoveryProcess = false
                let msg: String = getLocalTimeString() + " , (Olympus) Error : \(statusCode) Fail to request indoor position in Phase 5 // tail_index = \(fltInput.tail_index)"
                print(msg)
            }
        })
    }
    
    private func processPhase5InDRMode(currentTime: Int, mode: String, trajectoryInfo: [TrajectoryInfo], stableInfo: StableInfo, nodeCandidatesInfo: NodeCandidateInfo, prevNodeInfo: PassedNodeInfo) {
        if (mode == OlympusConstants.MODE_PDR) {
            self.currentLevel = removeLevelDirectionString(levelName: self.currentLevel)
        }
        var levelArray = [self.currentLevel]
        let isInLevelChangeArea = buildingLevelChanger.checkInLevelChangeArea(result: self.olympusResult, mode: mode)
        if (isInLevelChangeArea) {
            levelArray = buildingLevelChanger.makeLevelChangeArray(buildingName: self.currentBuilding, levelName: self.currentLevel, buildingLevel: buildingLevelChanger.buildingsAndLevels)
        }
        displayOutput.phase = String(OlympusConstants.PHASE_5) + " in DR Mode"
        displayOutput.searchDirection = []
        var input = FineLocationTracking(user_id: self.user_id, mobile_time: currentTime, sector_id: self.sector_id, operating_system: OlympusConstants.OPERATING_SYSTEM, building_name: self.currentBuilding, level_name_list: levelArray, phase: 5, search_range: [], search_direction_list: [], normalization_scale: OlympusConstants.NORMALIZATION_SCALE, device_min_rss: Int(OlympusConstants.DEVICE_MIN_RSSI), sc_compensation_list: [1.01], tail_index: prevNodeInfo.matchedIndex, head_section_number: stableInfo.head_section_number, node_number_list: stableInfo.node_number_list, node_index: stableInfo.tail_index, retry: false)
//        print(getLocalTimeString() + " , (Olympus) Request Phase 5 in DR Mode : input = \(input)")
        stateManager.setNetworkCount(value: stateManager.networkCount+1)
        if (REGION_NAME != "Korea" && self.deviceModel == "iPhone SE (2nd generation)") { input.normalization_scale = 1.01 }
        OlympusNetworkManager.shared.postStableFLT(url: CALC_FLT_URL, input: input, userTraj: trajectoryInfo, nodeCandidateInfo: nodeCandidatesInfo, completion: { [self] statusCode, returnedString, fltInput, inputTraj, inputNodeCandidatesInfo in
            if (!returnedString.contains("timed out")) { stateManager.setNetworkCount(value: 0) }
            if (statusCode == 200) {
                let results = jsonToFineLocatoinTrackingResultFromServerList(jsonString: returnedString)
                let (useResult, fltResult) = ambiguitySolver.selectResult(results: results.1, nodeCandidatesInfo: inputNodeCandidatesInfo)
                
                trajController.updateTrajCompensationArray(result: fltResult)
                trajController.setPastInfo(trajInfo: inputTraj, searchInfo: SearchInfo(), matchedDirection: fltResult.search_direction)
                if (fltResult.index > indexPast) {
                    // 임시
                    displayOutput.serverResult[0] = fltResult.x
                    displayOutput.serverResult[1] = fltResult.y
                    displayOutput.serverResult[2] = fltResult.absolute_heading
                    // 임시
                    
                    if useResult {
                        ambiguitySolver.setIsAmbiguousInDRMode(value: false)
                        stackServerResult(serverResult: fltResult)
                        let resultPhase = phaseController.controlPhase(serverResultArray: serverResultBuffer, drBuffer: unitDRInfoBuffer, UVD_INTERVAL: UVD_INPUT_NUM, TRAJ_LENGTH: USER_TRAJECTORY_LENGTH, INDEX_THRESHOLD: RQ_IDX, inputPhase: fltInput.phase, inputTrajType: TrajType.DR_UNKNOWN, mode: runMode, isVenusMode: stateManager.isVenusMode)
                        
                        // 임시
                        displayOutput.phase = String(OlympusConstants.PHASE_6)
                        displayOutput.indexRx = fltResult.index
                        displayOutput.scc = fltResult.scc
                        displayOutput.resultDirection = fltResult.search_direction
                        // 임시
                        
                        let inputNodeNumber = nodeCandidatesInfo.nodeCandidatesInfo[0].nodeNumber
                        if fltResult.node_number != inputNodeNumber {
                            // 결과가 현재 진행하는 길 위에 있지 않아서 결과를 옮겨야함
                            if (KF.isRunning && resultPhase.0 == OlympusConstants.PHASE_6) {
                                if (!(fltResult.x == 0 && fltResult.y == 0) && !buildingLevelChanger.isDetermineSpot && phaseController.PHASE != OlympusConstants.PHASE_2) {
                                    scCompensation = fltResult.sc_compensation
                                    unitDRGenerator.setScCompensation(value: fltResult.sc_compensation)
                                    if (isPhaseBreak) {
                                        KF.resetKalmanR()
                                        PADDING_VALUE = OlympusConstants.PADDING_VALUE_SMALL
                                        userMaskSendCount = 0
                                        isPhaseBreak = false
                                    }
                                    
                                    var pmFltRsult = fltResult
                                    var propagatedPmFltRsult = fltResult
                                    if (KF.muFlag) {
                                        let isNeedCalDhFromUvd: Bool = false
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
                                        }
                                        
                                        let dxdydh = KF.preProcessForMeasurementUpdate(fltResult: pmFltRsult, unitDRInfoBuffer: unitDRInfoBuffer, mode: runMode, isNeedCalDhFromUvd: isNeedCalDhFromUvd, isResultStraight: isResultStraight)
                                        propagatedPmFltRsult.x = pmFltRsult.x + dxdydh[0]
                                        propagatedPmFltRsult.y = pmFltRsult.y + dxdydh[1]
                                        if (isPossibleHeadingCorrection) {
                                            propagatedPmFltRsult.absolute_heading = pmFltRsult.absolute_heading + dxdydh[2]
                                        } else {
                                            propagatedPmFltRsult.absolute_heading = propagatedPmFltRsult.absolute_heading + dxdydh[2]
                                        }
                                        propagatedPmFltRsult.absolute_heading = compensateHeading(heading: propagatedPmFltRsult.absolute_heading)
                                        
                                        let muResult = KF.measurementUpdate(fltResult: fltResult, pmFltResult: pmFltRsult, propagatedPmFltResult: propagatedPmFltRsult, unitDRInfoBuffer: unitDRInfoBuffer, isPossibleHeadingCorrection: isPossibleHeadingCorrection, PADDING_VALUES: PADDING_VALUES, mode: runMode)
                                        let updatedResult = buildingLevelChanger.updateBuildingAndLevel(fltResult: muResult, currentBuilding: currentBuilding, currentLevel: currentLevel)
                                        currentBuilding = updatedResult.building_name
                                        currentLevel = updatedResult.level_name
//                                        print(getLocalTimeString() + " , (Olympus) Process Phase 5 in DRMode : muResult = \(muResult)")
                                        OlympusPathMatchingCalculator.shared.updateAnchorNodeAfterRecovery(badCaseNodeInfo: inputNodeCandidatesInfo, nodeNumber: fltResult.node_number)
                                        makeTemporalResult(input: updatedResult, isStableMode: false, mustInSameLink: false, updateType: .STABLE, pathMatchingType: .WIDE)
                                    }
                                } else if (fltResult.x == 0 && fltResult.y == 0) {
                                    phaseBreakInPhase4(fltResult: fltResult, isUpdatePhaseBreakResult: false)
                                }
                            } else {
                                phaseBreakInPhase4(fltResult: fltResult, isUpdatePhaseBreakResult: true)
                            }
                        } else {
                            displayOutput.phase = String(OlympusConstants.PHASE_6) + " // Correct"
                        }
                    } else {
                        if !results.1.flt_outputs.isEmpty {
                            let bestResult = ambiguitySolver.selectBestResult(results: results.1)
                            if bestResult.scc < OlympusConstants.PHASE_BREAK_SCC_DR {
                                phaseBreakInPhase4(fltResult: bestResult, isUpdatePhaseBreakResult: true)
                            }
                        }
                    }
                    indexPast = fltResult.index
                }
                preServerResultMobileTime = fltResult.mobile_time
            }
        })
    }
    
    private func processPhase6(currentTime: Int, mode: String, trajectoryInfo: [TrajectoryInfo], stableInfo: StableInfo, nodeCandidatesInfo: NodeCandidateInfo) {
        if (mode == OlympusConstants.MODE_PDR) {
            self.currentLevel = removeLevelDirectionString(levelName: self.currentLevel)
        }
        var levelArray = [self.currentLevel]
        let isInLevelChangeArea = buildingLevelChanger.checkInLevelChangeArea(result: self.olympusResult, mode: mode)
        if (isInLevelChangeArea) {
            levelArray = buildingLevelChanger.makeLevelChangeArray(buildingName: self.currentBuilding, levelName: self.currentLevel, buildingLevel: buildingLevelChanger.buildingsAndLevels)
        }
        displayOutput.phase = String(OlympusConstants.PHASE_6)
        displayOutput.searchDirection = []
        var input = FineLocationTracking(user_id: self.user_id, mobile_time: currentTime, sector_id: self.sector_id, operating_system: OlympusConstants.OPERATING_SYSTEM, building_name: self.currentBuilding, level_name_list: levelArray, phase: 6, search_range: [], search_direction_list: [], normalization_scale: OlympusConstants.NORMALIZATION_SCALE, device_min_rss: Int(OlympusConstants.DEVICE_MIN_RSSI), sc_compensation_list: [1.01], tail_index: stableInfo.tail_index, head_section_number: stableInfo.head_section_number, node_number_list: stableInfo.node_number_list, node_index: 0, retry: false)
        ambiguitySolver.setIsAmbiguous(value: false)
//        print(getLocalTimeString() + " , (Olympus) Request Phase 6 : input = \(input)")
        stateManager.setNetworkCount(value: stateManager.networkCount+1)
        if (REGION_NAME != "Korea" && self.deviceModel == "iPhone SE (2nd generation)") { input.normalization_scale = 1.01 }
        OlympusNetworkManager.shared.postStableFLT(url: CALC_FLT_URL, input: input, userTraj: trajectoryInfo, nodeCandidateInfo: nodeCandidatesInfo, completion: { [self] statusCode, returnedString, fltInput, inputTraj, inputNodeCandidatesInfo in
            if (!returnedString.contains("timed out")) { stateManager.setNetworkCount(value: 0) }
            if (statusCode == 200) {
                let results = jsonToFineLocatoinTrackingResultFromServerList(jsonString: returnedString)
                let (useResult, fltResult) = ambiguitySolver.selectResult(results: results.1, nodeCandidatesInfo: inputNodeCandidatesInfo)
//                print(getLocalTimeString() + " , (Olympus) Request Phase 6 : result = \(fltResult)")
                trajController.updateTrajCompensationArray(result: fltResult)
                trajController.setPastInfo(trajInfo: inputTraj, searchInfo: SearchInfo(), matchedDirection: fltResult.search_direction)
                if (fltResult.index > indexPast && useResult) {
                    // 임시
                    displayOutput.serverResult[0] = fltResult.x
                    displayOutput.serverResult[1] = fltResult.y
                    displayOutput.serverResult[2] = fltResult.absolute_heading
                    // 임시
                    
                    stackServerResult(serverResult: fltResult)
                    let resultPhase = phaseController.controlPhase(serverResultArray: serverResultBuffer, drBuffer: unitDRInfoBuffer, UVD_INTERVAL: UVD_INPUT_NUM, TRAJ_LENGTH: USER_TRAJECTORY_LENGTH, INDEX_THRESHOLD: RQ_IDX, inputPhase: fltInput.phase, inputTrajType: TrajType.DR_UNKNOWN, mode: runMode, isVenusMode: stateManager.isVenusMode)
                    // 임시
                    displayOutput.phase = String(resultPhase.0)
                    displayOutput.indexRx = fltResult.index
                    displayOutput.scc = fltResult.scc
                    displayOutput.resultDirection = fltResult.search_direction
                    // 임시
                    
                    if (KF.isRunning && resultPhase.0 == OlympusConstants.PHASE_6) {
                        if (!(fltResult.x == 0 && fltResult.y == 0) && !buildingLevelChanger.isDetermineSpot && phaseController.PHASE != OlympusConstants.PHASE_2) {
                            scCompensation = fltResult.sc_compensation
                            unitDRGenerator.setScCompensation(value: fltResult.sc_compensation)
                            if (isPhaseBreak) {
                                KF.resetKalmanR()
                                PADDING_VALUE = OlympusConstants.PADDING_VALUE_SMALL
                                userMaskSendCount = 0
                                isPhaseBreak = false
                            }
                            
                            if (fltResult.scc < OlympusConstants.PHASE5_RECOVERY_SCC && runMode == OlympusConstants.MODE_PDR) {
                                isInRecoveryProcess = true
                                processRecovery(currentTime: getCurrentTimeInMilliseconds(), mode: mode, fltInput: input, fltResult: fltResult, trajectoryInfo: trajectoryInfo, inputNodeCandidateInfo: inputNodeCandidatesInfo)
                            } else {
                                var pmFltRsult = fltResult
                                var propagatedPmFltRsult = fltResult
//                                unitDRGenerator.calAccBias(unitDRInfoBuffer: OlympusPathMatchingCalculator.shared.getUnitDRInfoBuffer(), resultIndex: fltResult.index, scCompensation: fltResult.sc_compensation)
//                                let scVelocityResult = OlympusPathMatchingCalculator.shared.calScVelocity(resultIndex: fltResult.index, scCompensation: fltResult.sc_compensation)
                                if (KF.muFlag) {
                                    let isNeedCalDhFromUvd: Bool = false
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
                                    }
                                    
                                    let dxdydh = KF.preProcessForMeasurementUpdate(fltResult: pmFltRsult, unitDRInfoBuffer: unitDRInfoBuffer, mode: runMode, isNeedCalDhFromUvd: isNeedCalDhFromUvd, isResultStraight: isResultStraight)
                                    propagatedPmFltRsult.x = pmFltRsult.x + dxdydh[0]
                                    propagatedPmFltRsult.y = pmFltRsult.y + dxdydh[1]
                                    if (isPossibleHeadingCorrection) {
                                        propagatedPmFltRsult.absolute_heading = pmFltRsult.absolute_heading + dxdydh[2]
                                    } else {
                                        propagatedPmFltRsult.absolute_heading = propagatedPmFltRsult.absolute_heading + dxdydh[2]
                                    }
                                    propagatedPmFltRsult.absolute_heading = compensateHeading(heading: propagatedPmFltRsult.absolute_heading)
                                    
//                                    print(getLocalTimeString() + " , (Olympus) Process Phase 6 : propagatedPmFltRsult = \(propagatedPmFltRsult)")
                                    let muResult = KF.measurementUpdate(fltResult: fltResult, pmFltResult: pmFltRsult, propagatedPmFltResult: propagatedPmFltRsult, unitDRInfoBuffer: unitDRInfoBuffer, isPossibleHeadingCorrection: isPossibleHeadingCorrection, PADDING_VALUES: PADDING_VALUES, mode: runMode)
                                    let updatedResult = buildingLevelChanger.updateBuildingAndLevel(fltResult: muResult, currentBuilding: currentBuilding, currentLevel: currentLevel)
                                    currentBuilding = updatedResult.building_name
                                    currentLevel = updatedResult.level_name
//                                    print(getLocalTimeString() + " , (Olympus) Process Phase 6 : muResult Final = \(muResult)")
                                    makeTemporalResult(input: updatedResult, isStableMode: false, mustInSameLink: false, updateType: .STABLE, pathMatchingType: .WIDE)
                                }
                            }
                        } else if (fltResult.x == 0 && fltResult.y == 0) {
                            phaseBreakInPhase4(fltResult: fltResult, isUpdatePhaseBreakResult: false)
                        }
                    } else {
                        phaseBreakInPhase4(fltResult: fltResult, isUpdatePhaseBreakResult: true)
                    }
                    indexPast = fltResult.index
                } else {
                    if (fltResult.x == 0 && fltResult.y == 0) {
                        phaseBreakInPhase4(fltResult: fltResult, isUpdatePhaseBreakResult: false)
                    }
                }
                preServerResultMobileTime = fltResult.mobile_time
                self.isInRecoveryProcess = false
            } else {
                self.isInRecoveryProcess = false
//                let msg: String = getLocalTimeString() + " , (Olympus) Error : \(statusCode) Fail to request indoor position in Phase 6 // tail_index = \(fltInput.tail_index)"
//                print(msg)
            }
        })
    }
    
    private func processRecovery(currentTime: Int, mode: String, fltInput: FineLocationTracking, fltResult: FineLocationTrackingFromServer, trajectoryInfo: [TrajectoryInfo], inputNodeCandidateInfo: NodeCandidateInfo) {
        var pathType: Int = 1
        if (mode == OlympusConstants.MODE_PDR) { pathType = 0 }
        var recoveryInput = fltInput
        recoveryInput.mobile_time = currentTime
        recoveryInput.retry = true
        let recoveryNodeCandidates = OlympusPathMatchingCalculator.shared.getAnchorNodeCandidatesForRecovery(fltResult: fltResult, inputNodeCandidateInfo: inputNodeCandidateInfo, pathType: pathType)
        let nodeCandidatesInfo = recoveryNodeCandidates.nodeCandidatesInfo
        if (nodeCandidatesInfo.isEmpty) {
//            print(getLocalTimeString() + " , (Olympus) Request Recovery : nodeCandidatesInfo is Empty")
            phaseBreakInPhase4(fltResult: fltResult, isUpdatePhaseBreakResult: false)
        } else {
            displayOutput.phase = "\(OlympusConstants.PHASE_6) // Recovery"
            displayOutput.searchDirection = []
            stateManager.setNetworkCount(value: stateManager.networkCount+1)
            
            var nodeNumberCandidates = [Int]()
            for item in nodeCandidatesInfo {
                nodeNumberCandidates.append(item.nodeNumber)
            }
            recoveryInput.node_number_list = nodeNumberCandidates
            
            if (REGION_NAME != "Korea" && self.deviceModel == "iPhone SE (2nd generation)") { recoveryInput.normalization_scale = 1.01 }
//            print(getLocalTimeString() + " , (Olympus) Request Recovery : recoveryInput = \(recoveryInput))")
            OlympusNetworkManager.shared.postRecoveryFLT(url: CALC_FLT_URL, input: recoveryInput, userTraj: trajectoryInfo, nodeCandidateInfo: recoveryNodeCandidates, preFltResult: fltResult, completion: { [self] statusCode, returnedString, fltInput, inputTraj, inputNodeCandidateInfo, preFltResult in
                if (!returnedString.contains("timed out")) { stateManager.setNetworkCount(value: 0) }
                if (statusCode == 200) {
                    let results = jsonToFineLocatoinTrackingResultFromServerList(jsonString: returnedString)
                    let result = results.1.flt_outputs
                    var fltResult = result.isEmpty ? FineLocationTrackingFromServer() : result[0]
//                    print(getLocalTimeString() + " , (Olympus) Request Phase Recovery : result = \(fltResult)")
                    var isUsePreResult: Bool = false
                    if (fltResult.scc < preFltResult.scc) {
                        fltResult = preFltResult
//                        print(getLocalTimeString() + " , (Olympus) processRecovery : Use Previous Result")
                        isUsePreResult = true
                    }
                    
                    trajController.setPastInfo(trajInfo: inputTraj, searchInfo: SearchInfo(), matchedDirection: fltResult.search_direction)
                    if (fltResult.index >= indexPast) {
                        // 임시
                        displayOutput.serverResult[0] = fltResult.x
                        displayOutput.serverResult[1] = fltResult.y
                        displayOutput.serverResult[2] = fltResult.absolute_heading
                        // 임시
                        
                        stackServerResult(serverResult: fltResult)
                        let resultPhase = phaseController.controlPhase(serverResultArray: serverResultBuffer, drBuffer: unitDRInfoBuffer, UVD_INTERVAL: UVD_INPUT_NUM, TRAJ_LENGTH: USER_TRAJECTORY_LENGTH, INDEX_THRESHOLD: RQ_IDX, inputPhase: fltInput.phase, inputTrajType: TrajType.DR_UNKNOWN, mode: runMode, isVenusMode: stateManager.isVenusMode)
//                        print(getLocalTimeString() + " , (Olympus) processRecovery : resultPhase = \(resultPhase)")
//                        print(getLocalTimeString() + " , (Olympus) processRecovery : fltResult = \(fltResult)")
                        // 임시
                        displayOutput.phase = String(resultPhase.0)
                        // 임시
                        
                        if (KF.isRunning && resultPhase.0 == OlympusConstants.PHASE_6) {
                            if (!(fltResult.x == 0 && fltResult.y == 0) && !buildingLevelChanger.isDetermineSpot && phaseController.PHASE != OlympusConstants.PHASE_2) {
                                scCompensation = fltResult.sc_compensation
                                unitDRGenerator.setScCompensation(value: fltResult.sc_compensation)
                                // 임시
                                displayOutput.indexRx = fltResult.index
                                displayOutput.scc = fltResult.scc
                                displayOutput.resultDirection = fltResult.search_direction
                                // 임시
                                
                                if (isPhaseBreak) {
                                    KF.resetKalmanR()
                                    PADDING_VALUE = OlympusConstants.PADDING_VALUE_SMALL
                                    userMaskSendCount = 0
                                    isPhaseBreak = false
                                }
                                
                                var pmFltRsult = fltResult
                                var propagatedPmFltRsult = fltResult
                                if (KF.muFlag) {
                                    let isNeedCalDhFromUvd: Bool = true
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
                                    }
                                    
                                    let dxdydh = KF.preProcessForMeasurementUpdate(fltResult: pmFltRsult, unitDRInfoBuffer: unitDRInfoBuffer, mode: runMode, isNeedCalDhFromUvd: isNeedCalDhFromUvd, isResultStraight: isResultStraight)
                                    propagatedPmFltRsult.x = pmFltRsult.x + dxdydh[0]
                                    propagatedPmFltRsult.y = pmFltRsult.y + dxdydh[1]
                                    if (isPossibleHeadingCorrection) {
                                        propagatedPmFltRsult.absolute_heading = pmFltRsult.absolute_heading + dxdydh[2]
                                    } else {
                                        propagatedPmFltRsult.absolute_heading = propagatedPmFltRsult.absolute_heading + dxdydh[2]
                                    }
                                    propagatedPmFltRsult.absolute_heading = compensateHeading(heading: propagatedPmFltRsult.absolute_heading)
                                    
                                    let muResult = KF.measurementUpdate(fltResult: fltResult, pmFltResult: pmFltRsult, propagatedPmFltResult: propagatedPmFltRsult, unitDRInfoBuffer: unitDRInfoBuffer, isPossibleHeadingCorrection: isPossibleHeadingCorrection, PADDING_VALUES: PADDING_VALUES, mode: runMode)
                                    let updatedResult = buildingLevelChanger.updateBuildingAndLevel(fltResult: muResult, currentBuilding: currentBuilding, currentLevel: currentLevel)
                                    currentBuilding = updatedResult.building_name
                                    currentLevel = updatedResult.level_name
                                    
                                    if (!isUsePreResult) {
                                        OlympusPathMatchingCalculator.shared.updateAnchorNodeAfterRecovery(badCaseNodeInfo: inputNodeCandidateInfo, nodeNumber: fltResult.node_number)
                                    }
                                    makeTemporalResult(input: updatedResult, isStableMode: false, mustInSameLink: false, updateType: .NONE, pathMatchingType: .WIDE)
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
                    self.isInRecoveryProcess = false
//                    let msg: String = getLocalTimeString() + " , (Olympus) Error : \(statusCode) Fail to request indoor position in Phase 5 recovery"
//                    print(msg)
                }
            })
        }
    }
    
    func outputTimerUpdate() {
        // Run every 0.2s
        let validInfo = checkSolutionValidity(reportFlag: self.pastReportFlag, reportTime: self.pastReportTime, isIndoor: stateManager.isIndoor)
        if (isStartRouteTrack) {
            olympusResult = temporalToOlympus(fromServer: routeTrackResult, phase: 4, velocity: olympusVelocity, mode: runMode, ble_only_position: stateManager.isVenusMode, isIndoor: stateManager.isIndoor, validity: validInfo.0, validity_flag: validInfo.1)
        } else {
            olympusResult = temporalToOlympus(fromServer: temporalResult, phase: phaseController.PHASE, velocity: olympusVelocity, mode: runMode, ble_only_position: stateManager.isVenusMode, isIndoor: stateManager.isIndoor, validity: validInfo.0, validity_flag: validInfo.1)
        }
        if isOlympusResultValid(result: self.olympusResult) {
            self.olympusResult.absolute_heading = compensateHeading(heading: self.olympusResult.absolute_heading)
            self.olympusResult.mobile_time = getCurrentTimeInMilliseconds()
            self.tracking(input: self.olympusResult)
        }
    }
    
    private func isOlympusResultValid(result: FineLocationTrackingResult) -> Bool {
        if result.building_name == "" || result.level_name == "" {
            return false
        } else if result.x == 0 && result.y == 0 {
            return false
        } else {
            return true
        }
    }
    
    func makeTemporalResult(input: FineLocationTrackingFromServer, isStableMode: Bool, mustInSameLink: Bool, updateType: UpdateNodeLinkType, pathMatchingType: PathMatchingType) {
        var result = input
        let resultIndex = unitDRInfoIndex
        let resultMobileTime = getCurrentTimeInMilliseconds()
        result.index = resultIndex
        var correctedXYH = [Double]()
        preTemporalResult.index = resultIndex
        
        var isUseHeading: Bool = false
        if ((result.x != 0 || result.y != 0) && result.building_name != "" && result.level_name != "") {
            let buildingName: String = result.building_name
            let levelName: String = removeLevelDirectionString(levelName: result.level_name)
            result.level_name = levelName
            var temporalResultHeading: Double = result.absolute_heading
            var pathTypeForNodeAndLink = 0
            var isPmFailed: Bool = false
            if (runMode == OlympusConstants.MODE_PDR) {
                pathTypeForNodeAndLink = 0
                var headingRange = OlympusConstants.HEADING_RANGE
                let paddings = paddingValues
                if (pathMatchingType == .NARROW) {
                    isUseHeading = true // true
                    headingRange -= 10
                }
                
                let correctedResult = OlympusPathMatchingCalculator.shared.pathMatching(building: buildingName, level: levelName, x: result.x, y: result.y, heading: result.absolute_heading, HEADING_RANGE: headingRange, isUseHeading: isUseHeading, pathType: 0, PADDING_VALUES: paddings)
                if (correctedResult.isSuccess) {
//                    print(getLocalTimeString() + " , (Olympus) Path-Matching : correctedResult = \(result.x), \(result.y), \(result.absolute_heading)")
                    result.absolute_heading = correctedResult.xyhs[2]
//                    if result.absolute_heading == 0 || result.absolute_heading == 180 {
//                        result.y = correctedResult.xyhs[1]
//                    } else if result.absolute_heading == 90 || result.absolute_heading == 270 {
//                        result.x = correctedResult.xyhs[0]
//                    } else {
//                        result.x = correctedResult.xyhs[0]
//                        result.y = correctedResult.xyhs[1]
//                    }
                    result.x = correctedResult.xyhs[0]
                    result.y = correctedResult.xyhs[1]
                    temporalResultHeading = correctedResult.bestHeading
                    self.curTemporalResultHeading = correctedResult.bestHeading
                } else {
                    let key: String = "\(buildingName)_\(levelName)"
                    
                    var ppIsLoaded: Bool = true
                    if let isLoaded: Bool = OlympusPathMatchingCalculator.shared.PpIsLoaded[key] { ppIsLoaded = isLoaded }
                    if let _ = OlympusPathMatchingCalculator.shared.PpCoord[key] {
                        OlympusPathMatchingCalculator.shared.PpIsLoaded[key] = true
                    } else {
                        if (!ppIsLoaded) {
                            OlympusPathMatchingCalculator.shared.loadPathPixel(sector_id: sector_id, PathPixelURL: OlympusPathMatchingCalculator.shared.PpURL)
                        }
                    }
                    isPmFailed = true
                }
                isUseHeading = false
            } else {
                pathTypeForNodeAndLink = 1
                isUseHeading = stateManager.isVenusMode ? false : true
                let paddings = levelName == "B0" ? OlympusConstants.PADDING_VALUES : paddingValues
                let correctedResult = OlympusPathMatchingCalculator.shared.pathMatching(building: buildingName, level: levelName, x: result.x, y: result.y, heading: result.absolute_heading, HEADING_RANGE: OlympusConstants.HEADING_RANGE, isUseHeading: isUseHeading, pathType: 1, PADDING_VALUES: paddings)
//                print(getLocalTimeString() + " , (Olympus) Path-Matching : correctedResult (before) // xyh = [\(result.x) , \(result.y) , \(result.absolute_heading)]")
//                print(getLocalTimeString() + " , (Olympus) Path-Matching : correctedResult // isUseHeading = \(isUseHeading) // mustInSameLink = \(mustInSameLink) // updateType = \(updateType) // paddings = \(paddings)")
//                print(getLocalTimeString() + " , (Olympus) Path-Matching : correctedResult (after) // success = \(correctedResult.isSuccess) // xyh = [\(correctedResult.xyhs[0]) , \(correctedResult.xyhs[1]) , \(correctedResult.xyhs[2])]")
                if (correctedResult.isSuccess) {
                    unitDRGenerator.setVelocityScale(scale: correctedResult.xyhs[3])
                    result.x = correctedResult.xyhs[0]
                    result.y = correctedResult.xyhs[1]
                    result.absolute_heading = correctedResult.xyhs[2]
                    temporalResultHeading = correctedResult.bestHeading
                    self.curTemporalResultHeading = correctedResult.bestHeading
                } else {
                    let key: String = "\(buildingName)_\(levelName)"
                    var ppIsLoaded: Bool = true
                    if let isLoaded: Bool = OlympusPathMatchingCalculator.shared.PpIsLoaded[key] { ppIsLoaded = isLoaded }
                    if let _ = OlympusPathMatchingCalculator.shared.PpCoord[key] {
                        OlympusPathMatchingCalculator.shared.PpIsLoaded[key] = true
                    } else {
                        if (!ppIsLoaded) {
                            OlympusPathMatchingCalculator.shared.loadPathPixel(sector_id: sector_id, PathPixelURL: OlympusPathMatchingCalculator.shared.PpURL)
                        }
                    }
                    isPmFailed = true
                }
            }
//            print(getLocalTimeString() + " , (Olympus) Path-Matching : index = \(result.index) // linkDir = \(KF.linkDirections) // linkCoord = \(KF.linkCoord)")
            if (mustInSameLink && levelName != "B0") {
                let directions = KF.linkDirections
                let linkCoord = KF.linkCoord
                if (directions.count == 2) {
                    let MARGIN: Double = 30
                    if (directions.contains(0) && directions.contains(180)) {
                        // 이전 y축 값과 현재 y값은 같아야 함
                        let diffHeading = compensateHeading(heading: abs(result.absolute_heading - directions[0]))
//                        print(getLocalTimeString() + " , (Olympus) Path-Matching : Must In Same Link : (1) diffHeading = \(diffHeading)")
                        if !((diffHeading > 90-MARGIN && diffHeading <= 90+MARGIN) || (diffHeading > 270-MARGIN && diffHeading <= 270+MARGIN)) {
                            result.y = linkCoord[1]
//                            print(getLocalTimeString() + " , (Olympus) Path-Matching : Must In Same Link : y축")
                        }
                        
                    } else if (directions.contains(90) && directions.contains(270)) {
                        // 이전 x축 값과 현재 x축 값은 같아야 함
                        let diffHeading = compensateHeading(heading: abs(result.absolute_heading - directions[0]))
//                        print(getLocalTimeString() + " , (Olympus) Path-Matching : Must In Same Link : (2) diffHeading = \(diffHeading)")
                        if !((diffHeading > 90-MARGIN && diffHeading <= 90+MARGIN) || (diffHeading > 270-MARGIN && diffHeading <= 270+MARGIN)) {
                            result.x = linkCoord[0]
//                            print(getLocalTimeString() + " , (Olympus) Path-Matching : Must In Same Link : x축")
                        }
                    }
                }
            }
            
//            print(getLocalTimeString() + " , (Olympus) Path-Matching : isUseHeading = \(isUseHeading) // isStableMode = \(isStableMode) // isPmFailed = \(isPmFailed)")
            if (isUseHeading && isStableMode && !self.isPhaseBreak) {
                let diffX = result.x - temporalResult.x
                let diffY = result.y - temporalResult.y
                let diffNorm = sqrt(diffX*diffX + diffY*diffY)
                if diffNorm >= 2 {
                    currentTuResult.x = result.x
                    currentTuResult.y = result.y
                    KF.updateTuResult(x: result.x, y: result.y)
                    KF.updateTuResultNow(result: currentTuResult)
                }
            }
            
            if (isPmFailed) {
                self.displayOutput.isPmSuccess = false
                if (KF.isRunning) {
                    result = self.preTemporalResult
                    let correctedResult = OlympusPathMatchingCalculator.shared.pathMatching(building: buildingName, level: levelName, x: result.x, y: result.y, heading: result.absolute_heading, HEADING_RANGE: OlympusConstants.HEADING_RANGE, isUseHeading: false, pathType: pathTypeForNodeAndLink, PADDING_VALUES: OlympusConstants.PADDING_VALUES)
                    if correctedResult.isSuccess {
                        result.x = correctedResult.xyhs[0]
                        result.y = correctedResult.xyhs[1]
                    }
                }
            } else {
                self.displayOutput.isPmSuccess = true
            }
            
            if (KF.isRunning) {
//                print(getLocalTimeString() + " , (Olympus) Path-Matching : before updateNodeAndLinkInfo // result = \(result.x), \(result.y), \(result.absolute_heading) // updateType = \(updateType)")
                OlympusPathMatchingCalculator.shared.updateNodeAndLinkInfo(uvdIndex: resultIndex, currentResult: result, currentResultHeading: self.curTemporalResultHeading, pastResult: preTemporalResult, pastResultHeading: preTemporalResultHeading, pathType: pathTypeForNodeAndLink, updateType: updateType)
                KF.setLinkInfo(coord: OlympusPathMatchingCalculator.shared.linkCoord, directions: OlympusPathMatchingCalculator.shared.linkDirections)
                self.paddingValues = OlympusPathMatchingCalculator.shared.getPaddingValues(mode: runMode, isPhaseBreak: isPhaseBreak, PADDING_VALUE: PADDING_VALUE)
            }
            
            let data = UserMask(user_id: self.user_id, mobile_time: resultMobileTime, section_number: sectionController.sectionNumber, index: resultIndex, x: Int(result.x), y: Int(result.y), absolute_heading: result.absolute_heading)
            stackUserMaskPathTrajMatching(data: data)
            
            if !self.isDRMode {
                self.isDRMode = buildingLevelChanger.checkInSectorDRModeArea(fltResult: result, passedNodeInfo: OlympusPathMatchingCalculator.shared.currentPassedNodeInfo)
            } else {
                self.isDRMode = buildingLevelChanger.checkOutSectorDRModeArea(fltResult: result, anchorNodeInfo: OlympusPathMatchingCalculator.shared.getCurrentAnchorNodeInfo())
                if !self.isDRMode {
                    isDRModeRqInfoSaved = false
                    drModeRequestInfo = DRModeRequestInfo(trajectoryInfo: [], stableInfo: StableInfo(tail_index: -1, head_section_number: 0, node_number_list: []), nodeCandidatesInfo: NodeCandidateInfo(isPhaseBreak: false, nodeCandidatesInfo: []), prevNodeInfo: PassedNodeInfo(nodeNumber: -1, nodeCoord: [], nodeHeadings: [], matchedIndex: 0, userHeading: 0))
                }
            }
            
            if (isStableMode) {
                if (stableModeInitFlag) {
                    sectionController.setInitialAnchorTailIndex(value: result.index)
                    stableModeInitFlag = false
                }
                
                self.inputUserMask.append(data)
                if ((self.inputUserMask.count) >= OlympusConstants.USER_MASK_INPUT_NUM) {
                    OlympusNetworkManager.shared.postUserMask(url: REC_UMD_URL, input: self.inputUserMask, completion: { [self] statusCode, returnedString, inputUserMask in
                        if (statusCode == 200) {
                            userMaskSendCount += 1
                        } else {
                            let localTime = getLocalTimeString()
                            let msg: String = localTime + " , (Olympus) Error : UserMask \(statusCode) // " + returnedString
                            print(msg)
                        }
                    })
                    inputUserMask = []
                }
                stackUserMask(data: data)
                stackUserMaskForDisplay(data: data)
                if (runMode == OlympusConstants.MODE_PDR) {
                    self.isNeedPathTrajMatching = checkIsNeedPathTrajMatching(userMaskBuffer: self.userMaskBuffer)
                } else {
                    if self.isDRMode {
                        if(checkIsBadCase(userMaskBuffer: self.userMaskBuffer) && !self.isPhaseBreak) {
                            if buildingLevelChanger.checkCoordInSectorDRModeArea(fltResult: result) {
                                self.phaseBreakInPhase4(fltResult: result, isUpdatePhaseBreakResult: true)
                            }
                        }
                    }
                }
            }
            
            self.temporalResult = result
            self.preTemporalResult = result
            self.preTemporalResultHeading = temporalResultHeading
//            KF.updateTuResult(x: result.x, y: result.y)
//            KF.updateTuResultNow(result: result)
        }
    }
    
    private func setTemporalResult(coord: [Double]) {
        self.temporalResult.x = coord[0]
        self.temporalResult.y = coord[1]
        
        self.preTemporalResult.x = coord[0]
        self.preTemporalResult.y = coord[1]
    }
    
    func osrTimerUpdate() {
        if !isStartRouteTrack {
            buildingLevelChanger.estimateBuildingLevel(user_id: self.user_id, mode: self.runMode, phase: phaseController.PHASE, isGetFirstResponse: stateManager.isGetFirstResponse, networkStatus: self.networkStatus, isDRMode: self.isDRMode, passedNodes: OlympusPathMatchingCalculator.shared.getPassedNodeInfoBuffer(), result: self.olympusResult, currentBuilding: self.currentBuilding, currentLevel: self.currentLevel, currentEntrance: routeTracker.currentEntrance)
        }
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
    
    private func stackUnitDRInfoForPhase4(isNeedClear: Bool) {
        if (isNeedClear) {
            self.unitDRInfoBufferForPhase4 = []
            self.isNeedClearBuffer = false
        }
        self.unitDRInfoBufferForPhase4.append(self.unitDRInfo)
    }
    
    private func stackUserMask(data: UserMask) {
        if (self.userMaskBuffer.count > 0) {
            let lastIndex = self.userMaskBuffer[self.userMaskBuffer.count-1].index
            let currentIndex = data.index
            
            if (lastIndex == currentIndex) {
                self.userMaskBuffer.remove(at: self.userMaskBuffer.count-1)
            }
        }
        
        self.userMaskBuffer.append(data)
        if (self.userMaskBuffer.count > OlympusConstants.DR_INFO_BUFFER_SIZE) {
            self.userMaskBuffer.remove(at: 0)
        }
    }
    
    private func stackUserMaskPathTrajMatching(data: UserMask) {
        if (self.userMaskBufferPathTrajMatching.count > 0) {
            let lastIndex = self.userMaskBufferPathTrajMatching[self.userMaskBufferPathTrajMatching.count-1].index
            let currentIndex = data.index
            
            if (lastIndex == currentIndex) {
                self.userMaskBufferPathTrajMatching.remove(at: self.userMaskBufferPathTrajMatching.count-1)
            }
        }
        
        self.userMaskBufferPathTrajMatching.append(data)
        if (self.userMaskBufferPathTrajMatching.count > OlympusConstants.DR_INFO_BUFFER_SIZE) {
            self.userMaskBufferPathTrajMatching.remove(at: 0)
        }
    }
    
    private func stackUserMaskForDisplay(data: UserMask) {
        if (self.userMaskBufferDisplay.count > 0) {
            let lastIndex = self.userMaskBufferDisplay[self.userMaskBufferDisplay.count-1].index
            let currentIndex = data.index
            
            if (lastIndex == currentIndex) {
                self.userMaskBufferDisplay.remove(at: self.userMaskBufferDisplay.count-1)
            }
        }
        
        self.userMaskBufferDisplay.append(data)
        if (self.userMaskBufferDisplay.count > 300) {
            self.userMaskBufferDisplay.remove(at: 0)
        }
    }
    
    private func checkIsNeedPathTrajMatching(userMaskBuffer: [UserMask]) -> IsNeedPathTrajMatching {
        let th = OlympusConstants.SAME_COORD_THRESHOLD
        let straightTh = OlympusConstants.STRAIGHT_SAME_COORD_THRESHOLD
        
        var isNeedPathTrajMatching: Bool = false
        var isNeedPathTrajMatchingInStragiht: Bool = false

        if (isInRecoveryProcess) {
            isInRecoveryProcess = false
            recoveryIndex = unitDRInfoIndex
            return IsNeedPathTrajMatching(turn: false, straight: false)
        }
        
        if userMaskBuffer.count >= th {
            var diffX: Int = 0
            var diffY: Int = 0
            var checkCount: Int = 0
            for i in userMaskBuffer.count-(th-1)..<userMaskBuffer.count {
                if (userMaskBuffer[i].index) > recoveryIndex {
                    diffX += abs(userMaskBuffer[i-1].x - userMaskBuffer[i].x)
                    diffY += abs(userMaskBuffer[i-1].y - userMaskBuffer[i].y)
                    checkCount += 1
                }
            }
            if diffX == 0 && diffY == 0 && checkCount >= (th-1) {
                isNeedPathTrajMatching = true
            }
        }
        
        if userMaskBuffer.count >= straightTh {
            var diffX: Int = 0
            var diffY: Int = 0
            var checkCount: Int = 0
            for i in userMaskBuffer.count-(straightTh-1)..<userMaskBuffer.count {
                if (userMaskBuffer[i].index) > recoveryIndex {
                    diffX += abs(userMaskBuffer[i-1].x - userMaskBuffer[i].x)
                    diffY += abs(userMaskBuffer[i-1].y - userMaskBuffer[i].y)
                    checkCount += 1
                }
            }
            if diffX == 0 && diffY == 0 && checkCount >= (th-1) {
                isNeedPathTrajMatchingInStragiht = true
            }
        }
        
        return IsNeedPathTrajMatching(turn: isNeedPathTrajMatching, straight: isNeedPathTrajMatchingInStragiht)
    }
    
    private func checkIsBadCase(userMaskBuffer: [UserMask]) -> Bool {
        var isBadCase: Bool = false
        
        let th = OlympusConstants.SAME_COORD_THRESHOLD*8
        
        if userMaskBuffer.count >= th {
            var diffX: Int = 0
            var diffY: Int = 0
            var checkCount: Int = 0
            for i in userMaskBuffer.count-(th-1)..<userMaskBuffer.count {
                if (userMaskBuffer[i].index) > recoveryIndex {
                    diffX += abs(userMaskBuffer[i-1].x - userMaskBuffer[i].x)
                    diffY += abs(userMaskBuffer[i-1].y - userMaskBuffer[i].y)
                    checkCount += 1
                }
            }
            if diffX == 0 && diffY == 0 && checkCount >= (th-1) {
                isBadCase = true
            }
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
    
    private func getUnitDRInfoFromUvdIndex(from unitDRInfoBuffer: [UnitDRInfo], uvdIndex: Int) -> [UnitDRInfo] {
        var result: [UnitDRInfo] = []
        for i in 0..<unitDRInfoBuffer.count {
            if unitDRInfoBuffer[i].index >= uvdIndex {
                if (result.isEmpty) {
                    if (unitDRInfoBuffer[i].index != uvdIndex) {
                        return result
                    }
                }
                result.append(unitDRInfoBuffer[i])
            }
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
    
    private func stackDiffHeadingBuffer(diffHeading: Double) {
        self.diffHeadingBuffer.append(abs(diffHeading))
        if (self.diffHeadingBuffer.count > 3) {
            self.diffHeadingBuffer.remove(at: 0)
        }
    }
    
    private func getHeadingVar(of values: [Double]) -> Double {
        var diffHeadingVar: Double = 0
        
        let mean = values.reduce(0, +) / Double(values.count)
        let squaredDifferences = values.map { ($0 - mean) * ($0 - mean) }
        let sumOfSquaredDifferences = squaredDifferences.reduce(0, +)
        
        diffHeadingVar = sumOfSquaredDifferences / Double(values.count)
        
        return diffHeadingVar > 22 ? 22 : diffHeadingVar
    }
    
    private func stackHeadingForCheckCorrection() {
        self.headingBufferForCorrection.append(self.unitDRInfo.heading)
        if (self.headingBufferForCorrection.count > OlympusConstants.HEADING_BUFFER_SIZE) {
            self.headingBufferForCorrection.remove(at: 0)
        }
    }
    
    private func phaseBreakInPhase4(fltResult: FineLocationTrackingFromServer, isUpdatePhaseBreakResult: Bool) {
        displayOutput.phase = "1"
        if (KF.isRunning) {
            KF.minimizeKalmanR()
            PADDING_VALUE = OlympusConstants.PADDING_VALUE_LARGE
            if (isUpdatePhaseBreakResult) {
                phaseBreakResult = fltResult
            }
        }
        ambiguitySolver.setIsAmbiguous(value: false)
        ambiguitySolver.setIsAmbiguousInDRMode(value: false)
        trajController.setIsNeedTrajCheck(flag: true)
        NotificationCenter.default.post(name: .phaseChanged, object: nil, userInfo: ["phase": OlympusConstants.PHASE_1])
        isInRecoveryProcess = false
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
            self.backgroundUpTimer!.setEventHandler { [weak self] in
                guard let self = self else { return }
                self.outputTimerUpdate()
            }
            self.backgroundUpTimer!.resume()
        }
            
        if (self.backgroundUvTimer == nil) {
            self.backgroundUvTimer = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .background))
            self.backgroundUvTimer!.schedule(deadline: .now(), repeating: OlympusConstants.UVD_INTERVAL)
            self.backgroundUvTimer!.setEventHandler { [weak self] in
                guard let self = self else { return }
                self.userVelocityTimerUpdate()
            }
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
    
    private func setModeParam(mode: String, phase: Int) {
        if (mode == OlympusConstants.MODE_PDR) {
            RQ_IDX = OlympusConstants.RQ_IDX_PDR
            USER_TRAJECTORY_LENGTH = OlympusConstants.USER_TRAJECTORY_LENGTH_PDR

            INIT_INPUT_NUM = 4
            VALUE_INPUT_NUM = 6
            PADDING_VALUE = OlympusConstants.PADDING_VALUE_SMALL
            PADDING_VALUES = [Double] (repeating: PADDING_VALUE, count: 4)
            
            if (phase >= OlympusConstants.PHASE_4) {
                UVD_INPUT_NUM = VALUE_INPUT_NUM
                INDEX_THRESHOLD = 21
            } else {
                UVD_INPUT_NUM = INIT_INPUT_NUM
                INDEX_THRESHOLD = 11
            }
        } else if (mode == OlympusConstants.MODE_DR) {
            RQ_IDX = OlympusConstants.RQ_IDX_DR
            USER_TRAJECTORY_LENGTH = OlympusConstants.USER_TRAJECTORY_LENGTH_DR

            INIT_INPUT_NUM = 5
            VALUE_INPUT_NUM = OlympusConstants.UVD_BUFFER_SIZE
            PADDING_VALUE = OlympusConstants.PADDING_VALUE_LARGE
            PADDING_VALUES = [Double] (repeating: PADDING_VALUE, count: 4)
            
            if (phase >= OlympusConstants.PHASE_4) {
                UVD_INPUT_NUM = VALUE_INPUT_NUM
                INDEX_THRESHOLD = (UVD_INPUT_NUM*2)+1
            } else {
                UVD_INPUT_NUM = INIT_INPUT_NUM
                INDEX_THRESHOLD = UVD_INPUT_NUM+1
            }
        }
    }
    
    // Collect
    public func initCollect(region: String) {
        unitDRGenerator.setMode(mode: "pdr")
        let initSensors = sensorManager.initSensors()
        let initBle = bleManager.initBle()
        
        OlympusFileManager.shared.createCollectFile(region: region, deviceModel: deviceModel, osVersion: deviceOsVersion)
        startCollectTimer()
    }
    
    public func startCollect() {
        isStartCollect = true
    }
    
    public func stopCollect() {
        bleManager.stopScan()
        stopCollectTimer()
        OlympusFileManager.shared.saveCollectData()
        
        isStartCollect = false
    }
    
    func startCollectTimer() {
        if (self.collectTimer == nil) {
            let queueCollect = DispatchQueue(label: Bundle.main.bundleIdentifier! + ".collectTimer")
            self.collectTimer = DispatchSource.makeTimerSource(queue: queueCollect)
            self.collectTimer!.schedule(deadline: .now(), repeating: OlympusConstants.UVD_INTERVAL)
            self.collectTimer!.setEventHandler { [weak self] in
                guard let self = self else { return }
                self.collectTimerUpdate()
            }
            self.collectTimer!.resume()
        }
        
    }
    
    func stopCollectTimer() {
        self.collectTimer?.cancel()
        self.collectTimer = nil
    }
    
    func collectTimerUpdate() {
        let currentTime = getCurrentTimeInMilliseconds()
        
        var collectData = sensorManager.getCollecttData()
        collectData.time = currentTime
        
        let validTime = OlympusConstants.BLE_VALID_TIME
        let bleDictionary: [String: [[Double]]]? = bleManager.getBLEData()
        if let bleData = bleDictionary {
            let trimmedResult = OlympusRFDFunctions.shared.trimBleData(bleInput: bleData, nowTime: getCurrentTimeInMillisecondsDouble(), validTime: validTime)
            switch trimmedResult {
            case .success(let trimmedData):
                let bleAvg = OlympusRFDFunctions.shared.avgBleData(bleDictionary: trimmedData)
                let bleRaw = OlympusRFDFunctions.shared.getLatestBleData(bleDictionary: trimmedData)
                
                collectData.bleAvg = bleAvg
                collectData.bleRaw = bleRaw
            case .failure(_):
                print(getLocalTimeString() + " , (Olympus) Error : BLE trim error in collect")
            }
        }
        
        if (isStartCollect) {
            unitDRInfo = unitDRGenerator.generateDRInfo(sensorData: sensorManager.sensorData)
            collectData.isIndexChanged = false
            if (unitDRInfo.isIndexChanged) {
                collectData.isIndexChanged = unitDRInfo.isIndexChanged
                collectData.index = unitDRInfo.index
                collectData.length = unitDRInfo.length
                collectData.heading = unitDRInfo.heading
                collectData.lookingFlag = unitDRInfo.lookingFlag
            }
            
            self.collectData = collectData
            OlympusFileManager.shared.writeCollectData(data: collectData)
        }
    }
    
    public func getCollectData() -> OlympusCollectData {
        return self.collectData
    }
}
