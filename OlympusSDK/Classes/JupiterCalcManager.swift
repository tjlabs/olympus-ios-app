import Foundation
import CoreLocation
import UIKit
import simd
import TJLabsCommon
import TJLabsResource

class JupiterCalcManager: NSObject, RFDGeneratorDelegate, UVDGeneratorDelegate, TJLabsResourceManagerDelegate, BuildingLevelChangerDelegate, StateManagerDelegate, LSEManagerDelegate, CLLocationManagerDelegate {
    
    // MARK: - Classes
    private var tjlabsResourceManager = TJLabsResourceManager()
    
    private var entManager: EntranceManager?
    private var buildingLevelChanger: BuildingLevelChanger?
    private var wardAvgManager: WardAveragingManager?
    private var peakDetector = PeakDetector()
    private var stackManager = StackManager()
    private var kalmanFilter: KalmanFilter?
    private var sectionController = SectionController()
    private var landmarkTagger: LandmarkTagger?
    private var solutionEstimator: SolutionEstimator?
    private var stateManager: JupiterStateManager?
    private var lseManager: LSEManager?
    
    // MARK: - Delegate
    weak var delegate: JupiterCalcManagerDelegate?
    
    // MARK: - User Properties
    var externalName: String = ""
    var cloud: String = JupiterCloud.GCP.rawValue
    var region: String = JupiterRegion.KOREA.rawValue
    var sectorId: Int = 0
    var os: String = JupiterNetworkConstants.OPERATING_SYSTEM
    var tenantUserName: String = ""
    
    // MARK: - Generator
    private var rfdGenerator: RFDGenerator?
    private var uvdGenerator: UVDGenerator?
    private var uvdStopTimestamp: Double = 0
    private var rfdEmptyMillis: Double = 0
    private var pressure: Float = 0
    
    var curRfd = ReceivedForce(tenant_user_name: "", mobile_time: 0, rfs: [String: Double](), pressure: 0)
    var curUvd = UserVelocity(tenant_user_name: "", mobile_time: 0, index: 0, length: 0, heading: 0, looking: false)
    var pastUvd = UserVelocity(tenant_user_name: "", mobile_time: 0, index: 0, length: 0, heading: 0, looking: false)
    var curVelocity: Float = 0
    var curUserMode: String = "DR"
    var curUserModeEnum: UserMode = .MODE_VEHICLE
    
    // MARK: - Constants
    private let AVG_BUFFER_SIZE = 2
    private let LSE_RESULT_BUFFER_SIZE = 5
    private let LSE_SNAPSHOT_BUFFER_SIZE = 10
    private let LSE_REPRESENTATIVE_CLUSTER_SIZE = 3
    private let LSE_HEADING_MIN_DISTANCE: Float = 1.0
    
    // MARK: - Searching
    private var searcingId: String = ""
    private var searchingIndex: Int = 0
    
    // MARK: - Landmark Correction
    private var correctionId: String = ""
    private var correctionIndex: Int = 0
    private var uvdIndexWhenCorrection: Int = 0
    var paddingValues = JupiterMode.PADDING_VALUES_MEDIUM
    var preFixed: FixedPeak?
    
    // MARK: - Recovery
    private var recoveryIndex: Int = 0
    private var recentUserPeakIndex: Int = 0
    private var recentLandmarkPeaks: [PeakData]?
    
    // MARK: - Navigation
    private var feedbackIndex: Int = 0
    
    // MARK: - Etc..
    private var pathMatchingCondition = PathMatchingCondition()
    private var report = -1
    
    // MARK: - Result
    var jupiterPhase: JupiterPhase = .NONE
    var curResult: FineLocationTrackingOutput?
    var preResult: FineLocationTrackingOutput?
    var curPathMatchingResult: FineLocationTrackingOutput?
    var curLSEResult: FineLocationTrackingOutput?
    var curPathMatchingLSEResult: FineLocationTrackingOutput?
    var lseResultBuffer = [FineLocationTrackingOutput]()
    var lseSnapshotBuffer = [SingleEpochSnapshot]()
    var curRepresentativeLSEResult: FineLocationTrackingOutput?
    var curPathMatchingRepresentativeLSEResult: FineLocationTrackingOutput?
    var buildingsData: [BuildingData]?
    var levelByBle: String?
    
    // MARK: - Debuging
    var sectorDebugOption: Bool = false
    var debugOption: Bool = false
    
    var debug_calc_xyh: [Float] = [0, 0, 0]
    var debug_tu_xyh: [Float] = [0, 0, 0]
    var debug_landmark: LandmarkData?
    var debug_best_landmark: PeakData?
    var debug_lse_rep_xyh: [Float]?
    var debug_ent_compensated_traj: [[Double]]?
    var debug_recon_raw_traj: [[Double]]?
    var debug_recon_corr_traj: [FineLocationTrackingOutput]?
    var debug_selected_search: SelectedSearch?
    var debug_selected_cand: SelectedCandidate?
    var debug_ratio: Float?
    var debug_navi_xyh: [Float] = [0, 0, 0]
    
    // MARK: - OS Heading
    private let locationManager = CLLocationManager()
    private var latestMagneticHeading: Double?
    var isUseOSHeading: Bool = false {
        didSet {
            updateOSHeadingMonitoring()
            applyOSHeadingToRepresentativeResultIfNeeded()
        }
    }
    
    // MARK: - init & deinit
    init(cloud: String, region: String, id: String, sectorId: Int, tenantUserName: String) {
        super.init()

        self.externalName = id
        self.cloud = cloud
        self.region = region
        self.sectorId = sectorId
        self.tenantUserName = tenantUserName
        
        self.entManager = EntranceManager(sectorId: sectorId)
        self.buildingLevelChanger = BuildingLevelChanger(sectorId: sectorId)
        self.wardAvgManager = WardAveragingManager(bufferSize: AVG_BUFFER_SIZE)
        self.kalmanFilter = KalmanFilter(stackManager: stackManager)
        self.landmarkTagger = LandmarkTagger(sectorId: sectorId)
        self.solutionEstimator = SolutionEstimator(sectorId: sectorId)
        self.stateManager = JupiterStateManager()
        self.lseManager = LSEManager(sectorId: sectorId, traceId: tenantUserName, externalName: id, resourceManager: tjlabsResourceManager)
        
        peakDetector.setInnerWardIds(ids: self.entManager!.getEntInnermostWardIds())
        
        tjlabsResourceManager.delegate = self
        buildingLevelChanger?.delegate = self
        stateManager?.delegate = self
        lseManager?.delegate = self
        
        locationManager.delegate = self
        locationManager.headingFilter = kCLHeadingFilterNone
    }
    
    deinit {
        JupiterLogger.i(tag: "JupiterCalcManager", message: "deinit")
        // 1. delegate 끊기
        tjlabsResourceManager.delegate = nil
        buildingLevelChanger?.delegate = nil
        stateManager = nil
        delegate = nil

        // 2. generator stop
        stopGenerator()

        // 3. generator delegate 끊기
        rfdGenerator?.delegate = nil
        uvdGenerator?.delegate = nil

        // 4. optional cleanup (선택)
        rfdGenerator = nil
        uvdGenerator = nil
        locationManager.stopUpdatingHeading()
        locationManager.delegate = nil
    }
    
    // MARK: - Functions
    func initialize(completion: @escaping (Bool, String) -> Void) {
        tjlabsResourceManager.loadResources(cloud: cloud, region: region, sectorId: sectorId, landmarkTh: -92, forceUpdate: true, completion: { isSuccess in
            let msg: String = isSuccess ? "JupiterCalcManager initialize success" : "JupiterCalcManager initialize failed"
            completion(isSuccess, msg)
        })
    }
    
    func start(completion: @escaping (Bool, String) -> Void) {
        tjlabsResourceManager.loadResources(cloud: cloud, region: region, sectorId: sectorId, landmarkTh: -92, forceUpdate: true, completion: { isSuccess in
            let msg: String = isSuccess ? "JupiterCalcManager start success" : "JupiterCalcManager start failed"
            completion(isSuccess, msg)
        })
    }
    
    func getBuildingsData() -> [BuildingData]? {
        JupiterLogger.i(tag: "JupiterCalcManager", message: "getBuildingsData : buildingsData= \(buildingsData)")
        return self.buildingsData
    }
    
    // MARK: - Set REC length
    func startGenerator(mode: UserMode, completion: @escaping (Bool, String) -> Void) {
        PathMatcher.shared.setGraphMode(mode)
        rfdGenerator = RFDGenerator(userId: tenantUserName)
        uvdGenerator = UVDGenerator(userId: tenantUserName)

        guard let rfd = rfdGenerator else {
            completion(false, "rfdGenerator is nil")
            return
        }
        
        guard let uvd = uvdGenerator else {
            completion(false, "uvdGenerator is nil")
            return
        }

        let (isRfdSuccess, rfdMsg) = rfd.checkIsAvailableRfd()
        guard isRfdSuccess else {
            completion(false, rfdMsg)
            return
        }

        let (isUvdSuccess, uvdMsg) = uvd.checkIsAvailableUvd()
        guard isUvdSuccess else {
            completion(false, uvdMsg)
            return
        }
        
        JupiterReplayer.shared.replayMode ? rfdGenerator?.generateReplayRfd() : rfdGenerator?.generateRfd()
        rfdGenerator?.delegate = self
        rfdGenerator?.pressureProvider = { [self] in
            return self.pressure
        }

        uvdGenerator?.setUserMode(mode: mode)
        JupiterReplayer.shared.replayMode ? uvdGenerator?.generateReplayUvd() : uvdGenerator?.generateUvd()
        uvdGenerator?.delegate = self
        
        let lseAppName = JupiterReplayer.shared.replayMode ? "ios_jupiter_replay" : "ios_jupiter_dev"
        lseManager?.setAppName(name: lseAppName)
        lseManager?.startService()
        updateOSHeadingMonitoring()
        
        completion(true, "")
    }
    
    func stopGenerator() {
        rfdGenerator?.delegate = nil
        rfdGenerator?.stopRfdGeneration()
        uvdGenerator?.delegate = nil
        uvdGenerator?.stopUvdGeneration()
        rfdGenerator = nil
        uvdGenerator = nil
        
        lseManager?.stopService()
        updateOSHeadingMonitoring()
    }

    func resetRuntimeState() {
        JupiterStates.resetAll(isStopService: true)

        uvdStopTimestamp = 0
        rfdEmptyMillis = 0
        pressure = 0

        curRfd = ReceivedForce(tenant_user_name: "", mobile_time: 0, rfs: [String: Double](), pressure: 0)
        curUvd = UserVelocity(tenant_user_name: "", mobile_time: 0, index: 0, length: 0, heading: 0, looking: false)
        pastUvd = UserVelocity(tenant_user_name: "", mobile_time: 0, index: 0, length: 0, heading: 0, looking: false)
        curVelocity = 0
        curUserMode = "DR"
        curUserModeEnum = .MODE_VEHICLE

        entManager?.toggleToOutdoor()
        buildingLevelChanger?.toggleToOutdoor()

        peakDetector = PeakDetector()
        if let entManager {
            peakDetector.setInnerWardIds(ids: entManager.getEntInnermostWardIds())
        }

        wardAvgManager = WardAveragingManager(bufferSize: AVG_BUFFER_SIZE)
        stackManager = StackManager()
        kalmanFilter = KalmanFilter(stackManager: stackManager)
        sectionController = SectionController()
        solutionEstimator = SolutionEstimator(sectorId: sectorId)
        stateManager?.delegate = nil
        stateManager = JupiterStateManager()
        stateManager?.delegate = self

        searcingId = ""
        searchingIndex = 0
        correctionId = ""
        correctionIndex = 0
        uvdIndexWhenCorrection = 0
        paddingValues = JupiterMode.PADDING_VALUES_MEDIUM
        preFixed = nil
        recoveryIndex = 0
        recentUserPeakIndex = 0
        recentLandmarkPeaks = nil
        feedbackIndex = 0
        pathMatchingCondition = PathMatchingCondition()
        report = -1

        jupiterPhase = .NONE
        curResult = nil
        preResult = nil
        curPathMatchingResult = nil
        curLSEResult = nil
        curPathMatchingLSEResult = nil
        lseResultBuffer.removeAll()
        curRepresentativeLSEResult = nil
        curPathMatchingRepresentativeLSEResult = nil
        
        debug_calc_xyh = [0, 0, 0]
        debug_tu_xyh = [0, 0, 0]
        debug_landmark = nil
        debug_best_landmark = nil
        debug_lse_rep_xyh = nil
        debug_ent_compensated_traj = nil
        debug_recon_raw_traj = nil
        debug_recon_corr_traj = nil
        debug_selected_search = nil
        debug_selected_cand = nil
        debug_ratio = nil
        debug_navi_xyh = [0, 0, 0]
    }
    
    func getJupiterResult() -> JupiterResult? {
        let currentTime = TJLabsUtilFunctions.shared.getCurrentTimeInMilliseconds(as: .int) as! Int
        let is_vehicle = curUserModeEnum == .MODE_VEHICLE
        var isShowLSEResult: Bool = false
        if let levelByBle = self.levelByBle, levelByBle != "B0" {
            if jupiterPhase == .ENTERING || jupiterPhase == .TRACKING {
                isShowLSEResult = false
            } else {
                isShowLSEResult = true
            }
        }
        let currentResult = !isShowLSEResult ? self.curPathMatchingResult : (self.curRepresentativeLSEResult ?? self.curPathMatchingLSEResult)
//        let currentResult = is_vehicle && jupiterPhase != .SEARCHING ? self.curPathMatchingResult : (self.curRepresentativeLSEResult ?? self.curPathMatchingLSEResult)
        guard let curPathMatchingResult = currentResult else { return nil }
        self.debug_calc_xyh = [curPathMatchingResult.x, curPathMatchingResult.y, curPathMatchingResult.absolute_heading]
        
        let buildingName = curPathMatchingResult.building_name
        let levelName = curPathMatchingResult.level_name
        let x = curPathMatchingResult.x
        let y = curPathMatchingResult.y
        let absoluteHeading = curPathMatchingResult.absolute_heading

        var llh: LLH?
        if let affineParam = AffineConverter.shared.getAffineParam(sectorId: sectorId) {
            let converted = AffineConverter.shared.convertPpToLLH(x: Double(x), y: Double(y), heading: Double(absoluteHeading), param: affineParam)
            llh = LLH(lat: converted.lat, lon: converted.lon, azimuth: converted.azimuth)
        }
        
        let jupiterResult = JupiterResult(mobile_time: currentTime,
                                          index: curUvd.index,
                                          building_name: buildingName,
                                          level_name: levelName,
                                          jupiter_pos: Position(x: x, y: y, heading: absoluteHeading),
                                          navi_pos: nil,
                                          passed_point_id: nil,
                                          llh: llh,
                                          velocity: curVelocity,
                                          is_vehicle: is_vehicle,
                                          is_indoor: JupiterResultState.isIndoor,
                                          validity_flag: 1)
        
        return jupiterResult
    }
    
    func getJupiterDebugResult() -> JupiterDebugResult? {
        let currentTime = TJLabsUtilFunctions.shared.getCurrentTimeInMilliseconds(as: .int) as! Int
        let is_vehicle = curUserModeEnum == .MODE_VEHICLE
        var isShowLSEResult: Bool = false
        if let levelByBle = self.levelByBle, levelByBle != "B0" {
            if jupiterPhase == .ENTERING || jupiterPhase == .TRACKING {
                isShowLSEResult = false
            } else {
                isShowLSEResult = true
            }
            
        }
        let currentResult = !isShowLSEResult ? self.curPathMatchingResult : (self.curRepresentativeLSEResult ?? self.curPathMatchingLSEResult)
//        let currentResult = is_vehicle && jupiterPhase != .SEARCHING ? self.curPathMatchingResult : (self.curRepresentativeLSEResult ?? self.curPathMatchingLSEResult)
        guard let curPathMatchingResult = currentResult else { return nil }
        self.debug_calc_xyh = [curPathMatchingResult.x, curPathMatchingResult.y, curPathMatchingResult.absolute_heading]

        let buildingName = curPathMatchingResult.building_name
        let levelName = curPathMatchingResult.level_name
        let x = curPathMatchingResult.x
        let y = curPathMatchingResult.y
        let absoluteHeading = curPathMatchingResult.absolute_heading
        
        var llh: LLH?
        if let affineParam = AffineConverter.shared.getAffineParam(sectorId: sectorId) {
            let converted = AffineConverter.shared.convertPpToLLH(x: Double(x), y: Double(y), heading: Double(absoluteHeading), param: affineParam)
            llh?.lat = converted.lat
            llh?.lon = converted.lon
            llh?.azimuth = converted.azimuth
        }
        
        let jupiterDebugResult = JupiterDebugResult(
            mobile_time: currentTime,
            building_name: buildingName,
            level_name: levelName,
            x: x,
            y: y,
            llh: llh,
            absolute_heading: absoluteHeading,
            index: curUvd.index,
            velocity: curVelocity,
            mode: curUserMode,
            ble_only_position: false,
            isIndoor: JupiterResultState.isIndoor,
            validity: false,
            validity_flag: 0,
            calc_xyh: self.debug_calc_xyh,
            tu_xyh: self.debug_tu_xyh,
            landmark: self.debug_landmark,
            best_landmark: self.debug_best_landmark,
            lse_rep_xyh: self.debug_lse_rep_xyh,
            ent_compensated_traj: self.debug_ent_compensated_traj,
            recon_raw_traj: self.debug_recon_raw_traj,
            recon_corr_traj: self.debug_recon_corr_traj,
            selected_cand: self.debug_selected_cand,
            selected_search: self.debug_selected_search,
            ratio: self.debug_ratio,
            navi_xyh: self.debug_navi_xyh
        )
        
        return jupiterDebugResult
    }

    // MARK: - RFDGeneratorDelegate Methods
    func onRfdResult(_ generator: TJLabsCommon.RFDGenerator, receivedForce: TJLabsCommon.ReceivedForce) {
        if debugOption { JupiterFileManager.shared.writeRFD(rfd: receivedForce) }
        handleRfd(rfd: receivedForce)
        lseManager?.onRfdResult(generator, receivedForce: receivedForce)
        delegate?.onRfdResult(receivedForce: receivedForce)
    }
    
    func handleRfd(rfd: ReceivedForce) {
        self.curRfd = rfd
        let currentTime = TJLabsUtilFunctions.shared.getCurrentTimeInMilliseconds(as: .int) as! Int
        guard let bleAvailable = rfdGenerator?.checkIsAvailableRfd() else { return }
        if !bleAvailable.0 { delegate?.onStateReported(.BLUETOOTH_UNAVAILABLE) }
        guard let bleReady = rfdGenerator?.isBluetoothReady() else { return }
        guard let lastScannedTime = rfdGenerator?.getBleLastScannedTime() else { return }
        stateManager?.checkBleOff(bluetoothReady: bleReady, bleLastScannedTime: lastScannedTime)
        stateManager?.checkNetworkConnection()
        
        guard let blChanger = self.buildingLevelChanger else { return }
        if let top3Ble = stackManager.extractTop3BleInWindow(currentTime: currentTime, ble: rfd.rfs) {
            if let estimatedLevel = blChanger.calculateLevelByBle(data: top3Ble) {
                self.levelByBle = estimatedLevel
            }
        }
    }
    
    func onRfdError(_ generator: TJLabsCommon.RFDGenerator, code: Int, msg: String) {
        JupiterLogger.i(tag: "JupiterCalcManager", message: "(onRfdError): \(code), \(msg)")
        lseManager?.onRfdError(generator, code: code, msg: msg)
    }
    
    func onRfdEmptyMillis(_ generator: TJLabsCommon.RFDGenerator, time: Double) {
        rfdEmptyMillis = time
        lseManager?.onRfdEmptyMillis(generator, time: time)
    }
    
    // MARK: - UVDGeneratorDelegate Methods
    func onPressureResult(_ generator: UVDGenerator, hPa: Double) {
        // TODO: Handle pressure result
        pressure = Float(hPa)
    }
    
    func onUvdError(_ generator: UVDGenerator, error: String) {
        JupiterLogger.i(tag: "JupiterCalcManager", message: "(onUvdError): \(error)")
    }
    
    func onUvdPauseMillis(_ generator: UVDGenerator, time: Double) {
        // TODO: Handle UVD pause
    }
    
    func onUvdResult(_ generator: UVDGenerator, mode: UserMode, userVelocity: UserVelocity) {
        if debugOption { JupiterFileManager.shared.writeUVD(uvd: userVelocity, mode: mode) }
        let currentTime = TJLabsUtilFunctions.shared.getCurrentTimeInMilliseconds(as: .int) as! Int

        let rfs = curRfd.rfs
        var rfdDataString = ""
        for (key, value) in rfs {
            let str = ",\(key)=\(value)"
            rfdDataString.append(str)
        }

        // Update Current UVD
        self.curUvd = userVelocity
        let curIndex = userVelocity.index
        guard let entManager = self.entManager else { return }
        guard let blChanger = self.buildingLevelChanger else { return }
        guard let landmarkTagger = self.landmarkTagger else { return }
        stackManager.stackUvd(uvd: userVelocity)
        let uvdBuffer = stackManager.getUvdBuffer()
        let capturedRfd = self.curRfd
        let bleData = capturedRfd.rfs // [String: Float] BLE_ID: RSSI
        
        var reconCurResultBuffer: [FineLocationTrackingOutput]?
        var olderPeakIndex: Int?
        
        // Moving Averaging
        guard let wardAvgManager = wardAvgManager else { return }
        let avgBleData: [String: Double] = wardAvgManager.updateEpoch(bleData: bleData)
        
        var jumpInfo: JumpInfo?
        var blTagResult: BuildingLevelTagResult?
        var curPeak: UserPeak?
        var blByPeak: (building: String, level: String)?
        let windowSize = determineWindowSize(jupiterPhase: jupiterPhase)
        if let userPeak = peakDetector.updateEpoch(uvdIndex: curIndex, bleAvg: avgBleData, windowSize: windowSize, jupiterPhase: jupiterPhase) {
            curPeak = userPeak
            self.debug_selected_cand = nil
            self.debug_ratio = nil
            
            let peakEventInfo: String = "ward_id:\(userPeak.id),start_index:\(userPeak.start_index),peak_index:\(userPeak.peak_index),end_index:\(userPeak.end_index),peak_rssi:\(userPeak.peak_rssi),th:\(userPeak.threshold)"
            JupiterFileManager.shared.writeEvent(event: JupiterEvent(mobile_time: currentTime, event_code: JupiterServiceCode.PEAK_DETECTED.rawValue, event_info: peakEventInfo))
            peakHandling: do {
                JupiterLogger.i(tag: "JupiterCalcManager", message: "(onUvdResult) PEAK detected : id=\(userPeak.id) // peak_idx=\(userPeak.peak_index), peak_rssi=\(userPeak.peak_rssi), detected_idx = \(userPeak.end_index), detected_rssi = \(userPeak.end_rssi)")
                startEntranceTracking(currentTime: currentTime, entManager: entManager, uvd: userVelocity, userPeak: userPeak, bleData: bleData)
                if let buildingLevelByPeak = blChanger.getMatchedBuildingLevelByUserPeak(userPeak: userPeak) {
                    blByPeak = buildingLevelByPeak
                    stackManager.stackBuildingLevelByPeak(buildingLevel: buildingLevelByPeak)
                    let buildingLevelByPeakBuffer = stackManager.getBuildingLevelByPeakBuffer(size: 3)
                    startIndoorSearching(uvd: userVelocity, blChanger: blChanger, buildingLevelByPeakBuffer: buildingLevelByPeakBuffer)
                }
                
                // Building & Level Changer
//                if let blTag = blChanger.isBuildingLevelChangerTagged(userPeak: userPeak, curResult: curResult, mode: mode),
//                   let destinations = blChanger.getBuildingLevelDestination(tag: blTag, curResult: curResult),
//                   let detectionResult = blChanger.determineTagDetection(time: currentTime, tag: blTag, buildingDestination: destinations.buildingDestination, levelDestination: destinations.levelDestination, tagCoord: [Float(blTag.x), Float(blTag.y)], curResult: curResult),
//                   !JupiterResultState.isEntTrack {
//                    blTagResult = detectionResult
//                    if let kf = kalmanFilter {
//                        kf.updateTuBuildingLevel(building: detectionResult.building, level: detectionResult.level)
//                    }
//                    break peakHandling
//                }
            }
        }
        
        var uturnLink = false
        switch (jupiterPhase) {
        case .ENTERING:
            calcEntranceResult(currentTime: currentTime, entManager: entManager, uvd: userVelocity)
        case .TRACKING:
            uturnLink = PathMatcher.shared.isInUturnLink()
            applyCorrectionWithPeaks(userPeak: curPeak, mode: mode, userVelocity: userVelocity, uvdBuffer: uvdBuffer)
            calcIndoorResult(mode: mode, uvd: userVelocity, olderPeakIndex: olderPeakIndex, jumpInfo: jumpInfo, uturnLink: uturnLink)
        case .SEARCHING:
            calcIndoorSearching(userPeak: curPeak, buildingLevelByPeak: blByPeak, mode: mode, userVelocity: userVelocity, uvdBuffer: uvdBuffer)
        case .EXITING:
            // TODO
            JupiterLogger.i(tag: "EXITING", message: "TODO")
        case .OUTDOOR:
            JupiterLogger.i(tag: "OUTDOOR", message: "TODO")
        case .NONE:
            break
        }
        self.pastUvd = userVelocity
        
        // MARK: - Update CurPathMatchingResult
        guard let curResult = self.curResult else { return }
        stackManager.stackCurResult(curResult: curResult, reconCurResultBuffer: reconCurResultBuffer)
        
        guard let pmResult = PathMatcher.shared.pathMatching(sectorId: sectorId, building: curResult.building_name, level: curResult.level_name, x: curResult.x, y: curResult.y, heading: curResult.absolute_heading, isUseHeading: true, mode: mode, paddingValues: paddingValues) else { return }
        curPathMatchingResult = curResult
        curPathMatchingResult?.x = pmResult.x
        curPathMatchingResult?.y = pmResult.y
        curPathMatchingResult?.absolute_heading = pmResult.heading
        
        guard let curPmResult = curPathMatchingResult else { return }
        stackManager.stackCurPmResultBuffer(curPmResult: curPmResult)
        lseManager?.updateCurPmResult(curPmResult: curPmResult)
        
        var distWithLSE: Float = 0
        if let curLSEResult = curLSEResult {
            let diffX = curPmResult.x - curLSEResult.x
            let diffY = curPmResult.y - curLSEResult.y
            distWithLSE = sqrt(diffX*diffX + diffY*diffY)
        }
        // Bad Case 확인
        let travelingLinkDist = PathMatcher.shared.getCurPassedLinksDist()
        if stackManager.checkIsBadCase(jupiterPhase: jupiterPhase, uvdIndexWhenCorrection: self.uvdIndexWhenCorrection, travelingLinkDist: travelingLinkDist, distWithLSE: distWithLSE) && !uturnLink {
            JupiterLogger.i(tag: "JupiterCalcManager", message: "(onUvdResult) BadCase: entered, index=\(userVelocity.index), phase=\(jupiterPhase), travelingLinkDist=\(travelingLinkDist)")
            let userPeakAndLinksBuffer = stackManager.getUserPeakAndLinksBuffer()
            if userPeakAndLinksBuffer.count < 2 {
                JupiterLogger.i(tag: "JupiterCalcManager", message: "(onUvdResult) BadCase: return - peaks are not sufficient, count=\(userPeakAndLinksBuffer.count)")
                return
            }
            JupiterResultState.isInRecoveryProcess = true
            guard let recentAndOld = getRecentAndOlderUserPeak(userPeakAndLinksBuffer: userPeakAndLinksBuffer) else {
                JupiterLogger.i(tag: "JupiterCalcManager", message: "(onUvdResult) BadCase: return - getRecentAndOlderUserPeak returned nil")
                return
            }
            guard let solutionEstimator = self.solutionEstimator else {
                JupiterLogger.i(tag: "JupiterCalcManager", message: "(onUvdResult) BadCase: return - solutionEstimator is nil")
                return
            }
            let recentUserPeak = recentAndOld.recent.0
            let olderUserPeak = recentAndOld.old.0
            
            let uvdBufferForRecovery = solutionEstimator.getUvdBufferForEstimation(startIndex: olderUserPeak.peak_index,
                                                                                    endIndex: userVelocity.index,
                                                                                    uvdBuffer: uvdBuffer)
            let pmResultBuffer = stackManager.getCurPmResultBuffer(from: olderUserPeak.peak_index)
            let pathHeadings = stackManager.makeHeadingSet(resultBuffer: pmResultBuffer)

            let uvdBufferForStraight = stackManager.getUvdBuffer(from: recentUserPeak.peak_index)
            let isDrStraight = stackManager.isDrBufferStraightCircularStd(uvdBuffer: uvdBufferForStraight, condition: 5)
            
            if let tuResult = kalmanFilter?.getTuResult() {
                let curResultBuffer = stackManager.getCurResultBuffer()
                if let matchedWithOlderPeak = landmarkTagger.findMatchedLandmarkWithUserPeak(userPeak: olderUserPeak, curResult: curResult, curResultBuffer: curResultBuffer),
                   let matchedWithRecentPeak = landmarkTagger.findMatchedLandmarkWithUserPeak(userPeak: recentUserPeak, curResult: curResult, curResultBuffer: curResultBuffer) {
                    let hasMajorDirection = stackManager.checkHasMajorDirection(uvdBuffer: uvdBufferForRecovery)
                    JupiterLogger.i(tag: "JupiterCalcManager", message: "(onUvdResult) BadCase: hasMajorDirection= \(hasMajorDirection)")
                    if hasMajorDirection {
                        let majorSection = stackManager.extractSectionWithLeastChange(inputArray: uvdBufferForRecovery.map{ Float($0.heading) })
                        JupiterLogger.i(tag: "JupiterCalcManager", message: "(onUvdResult) BadCase: majorSection= \(majorSection)")
                        
                        let candidateTrajList = solutionEstimator.makeMultipleCandidateTrajectory(uvdBuffer: uvdBufferForRecovery, majorSection: majorSection, pathHeadings: pathHeadings, endHeading: tuResult.absolute_heading)
                        let candidateResult = solutionEstimator.calculateLossParamAtEachCand(trackingTrajList: candidateTrajList,
                                                                                                  userPeakAndLinksBuffer: userPeakAndLinksBuffer,
                                                                                                  landmarks: (matchedWithOlderPeak.0, matchedWithRecentPeak.0),
                                                                                                  curPmResult: curPmResult,
                                                                                                  mode: mode, matchedNode: nil, isDrStraight: isDrStraight.0)
                        if let bestResult = solutionEstimator.calculateBadCaseResult(lossParamAtEachCand: candidateResult) {
                            self.debug_selected_cand = bestResult
                            self.recoveryIndex = userVelocity.index
                            
                            let paddings = JupiterMode.PADDING_VALUES_MEDIUM
                            stackManager.editCurResultBuffer(sectorId: sectorId, mode: mode, from: recentUserPeak.peak_index, shifteTraj: bestResult.traj, paddings: paddings)
                            let updatedCurPmResult = stackManager.editCurPmResultBuffer(sectorId: sectorId, mode: mode, from: recentUserPeak.peak_index, shifteTraj: bestResult.traj,paddings: paddings)
                            kalmanFilter?.editTuResultBuffer(sectorId: sectorId, mode: mode, from: recentUserPeak.peak_index, shifteTraj: bestResult.traj, curResult: curResult,paddings: paddings)
                            
                            let curPmResultBuffer = stackManager.getCurPmResultBuffer(from: recentUserPeak.peak_index)
                            PathMatcher.shared.editPassingLinkBuffer(from: recentUserPeak.peak_index, sectorId: sectorId, curPmResultBuffer: curPmResultBuffer, mode: mode)
                            let recoveryCoord: [Float] = [updatedCurPmResult.x, updatedCurPmResult.y, updatedCurPmResult.absolute_heading]
                            if let pmResult = PathMatcher.shared.pathMatching(sectorId: sectorId, building: curResult.building_name, level: curResult.level_name, x: recoveryCoord[0],y: recoveryCoord[1], heading: recoveryCoord[2], isUseHeading: true, mode: mode, paddingValues: JupiterMode.PADDING_VALUES_MEDIUM) {
                                curPathMatchingResult = bestResult.headResult
                                curPathMatchingResult?.x = pmResult.x
                                curPathMatchingResult?.y = pmResult.y
                                curPathMatchingResult?.absolute_heading = pmResult.heading
                                JupiterLogger.i(tag: "JupiterCalcManager", message: "(onUvdResult) BadCase: recoveryCoord= \(recoveryCoord), loss= \(bestResult.loss)")
                                kalmanFilter?.updateTuPosition(coord: [pmResult.x, pmResult.y])
                                self.curResult? = curPathMatchingResult!
                                if let matchedLink = PathMatcher.shared.getLinkInfoWithResult(sectorId: sectorId, result: curPathMatchingResult!, checkAll: true, mode: mode) {
                                    let jumpInfo = JumpInfo(link_number: matchedLink.number, jumped_nodes: [])
                                    PathMatcher.shared.updateNodeAndLinkInfo(sectorId: sectorId, uvdIndex: curIndex, curResult: curPathMatchingResult!, jumpInfo: jumpInfo, mode: mode)
                                } else {
                                    JupiterLogger.i(tag: "JupiterCalcManager", message: "(onUvdResult) BadCase: recovery succeeded but matchedLink is nil")
                                }
                            } else {
                                JupiterLogger.i(tag: "JupiterCalcManager", message: "(onUvdResult) BadCase: recovery pathMatching failed, using raw recoveryCoord=\(recoveryCoord)")
                                kalmanFilter?.updateTuPosition(coord: recoveryCoord)
                                var copiedResult = bestResult.headResult
                                copiedResult.x = recoveryCoord[0]
                                copiedResult.y = recoveryCoord[1]
                                copiedResult.absolute_heading = recoveryCoord[2]
                                self.curResult? = copiedResult
                                PathMatcher.shared.initPassedLinkInfo()
                            }
                        } else {
                            JupiterLogger.i(tag: "JupiterCalcManager", message: "(onUvdResult) BadCase: calculateBadCaseResult returned nil")
                        }
                    } else {
                        JupiterLogger.i(tag: "JupiterCalcManager", message: "(onUvdResult) BadCase: cannot find major direction")
                    }
                } else {
                    JupiterLogger.i(tag: "JupiterCalcManager", message: "(onUvdResult) BadCase: landmark matching failed, olderPeak=\(olderUserPeak.peak_index), recentPeak=\(recentUserPeak.peak_index)")
                }
            } else {
                JupiterLogger.i(tag: "JupiterCalcManager", message: "(onUvdResult) BadCase: kalmanFilter tuResult is nil")
            }
            JupiterResultState.isInRecoveryProcess = false
            JupiterLogger.i(tag: "JupiterCalcManager", message: "(onUvdResult) BadCase: exited recovery block")
        }
        
        if jupiterPhase == .TRACKING {
            let indexForEdit = max(correctionIndex, feedbackIndex)
            guard let trackingFeedback = delegate?.provideTrackingCorrection(mode: mode, userVelocity: userVelocity, peakIndex: curPeak?.peak_index, recentLandmarkPeaks: recentLandmarkPeaks, travelingLinkDist: travelingLinkDist, indexForEdit: indexForEdit, curPmResult: curPmResult) else {
                JupiterLogger.i(tag: "JupiterCalcManager", message: "(onUvdResult) return - provideTrackingCorrection returned nil, indexForEdit=\(indexForEdit), curPmResultExists=\(curPathMatchingResult != nil)")
                return
            }
            let naviCorrectionInfo = trackingFeedback.0
            let stackEditInfoBuffer = trackingFeedback.1
            let paddings = JupiterMode.PADDING_VALUES_MEDIUM
            stackManager.editCurResultBuffer(sectorId: sectorId, mode: mode, from: indexForEdit, stackEditInfoBuffer: stackEditInfoBuffer, paddings: paddings)
            _ = stackManager.editCurPmResultBuffer(sectorId: sectorId, mode: mode, from: indexForEdit, stackEditInfoBuffer: stackEditInfoBuffer, paddings: paddings)
            kalmanFilter?.editTuResultBuffer(sectorId: sectorId, mode: mode, from: indexForEdit, stackEditInfoBuffer: stackEditInfoBuffer, curResult: curResult, paddings: paddings)
            
            kalmanFilter?.updateTuPosition(coord: [naviCorrectionInfo.x, naviCorrectionInfo.y])
            feedbackIndex = userVelocity.index
            
            let dist = sqrt((naviCorrectionInfo.x - curResult.x)*(naviCorrectionInfo.x - curResult.x) + (naviCorrectionInfo.y - curResult.y)*(naviCorrectionInfo.y - curResult.y))
            if dist > 2 {
                var naviResult = curResult
                naviResult.x = naviCorrectionInfo.x
                naviResult.y = naviCorrectionInfo.y
                naviResult.absolute_heading = naviCorrectionInfo.heading
                if let naviResultLink = PathMatcher.shared.getLinkInfoWithResult(sectorId: sectorId, result: naviResult, checkAll: true, mode: mode),
                   let curLinkInfo = PathMatcher.shared.getCurPassedLinkInfo(),
                   let jumped = calcJumpedNodes(from: curResult, to: naviResult, curLinkInfo: curLinkInfo, jumpedLinkNum: naviResultLink.number, mode: mode) {
                    JupiterLogger.i(tag: "JupiterCalcManager", message: "(onUvdResult) jumped: link= \(jumped.link_number), nodes= \(jumped.jumped_nodes)")
                    let jumpInfo: JumpInfo = JumpInfo(link_number: jumped.link_number, jumped_nodes: jumped.jumped_nodes)
                    PathMatcher.shared.updateNodeAndLinkInfo(sectorId: sectorId, uvdIndex: userVelocity.index, curResult: naviResult, jumpInfo: jumpInfo, mode: mode)
                } else {
                    PathMatcher.shared.initPassedNodeInfo()
                }
            }
        }
        
        updateDebugTuResult()
    }
    
    private func updateDebugTuResult() {
        if let tuResult = kalmanFilter?.getTuResult() {
            JupiterLogger.i(tag: "JupiterCalcManager", message: "(updateDebugTuResult) - tuResult: [\(tuResult.x), \(tuResult.y), \(tuResult.absolute_heading)]")
            self.debug_tu_xyh = [tuResult.x, tuResult.y, tuResult.absolute_heading]
        }
    }
    
    private func startEntranceTracking(currentTime: Int, entManager: EntranceManager, uvd: UserVelocity, userPeak: UserPeak, bleData: [String: Double]) {
        let peakId = userPeak.id
        if !JupiterResultState.isIndoor && jupiterPhase != .ENTERING && jupiterPhase != .SEARCHING {
            guard let entKey = entManager.checkStartEntTrack(wardId: peakId, sec: 3) else { return }
            jupiterPhase = .ENTERING
            delegate?.isJupiterPhaseChanged(index: uvd.index, phase: jupiterPhase, xyh: nil)
            CallWhenFirstResponse()
            let entTrackData = entKey.split(separator: "_")
            JupiterLogger.i(tag: "JupiterCalcManager", message: "(onUvdResult) index:\(uvd.index) - entTrackData = \(entTrackData)")

            if let blChanger = self.buildingLevelChanger,
               let _ = entManager.getEntInnermostWardCoord(key: entKey) {
                if let fromLevel = entManager.getEntTrackEndLevel(),
                   let levelId = blChanger.getLevelIdWithName(levelName: fromLevel) {
                    delegate?.onEntering(userVelocity: uvd, peakIndex: userPeak.peak_index, key: entKey, level_id: levelId)
                } else {
                    JupiterLogger.w(tag: "JupiterCalcManager", message: "(requestRouting) unwrap fail")
                }
            }
        }
        
        if jupiterPhase == .ENTERING {
//            var forceStop = false
//            let uvdBuffer = stackManager.getUvdBuffer(from: uvd.index-50)
//            let majorSection = stackManager.extractSectionWithLeastChange(inputArray: uvdBuffer.map{ Float($0.heading) })
//            forceStop = majorSection.isEmpty
//            
//            if !forceStop, let promotedResult = entManager.maybePromoteEnteringToTrackingUsingLse(curResult: curResult, uvd: uvd, uvdBuffer: uvdBuffer, lseSnapshotBuffer: lseSnapshotBuffer, majorSection: majorSection) {
//                startIndoorTracking(uvd: uvd, fltResult: promotedResult)
//            }
            
            var forceStop = false
            if let innermostWard = entManager.stopEntTrack(wardId: peakId) {
                let uvdBuffer = stackManager.getUvdBuffer(from: uvd.index-50)
                let majorSection = stackManager.extractSectionWithLeastChange(inputArray: uvdBuffer.map{ Float($0.heading) })
                forceStop = majorSection.isEmpty
                if !forceStop {
                    var wardArea: [EntWardArea]?
                    if innermostWard.name.contains("46E") {
                        // Convensia Ent1
                        wardArea = [
                            EntWardArea(x: 30, y: 199, heading: [0]),
                            EntWardArea(x: 31, y: 199, heading: [0]),
                            EntWardArea(x: 32, y: 199, heading: [0]),
                            EntWardArea(x: 33, y: 199, heading: [0]),
                            EntWardArea(x: 34, y: 199, heading: [0]),
                            EntWardArea(x: 35, y: 199, heading: [0]),
                            EntWardArea(x: 36, y: 199, heading: [0]),
                            EntWardArea(x: 37, y: 199, heading: [0]),
                            EntWardArea(x: 38, y: 199, heading: [0]),
                            EntWardArea(x: 39, y: 199, heading: [0]),
                            EntWardArea(x: 40, y: 199, heading: [0]),
                            EntWardArea(x: 41, y: 199, heading: [0]),
                            EntWardArea(x: 42, y: 199, heading: [0]),
                            EntWardArea(x: 43, y: 199, heading: [0]),
                            EntWardArea(x: 44, y: 199, heading: [0]),
                            EntWardArea(x: 45, y: 199, heading: [0]),
                            EntWardArea(x: 46, y: 199, heading: [0]),
                            EntWardArea(x: 47, y: 199, heading: [0]),
                            EntWardArea(x: 48, y: 199, heading: [0])
                        ]
                    } else if innermostWard.name.contains("114") {
                        // Convensia Ent2
                        wardArea = [
                            EntWardArea(x: 362, y: 152, heading: [158, 180]),
                            EntWardArea(x: 361, y: 153, heading: [158, 180]),
                            EntWardArea(x: 360, y: 153, heading: [158, 180]),
                            EntWardArea(x: 359, y: 154, heading: [158]),
                            EntWardArea(x: 358, y: 154, heading: [158]),
                            EntWardArea(x: 357, y: 154, heading: [158]),
                            EntWardArea(x: 357, y: 154, heading: [158]),
                            EntWardArea(x: 356, y: 155, heading: [158]),
                            EntWardArea(x: 355, y: 155, heading: [158]),
                            EntWardArea(x: 354, y: 155, heading: [158]),
                            EntWardArea(x: 353, y: 156, heading: [158]),
                            EntWardArea(x: 352, y: 156, heading: [158]),
                            EntWardArea(x: 352, y: 157, heading: [158]),
                            EntWardArea(x: 351, y: 157, heading: [158]),
                            EntWardArea(x: 350, y: 157, heading: [158]),
                            EntWardArea(x: 349, y: 158, heading: [158]),
                            EntWardArea(x: 348, y: 158, heading: [90, 158]),
                            EntWardArea(x: 348, y: 159, heading: [90]),
                            EntWardArea(x: 348, y: 160, heading: [90]),
                            EntWardArea(x: 348, y: 161, heading: [90]),
                            EntWardArea(x: 348, y: 162, heading: [90]),
                            EntWardArea(x: 348, y: 163, heading: [90]),
                            EntWardArea(x: 348, y: 164, heading: [90]),
                            EntWardArea(x: 348, y: 165, heading: [90])
                        ]
                    } else if innermostWard.name.contains("117") {
                        wardArea = [
                            EntWardArea(x: 348, y: 50, heading: [90]),
                            EntWardArea(x: 348, y: 51, heading: [90]),
                            EntWardArea(x: 348, y: 52, heading: [90]),
                            EntWardArea(x: 348, y: 53, heading: [90]),
                            EntWardArea(x: 348, y: 54, heading: [90]),
                            EntWardArea(x: 348, y: 55, heading: [90]),
                            EntWardArea(x: 348, y: 56, heading: [90]),
                            EntWardArea(x: 348, y: 57, heading: [90]),
                            EntWardArea(x: 348, y: 58, heading: [90]),
                            EntWardArea(x: 348, y: 59, heading: [90]),
                            EntWardArea(x: 348, y: 60, heading: [90]),
                            EntWardArea(x: 348, y: 61, heading: [90]),
                            EntWardArea(x: 348, y: 62, heading: [90]),
                            EntWardArea(x: 348, y: 63, heading: [90]),
                            EntWardArea(x: 348, y: 64, heading: [90]),
                            EntWardArea(x: 348, y: 65, heading: [90]),
                            EntWardArea(x: 348, y: 66, heading: [90]),
                            EntWardArea(x: 348, y: 67, heading: [90]),
                            EntWardArea(x: 348, y: 68, heading: [90, 135, 180])
                        ]
                    } else {
                        wardArea = [
                            EntWardArea(x: innermostWard.x, y: innermostWard.y, heading: innermostWard.headings)
                        ]
                    }
                    
                    let headingForCompensation = majorSection.average - uvdBuffer[0].heading
                    
                    if let curResult = curResult {
                        self.debug_ent_compensated_traj = nil

                        struct EntTrackCandidateResult {
                            let dist: Float
                            let result: FineLocationTrackingOutput
                            let wardX: Float
                            let wardY: Float
                            let pathHeading: Float
                            let compensatedTraj: [[Double]]
                        }
                        
                        let candidateInputs: [(wardX: Float, wardY: Float, pathHeading: Float)] = wardArea!.flatMap { area in
                            area.heading.map { heading in
                                (wardX: area.x, wardY: area.y, pathHeading: heading)
                            }
                        }
                        
                        let candidateResults = NSLock()
                        var evaluatedCandidates = [EntTrackCandidateResult]()
                        
                        DispatchQueue.concurrentPerform(iterations: candidateInputs.count) { candidateIndex in
                            let candidate = candidateInputs[candidateIndex]
                            let wardX = candidate.wardX
                            let wardY = candidate.wardY
                            let pathHeading = candidate.pathHeading
                            
//                            JupiterLogger.i(tag: "JupiterCalcManager", message: "(onUvdResult) index:\(uvd.index) - EntTrack Finished : ward=(\(wardX), \(wardY)) heading=\(pathHeading)")
                            
                            let startHeading = Float(TJLabsUtilFunctions.shared.compensateDegree(Double(pathHeading) - Double(headingForCompensation)))
                            var coord: [Float] = [0, 0]
                            var heading: Float = startHeading
                            
                            var offset: [Float] = [0, 0]
                            var resultBuffer = [[Float]]()
                            resultBuffer.reserveCapacity(max(uvdBuffer.count - 1, 0))
                            
                            for i in 1..<uvdBuffer.count {
                                let curUvd = uvdBuffer[i]
                                let preUvd = uvdBuffer[i-1]
                                
                                let diffHeading: Float = Float(curUvd.heading - preUvd.heading)
                                let updatedHeading = TJLabsUtilFunctions.shared.compensateDegree(Double(heading + diffHeading))
                                let updatedHeadingRadian = TJLabsUtilFunctions.shared.degree2radian(degree: updatedHeading)
                                
                                let dx = curUvd.length * cos(updatedHeadingRadian)
                                let dy = curUvd.length * sin(updatedHeadingRadian)
                                
                                coord[0] += Float(dx)
                                coord[1] += Float(dy)
                                heading = Float(updatedHeading)
                                
                                if uvdBuffer[i].index == userPeak.peak_index {
                                    offset[0] = Float(wardX) - coord[0]
                                    offset[1] = Float(wardY) - coord[1]
                                }
                                
                                resultBuffer.append([coord[0], coord[1], heading])
                            }
                            
                            guard !resultBuffer.isEmpty else { return }
                            
                            var compensatedBuffer = [[Float]]()
                            compensatedBuffer.reserveCapacity(resultBuffer.count)
                            for value in resultBuffer {
                                let new: [Float] = [value[0] + offset[0], value[1] + offset[1], value[2]]
                                compensatedBuffer.append(new)
                            }
                            
                            let sampleCount = 7
                            let lastIndex = compensatedBuffer.count - 1
                            var sampleIndices = [Int]()
                            if lastIndex == 0 {
                                sampleIndices = [0]
                            } else {
                                for sampleOrder in 0..<sampleCount {
                                    let ratio = Double(sampleOrder) / Double(sampleCount - 1)
                                    let sampledIndex = Int(round(ratio * Double(lastIndex)))
                                    if sampleIndices.last != sampledIndex {
                                        sampleIndices.append(sampledIndex)
                                    }
                                }
                            }
                            
                            var totalDist: Float = 0
                            var validSampleCount = 0
                            for sampleIndex in sampleIndices {
                                let sample = compensatedBuffer[sampleIndex]
                                let sampleX = sample[0]
                                let sampleY = sample[1]
                                let sampleHeading = TJLabsUtilFunctions.shared.compensateDegree(Double(sample[2]))
                                
                                var sampleResult = curResult
                                sampleResult.x = sampleX
                                sampleResult.y = sampleY
                                sampleResult.absolute_heading = Float(sampleHeading)
                                
                                guard let samplePm = PathMatcher.shared.pathMatching(sectorId: sectorId,
                                                                                     building: sampleResult.building_name,
                                                                                     level: sampleResult.level_name,
                                                                                     x: sampleResult.x, y: sampleResult.y, heading: sampleResult.absolute_heading, isUseHeading: true, mode: .MODE_VEHICLE, paddingValues: JupiterMode.PADDING_VALUES_MEDIUM) else {
                                    validSampleCount = 0
                                    break
                                }
                                
                                let dx = sampleX - samplePm.x
                                let dy = sampleY - samplePm.y
                                let sampleDist = sqrt(dx*dx + dy*dy)
                                totalDist += sampleDist
                                validSampleCount += 1
                            }
                            
                            guard validSampleCount == sampleIndices.count, validSampleCount > 0 else { return }
                            let dist = totalDist / Float(validSampleCount)
                            
                            let lastX = compensatedBuffer[lastIndex][0]
                            let lastY = compensatedBuffer[lastIndex][1]
                            let lastHeading = TJLabsUtilFunctions.shared.compensateDegree(Double(compensatedBuffer[lastIndex][2]))
                            var lastResult = curResult
                            lastResult.x = lastX
                            lastResult.y = lastY
                            lastResult.absolute_heading = Float(lastHeading)
                            
                            guard let lastPm = PathMatcher.shared.pathMatching(sectorId: sectorId,
                                                                               building: lastResult.building_name,
                                                                               level: lastResult.level_name,
                                                                               x: lastResult.x, y: lastResult.y, heading: lastResult.absolute_heading, isUseHeading: true, mode: .MODE_VEHICLE, paddingValues: JupiterMode.PADDING_VALUES_MEDIUM) else { return }
                            
                            lastResult.x = lastPm.x
                            lastResult.y = lastPm.y
                            
                            let candidateResult = EntTrackCandidateResult(dist: dist,
                                                                         result: lastResult,
                                                                         wardX: wardX,
                                                                         wardY: wardY,
                                                                         pathHeading: pathHeading,
                                                                         compensatedTraj: compensatedBuffer.map { [Double($0[0]), Double($0[1]), Double($0[2])] })
                            candidateResults.lock()
                            evaluatedCandidates.append(candidateResult)
                            candidateResults.unlock()
                        }
                        
                        if let bestCandidate = evaluatedCandidates.min(by: { $0.dist < $1.dist }) {
                            self.debug_ent_compensated_traj = bestCandidate.compensatedTraj
                            var tempResult = bestCandidate.result
                            tempResult.building_name = entManager.getEntTrackEndBuilding()
                            tempResult.level_name = innermostWard.level.name
                            JupiterLogger.i(tag: "JupiterCalcManager", message: "(onUvdResult) index:\(uvd.index) - EntTrack Finished : wardXY:[\(bestCandidate.wardX),\(bestCandidate.wardY)] // headings:\(bestCandidate.pathHeading) // dist \(bestCandidate.dist) // tempResult \(tempResult)")
                            startIndoorTracking(uvd: uvd, fltResult: tempResult)
                        }
                    }
                }
            }
            
            if entManager.forcedStopEntTrack(bleAvg: bleData, sec: 30) || forceStop {
                // Entrance Tracking Finshid (Force)
                JupiterLogger.i(tag: "JupiterCalcManager", message: "(calcEntranceResult) index:\(uvd.index) - forcedStopEntTrack")
                if let blChanger = self.buildingLevelChanger {
                    if let buildingLevelByPeak = blChanger.getMatchedBuildingLevelByUserPeak(userPeak: userPeak) {
                        stackManager.stackBuildingLevelByPeak(buildingLevel: buildingLevelByPeak)
                        let buildingLevelByPeakBuffer = stackManager.getBuildingLevelByPeakBuffer(size: 3)
                        startIndoorSearching(uvd: uvd, blChanger: blChanger, buildingLevelByPeakBuffer: buildingLevelByPeakBuffer, force: true)
                    } else {
                        JupiterLogger.i(tag: "JupiterCalcManager", message: "(calcEntranceResult) buildingLevelByPeak is nil")
                    }
                } else {
                    JupiterLogger.i(tag: "JupiterCalcManager", message: "(calcEntranceResult) buildingLevelChanger is nil")
                }
                entManager.setEntTrackFinishedTimestamp(time: currentTime)
            }
        }
    }
    
    private func calcEntranceResult(currentTime: Int, entManager: EntranceManager, uvd: UserVelocity) {
        guard let entTrackResult = entManager.startEntTrack(currentTime: currentTime, uvd: uvd) else { return }
        self.curResult = entTrackResult
    }
    
    private func startIndoorSearching(uvd: UserVelocity, blChanger: BuildingLevelChanger, buildingLevelByPeakBuffer: [(String, String)], force: Bool = false) {
        if jupiterPhase == .NONE || force {
            if blChanger.isIndoorLevel(buildingLevelByPeakBuffer: buildingLevelByPeakBuffer) {
                jupiterPhase = .SEARCHING
                delegate?.isJupiterPhaseChanged(index: uvd.index, phase: jupiterPhase, xyh: nil)
                JupiterLogger.i(tag: "JupiterCalcManager", message: "(startIndoorSearching) start")
            } else {
                JupiterLogger.i(tag: "JupiterCalcManager", message: "(startIndoorSearching) isIndoorLevel result is nil")
            }
        }
    }
    
    private func calcIndoorSearching(userPeak: UserPeak?,
                                     buildingLevelByPeak: (String, String)?,
                                     mode: UserMode,
                                     userVelocity: UserVelocity,
                                     uvdBuffer: [UserVelocity]) {
        if jupiterPhase != .SEARCHING { return }
        
        guard let landmarkTagger = self.landmarkTagger else { return }
        guard let solutionEstimator = self.solutionEstimator else { return }
        guard let userPeak = userPeak else { return }
        guard let buildingLevelByPeak = buildingLevelByPeak else { return }
        
        peakHandling: do {
            let curIndex = userVelocity.index
            let building = buildingLevelByPeak.0
            let level = buildingLevelByPeak.1
            
            if userPeak.peak_index - searchingIndex < 5 {
                JupiterLogger.i(tag: "JupiterCalcManager", message: "(calcIndoorSearching) PEAK is too close with previous peak index")
                break peakHandling
            } else if userPeak.id == searcingId {
                JupiterLogger.i(tag: "JupiterCalcManager", message: "(calcIndoorSearching) same PEAK detected just before id:\(userPeak.id)")
                break peakHandling
            }
            guard let matchedWithUserPeak = landmarkTagger.findMatchedLandmarkWithUserPeak(userPeak: userPeak,
                                                                                           building: building,
                                                                                           level: level) else {
                JupiterLogger.i(tag: "JupiterCalcManager", message: "(calcIndoorSearching) cannot find matched landmark with user peak \(userPeak.id)")
                break peakHandling
            }
            
            self.debug_landmark = matchedWithUserPeak
            stackManager.stackUserPeak(userPeak: userPeak)
            
            let userPeakBuffer = stackManager.getUserPeakBuffer()
            if userPeakBuffer.count < 2 { break peakHandling }
            
            let olderUserPeak = userPeakBuffer[userPeakBuffer.count - 2]
            let recentUserPeak = userPeakBuffer[userPeakBuffer.count - 1]
            JupiterLogger.i(tag: "JupiterCalcManager", message: "(calcIndoorSearching) 2 Peaks : older= \(olderUserPeak.id), recent= \(recentUserPeak.id)")

            let uvdBufferForSearching = solutionEstimator.getUvdBufferForEstimation(startIndex: olderUserPeak.peak_index,
                                                                                    endIndex: userVelocity.index,
                                                                                    uvdBuffer: uvdBuffer)
            let uvdBufferForStraight = stackManager.getUvdBuffer(from: recentUserPeak.peak_index)
            let isDrStraight = stackManager.isDrBufferStraightCircularStd(uvdBuffer: uvdBufferForStraight, condition: 5)
            guard let matchedWithOldUserPeak = landmarkTagger.findMatchedLandmarkWithUserPeak(userPeak: olderUserPeak,
                                                                                        building: building,
                                                                                        level: level) else {
                JupiterLogger.i(tag: "JupiterCalcManager", message: "(calcIndoorSearching) cannot find matched landmark with old user peak \(olderUserPeak.id)")
                break peakHandling
            }
            
            let pathHeadings = JupiterMode.DEFAULT_HEADINGS
            let hasMajorDirection = stackManager.checkHasMajorDirection(uvdBuffer: uvdBufferForSearching)
            JupiterLogger.i(tag: "JupiterCalcManager", message: "(calcIndoorSearching) hasMajorDirection= \(hasMajorDirection)")
            if hasMajorDirection {
                let majorSection = stackManager.extractSectionWithLeastChange(inputArray: uvdBufferForSearching.map{ Float($0.heading) })
                let searchTrajList = solutionEstimator.makeMultipleCandidateTrajectory(uvdBuffer: uvdBufferForSearching, majorSection: majorSection, pathHeadings: pathHeadings)
                JupiterLogger.i(tag: "JupiterCalcManager", message: "(calcIndoorSearching) searchTrajList.count= \(searchTrajList.count)")
                
                let searchResult = solutionEstimator.calculateLossParamAtEachCandInSearch(searchTrajList: searchTrajList,
                                                                                          userPeakBuffer: userPeakBuffer,
                                                                                          buildingLevelByUserPeak: buildingLevelByPeak,
                                                                                          landmarks: (matchedWithOldUserPeak, matchedWithUserPeak),
                                                                                          mode: mode, isDrStraight: isDrStraight.0,
                                                                                          lseResult: self.curLSEResult,
                                                                                          lseSnapshotBuffer: self.lseSnapshotBuffer)
                if let selectedSearch = solutionEstimator.calculateSearchResult(lossParamAtEachCand: searchResult) {
                    let bestResult = selectedSearch.headResult
                    solutionEstimator.setPreFixedLandmark(peakData: selectedSearch.recent)
                    self.debug_selected_search = selectedSearch
                    self.searchingIndex = userPeak.peak_index
                    self.curResult = bestResult
                    self.CallWhenFirstResponse()
                    JupiterLogger.i(tag: "JupiterCalcManager", message: "(calcIndoorSearching) searchResult= [index:\(bestResult.index), x:\(bestResult.x), y:\(bestResult.y), h:\(bestResult.absolute_heading)]")
                    stackManager.stackSearchResult(searchResult: bestResult)
                    let searchResultBuffer = stackManager.getSearchResultBuffer(size: 3)
                    if searchResultBuffer.count < 3 { break peakHandling }
                    
                    JupiterLogger.i(tag: "JupiterCalcManager", message: "(calcIndoorSearching) best searchResult lm= [\(selectedSearch.recent?.x), \(selectedSearch.recent?.y)")
                    JupiterLogger.i(tag: "JupiterCalcManager", message: "(calcIndoorSearching) best searchResult= [index:\(bestResult.index), x:\(bestResult.x), y:\(bestResult.y), h:\(bestResult.absolute_heading)]")
                    
                    guard let ixyhs = stackManager.propagateUsingUvd(uvdBuffer: uvdBufferForSearching, fltResult: bestResult) else { break peakHandling }
                    JupiterLogger.i(tag: "JupiterCalcManager", message: "(calcIndoorSearching) propagateUsingUvd : curIndex= \(userVelocity.index)")
                    JupiterLogger.i(tag: "JupiterCalcManager", message: "(calcIndoorSearching) propagateUsingUvd : ixyhs=[\(ixyhs.x), \(ixyhs.y), \(ixyhs.heading)]")
                    var curResult = bestResult
                    let propagatedX = bestResult.x + ixyhs.x
                    let propagatedY = bestResult.y + ixyhs.y
                    let propagatedH = Float(TJLabsUtilFunctions.shared.compensateDegree(Double(bestResult.absolute_heading + ixyhs.heading)))
                    curResult.x = propagatedX
                    curResult.y = propagatedY
                    curResult.absolute_heading = propagatedH
                    guard let pmResult = PathMatcher.shared.pathMatching(sectorId: sectorId, building: curResult.building_name, level: curResult.level_name, x: curResult.x, y: curResult.y, heading: curResult.absolute_heading, isUseHeading: false, mode: mode, paddingValues: JupiterMode.PADDING_VALUES_MEDIUM) else { break peakHandling }
                    curResult.x = pmResult.x
                    curResult.y = pmResult.y
                    curResult.absolute_heading = pmResult.heading
                    
                    correctionIndex = userPeak.peak_index
                    correctionId = userPeak.id
                    startIndoorTracking(uvd: userVelocity, fltResult: curResult)
                    
//                    let isConnected = checkResultConnectionForTracking(preResult: preSearchResult, curResult: curSearchResult, uvdBuffer: uvdBufferForSearching, mode: mode)
//                    if isConnected {
//                        guard let ixyhs = stackManager.propagateUsingUvd(uvdBuffer: uvdBufferForSearching, fltResult: bestResult) else { break peakHandling }
//                        var curResult = bestResult
//                        let propagatedX = bestResult.x + ixyhs.x
//                        let propagatedY = bestResult.y + ixyhs.y
//                        let propagatedH = Float(TJLabsUtilFunctions.shared.compensateDegree(Double(bestResult.absolute_heading + ixyhs.heading)))
//                        curResult.x = propagatedX
//                        curResult.y = propagatedY
//                        curResult.absolute_heading = propagatedH
//                        guard let pmResult = PathMatcher.shared.pathMatching(sectorId: sectorId, building: curResult.building_name, level: curResult.level_name, x: curResult.x, y: curResult.y, heading: curResult.absolute_heading, isUseHeading: false, mode: mode, paddingValues: JupiterMode.PADDING_VALUES_MEDIUM) else { break peakHandling }
//                        curResult.x = pmResult.x
//                        curResult.y = pmResult.y
//                        curResult.absolute_heading = pmResult.heading
//                        
//                        correctionIndex = userPeak.peak_index
//                        correctionId = userPeak.id
//                        startIndoorTracking(uvd: userVelocity, fltResult: curResult)
//                    }
                }
            }
        }
    }
    
    private func checkResultConnectionForTracking(preResult: FineLocationTrackingOutput, curResult: FineLocationTrackingOutput, uvdBuffer: [UserVelocity], mode: UserMode) -> Bool {
        if (preResult.index == 0 || curResult.index == 0) { return false }
        
        let distanceCondition: Float = mode == .MODE_PEDESTRIAN ? 10 : 20
        let headingCondition: Float = mode == .MODE_PEDESTRIAN ? 15 : 30

        if (curResult.index <= preResult.index) {
            JupiterLogger.i(tag: "JupiterCalcManager", message: "(checkResultConnectionForTracking) : curResultIndex=\(curResult.index) , preResultIndex=\(preResult.index)")
            return false
        } else {
            var drBufferStartIndex: Int = 0
            var drBufferEndIndex: Int = 0
            var headingCompensation: Float = 0
            for i in 0..<uvdBuffer.count {
                if uvdBuffer[i].index == preResult.index {
                    drBufferStartIndex = i
                    headingCompensation = preResult.absolute_heading -  Float(uvdBuffer[i].heading)
                }
                
                if uvdBuffer[i].index == curResult.index {
                    drBufferEndIndex = i
                }
            }
            
            guard let prePmResult = PathMatcher.shared.pathMatching(sectorId: sectorId, building: preResult.building_name, level: preResult.level_name, x: preResult.x, y: preResult.y, heading: preResult.absolute_heading, isUseHeading: false, mode: mode, paddingValues: JupiterMode.PADDING_VALUES_MEDIUM) else { return false }
            guard let curPmResult = PathMatcher.shared.pathMatching(sectorId: sectorId, building: curResult.building_name, level: curResult.level_name, x: curResult.x, y: curResult.y, heading: curResult.absolute_heading, isUseHeading: false, mode: mode, paddingValues: JupiterMode.PADDING_VALUES_MEDIUM) else { return false }

            var propagatedXyh: [Float] = [prePmResult.x, prePmResult.y, prePmResult.heading]
            for i in drBufferStartIndex..<drBufferEndIndex {
                let length = uvdBuffer[i].length
                let heading = uvdBuffer[i].heading + Double(headingCompensation)
                let dx = Float(length*cos(TJLabsUtilFunctions.shared.degree2radian(degree: heading)))
                let dy = Float(length*sin(TJLabsUtilFunctions.shared.degree2radian(degree: heading)))
                    
                propagatedXyh[0] += dx
                propagatedXyh[1] += dy
            }
            let dh = Float(uvdBuffer[drBufferEndIndex].heading - uvdBuffer[drBufferStartIndex].heading)
            propagatedXyh[2] += dh
            propagatedXyh[2] = Float(TJLabsUtilFunctions.shared.compensateDegree(Double(propagatedXyh[2])))
            
            guard let pmResult = PathMatcher.shared.pathMatching(sectorId: sectorId, building: curResult.building_name, level: curResult.level_name, x: propagatedXyh[0], y: propagatedXyh[1], heading: propagatedXyh[2], isUseHeading: false, mode: mode, paddingValues: JupiterMode.PADDING_VALUES_MEDIUM) else { return false }
            
            let diffX = abs(pmResult.x - curPmResult.x)
            let diffY = abs(pmResult.y - curPmResult.y)
            let curResultHeading = Float(TJLabsUtilFunctions.shared.compensateDegree(Double(curPmResult.heading)))
            
            var diffH: Float = abs(pmResult.heading - curResultHeading)
            if (diffH > 270) { diffH = 360 - diffH }
            
            let rendezvousDistance = sqrt(diffX*diffX + diffY*diffY)
            JupiterLogger.i(tag: "JupiterCalcManager", message: "(checkResultConnectionForTracking) : rendezvousDistance=\(rendezvousDistance) , diffH=\(diffH)")
            if (rendezvousDistance <= distanceCondition) && diffH <= headingCondition {
                return true
            }
        }
        return false
    }
    
    private func startIndoorTracking(uvd: UserVelocity, fltResult: FineLocationTrackingOutput?) {
        jupiterPhase = .TRACKING
        guard let fltResult = fltResult else { return }
        curResult = fltResult
        kalmanFilter?.activateKalmanFilter(fltResult: fltResult)
        CallWhenFirstResponse()
        delegate?.isJupiterPhaseChanged(index: uvd.index, phase: jupiterPhase, xyh: [fltResult.x, fltResult.y, fltResult.absolute_heading])
        JupiterLogger.i(tag: "JupiterCalcManager", message: "(startIndoorTracking) : start indoor tracking at uvd:\(fltResult.index) // phase = \(jupiterPhase)")
        JupiterLogger.i(tag: "JupiterCalcManager", message: "(startIndoorTracking) : start indoor tracking at xyh:[\(fltResult.x), \(fltResult.y), \(fltResult.absolute_heading)]")
    }
    
    private func calcIndoorResult(mode: UserMode, uvd: UserVelocity, olderPeakIndex: Int?, jumpInfo: JumpInfo?, uturnLink: Bool = false) {
        let (tuResult, isDidPathTrajMatching) = updateResultFromTimeUpdate(mode: mode, uvd: uvd, pastUvd: pastUvd, pathMatchingCondition: self.pathMatchingCondition, uturnLink: uturnLink)
        guard var tuResult = tuResult else { return }
        updateDebugTuResult()
        guard let curResult = self.curResult else { return }
        let pathMatchingArea = PathMatcher.shared.checkInEntranceMatchingArea(sectorId: sectorId, building: tuResult.building_name, level: tuResult.level_name, x: tuResult.x, y: tuResult.y)
        
        var mustInSameLink = true
        
        if isDidPathTrajMatching {
            // 1. Path-Traj Matching 결과가 있을 경우
            // PDR 에서만 적용, DR 모드에서는 항상 false임
            mustInSameLink = false
        } else if pathMatchingArea != nil || PathMatcher.shared.isInNode {
            // 2. Node에 있거나 Entrance Matching Area에 해당하는 경우
            // 길끝에 위치하는지 확인
            mustInSameLink = false
            let isInMapEnd = PathMatcher.shared.checkIsInMapEnd(sectorId: sectorId, tuResult: tuResult, mode: mode)
            JupiterLogger.i(tag: "JupiterCalcManager", message: "(calcIndoorResult) : index= \(uvd.index) // isInNode= \(PathMatcher.shared.isInNode) // isInMapEnd= \(isInMapEnd)")
            if isInMapEnd {
                tuResult.x = curResult.x
                tuResult.y = curResult.y
                kalmanFilter?.updateTuPosition(coord: [curResult.x, curResult.y])
            }
        }
        let isNeedUpdateAnchorNode = sectionController.extendedCheckIsNeedAnchorNodeUpdate(uvdLength: uvd.length, curHeading: curResult.absolute_heading)
        if isNeedUpdateAnchorNode {
            PathMatcher.shared.updateAnchorNode(sectorId: sectorId, fltResult: curResult, mode: mode, sectionNumber: sectionController.getSectionNumber())
        }
        kalmanFilter?.updateTuInformation(uvd: uvd, olderPeakIndex: olderPeakIndex)
        
        let indoorResult = makeCurrentResult(input: tuResult, mustInSameLink: mustInSameLink, pathMatchingType: .NARROW, phase: .TRACKING, jumpInfo: jumpInfo, mode: mode)
        self.curResult = indoorResult
    }
    
    private func updateResultFromTimeUpdate(mode: UserMode, uvd: UserVelocity, pastUvd: UserVelocity,
                                            pathMatchingCondition: PathMatchingCondition, uturnLink: Bool) -> (FineLocationTrackingOutput?, Bool) {
        guard let kalmanFilter = self.kalmanFilter else { return (nil, false) }
        if mode == .MODE_PEDESTRIAN {
//            result = kalmanFilter.pdrTimeUpdate(region: region, sectorId: sectorId, uvd: uvd, pastUvd: pastUvd, pathMatchingCondition: pathMatchingCondition)
            return (nil, false)
        } else {
            guard let drTuResult = kalmanFilter.drTimeUpdate(region: region, sectorId: sectorId, uvd: uvd, pastUvd: pastUvd, uturnLink: uturnLink, isInNode: PathMatcher.shared.isInNode) else { return (nil, false) }
            return (drTuResult, false)
        }
    }
    
    private func getRecentAndOlderUserPeak(userPeakAndLinksBuffer: [(UserPeak, [LinkData])]) -> (recent: (UserPeak, [LinkData]), old: (UserPeak, [LinkData]))? {
        let recentUserPeakAndLinks = userPeakAndLinksBuffer[userPeakAndLinksBuffer.count - 1]
        let recentUserPeak = recentUserPeakAndLinks.0
        var oldP: (UserPeak, [LinkData])?
        for pAndL in userPeakAndLinksBuffer.reversed() {
            let diffPeakIndex = recentUserPeak.peak_index - pAndL.0.peak_index
            if diffPeakIndex > 10 {
                oldP = pAndL
                break
            }
        }
        guard let olderUserPeakAndLinks = oldP else { return nil }
        
        return (recentUserPeakAndLinks, olderUserPeakAndLinks)
    }
    
    private func applyCorrectionWithPeaks(userPeak: UserPeak?,
                                          mode: UserMode,
                                          userVelocity: UserVelocity,
                                          uvdBuffer: [UserVelocity]) {
        guard let landmarkTagger = self.landmarkTagger else { return }
        guard let solutionEstimator = self.solutionEstimator else { return }
        guard let kalmanFilter = self.kalmanFilter else { return }
        guard let userPeak = userPeak else { return }
        
        peakHandling: do {
            // LandmarkTag
            if userPeak.peak_index - correctionIndex < 10 {
                JupiterLogger.i(tag: "JupiterCalcManager", message: "(applyCorrectionWithPeaks) PEAK is too close with previous landmark correction at \(userVelocity.index) uvd index")
                break peakHandling
            } else if userPeak.id == correctionId {
                JupiterLogger.i(tag: "JupiterCalcManager", message: "(applyCorrectionWithPeaks) same PEAK detected just before id:\(userPeak.id)")
                break peakHandling
            }
            let shouldSkipCorrectionAfterRecovery = userPeak.peak_index <= recoveryIndex

            // MARK: - Use Two peaks anytime
            let curResultBuffer = stackManager.getCurResultBuffer()
            if let matchedWithUserPeak = landmarkTagger.findMatchedLandmarkWithUserPeak(userPeak: userPeak,
                                                                                       curResult: self.curResult,
                                                                                       curResultBuffer: curResultBuffer),
               let linkInfosWhenPeak = PathMatcher.shared.getLinkInfosWithResult(sectorId: sectorId,
                                                                                   result: matchedWithUserPeak.matchedResult,
                                                                                   checkAll: true,
                                                                                   mode: mode)
            {
                self.debug_landmark = matchedWithUserPeak.landmark
                stackManager.stackUserPeakAndLinks(userPeakAndLinks: (userPeak, linkInfosWhenPeak))
            } else {
                JupiterLogger.i(tag: "JupiterCalcManager", message: "(applyCorrectionWithPeaks) cannot find matched landmark with user peak \(userPeak.id) or cannot find linkInfosWhenPeak")
                break peakHandling
            }

            if shouldSkipCorrectionAfterRecovery {
                JupiterLogger.i(tag: "JupiterCalcManager", message: "(applyCorrectionWithPeaks) Recovery worked at \(recoveryIndex) uvd index")
                break peakHandling
            }

            if jupiterPhase == .ENTERING {
                break peakHandling
            }

            let userPeakAndLinksBuffer = stackManager.getUserPeakAndLinksBuffer()
            if userPeakAndLinksBuffer.count < 2 { break peakHandling }

            guard let curResult = self.curResult,
                  let curPmResult = self.curPathMatchingResult,
                  let tuResult = kalmanFilter.getTuResult() else {
                break peakHandling
            }
            
            guard let recentAndOld = getRecentAndOlderUserPeak(userPeakAndLinksBuffer: userPeakAndLinksBuffer) else { break peakHandling }
            let recentUserPeak = recentAndOld.recent.0
            let olderUserPeak = recentAndOld.old.0
            
            JupiterLogger.i(tag: "JupiterCalcManager", message: "(applyCorrectionWithPeaks) 2 Peaks : older= \(olderUserPeak.id), recent= \(recentUserPeak.id)")
            let uvdBufferForEstimation = solutionEstimator.getUvdBufferForEstimation(startIndex: olderUserPeak.peak_index, endIndex: userVelocity.index, uvdBuffer: uvdBuffer)
            
            let pmResultBuffer = stackManager.getCurPmResultBuffer(from: olderUserPeak.peak_index)
            let pathHeadings = stackManager.makeHeadingSet(resultBuffer: pmResultBuffer)

            let uvdBufferForStraight = stackManager.getUvdBuffer(from: userPeak.peak_index)
            let isDrStraight = stackManager.isDrBufferStraightCircularStd(uvdBuffer: uvdBufferForStraight, condition: 5)
            let isTurn = !stackManager.isDrBufferStraightCircularStd(uvdBuffer: uvdBufferForStraight, condition: 15).0

            guard let tuResultWhenRecentPeak = kalmanFilter.getTuResultWithUvdIndex(index: recentUserPeak.peak_index) else {
                break peakHandling
            }

            if let matchedWithOlderPeak = landmarkTagger.findMatchedLandmarkWithUserPeak(userPeak: olderUserPeak,
                                                                                        curResult: curResult,
                                                                                        curResultBuffer: curResultBuffer),
               let matchedWithRecentPeak = landmarkTagger.findMatchedLandmarkWithUserPeak(userPeak: recentUserPeak,
                                                                                         curResult: curResult,
                                                                                         curResultBuffer: curResultBuffer) {
                let hasMajorDirection = stackManager.checkHasMajorDirection(uvdBuffer: uvdBufferForEstimation)
                if hasMajorDirection {
                    let majorSection = stackManager.extractSectionWithLeastChange(inputArray: uvdBufferForEstimation.map { Float($0.heading) })
                    let candTrajList = solutionEstimator.makeMultipleCandidateTrajectory(uvdBuffer: uvdBufferForEstimation,
                                                                                             majorSection: majorSection,
                                                                                             pathHeadings: pathHeadings,
                                                                                             endHeading: tuResult.absolute_heading)
                    let matchedNode = PathMatcher.shared.getNodeInfoWithResult(sectorId: sectorId,
                                                                           result: matchedWithRecentPeak.matchedResult,
                                                                           checkAll: true,
                                                                           acceptDist: 15,
                                                                           mode: mode)
                    
//                    let passingLinkBuffer = PathMatcher.shared.getPassingLinkBuffer(index: olderUserPeak.peak_index)
                    let passingLinkBuffer = PathMatcher.shared.getPassingLinkBuffer()
                    JupiterLogger.i(tag: "JupiterCalcManager", message: "(applyCorrectionWithPeaks) passingLinkBuffer= \(passingLinkBuffer)")
                    let passingLinkGroupNumSet = Set(passingLinkBuffer.map { $0.link_group_number })
                    let isLinkNotChanged = isTurn && passingLinkGroupNumSet.count == 1 && !PathMatcher.shared.isInNode ? true : false
                    JupiterLogger.i(tag: "JupiterCalcManager", message: "(applyCorrectionWithPeaks) linkConnection : isTurn= \(isTurn), passingLinkGroupNumSet= \(passingLinkGroupNumSet) , isInNode= \(PathMatcher.shared.isInNode) -> isLinkNotChanged= \(isLinkNotChanged)")
                    
                    let lossParamResult = solutionEstimator.calculateLossParamAtEachCand(trackingTrajList: candTrajList,
                                                                                         userPeakAndLinksBuffer: userPeakAndLinksBuffer,
                                                                                         landmarks: (matchedWithOlderPeak.0, matchedWithRecentPeak.0),
                                                                                         tuResultWhenRecentPeak: tuResultWhenRecentPeak,
                                                                                         curPmResult: curPmResult,
                                                                                         mode: mode, matchedNode: matchedNode, preFixed: preFixed, isDrStraight: isDrStraight.0)
                    let filteredCandResult = solutionEstimator.calculateJupiterResult(lossParamAtEachCand: lossParamResult, isLinkNotChanged: isLinkNotChanged)
                    if let selectedCandResult = solutionEstimator.selectCandidate(filtered: filteredCandResult) {
                        let trackingResult = selectedCandResult.0
                        self.debug_ratio = selectedCandResult.1
                        
                        let headResult = trackingResult.headResult
                        var trackingCoord = [Float]()
                        var paddings = JupiterMode.PADDING_VALUES_LARGE
                        var axisConstraint: PathMatchingAxisConstraint?

                        if isDrStraight.0 {
                            if let linkData = PathMatcher.shared.getLinkData(sectorId: sectorId,
                                                                            building: curResult.building_name,
                                                                            level: curResult.level_name,
                                                                            mode: mode),
                               let recent = trackingResult.recent,
                               let _ = trackingResult.older {
                                let bestCand = recent
                                let linkNums = bestCand.matched_links
                                if linkNums.count == 1 {
                                    if let matchedLink = linkData[linkNums[0]] {
                                        paddings = PathMatcher.shared.getLimitationRangeWithLink(link: matchedLink)
                                        axisConstraint = PathMatcher.shared.getAxisConstraintWithLink(link: matchedLink)
                                    }
                                } else {
                                    let limitType: LimitationType = .SMALL_LIMIT
                                    paddings = PathMatcher.shared.getLimitationRangeWithType(limitType: limitType)
                                }
                            }
                        }
                        
                        self.debug_selected_cand = trackingResult
                        self.correctionIndex = userPeak.peak_index
                        self.uvdIndexWhenCorrection = userVelocity.index
                        self.preFixed = FixedPeak(id: recentUserPeak.id,
                                                  peak_index: recentUserPeak.peak_index,
                                                  peak_rssi: recentUserPeak.peak_rssi,
                                                  lm_x: selectedCandResult.0.recent?.x,
                                                  lm_y: selectedCandResult.0.recent?.y,
                                                  lm_links: selectedCandResult.0.links,
                                                  lm_linkGroups: selectedCandResult.0.linkGroups)
                        stackManager.editCurResultBuffer(sectorId: sectorId,
                                                         mode: mode,
                                                         from: userPeak.peak_index,
                                                         shifteTraj: trackingResult.traj,
                                                         paddings: paddings,
                                                         axisConstraint: axisConstraint)

                        let updatedCurPmResult = stackManager.editCurPmResultBuffer(sectorId: sectorId,
                                                                                    mode: mode,
                                                                                    from: recentUserPeak.peak_index,
                                                                                    shifteTraj: trackingResult.traj,
                                                                                    paddings: paddings,
                                                                                    axisConstraint: axisConstraint)

                        kalmanFilter.editTuResultBuffer(sectorId: sectorId,
                                                        mode: mode,
                                                        from: userPeak.peak_index,
                                                        shifteTraj: trackingResult.traj,
                                                        curResult: curResult,
                                                        paddings: paddings,
                                                        axisConstraint: axisConstraint)

                        trackingCoord = [updatedCurPmResult.x, updatedCurPmResult.y, updatedCurPmResult.absolute_heading]
                        
                        if !isLinkNotChanged {
                            let curPmResultBufferFromRecentPeak = stackManager.getCurPmResultBuffer(from: recentUserPeak.peak_index)
                            PathMatcher.shared.editPassingLinkBuffer(from: recentUserPeak.peak_index,
                                                                     sectorId: sectorId,
                                                                     curPmResultBuffer: curPmResultBufferFromRecentPeak,
                                                                     mode: mode)
                        }

                        if let pmResult = PathMatcher.shared.pathMatching(sectorId: sectorId,
                                                                         building: curResult.building_name,
                                                                         level: curResult.level_name,
                                                                         x: trackingCoord[0],
                                                                         y: trackingCoord[1],
                                                                         heading: trackingCoord[2],
                                                                         isUseHeading: true,
                                                                         mode: mode,
                                                                         paddingValues: paddings,
                                                                         axisConstraint: axisConstraint) {
                            curPathMatchingResult = headResult
                            curPathMatchingResult?.x = pmResult.x
                            curPathMatchingResult?.y = pmResult.y
                            curPathMatchingResult?.absolute_heading = pmResult.heading

                            JupiterLogger.i(tag: "JupiterCalcManager", message: "(applyCorrectionWithPeaks) 2 Peaks : best= \(headResult.x),\(headResult.y),\(headResult.absolute_heading)")
                            JupiterLogger.i(tag: "JupiterCalcManager", message: "(applyCorrectionWithPeaks) 2 Peaks : pm= \(pmResult.x),\(pmResult.y),\(pmResult.heading)")

                            kalmanFilter.updateTuPosition(coord: [pmResult.x, pmResult.y])
                            self.curResult? = curPathMatchingResult!
                        } else {
                            kalmanFilter.updateTuPosition(coord: trackingCoord)
                            self.curResult? = headResult
                        }

                        if let curPmResult2 = curPathMatchingResult,
                           let matchedLink = PathMatcher.shared.getLinkInfoWithResult(sectorId: sectorId,
                                                                                      result: curPmResult2,
                                                                                      checkAll: true,
                                                                                      mode: mode) {
                            let jumpInfo = JumpInfo(link_number: matchedLink.number, jumped_nodes: [])
                            PathMatcher.shared.updateNodeAndLinkInfo(sectorId: sectorId,
                                                                     uvdIndex: userVelocity.index,
                                                                     curResult: curPmResult2,
                                                                     jumpInfo: jumpInfo,
                                                                     mode: mode,
                                                                     pLinkCutIndex: recentUserPeak.peak_index)
                        } else {
                            PathMatcher.shared.initPassedLinkInfo()
                        }
                        
                    }
                }
                
                recentUserPeakIndex = recentUserPeak.peak_index
                recentLandmarkPeaks = matchedWithRecentPeak.landmark.peaks
            }
        }
    }
    
    private func makeCurrentResult(input: FineLocationTrackingOutput,
                                   mustInSameLink: Bool,
                                   pathMatchingType: PathMatchingType,
                                   phase: JupiterPhase,
                                   jumpInfo: JumpInfo?,
                                   mode: UserMode) -> FineLocationTrackingOutput {
        JupiterLogger.i(tag: "JupiterCalcManager", message: "(makeCurrentResult) - input: \(input.building_name), \(input.level_name), [\(input.x),\(input.y),\(input.absolute_heading)]")
        var result = input
        let curIndex = curUvd.index
        result.index = curIndex
        
        let buildingName: String = result.building_name
        let levelName: String = TJLabsUtilFunctions.shared.removeLevelDirectionString(levelName: result.level_name)
        result.level_name = levelName
        
        var isPmFailed = false
        let isPdrMode = curUserModeEnum == UserMode.MODE_PEDESTRIAN
        
        var headingRange = Float(JupiterMode.HEADING_RANGE)
        var isUseHeading = false
        if mode == .MODE_PEDESTRIAN {
            // PDR
            if pathMatchingType == .NARROW {
                isUseHeading = true
                headingRange -= 10
            }
            let paddings = (!isPdrMode && levelName == "B0") ? JupiterMode.PADDING_VALUES_SMALL : self.paddingValues
            if let pmResult = PathMatcher.shared.pathMatching(sectorId: sectorId, building: buildingName, level: levelName, x: result.x, y: result.y, heading: result.absolute_heading, headingRange: headingRange, isUseHeading: isUseHeading, mode: .MODE_PEDESTRIAN, paddingValues: paddings) {
                result.x = pmResult.x
                result.y = pmResult.y
                result.absolute_heading = pmResult.heading
            } else {
                isPmFailed = true
            }
        } else {
            // DR
            JupiterLogger.i(tag: "JupiterCalcManager", message: "(makeCurrentResult) - pathMatchingType= \(pathMatchingType)")
            isUseHeading = !JupiterResultState.isVenus
            var axisConstraint: PathMatchingAxisConstraint?
            if let kf = kalmanFilter, pathMatchingType == .NARROW {
                self.paddingValues = kf.getPaddings()
                axisConstraint = kf.getPathMatchingAxisConstraint()
            }
            
            let paddings = (!isPdrMode && levelName == "B0") ? JupiterMode.PADDING_VALUES_MEDIUM : self.paddingValues
            JupiterLogger.i(tag: "JupiterCalcManager", message: "(makeCurrentResult) - result: paddings \(paddings)")
            if let pmResult = PathMatcher.shared.pathMatching(sectorId: sectorId, building: buildingName, level: levelName, x: result.x, y: result.y, heading: result.absolute_heading, headingRange: headingRange, isUseHeading: isUseHeading, mode: .MODE_VEHICLE, paddingValues: paddings, axisConstraint: levelName == "B0" ? nil : axisConstraint) {
                result.x = pmResult.x
                result.y = pmResult.y
                result.absolute_heading = pmResult.heading
                uvdGenerator?.updateDrVelocityScale(scale: Double(pmResult.scale))
                JupiterLogger.i(tag: "JupiterCalcManager", message: "(makeCurrentResult) - result: \(result.building_name), \(result.level_name), [\(result.x),\(result.y),\(result.absolute_heading)]")
            } else {
                uvdGenerator?.updateDrVelocityScale(scale: 1.0)
                isPmFailed = true
            }
        }
        
        if isUseHeading && phase == .TRACKING, let curResult = self.curResult {
            JupiterLogger.i(tag: "JupiterCalcManager", message: "(makeCurrentResult) - tu correction (1): curResult xy= [\(result.x), \(result.y)]")
            let diffX = result.x - curResult.x
            let diffY = result.y - curResult.y
            let diffNorm = sqrt(diffX*diffX + diffY*diffY)
            if diffNorm >= 2 {
                kalmanFilter?.updateTuPosition(coord: [result.x, result.y])
                let isInLevelChangeArea = buildingLevelChanger!.checkInLevelChangeArea(sectorId: sectorId, building: buildingName, level: levelName, x: result.x, y: result.y, mode: mode)
                PathMatcher.shared.updateNodeAndLinkInfo(sectorId: sectorId, uvdIndex: curIndex, curResult: result, jumpInfo: jumpInfo, mode: mode, isInLevelChangeArea: isInLevelChangeArea, checkOption: true)
            }
            JupiterLogger.i(tag: "JupiterCalcManager", message: "(makeCurrentResult) - tu correction (1): diffNorm= \(diffNorm), xyh= [\(result.x), \(result.y), \(result.absolute_heading)]")
        }
        
        let isInNode = PathMatcher.shared.isInNode
        
        if mustInSameLink && levelName != "B0", let curLinkInfo = PathMatcher.shared.getCurPassedLinkInfo(), !isInNode {
            let userCoord = curLinkInfo.user_coord
            let linkDirs = curLinkInfo.included_heading
            JupiterLogger.i(tag: "JupiterCalcManager", message: "(makeCurrentResult) - curLinkInfo: userCoord= \(userCoord), linkDirs= \(linkDirs)")
            if (userCoord.count == 2 && linkDirs.count == 2) {
                let MARGIN: Float = 30
                
                let linkDir = Float(linkDirs[0])
                let constrained = constrainToLinkAxis(
                    resultX: input.x,
                    resultY: input.y,
                    baseX: result.x,
                    baseY: result.y,
                    linkDirDegree: linkDir
                )
                
                result.x = constrained.x
                result.y = constrained.y
            }
        } else {
            JupiterLogger.i(tag: "JupiterCalcManager", message: "(makeCurrentResult) - mustInSameLink: \(mustInSameLink), curLinkInfo: \(PathMatcher.shared.getCurPassedLinkInfo())")
        }
        
        JupiterLogger.i(tag: "JupiterCalcManager", message: "(makeCurrentResult) - result (after link corr): \(result.building_name), \(result.level_name), [\(result.x),\(result.y),\(result.absolute_heading)]")
        
        if isUseHeading && phase == .TRACKING, let curResult = self.curResult {
            let diffX = result.x - curResult.x
            let diffY = result.y - curResult.y
            let diffNorm = sqrt(diffX*diffX + diffY*diffY)
            JupiterLogger.i(tag: "JupiterCalcManager", message: "(makeCurrentResult) - tu correction: diffNorm= \(diffNorm), xy= [\(result.x), \(result.y)]")
            if diffNorm >= 2 {
                kalmanFilter?.updateTuPosition(coord: [result.x, result.y])
            }
            kalmanFilter?.updateTuPosition(coord: [result.x, result.y])
            JupiterLogger.i(tag: "JupiterCalcManager", message: "(makeCurrentResult) - tu correction (2): xyh= [\(result.x), \(result.y), \(result.absolute_heading)]")
        }
        
        if KalmanState.isKalmanFilterRunning {
            let isInLevelChangeArea = buildingLevelChanger!.checkInLevelChangeArea(sectorId: sectorId, building: buildingName, level: levelName, x: result.x, y: result.y, mode: mode)
            PathMatcher.shared.updateNodeAndLinkInfo(sectorId: sectorId, uvdIndex: curIndex, curResult: result, jumpInfo: jumpInfo, mode: mode, isInLevelChangeArea: isInLevelChangeArea)
        }
        
        return result
    }
    
    func constrainToLinkAxis(
        resultX: Float,
        resultY: Float,
        baseX: Float,
        baseY: Float,
        linkDirDegree: Float
    ) -> (x: Float, y: Float) {
        
        let rad = Double(linkDirDegree) * Double.pi / 180.0
        
        let ux = Float(cos(rad))
        let uy = Float(sin(rad))
        
        let dx = resultX - baseX
        let dy = resultY - baseY
        
        let projected = dx * ux + dy * uy
        
        let constrainedX = baseX + projected * ux
        let constrainedY = baseY + projected * uy
        
        return (constrainedX, constrainedY)
    }
    
    private func calcJumpedNodes(from: FineLocationTrackingOutput?,
                                 to: FineLocationTrackingOutput,
                                 curLinkInfo: PassedLinkInfo,
                                 jumpedLinkNum: Int,
                                 mode: UserMode) -> JumpInfo? {
        var jumpInfo: JumpInfo?

        guard let linkData = PathMatcher.shared.getLinkData(sectorId: sectorId,
                                                            building: to.building_name,
                                                            level: to.level_name,
                                                            mode: mode) else { return nil }
        guard let jumpedLinkInfo = linkData[jumpedLinkNum] else { return nil }
        guard let from = from else { return nil }
        
        if jumpedLinkInfo.group_number == curLinkInfo.group_number {
            var isJumped: Bool = false
            var intermediatePoints: [[Float]] = []
            
            let userX = from.x
            let userY = from.y
            let userDir = from.absolute_heading
            
            let resultX = to.x
            let resultY = to.y
            let resultDir = to.absolute_heading
            
            let deltaDir = abs(userDir - resultDir).truncatingRemainder(dividingBy: 360)
            let angleDiff = deltaDir > 180 ? 360 - deltaDir : deltaDir
            let isDirectionAligned = angleDiff <= 10.0
            
            let dx = resultX - userX
            let dy = resultY - userY
            let distance = sqrt(dx * dx + dy * dy)
            
            let headingRad = userDir * .pi / 180.0
            let dirVector = SIMD2(x: cos(headingRad), y: sin(headingRad))
            let movementVector = SIMD2(x: dx, y: dy)
            let dotProduct = simd_dot(dirVector, movementVector)
            let isSameDirection = dotProduct > 0.0
            
            isJumped = distance >= 2.0 && isDirectionAligned && isSameDirection
            if isJumped {
                let unitVector = simd_normalize(dirVector)
                let stepCount = Int(distance)
                for i in 1..<stepCount {
                    let step = Float(i)
                    let x = userX + step * unitVector.x
                    let y = userY + step * unitVector.y
                    intermediatePoints.append([x, y])
                }
            }
            
            JupiterLogger.i(tag: "JupiterCalcManager", message: "(onUvdResult) jump // calcJumpedNodes in same link")
            var jumpedNodes = [PassedNodeInfo]()
            for point in intermediatePoints {
                if let matchedNodeResult = PathMatcher.shared.getMatchedNodeWithCoord(sectorId: sectorId, fltResult: to, originCoord: point, coordToCheck: point, paddingValues: [1, 1, 1, 1], mode: mode) {
                    let nodeInfo = PassedNodeInfo(number: matchedNodeResult.0, coord: point, headings: matchedNodeResult.1, matched_index: to.index, user_heading: to.absolute_heading)
                    jumpedNodes.append(nodeInfo)
                }
            }
            jumpInfo = JumpInfo(link_number: jumpedLinkNum, jumped_nodes: jumpedNodes)
        } else {
            let userX = round(to.x)
            let userY = round(to.y)
            let userDir = to.absolute_heading
            
            let oppDir = PathMatcher.shared.oppositeOf(userDir)
            let oppLinkDir = PathMatcher.shared.closestHeading(to: oppDir, candidates: jumpedLinkInfo.included_heading).0
            
            let deltaDir = abs(oppDir - oppLinkDir).truncatingRemainder(dividingBy: 360)
            let angleDiff = deltaDir > 180 ? 360 - deltaDir : deltaDir

            let headingRad = oppLinkDir * .pi / 180.0
            let dirVector = SIMD2(x: cos(headingRad), y: sin(headingRad))
            
            var jumpedNodes = [PassedNodeInfo]()
            JupiterLogger.i(tag: "JupiterCalcManager", message: "(onUvdResult) jump // calcJumpedNodes link jump")
            let unitVector = simd_normalize(dirVector)
            let stepCount = 100
            for i in 1..<stepCount {
                let step = Float(i)
                let x = userX + step * unitVector.x
                let y = userY + step * unitVector.y
                let point: [Float] = [x, y]
                if let matchedNodeResult = PathMatcher.shared.getMatchedNodeWithCoord(sectorId: sectorId, fltResult: to, originCoord: point, coordToCheck: point, paddingValues: [1, 1, 1, 1], mode: mode) {
                    let nodeNum = matchedNodeResult.0
                    let nodeInfo = PassedNodeInfo(number: nodeNum, coord: point, headings: matchedNodeResult.1, matched_index: to.index, user_heading: to.absolute_heading)
                    jumpedNodes.append(nodeInfo)
                    if nodeNum == jumpedLinkInfo.start_node || nodeNum == jumpedLinkInfo.end_node {
                        jumpInfo = JumpInfo(link_number: jumpedLinkNum, jumped_nodes: jumpedNodes)
                        return jumpInfo
                    }
                }
            }
        }

        return jumpInfo
    }
    
    private func checkPossibleBadCase(landmarkPeaks: [PeakData]?, curPmResult: FineLocationTrackingOutput, searchRange: Float) -> Bool {
        guard let landmarkPeaks = landmarkPeaks else { return true }
        for lm in landmarkPeaks {
            let diffX = Float(lm.x) - curPmResult.x
            let diffY = Float(lm.y) - curPmResult.y
            let dist = sqrt(diffX*diffX + diffY*diffY)
            
            JupiterLogger.i(tag: "JupiterCalcManager", message: "(checkPossibleBadCase) BadCase : searchRange= \(searchRange), dist= \(dist)")
            if dist <= searchRange {
                return false
            }
        }
        return true
    }
    
    func changeUserMode(mode: UserMode) {
        self.curUserModeEnum = mode
        PathMatcher.shared.setGraphMode(mode)
        if mode == .MODE_VEHICLE {
            self.curUserMode = "DR"
        } else if mode == .MODE_PEDESTRIAN {
            self.curUserMode = "PDR"
            if jupiterPhase == .ENTERING {
                jupiterPhase = .SEARCHING
            }
        } else {
            self.curUserMode = "UNKNOWN"
        }
    }
    
    private func determineWindowSize(jupiterPhase: JupiterPhase) -> Int {
        switch jupiterPhase {
        case .ENTERING:
            return 30
        case .SEARCHING:
            return 30
        case .TRACKING:
            return 50
        case .EXITING:
            return 30
        case .OUTDOOR:
            return 10
        case .NONE:
            return 10
        }
    }
    
    private func determinInOutState(state: InOutState) {
        let inputState = state
        
        if inputState == .OUT_TO_IN {
            
        }
    }
    
    private func mostFrequent<T: Hashable>(_ array: [T]) -> T? {
        guard !array.isEmpty else { return nil }
        
        let freq = Dictionary(grouping: array, by: { $0 })
            .mapValues { $0.count }
        
        return freq.max(by: { $0.value < $1.value })?.key
    }
    
    private func CallWhenFirstResponse() {
        JupiterResultState.isIndoor = true
        JupiterResultState.isGetFirstResponse = true
    }
    
    func onVelocityResult(_ generator: UVDGenerator, kmPh: Double) {
        curVelocity = Float(kmPh)
    }
    func onMagNormSmoothingVarResult(_ generator: TJLabsCommon.UVDGenerator, value: Double) {
        //
    }
    
    // MARK: - Bridging
    func setLSEAppName(name: String) {
        lseManager?.setAppName(name: name)
    }
    
    func getMatchedLevelId(key: String) -> Int? {
        return tjlabsResourceManager.getMatchedLevelId(key: key)
    }

    func getBuildingName(buildingId: Int) -> String? {
        return tjlabsResourceManager.getBuildingName(buildingId: buildingId)
    }

    func getBuildingId(buildingName: String) -> Int? {
        return tjlabsResourceManager.getBuildingId(buildingName: buildingName)
    }

    func getLevelName(levelId: Int) -> String? {
        return tjlabsResourceManager.getLevelName(levelId: levelId)
    }

    func getLevelId(sectorId: Int, buildingName: String, levelName: String) -> Int? {
        return tjlabsResourceManager.getLevelId(sectorId: sectorId, buildingName: buildingName, levelName: levelName)
    }
    
    func getDefaultPosition(sectorId: Int) -> DefaultPosition? {
        return tjlabsResourceManager.getDefaultPosition(sectorId: sectorId)
    }
    
    func getWGS84Transform(sectorId: Int) -> WGS84Transform? {
        return tjlabsResourceManager.getWGS84Transform(sectorId: sectorId)
    }
    
    func getCurPmResultBuffer(from: Int) -> [FineLocationTrackingOutput] {
        return stackManager.getCurPmResultBuffer(from: from)
    }
    
    func getCurPmResultBuffer(size: Int) -> [FineLocationTrackingOutput] {
        return stackManager.getCurPmResultBuffer(size: size)
    }
    
    // MARK: - TJLabsResourceManagerDelegate Methods
    func onSectorBundleData(_ manager: TJLabsResource.TJLabsResourceManager, sectorId: Int, data: TJLabsResource.BundleOutput) {
        self.sectorDebugOption = tjlabsResourceManager.isDebug()
        if !debugOption && sectorDebugOption {
            debugOption = true
        }
    }
    
    func onUnitsData(_ manager: TJLabsResource.TJLabsResourceManager, key: String, data: [TJLabsResource.UnitData]) {
        // TO-DO
    }
    
    func onWardsData(_ manager: TJLabsResource.TJLabsResourceManager, key: String, data: [TJLabsResource.LevelWard]) {
        guard let blChanger = self.buildingLevelChanger else { return }
        blChanger.setLevelWards(levelKey: key, levelWardsData: data)
    }

    func onSectorError(_ manager: TJLabsResource.TJLabsResourceManager, error: TJLabsResource.ResourceError) {
        // TO-DO
    }
    
    func onBuildingsData(_ manager: TJLabsResource.TJLabsResourceManager, sectorId: Int, data: [TJLabsResource.BuildingData]) {
        guard let blChanger = self.buildingLevelChanger else { return }
        blChanger.setBuildingsData(buildingsData: data)
        self.buildingsData = data
    }
    
    func onScaleOffsetData(_ manager: TJLabsResource.TJLabsResourceManager, key: String, data: [Float]) {
        // TO-DO
    }
    
    func onPathPixelData(_ manager: TJLabsResource.TJLabsResourceManager, key: String, data: TJLabsResource.PathPixelData) {
        JupiterLogger.i(tag: "JupiterCalcManager", message: "(onPathPixelData) key= \(key)")
        PathMatcher.shared.setPathPixelData(key: key, data: data)
    }
    
    func onNodeLinkData(_ manager: TJLabsResource.TJLabsResourceManager, key: String, type: TJLabsResource.NodeLinkType, data: Any) {
        if type == .NODE {
            PathMatcher.shared.setNodeData(key: key, data: data as! [Int : NodeData])
        } else if type == .LINK {
            PathMatcher.shared.setLinkData(key: key, data: data as! [Int : LinkData])
            PathMatcher.shared.setLinkGroupLength(key: key)
        }
    }
    
    func onLandmarkData(_ manager: TJLabsResource.TJLabsResourceManager, key: String, data: [String : TJLabsResource.LandmarkData]) {
        landmarkTagger?.setLandmarkData(key: key, data: data)
    }
    
    func onSimulationData(_ manager: TJLabsResource.TJLabsResourceManager, sectorId: Int, data: [TJLabsResource.SimulationInfo]) {
        delegate?.onSimulationData(data)
    }
    
    func onGeofenceData(_ manager: TJLabsResource.TJLabsResourceManager, key: String, data: TJLabsResource.GeofenceData) {
        let levelChangeArea = data.levelChangeArea
        if let blChnager = self.buildingLevelChanger {
            blChnager.setLevelChangeArea(key: key, data: levelChangeArea)
        }
        PathMatcher.shared.setEntranceMatchingArea(key: key, data: data.entranceMatchingArea)
        PathMatcher.shared.setEntranceArea(key: key, data: data.entranceArea)
    }
    
    func onEntranceData(_ manager: TJLabsResource.TJLabsResourceManager, key: String, data: TJLabsResource.EntranceData) {
        entManager?.setEntData(key: key, data: data)
        guard let innermostward = data.innermostWard else { return }
        landmarkTagger?.setExceptionalTagInfo(id: innermostward.name)
    }
    
    func onEntranceRouteData(_ manager: TJLabsResource.TJLabsResourceManager, key: String, data: TJLabsResource.EntranceRouteData) {
        entManager?.setEntRouteData(key: key, data: data)
    }
    
    func onImageData(_ manager: TJLabsResource.TJLabsResourceManager, key: String, data: UIImage?) {
        // NONE
    }
    
    func onAffineParam(_ manager: TJLabsResource.TJLabsResourceManager, data: TJLabsResource.WGS84Transform) {
        AffineConverter.shared.setAffineParam(sectorId: sectorId, data: data)
    }
    
    func onError(_ manager: TJLabsResource.TJLabsResourceManager, error: TJLabsResource.ResourceError, key: String) {
        // TO-DO
    }
    
    func isBuildingLevelChanged(isChanged: Bool, newBuilding: String, newLevel: String, newCoord: [Float]) {
        // TODO
    }
    
    func onStateReported(_ code: JupiterServiceCode) {
        delegate?.onStateReported(code)
    }

    private func updateLSEBuffer(with result: FineLocationTrackingOutput) {
        if let last = lseResultBuffer.last,
           (last.building_name != result.building_name || last.level_name != result.level_name) {
            lseResultBuffer.removeAll()
            curRepresentativeLSEResult = nil
            curPathMatchingRepresentativeLSEResult = nil
            debug_lse_rep_xyh = nil
        }

        lseResultBuffer.append(result)
        if lseResultBuffer.count > LSE_RESULT_BUFFER_SIZE {
            lseResultBuffer.removeFirst(lseResultBuffer.count - LSE_RESULT_BUFFER_SIZE)
        }
    }
    
    private func updateLSESnapshotBuffer(with snpshot: SingleEpochSnapshot) {
        lseSnapshotBuffer.append(snpshot)
        if lseSnapshotBuffer.count > LSE_SNAPSHOT_BUFFER_SIZE {
            lseSnapshotBuffer.removeFirst(lseSnapshotBuffer.count - LSE_SNAPSHOT_BUFFER_SIZE)
        }
    }

    private func selectRepresentativeLSECluster() -> [FineLocationTrackingOutput] {
        let buffer = lseResultBuffer
        guard buffer.count > LSE_REPRESENTATIVE_CLUSTER_SIZE else { return buffer }

        var bestCluster = Array(buffer.suffix(LSE_REPRESENTATIVE_CLUSTER_SIZE))
        var bestScore = Float.greatestFiniteMagnitude

        for i in 0..<(buffer.count - 2) {
            for j in (i + 1)..<(buffer.count - 1) {
                for k in (j + 1)..<buffer.count {
                    let cluster = [buffer[i], buffer[j], buffer[k]]
                    let score = pairwiseDistanceSum(for: cluster)
                    if score < bestScore {
                        bestScore = score
                        bestCluster = cluster
                    }
                }
            }
        }

        return bestCluster
    }

    private func pairwiseDistanceSum(for cluster: [FineLocationTrackingOutput]) -> Float {
        guard cluster.count > 1 else { return 0 }

        var score: Float = 0
        for i in 0..<(cluster.count - 1) {
            for j in (i + 1)..<cluster.count {
                let dx = cluster[i].x - cluster[j].x
                let dy = cluster[i].y - cluster[j].y
                score += sqrt(dx * dx + dy * dy)
            }
        }
        return score
    }

    private func calculateRepresentativeLSEHeading(x: Float, y: Float, fallbackHeading: Float) -> Float {
        guard let previousRepresentative = curRepresentativeLSEResult else { return fallbackHeading }

        let dx = x - previousRepresentative.x
        let dy = y - previousRepresentative.y
        let distance = sqrt(dx * dx + dy * dy)
        guard distance >= LSE_HEADING_MIN_DISTANCE else {
            return previousRepresentative.absolute_heading
        }

        let headingRadian = atan2(Double(dy), Double(dx))
        let headingDegree = TJLabsUtilFunctions.shared.radian2degree(radian: headingRadian)
        return Float(TJLabsUtilFunctions.shared.compensateDegree(headingDegree))
    }

    private func makeRepresentativeLSEResult(currentTime: Int,
                                             index: Int,
                                             buildingName: String,
                                             levelName: String,
                                             fallbackHeading: Float) -> FineLocationTrackingOutput? {
        let cluster = selectRepresentativeLSECluster()
        guard !cluster.isEmpty else { return nil }

        let sumX = cluster.reduce(Float(0)) { $0 + $1.x }
        let sumY = cluster.reduce(Float(0)) { $0 + $1.y }
        let representativeX = sumX / Float(cluster.count)
        let representativeY = sumY / Float(cluster.count)
        let calculatedHeading = calculateRepresentativeLSEHeading(x: representativeX, y: representativeY, fallbackHeading: fallbackHeading)
        let representativeHeading = resolvedRepresentativeHeading(fallbackHeading: calculatedHeading)

        return FineLocationTrackingOutput(mobile_time: currentTime,
                                          index: index,
                                          building_name: buildingName,
                                          level_name: levelName,
                                          x: representativeX,
                                          y: representativeY,
                                          absolute_heading: representativeHeading)
    }
    
    func lseManager(
        _ manager: LSEManager,
        didReceiveSingleEpochResult result: LocationSingleEpochResult,
        requestPayload: LocationRequestPayload,
        requestContext: LSERequestContext?
    ) {
        switch (result) {
        case .success(let success):
            let context = requestContext
            
            let currentTime = TJLabsUtilFunctions.shared.getCurrentTimeInMilliseconds(as: .int) as! Int
            let curIndex = curUvd.index
            
            let buildingId = success.location.building_id
            let levelId = success.location.level_id
            guard let bName = getBuildingName(buildingId: buildingId), let lName = getLevelName(levelId: levelId) else { return }
            
            let x = Float(success.location.x)
            let y = Float(success.location.y)
            let h: Float = 0

            let rawLSEResult = FineLocationTrackingOutput(mobile_time: currentTime,
                                                          index: curIndex,
                                                          building_name: bName,
                                                          level_name: lName,
                                                          x: x,
                                                          y: y,
                                                          absolute_heading: h)
            self.curLSEResult = rawLSEResult
            updateLSEBuffer(with: rawLSEResult)
            updateLSESnapshotBuffer(with: SingleEpochSnapshot(requestContext: context, result: rawLSEResult))
            
            if let pmResult = PathMatcher.shared.pathMatching(sectorId: self.sectorId, building: bName, level: lName, x: x, y: y, heading: h, isUseHeading: false, mode: curUserModeEnum, paddingValues: JupiterMode.PADDING_VALUES_MEDIUM) {
                var pathMatchedRawLSEResult = rawLSEResult
                pathMatchedRawLSEResult.x = pmResult.x
                pathMatchedRawLSEResult.y = pmResult.y
                self.curPathMatchingLSEResult = pathMatchedRawLSEResult
            } else {
                self.curPathMatchingLSEResult = rawLSEResult
            }

            let fallbackHeading = curRepresentativeLSEResult?.absolute_heading ?? h
            guard let representativeLSEResult = makeRepresentativeLSEResult(currentTime: currentTime,
                                                                             index: curIndex,
                                                                             buildingName: bName,
                                                                             levelName: lName,
                                                                             fallbackHeading: fallbackHeading) else {
                self.debug_lse_rep_xyh = nil
                self.curRepresentativeLSEResult = nil
                self.curPathMatchingRepresentativeLSEResult = nil
                self.debug_navi_xyh = [rawLSEResult.x, rawLSEResult.y, rawLSEResult.absolute_heading]
                return
            }

            self.curRepresentativeLSEResult = representativeLSEResult
            self.debug_lse_rep_xyh = [representativeLSEResult.x, representativeLSEResult.y, representativeLSEResult.absolute_heading]

            if let pmResult = PathMatcher.shared.pathMatching(sectorId: self.sectorId, building: bName, level: lName, x: representativeLSEResult.x, y: representativeLSEResult.y, heading: representativeLSEResult.absolute_heading, isUseHeading: false, mode: curUserModeEnum, paddingValues: JupiterMode.PADDING_VALUES_MEDIUM) {
                var pathMatchedRepresentativeLSEResult = representativeLSEResult
                pathMatchedRepresentativeLSEResult.x = pmResult.x
                pathMatchedRepresentativeLSEResult.y = pmResult.y
                self.curPathMatchingRepresentativeLSEResult = pathMatchedRepresentativeLSEResult
            } else {
                self.curPathMatchingRepresentativeLSEResult = representativeLSEResult
            }

            self.debug_navi_xyh = [rawLSEResult.x, rawLSEResult.y, rawLSEResult.absolute_heading]
        case .noLocation(let noLocation):
            print("noLocation")
        case .failure(let failure):
            print("failure")
        }
//        JupiterLogger.i(
//            tag: "JupiterCalcManager",
//            message: "(didReceiveSingleEpochResult) result= \(result), requestPayload= \(requestPayload), requestContext= \(requestContext)"
//        )
    }
    
    private func normalizedHeading(_ heading: Float) -> Float {
        let normalized = heading.truncatingRemainder(dividingBy: 360)
        return normalized >= 0 ? normalized : normalized + 360
    }
    
    private func resolvedRepresentativeHeading(fallbackHeading: Float) -> Float {
        return currentOSRepresentativeHeading() ?? fallbackHeading
    }
    
    private func currentOSRepresentativeHeading() -> Float? {
        guard isUseOSHeading,
              let magneticHeading = latestMagneticHeading,
              let affineParam = AffineConverter.shared.getAffineParam(sectorId: sectorId) else {
            return nil
        }
        
        return convertedMapHeading(from: magneticHeading, headingOffset: affineParam.headingOffset)
    }
    
    private func applyOSHeadingToRepresentativeResultIfNeeded() {
        guard let osHeading = currentOSRepresentativeHeading() else { return }
        
        if curRepresentativeLSEResult != nil {
            curRepresentativeLSEResult?.absolute_heading = osHeading
        }
        if curPathMatchingRepresentativeLSEResult != nil {
            curPathMatchingRepresentativeLSEResult?.absolute_heading = osHeading
        }
        if let representativeResult = curRepresentativeLSEResult {
            debug_lse_rep_xyh = [representativeResult.x, representativeResult.y, representativeResult.absolute_heading]
        }
    }
    
    private func updateOSHeadingMonitoring() {
        let shouldUpdateHeading = isUseOSHeading && (rfdGenerator != nil || uvdGenerator != nil)
        let updateBlock = {
            guard CLLocationManager.headingAvailable() else {
                if shouldUpdateHeading {
                    JupiterLogger.w(tag: "JupiterCalcManager", message: "OS heading is unavailable on this device")
                }
                self.locationManager.stopUpdatingHeading()
                return
            }

            guard shouldUpdateHeading else {
                self.locationManager.stopUpdatingHeading()
                return
            }

            switch self.locationManager.authorizationStatus {
            case .authorizedAlways, .authorizedWhenInUse:
                self.locationManager.startUpdatingHeading()
            case .notDetermined:
                self.locationManager.requestWhenInUseAuthorization()
            case .restricted, .denied:
                JupiterLogger.w(tag: "JupiterCalcManager", message: "Location permission denied; OS heading is disabled")
                self.locationManager.stopUpdatingHeading()
            @unknown default:
                self.locationManager.stopUpdatingHeading()
            }
        }

        if Thread.isMainThread {
            updateBlock()
        } else {
            DispatchQueue.main.sync(execute: updateBlock)
        }
    }

    private func convertedMapHeading(from osAzimuth: Double, headingOffset: Double) -> Float {
        let localHeading = normalizedHeading(Float(osAzimuth + headingOffset))
        return normalizedHeading(360 - localHeading)
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        updateOSHeadingMonitoring()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        guard newHeading.headingAccuracy >= 0 else { return }
        latestMagneticHeading = newHeading.magneticHeading
        applyOSHeadingToRepresentativeResultIfNeeded()
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        JupiterLogger.w(tag: "JupiterCalcManager", message: "Failed to update OS heading: \(error.localizedDescription)")
    }
}
