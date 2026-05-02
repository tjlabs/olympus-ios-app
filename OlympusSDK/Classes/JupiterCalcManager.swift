import Foundation
import UIKit
import simd
import TJLabsCommon
import TJLabsResource

class JupiterCalcManager: RFDGeneratorDelegate, UVDGeneratorDelegate, TJLabsResourceManagerDelegate, BuildingLevelChangerDelegate, StateManagerDelegate {
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
    
    // MARK: - Delegate
    weak var delegate: JupiterCalcManagerDelegate?
    
    // MARK: - User Properties
    var id: String = ""
    var cloud: String = JupiterCloud.AWS.rawValue
    var region: String = JupiterRegion.KOREA.rawValue
    var sectorId: Int = 0
    var os: String = JupiterNetworkConstants.OPERATING_SYSTEM
    
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
    var curUserMode: String = "AUTO"
    var curUserModeEnum: UserMode = .MODE_AUTO
    
    // MARK: - Constants
    private let AVG_BUFFER_SIZE = 2
    
    // MARK: - Searching
    private var searcingId: String = ""
    private var searchingIndex: Int = 0
    
    // MARK: - Landmark Correction
    private var correctionId: String = ""
    private var correctionIndex: Int = 0
    private var uvdIndexWhenCorrection: Int = 0
    var paddingValues = JupiterMode.PADDING_VALUES_MEDIUM
    var preFixed: FixedPeak?
    var preSearchList: [SelectedSearch]?
    
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
    var prePathMatchingResult: FineLocationTrackingOutput?
    var buildingsData: [BuildingData]?
    
    // MARK: - Debuging
    var sectorDebugOption: Bool = false
    var debugOption: Bool = false
    var debug_calc_xyh: [Float] = [0, 0, 0]
    var debug_tu_xyh: [Float] = [0, 0, 0]
    var debug_landmark: LandmarkData?
    var debug_best_landmark: PeakData?
    var debug_recon_raw_traj: [[Double]]?
    var debug_recon_corr_traj: [FineLocationTrackingOutput]?
    var debug_list_search = [SelectedSearch]()
    var debug_selected_search: SelectedSearch?
    var debug_selected_cand: SelectedCandidate?
    var debug_tracking_cand: SelectedCandidate?
    var debug_ratio: Float?
    var debug_navi_xyh: [Float] = [0, 0, 0]
    
    // MARK: - init & deinit
    init(cloud: String, region: String, id: String, sectorId: Int) {
        self.id = id
        self.cloud = cloud
        self.region = region
        self.sectorId = sectorId
        
        self.entManager = EntranceManager(sectorId: sectorId)
        self.buildingLevelChanger = BuildingLevelChanger(sectorId: sectorId)
        self.wardAvgManager = WardAveragingManager(bufferSize: AVG_BUFFER_SIZE)
        self.kalmanFilter = KalmanFilter(stackManager: stackManager)
        self.landmarkTagger = LandmarkTagger(sectorId: sectorId)
        self.solutionEstimator = SolutionEstimator(sectorId: sectorId)
        self.stateManager = JupiterStateManager()
        
        peakDetector.setInnerWardIds(ids: self.entManager!.getEntInnermostWardIds())
        
        tjlabsResourceManager.delegate = self
        buildingLevelChanger?.delegate = self
        stateManager?.delegate = self
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
    }
    
    // MARK: - Functions
    func initialize(completion: @escaping (Bool, String) -> Void) {
        tjlabsResourceManager.loadResources(cloud: cloud, region: region, sectorId: sectorId, landmarkTh: -92, forceUpdate: true, completion: { isSuccess in
            let msg: String = isSuccess ? "JupiterCalcManager start success" : "JupiterCalcManager initialize failed"
            completion(isSuccess, msg)
        })
    }
    
    func getBuildingsData() -> [BuildingData]? {
        JupiterLogger.i(tag: "JupiterCalcManager", message: "getBuildingsData : buildingsData= \(buildingsData)")
        return self.buildingsData
    }
    
    // MARK: - Set REC length
    func startGenerator(mode: UserMode, completion: @escaping (Bool, String) -> Void) {
        rfdGenerator = RFDGenerator(userId: id)
        uvdGenerator = UVDGenerator(userId: id)

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
        
        JupiterSimulator.shared.isSimulationMode ? rfdGenerator?.generateRfdSimulation() : rfdGenerator?.generateRfd()
        rfdGenerator?.delegate = self
        rfdGenerator?.pressureProvider = { [self] in
            return self.pressure
        }

        uvdGenerator?.setUserMode(mode: mode)
        JupiterSimulator.shared.isSimulationMode ? uvdGenerator?.generateUvdSimulation() : uvdGenerator?.generateUvd()
        uvdGenerator?.delegate = self

        completion(true, "")
    }
    
    func stopGenerator() {
        rfdGenerator?.stopRfdGeneration()
        uvdGenerator?.stopUvdGeneration()
    }
    
    func getJupiterResult() -> JupiterResult? {
        let currentTime = TJLabsUtilFunctions.shared.getCurrentTimeInMilliseconds(as: .int) as! Int
        guard let curPathMatchingResult = self.curPathMatchingResult else { return nil }
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
        
        let is_vehicle = curUserModeEnum == .MODE_VEHICLE
        let jupiterResult = JupiterResult(mobile_time: currentTime,
                                          index: curUvd.index,
                                          building_name: buildingName,
                                          level_name: levelName,
                                          jupiter_pos: Position(x: x, y: y, heading: absoluteHeading),
                                          navi_pos: nil,
                                          llh: llh,
                                          velocity: curVelocity,
                                          is_vehicle: is_vehicle,
                                          is_indoor: JupiterResultState.isIndoor,
                                          validity_flag: 1)
        
        return jupiterResult
    }
    
    func getJupiterDebugResult() -> JupiterDebugResult? {
        let currentTime = TJLabsUtilFunctions.shared.getCurrentTimeInMilliseconds(as: .int) as! Int
        guard let curPathMatchingResult = self.curPathMatchingResult else { return nil }
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
            recon_raw_traj: self.debug_recon_raw_traj,
            recon_corr_traj: self.debug_recon_corr_traj,
            selected_cand: self.debug_selected_cand,
            tracking_cand: self.debug_tracking_cand,
            cand_search: self.debug_list_search,
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
        delegate?.onRfdResult(receivedForce: receivedForce)
    }
    
    func handleRfd(rfd: ReceivedForce) {
        self.curRfd = rfd
        guard let bleAvailable = rfdGenerator?.checkIsAvailableRfd() else { return }
        if !bleAvailable.0 { delegate?.onStateReported(.BLUETOOTH_UNAVAILABLE) }
        guard let bleReady = rfdGenerator?.isBluetoothReady() else { return }
        guard let lastScannedTime = rfdGenerator?.getBleLastScannedTime() else { return }
        stateManager?.checkBleOff(bluetoothReady: bleReady, bleLastScannedTime: lastScannedTime)
        stateManager?.checkNetworkConnection()
    }
    
    func onRfdError(_ generator: TJLabsCommon.RFDGenerator, code: Int, msg: String) {
        JupiterLogger.i(tag: "JupiterCalcManager", message: "(onRfdError): \(code), \(msg)")
    }
    
    func onRfdEmptyMillis(_ generator: TJLabsCommon.RFDGenerator, time: Double) {
        rfdEmptyMillis = time
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
        determineUserMode(mode: mode)

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
            self.debug_tracking_cand = nil
            self.debug_ratio = nil
            peakHandling: do {
                JupiterLogger.i(tag: "JupiterCalcManager", message: "(onUvdResult) PEAK detected : id=\(userPeak.id) // peak_idx=\(userPeak.peak_index), peak_rssi=\(userPeak.peak_rssi), detected_idx = \(userPeak.end_index), detected_rssi = \(userPeak.end_rssi)")
                startEntranceTracking(currentTime: currentTime, entManager: entManager, uvd: userVelocity, userPeak: userPeak, bleData: bleData)
                if let buildingLevelByPeak = blChanger.getMatchedBuildingLevelByUserPeak(userPeak: userPeak) {
                    blByPeak = buildingLevelByPeak
                    stackManager.stackBuildingLevelByPeak(buildingLevel: buildingLevelByPeak)
                    let buildingLevelByPeakBuffer = stackManager.getBuildingLevelByPeakBuffer(size: 3)
                    startIndoorSearching(uvd: userVelocity, blChanger: blChanger, buildingLevelByPeakBuffer: buildingLevelByPeakBuffer)
                } else {
                    JupiterLogger.i(tag: "JupiterCalcManager", message: "(onUvdResult) getMatchedBuildingLevelByUserPeak result is nil")
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
        
        // Bad Case 확인
        let travelingLinkDist = PathMatcher.shared.getCurPassedLinksDist()
        if stackManager.checkIsBadCase(jupiterPhase: jupiterPhase, uvdIndexWhenCorrection: self.uvdIndexWhenCorrection, travelingLinkDist: travelingLinkDist) && !uturnLink {
            let userPeakAndLinksBuffer = stackManager.getUserPeakAndLinksBuffer()
            if userPeakAndLinksBuffer.count < 2 { return }
            JupiterResultState.isInRecoveryProcess = true
            guard let recentAndOld = getRecentAndOlderUserPeak(userPeakAndLinksBuffer: userPeakAndLinksBuffer) else { return }
            guard let solutionEstimator = self.solutionEstimator else { return }
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
                            PathMatcher.shared.editPassingLinkBuffer(from: recentUserPeak.peak_index, sectorId: sectorId, curPmResultBuffer: curPmResultBuffer)
                            let recoveryCoord: [Float] = [updatedCurPmResult.x, updatedCurPmResult.y, updatedCurPmResult.absolute_heading]
                            if let pmResult = PathMatcher.shared.pathMatching(sectorId: sectorId, building: curResult.building_name, level: curResult.level_name, x: recoveryCoord[0],y: recoveryCoord[1], heading: recoveryCoord[2], isUseHeading: true, mode: mode, paddingValues: JupiterMode.PADDING_VALUES_MEDIUM) {
                                curPathMatchingResult = bestResult.headResult
                                curPathMatchingResult?.x = pmResult.x
                                curPathMatchingResult?.y = pmResult.y
                                curPathMatchingResult?.absolute_heading = pmResult.heading
                                JupiterLogger.i(tag: "JupiterCalcManager", message: "(onUvdResult) BadCase: recoveryCoord= \(recoveryCoord), loss= \(bestResult.loss)")
                                kalmanFilter?.updateTuPosition(coord: [pmResult.x, pmResult.y])
                                self.curResult? = curPathMatchingResult!
                                if let matchedLink = PathMatcher.shared.getLinkInfoWithResult(sectorId: sectorId, result: curPathMatchingResult!, checkAll: true) {
                                    let jumpInfo = JumpInfo(link_number: matchedLink.number, jumped_nodes: [])
                                    PathMatcher.shared.updateNodeAndLinkInfo(sectorId: sectorId, uvdIndex: curIndex, curResult: curPathMatchingResult!, jumpInfo: jumpInfo)
                                }
                            } else {
                                kalmanFilter?.updateTuPosition(coord: recoveryCoord)
                                var copiedResult = bestResult.headResult
                                copiedResult.x = recoveryCoord[0]
                                copiedResult.y = recoveryCoord[1]
                                copiedResult.absolute_heading = recoveryCoord[2]
                                self.curResult? = copiedResult
                                PathMatcher.shared.initPassedLinkInfo()
                            }
                        }
                    } else {
                        JupiterLogger.i(tag: "JupiterCalcManager", message: "(onUvdResult) BadCase: cannot find major direction")
                    }
                }
            }
            JupiterResultState.isInRecoveryProcess = false
        }
        
        if jupiterPhase == .TRACKING {
            let indexForEdit = max(correctionIndex, feedbackIndex)
            guard let trackingFeedback = delegate?.provideTrackingCorrection(mode: mode, userVelocity: userVelocity, peakIndex: curPeak?.peak_index, recentLandmarkPeaks: recentLandmarkPeaks, travelingLinkDist: travelingLinkDist, indexForEdit: indexForEdit, curPmResult: curPathMatchingResult) else { return }
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
                if let naviResultLink = PathMatcher.shared.getLinkInfoWithResult(sectorId: sectorId, result: naviResult, checkAll: true),
                   let curLinkInfo = PathMatcher.shared.getCurPassedLinkInfo(),
                   let jumped = calcJumpedNodes(from: curResult, to: naviResult, curLinkInfo: curLinkInfo, jumpedLinkNum: naviResultLink.number) {
                    JupiterLogger.i(tag: "JupiterCalcManager", message: "(onUvdResult) jumped: link= \(jumped.link_number), nodes= \(jumped.jumped_nodes)")
                    let jumpInfo: JumpInfo = JumpInfo(link_number: jumped.link_number, jumped_nodes: jumped.jumped_nodes)
                    PathMatcher.shared.updateNodeAndLinkInfo(sectorId: sectorId, uvdIndex: userVelocity.index, curResult: naviResult, jumpInfo: jumpInfo)
                } else {
                    PathMatcher.shared.initPassedNodeInfo()
                }
            }
//            self.naviCorrectionInfo = nil
//            self.stackEditInfoBuffer = nil
        }
        
        updateDebugTuResult()
    }
    
    private func updateDebugTuResult() {
        if let tuResult = kalmanFilter?.getTuResult() {
            self.debug_tu_xyh = [tuResult.x, tuResult.y, tuResult.absolute_heading]
        }
    }
    
    private func startEntranceTracking(currentTime: Int, entManager: EntranceManager, uvd: UserVelocity, userPeak: UserPeak, bleData: [String: Double]) {
        let peakId = userPeak.id
        if !JupiterResultState.isIndoor && jupiterPhase != .ENTERING && jupiterPhase != .SEARCHING {
            guard let entKey = entManager.checkStartEntTrack(wardId: peakId, sec: 3) else { return }
            jupiterPhase = .ENTERING
            delegate?.isJupiterPhaseChanged(index: uvd.index, phase: jupiterPhase, xyh: nil)
            JupiterResultState.isIndoor = true
            let entTrackData = entKey.split(separator: "_")
            JupiterLogger.i(tag: "JupiterCalcManager", message: "(onUvdResult) index:\(uvd.index) - entTrackData = \(entTrackData)")
            
            if let blChanger = self.buildingLevelChanger {
                if let fromLevel = entManager.getEntTrackEndLevel(),
                   let levelId = blChanger.getLevelIdWithName(levelName: fromLevel) {
                    delegate?.onEntering(userVelocity: uvd, peakIndex: userPeak.peak_index, key: entKey, level_id: levelId)
                } else {
                    JupiterLogger.i(tag: "JupiterCalcManager", message: "(requestRouting) unwrap fail")
                }
            }
        }
        
        if jupiterPhase == .ENTERING {
            var forceStop = false
            if let innermostWard = entManager.stopEntTrack(wardId: peakId) {
                JupiterLogger.i(tag: "JupiterCalcManager", message: "(onUvdResult) index:\(uvd.index) - EntTrack Finished : innermostWard \(innermostWard)")
                // Turn
                let uvdBuffer = stackManager.getUvdBuffer(from: uvd.index-50)
                let majorSection = stackManager.extractSectionWithLeastChange(inputArray: uvdBuffer.map{ Float($0.heading) })
                forceStop = majorSection.isEmpty
                if !forceStop {
                    var wardArea: [EntWardArea]?
                    if innermostWard.name.contains("46E") {
                        // Convensia Ent1
                        wardArea = [
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
                            EntWardArea(x: 48, y: 199, heading: [0]),
                            EntWardArea(x: 49, y: 199, heading: [0, 315]),
                            EntWardArea(x: 50, y: 199, heading: [0, 315]),
                            EntWardArea(x: 51, y: 199, heading: [0, 315]),
                            EntWardArea(x: 52, y: 199, heading: [0, 315, 270]),
                            EntWardArea(x: 52, y: 198, heading: [315, 270]),
                            EntWardArea(x: 52, y: 197, heading: [315, 270]),
                            EntWardArea(x: 52, y: 196, heading: [315, 270]),
                            EntWardArea(x: 52, y: 195, heading: [315, 270]),
                            EntWardArea(x: 52, y: 194, heading: [315, 270]),
                            EntWardArea(x: 52, y: 193, heading: [270]),
                            EntWardArea(x: 52, y: 192, heading: [270]),
                            EntWardArea(x: 52, y: 191, heading: [270]),
                            EntWardArea(x: 52, y: 190, heading: [270]),
                            EntWardArea(x: 52, y: 189, heading: [270])
                        ]
                    } else if innermostWard.name.contains("114") {
                        // Convensia Ent2
                        wardArea = [
                            EntWardArea(x: 348, y: 155, heading: [158]),
                            EntWardArea(x: 354, y: 155, heading: [158]),
                            EntWardArea(x: 353, y: 156, heading: [158]),
                            EntWardArea(x: 352, y: 156, heading: [158]),
                            EntWardArea(x: 352, y: 157, heading: [158]),
                            EntWardArea(x: 351, y: 157, heading: [158]),
                            EntWardArea(x: 350, y: 157, heading: [158]),
                            EntWardArea(x: 349, y: 158, heading: [158]),
                            EntWardArea(x: 348, y: 158, heading: [90, 158]),
                            EntWardArea(x: 348, y: 159, heading: [90, 158]),
                            EntWardArea(x: 348, y: 160, heading: [90, 158]),
                            EntWardArea(x: 348, y: 161, heading: [90]),
                            EntWardArea(x: 348, y: 162, heading: [90]),
                            EntWardArea(x: 348, y: 163, heading: [90]),
                            EntWardArea(x: 348, y: 164, heading: [90]),
                            EntWardArea(x: 348, y: 165, heading: [90]),
                            EntWardArea(x: 348, y: 166, heading: [90]),
                            EntWardArea(x: 348, y: 167, heading: [90]),
                            EntWardArea(x: 348, y: 168, heading: [90, 135, 180])
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
                            EntWardArea(x: 348, y: 64, heading: [90, 135]),
                            EntWardArea(x: 348, y: 65, heading: [90, 135]),
                            EntWardArea(x: 348, y: 66, heading: [90, 135]),
                            EntWardArea(x: 348, y: 67, heading: [90, 135]),
                            EntWardArea(x: 348, y: 68, heading: [90, 135, 180])
                        ]
                    } else {
                        wardArea = [
                            EntWardArea(x: innermostWard.x, y: innermostWard.y, heading: innermostWard.headings)
                        ]
                    }
                    
                    let headingForCompensation = majorSection.average - uvdBuffer[0].heading
                    
                    if let curResult = curResult {
                        struct EntTrackCandidateResult {
                            let dist: Float
                            let result: FineLocationTrackingOutput
                            let wardX: Float
                            let wardY: Float
                            let pathHeading: Float
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
                            
                            JupiterLogger.i(tag: "JupiterCalcManager", message: "(onUvdResult) index:\(uvd.index) - EntTrack Finished : ward=(\(wardX), \(wardY)) heading=\(pathHeading)")
                            
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
                                                                         pathHeading: pathHeading)
                            candidateResults.lock()
                            evaluatedCandidates.append(candidateResult)
                            candidateResults.unlock()
                        }
                        
                        if let bestCandidate = evaluatedCandidates.min(by: { $0.dist < $1.dist }) {
                            var tempResult = bestCandidate.result
                            tempResult.building_name = entManager.getEntTrackEndBuilding()
                            tempResult.level_name = innermostWard.level.name
                            JupiterLogger.i(tag: "JupiterCalcManager", message: "(onUvdResult) index:\(uvd.index) - EntTrack Finished : wardXY:[\(bestCandidate.wardX),\(bestCandidate.wardY)] // headings:\(bestCandidate.pathHeading) // dist \(bestCandidate.dist) // tempResult \(tempResult)")
                            startIndoorTracking(uvd: uvd, fltResult: tempResult)
                        } else {
                            JupiterLogger.i(tag: "JupiterCalcManager", message: "(onUvdResult) index:\(uvd.index) - EntTrack Finished (evaluatedCandidates is empty)")
                        }
                    } else {
                        JupiterLogger.i(tag: "JupiterCalcManager", message: "(onUvdResult) index:\(uvd.index) - EntTrack Finished (curResult is nil)")
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
//                startIndoorTracking(uvd: uvd, fltResult: nil)
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
        } else {
            JupiterLogger.i(tag: "JupiterCalcManager", message: "(startIndoorSearching) jupiterPhase is \(jupiterPhase)")
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
                JupiterLogger.i(tag: "JupiterCalcManager", message: "(calcIndoorSearching) cannot find matched landmark with old user peak \(userPeak.id)")
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
                                                                                             mode: mode, isDrStraight: isDrStraight.0)
                let curSearchList = solutionEstimator.calculateSearchCand(lossParamAtEachCand: searchResult)
                if !curSearchList.isEmpty {
                    if let preSearchList = self.preSearchList, let preFisrt = preSearchList.first {
                        let uvdBufferForConnection = solutionEstimator.getUvdBufferForEstimation(startIndex: preFisrt.headResult.index,
                                                                                                 endIndex: userVelocity.index,
                                                                                                 uvdBuffer: uvdBuffer)
                        struct ConnectedSearchCandidate {
                            let loss: Float
                            let preSearch: SelectedSearch
                            let curSearch: SelectedSearch
                        }
                        
                        var connectedCandidates = [ConnectedSearchCandidate]()
                        // 이전 Search 결과 있음
                        guard let curResult = self.curResult else { return }
                        let key = "\(self.sectorId)_\(curResult.building_name)_\(curResult.level_name)"
                        guard let linkData = PathMatcher.shared.linkData[key] else { return }
                        
                        for preSearch in preSearchList {
                            for curSearch in curSearchList {
                                guard let preLast = preSearch.traj.last, let curFirst = curSearch.traj.first else { continue }
                                JupiterLogger.i(tag: "JupiterCalcManager",
                                                message: "(calcIndoorSearching) preLastH= \(preLast.heading), curFirstH= \(curFirst.heading)")
                                let dh = headingDelta(preLast.heading, curFirst.heading)
                                if dh > 45 { continue }
                                guard let preRecent = preSearch.recent, let curOlder = curSearch.older else { continue }
                                var preLinkGroupSet = Set<Int>()
                                var curLinkGroupSet = Set<Int>()
                                for preLink in preRecent.matched_links {
                                    guard let matchedLink = linkData[preLink] else { continue }
                                    preLinkGroupSet.insert(matchedLink.group_number)
                                }
                                
                                for curLink in curOlder.matched_links {
                                    guard let matchedLink = linkData[curLink] else { continue }
                                    curLinkGroupSet.insert(matchedLink.group_number)
                                }
                                
                                let isInSameLinkGroup = !preLinkGroupSet.isDisjoint(with: curLinkGroupSet)
                                let dx = preRecent.x - curOlder.x
                                let dy = preRecent.y - curOlder.y
                                let dist: Float = sqrt(Float(dx*dx + dy*dy))
                                
                                JupiterLogger.i(tag: "JupiterCalcManager",
                                                message: "(calcIndoorSearching) preLastH= \(preLast.heading), curFirstH= \(curFirst.heading), dist= \(dist)")
                                
                                if !isInSameLinkGroup {
                                    continue
                                }
                                let loss = (dist + (curSearch.loss*3))/4
                                var newCurSearch = curSearch
                                newCurSearch.loss = loss
                                connectedCandidates.append(ConnectedSearchCandidate(loss: loss, preSearch: preSearch, curSearch: newCurSearch))
                                JupiterLogger.i(tag: "JupiterCalcManager",
                                                message: "(calcIndoorSearching) preSearch=\(preSearch.headResult), curSearch=\(curSearch.headResult), loss= \(loss) appended")
                            }
                        }
                        
                        self.debug_list_search = curSearchList
                        
                        if connectedCandidates.isEmpty {
                            JupiterLogger.i(tag: "JupiterCalcManager",
                                            message: "(calcIndoorSearching) every combination is not connected")
                        }
                        
                        let topMatchedCurSearchList: [SelectedSearch] = connectedCandidates
                            .sorted { $0.loss < $1.loss }
                            .prefix(5)
                            .map { $0.curSearch }
                        
                        if !topMatchedCurSearchList.isEmpty {
                            for i in 0..<topMatchedCurSearchList.count {
                                JupiterLogger.i(tag: "JupiterCalcManager",
                                                message: "(calcIndoorSearching) topMatchedCurSearch : \(i) -> [\(topMatchedCurSearchList[i].headResult.x), \(topMatchedCurSearchList[i].headResult.y), \(topMatchedCurSearchList[i].headResult.absolute_heading)] // loss -> \(topMatchedCurSearchList[i].loss)")
                            }
                            
                            if let selectedSearch = topMatchedCurSearchList.first {
                                let bestResult = selectedSearch.headResult
                                self.debug_selected_search = selectedSearch
                                self.searchingIndex = userPeak.peak_index
                                self.curResult = bestResult
                                JupiterResultState.isIndoor = true
                                JupiterLogger.i(tag: "JupiterCalcManager",
                                                message: "(calcIndoorSearching) Connected // searchResult= [index:\(bestResult.index), x:\(bestResult.x), y:\(bestResult.y), h:\(bestResult.absolute_heading)]")
                                stackManager.stackSearchResult(searchResult: bestResult)
                                
                                var curResult = bestResult
                                guard let pmResult = PathMatcher.shared.pathMatching(sectorId: sectorId, building: curResult.building_name, level: curResult.level_name, x: curResult.x, y: curResult.y, heading: curResult.absolute_heading, isUseHeading: false, mode: mode, paddingValues: JupiterMode.PADDING_VALUES_MEDIUM) else { break peakHandling }
                                curResult.x = pmResult.x
                                curResult.y = pmResult.y
                                curResult.absolute_heading = pmResult.heading
                                
                                correctionIndex = userPeak.peak_index
                                correctionId = userPeak.id
                                startIndoorTracking(uvd: userVelocity, fltResult: curResult)
                            }
                        }
                    } else {
                        // 이전 Search 결과 없음
                        self.debug_list_search = curSearchList
                        if let selectedSearch = solutionEstimator.calculateSearchResult(lossParamAtEachCand: searchResult) {
                            let bestResult = selectedSearch.headResult
                            self.debug_selected_search = selectedSearch
                            self.searchingIndex = userPeak.peak_index
                            self.curResult = bestResult
                            JupiterResultState.isIndoor = true
                            JupiterLogger.i(tag: "JupiterCalcManager", message: "(calcIndoorSearching) First // searchResult= [index:\(bestResult.index), x:\(bestResult.x), y:\(bestResult.y), h:\(bestResult.absolute_heading)]")
                            stackManager.stackSearchResult(searchResult: bestResult)
                        }
                    }
                    self.preSearchList = curSearchList
                } else {
//                    self.debug_list_search = []
                    self.debug_selected_search = nil
                }
            }
        }
    }
    
    func headingDelta(_ a: Float, _ b: Float) -> Float {
        var d = a - b
        d = fmod(d + 540.0, 360.0) - 180.0
        return abs(d)
    }
    
    private func checkResultConnectionForTracking(preResult: FineLocationTrackingOutput, curResult: FineLocationTrackingOutput, uvdBuffer: [UserVelocity], mode: UserMode) -> (dLoss: Float, hLoss: Float)? {
        if (preResult.index == 0 || curResult.index == 0) { return nil }
        
        let distanceCondition: Float = mode == .MODE_PEDESTRIAN ? 10 : 20
        let headingCondition: Float = mode == .MODE_PEDESTRIAN ? 15 : 30

        if (curResult.index <= preResult.index) {
            JupiterLogger.i(tag: "JupiterCalcManager", message: "(checkResultConnectionForTracking) : curResultIndex=\(curResult.index) , preResultIndex=\(preResult.index)")
            return nil
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
            
            guard let prePmResult = PathMatcher.shared.pathMatching(sectorId: sectorId, building: preResult.building_name, level: preResult.level_name, x: preResult.x, y: preResult.y, heading: preResult.absolute_heading, isUseHeading: false, mode: mode, paddingValues: JupiterMode.PADDING_VALUES_MEDIUM) else { return nil }
            guard let curPmResult = PathMatcher.shared.pathMatching(sectorId: sectorId, building: curResult.building_name, level: curResult.level_name, x: curResult.x, y: curResult.y, heading: curResult.absolute_heading, isUseHeading: false, mode: mode, paddingValues: JupiterMode.PADDING_VALUES_MEDIUM) else { return nil }

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
            
            guard let pmResult = PathMatcher.shared.pathMatching(sectorId: sectorId, building: curResult.building_name, level: curResult.level_name, x: propagatedXyh[0], y: propagatedXyh[1], heading: propagatedXyh[2], isUseHeading: false, mode: mode, paddingValues: JupiterMode.PADDING_VALUES_MEDIUM) else { return nil }
            
            let diffX = abs(pmResult.x - curPmResult.x)
            let diffY = abs(pmResult.y - curPmResult.y)
            let curResultHeading = Float(TJLabsUtilFunctions.shared.compensateDegree(Double(curPmResult.heading)))
            
            var diffH: Float = abs(pmResult.heading - curResultHeading)
            if (diffH > 270) { diffH = 360 - diffH }
            
            let rendezvousDistance = sqrt(diffX*diffX + diffY*diffY)
            JupiterLogger.i(tag: "JupiterCalcManager", message: "(checkResultConnectionForTracking) : rendezvous // cur:[\(curPmResult.x),\(curPmResult.y),\(curPmResult.heading)] , pm:[\(pmResult.x),\(pmResult.y),\(pmResult.heading)]")
            JupiterLogger.i(tag: "JupiterCalcManager", message: "(checkResultConnectionForTracking) : rendezvousDistance=\(rendezvousDistance) , diffH=\(diffH)")
            if (rendezvousDistance <= distanceCondition) && diffH <= headingCondition {
                return (rendezvousDistance, diffH)
            }
        }
        return nil
    }
    
    private func startIndoorTracking(uvd: UserVelocity, fltResult: FineLocationTrackingOutput?) {
        jupiterPhase = .TRACKING
        guard let fltResult = fltResult else { return }
        curResult = fltResult
        kalmanFilter?.activateKalmanFilter(fltResult: fltResult)
        JupiterResultState.isIndoor = true
        delegate?.isJupiterPhaseChanged(index: uvd.index, phase: jupiterPhase, xyh: [fltResult.x, fltResult.y, fltResult.absolute_heading])
        JupiterLogger.i(tag: "JupiterCalcManager", message: "(startIndoorTracking) : start indoor tracking at uvd:\(fltResult.index) // phase = \(jupiterPhase)")
        JupiterLogger.i(tag: "JupiterCalcManager", message: "(startIndoorTracking) : start indoor tracking at xyh:[\(fltResult.x), \(fltResult.y), \(fltResult.absolute_heading)]")
    }
    
    private func calcIndoorResult(mode: UserMode, uvd: UserVelocity, olderPeakIndex: Int?, jumpInfo: JumpInfo?, uturnLink: Bool = false) {
        let (tuResult, isDidPathTrajMatching) = updateResultFromTimeUpdate(mode: mode, uvd: uvd, pastUvd: pastUvd, pathMatchingCondition: self.pathMatchingCondition, uturnLink: uturnLink)
        guard var tuResult = tuResult else { return }
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
            let isInMapEnd = PathMatcher.shared.checkIsInMapEnd(sectorId: sectorId, tuResult: tuResult)
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
            } else if userPeak.peak_index <= recoveryIndex {
                JupiterLogger.i(tag: "JupiterCalcManager", message: "(applyCorrectionWithPeaks) Recovery worked at \(recoveryIndex) uvd index")
                break peakHandling
            }

            // MARK: - Use Two peaks anytime
            let curResultBuffer = stackManager.getCurResultBuffer()
            if let matchedWithUserPeak = landmarkTagger.findMatchedLandmarkWithUserPeak(userPeak: userPeak,
                                                                                       curResult: self.curResult,
                                                                                       curResultBuffer: curResultBuffer),
               let linkInfosWhenPeak = PathMatcher.shared.getLinkInfosWithResult(sectorId: sectorId,
                                                                                   result: matchedWithUserPeak.matchedResult,
                                                                                   checkAll: true)
            {
                self.debug_landmark = matchedWithUserPeak.landmark
                stackManager.stackUserPeakAndLinks(userPeakAndLinks: (userPeak, linkInfosWhenPeak))
            } else {
                JupiterLogger.i(tag: "JupiterCalcManager", message: "(applyCorrectionWithPeaks) cannot find matched landmark with user peak \(userPeak.id) or cannot find linkInfosWhenPeak")
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
                                                                           acceptDist: 15)
                    
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
                                                                                       mode: mode, matchedNode: matchedNode, isDrStraight: isDrStraight.0)
                    let filteredCandResult = solutionEstimator.calculateJupiterResult(lossParamAtEachCand: lossParamResult, isLinkNotChanged: isLinkNotChanged)
                    let trackingCandResult = solutionEstimator.calculateTrackingResult(lossParamAtEachCand: lossParamResult, isLinkNotChanged: isLinkNotChanged, olderUserPeak: olderUserPeak, preFixed: preFixed)
                    if !trackingCandResult.isEmpty {
                        JupiterLogger.i(tag: "JupiterCalcManager", message: "(applyCorrectionWithPeaks) : trackingCandResult= \(trackingCandResult)")
                        self.debug_tracking_cand = trackingCandResult[0]
                    }
                    
                    if let selectedCandResult = solutionEstimator.selectCandidate(filtered: filteredCandResult) {
                        var trackingResult = selectedCandResult.0
                        self.debug_ratio = selectedCandResult.1
                        
                        let headResult = trackingResult.headResult
                        var trackingCoord = [Float]()
                        var paddings = JupiterMode.PADDING_VALUES_LARGE

                        if isDrStraight.0 {
                            let key = "\(sectorId)_\(curResult.building_name)_\(curResult.level_name)"
                            if let linkData = PathMatcher.shared.linkData[key],
                               let recent = trackingResult.recent,
                               let _ = trackingResult.older {
                                let bestCand = recent
                                let linkNums = bestCand.matched_links
                                if linkNums.count == 1 {
                                    if let matchedLink = linkData[linkNums[0]] {
                                        let limitType = PathMatcher.shared.getLimitationTypeWithLink(link: matchedLink)
                                        paddings = PathMatcher.shared.getLimitationRangeWithType(limitType: limitType)
                                    }
                                } else {
                                    let limitType: LimitationType = .SMALL_LIMIT
                                    paddings = PathMatcher.shared.getLimitationRangeWithType(limitType: limitType)
                                }
                            }
                        }
                        
                        if let _ = self.preFixed, !trackingCandResult.isEmpty {
                            let dx = trackingCandResult[0].headResult.x - headResult.x
                            let dy = trackingCandResult[0].headResult.y - headResult.y
                            let dist = sqrt(dx*dx + dy*dy)
                            let dh = headingDelta(trackingCandResult[0].headResult.absolute_heading, headResult.absolute_heading)
                            
                            if dist > 10 || dh > 30 {
                                trackingResult = trackingCandResult[0]
                                JupiterLogger.i(tag: "JupiterCalcManager", message: "(applyCorrectionWithPeaks) : use trackingCandResult (1)")
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
                                                         paddings: paddings)

                        let updatedCurPmResult = stackManager.editCurPmResultBuffer(sectorId: sectorId,
                                                                                    mode: mode,
                                                                                    from: recentUserPeak.peak_index,
                                                                                    shifteTraj: trackingResult.traj,
                                                                                    paddings: paddings)

                        kalmanFilter.editTuResultBuffer(sectorId: sectorId,
                                                        mode: mode,
                                                        from: userPeak.peak_index,
                                                        shifteTraj: trackingResult.traj,
                                                        curResult: curResult,
                                                        paddings: paddings)

                        trackingCoord = [updatedCurPmResult.x, updatedCurPmResult.y, updatedCurPmResult.absolute_heading]
                        
                        if !isLinkNotChanged {
                            let curPmResultBufferFromRecentPeak = stackManager.getCurPmResultBuffer(from: recentUserPeak.peak_index)
                            PathMatcher.shared.editPassingLinkBuffer(from: recentUserPeak.peak_index,
                                                                     sectorId: sectorId,
                                                                     curPmResultBuffer: curPmResultBufferFromRecentPeak)
                        }

                        if let pmResult = PathMatcher.shared.pathMatching(sectorId: sectorId,
                                                                         building: curResult.building_name,
                                                                         level: curResult.level_name,
                                                                         x: trackingCoord[0],
                                                                         y: trackingCoord[1],
                                                                         heading: trackingCoord[2],
                                                                         isUseHeading: true,
                                                                         mode: mode,
                                                                         paddingValues: paddings) {
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
                                                                                      checkAll: true) {
                            let jumpInfo = JumpInfo(link_number: matchedLink.number, jumped_nodes: [])
                            PathMatcher.shared.updateNodeAndLinkInfo(sectorId: sectorId,
                                                                     uvdIndex: userVelocity.index,
                                                                     curResult: curPmResult2,
                                                                     jumpInfo: jumpInfo,
                                                                     pLinkCutIndex: recentUserPeak.peak_index)
                        } else {
                            PathMatcher.shared.initPassedLinkInfo()
                        }
                    } else if !trackingCandResult.isEmpty {
                        JupiterLogger.i(tag: "JupiterCalcManager", message: "(applyCorrectionWithPeaks) : use trackingCandResult (2)")
                        let trackingResult = trackingCandResult[0]
                        self.debug_ratio = trackingResult.loss
                        
                        let headResult = trackingResult.headResult
                        var trackingCoord = [Float]()
                        var paddings = JupiterMode.PADDING_VALUES_LARGE

                        if isDrStraight.0 {
                            let key = "\(sectorId)_\(curResult.building_name)_\(curResult.level_name)"
                            if let linkData = PathMatcher.shared.linkData[key],
                               let recent = trackingResult.recent,
                               let _ = trackingResult.older {
                                let bestCand = recent
                                let linkNums = bestCand.matched_links
                                if linkNums.count == 1 {
                                    if let matchedLink = linkData[linkNums[0]] {
                                        let limitType = PathMatcher.shared.getLimitationTypeWithLink(link: matchedLink)
                                        paddings = PathMatcher.shared.getLimitationRangeWithType(limitType: limitType)
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
                                                  lm_x: trackingResult.recent?.x,
                                                  lm_y: trackingResult.recent?.y,
                                                  lm_links: trackingResult.links,
                                                  lm_linkGroups: trackingResult.linkGroups)
                        stackManager.editCurResultBuffer(sectorId: sectorId,
                                                         mode: mode,
                                                         from: userPeak.peak_index,
                                                         shifteTraj: trackingResult.traj,
                                                         paddings: paddings)

                        let updatedCurPmResult = stackManager.editCurPmResultBuffer(sectorId: sectorId,
                                                                                    mode: mode,
                                                                                    from: recentUserPeak.peak_index,
                                                                                    shifteTraj: trackingResult.traj,
                                                                                    paddings: paddings)

                        kalmanFilter.editTuResultBuffer(sectorId: sectorId,
                                                        mode: mode,
                                                        from: userPeak.peak_index,
                                                        shifteTraj: trackingResult.traj,
                                                        curResult: curResult,
                                                        paddings: paddings)

                        trackingCoord = [updatedCurPmResult.x, updatedCurPmResult.y, updatedCurPmResult.absolute_heading]
                        
                        if !isLinkNotChanged {
                            let curPmResultBufferFromRecentPeak = stackManager.getCurPmResultBuffer(from: recentUserPeak.peak_index)
                            PathMatcher.shared.editPassingLinkBuffer(from: recentUserPeak.peak_index,
                                                                     sectorId: sectorId,
                                                                     curPmResultBuffer: curPmResultBufferFromRecentPeak)
                        }

                        if let pmResult = PathMatcher.shared.pathMatching(sectorId: sectorId,
                                                                         building: curResult.building_name,
                                                                         level: curResult.level_name,
                                                                         x: trackingCoord[0],
                                                                         y: trackingCoord[1],
                                                                         heading: trackingCoord[2],
                                                                         isUseHeading: true,
                                                                         mode: mode,
                                                                         paddingValues: paddings) {
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
                                                                                      checkAll: true) {
                            let jumpInfo = JumpInfo(link_number: matchedLink.number, jumped_nodes: [])
                            PathMatcher.shared.updateNodeAndLinkInfo(sectorId: sectorId,
                                                                     uvdIndex: userVelocity.index,
                                                                     curResult: curPmResult2,
                                                                     jumpInfo: jumpInfo,
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
            isUseHeading = !JupiterResultState.isVenus
            if let kf = kalmanFilter, pathMatchingType == .NARROW {
                self.paddingValues = kf.getPaddings()
            }
            
            let paddings = (!isPdrMode && levelName == "B0") ? JupiterMode.PADDING_VALUES_MEDIUM : self.paddingValues
            JupiterLogger.i(tag: "JupiterCalcManager", message: "(makeCurrentResult) - result: paddings \(paddings)")
            if let pmResult = PathMatcher.shared.pathMatching(sectorId: sectorId, building: buildingName, level: levelName, x: result.x, y: result.y, heading: result.absolute_heading, headingRange: headingRange, isUseHeading: isUseHeading, mode: .MODE_VEHICLE, paddingValues: paddings) {
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
        
        if mustInSameLink && levelName != "B0", let curLinkInfo = PathMatcher.shared.getCurPassedLinkInfo() {
            let userCoord = curLinkInfo.user_coord
            let linkDirs = curLinkInfo.included_heading
            if (userCoord.count == 2 && linkDirs.count == 2) {
                let MARGIN: Float = 30
                if (linkDirs.contains(0) && linkDirs.contains(180)) {
                    // 이전 y축 값과 현재 y값은 같아야 함
                    let diffHeading = Float(TJLabsUtilFunctions.shared.compensateDegree(Double(abs(result.absolute_heading) - linkDirs[0])))
                    if !((diffHeading > 90-MARGIN && diffHeading <= 90+MARGIN) || (diffHeading > 270-MARGIN && diffHeading <= 270+MARGIN)) {
                        result.y = userCoord[1]
                    }
                    
                } else if (linkDirs.contains(90) && linkDirs.contains(270)) {
                    // 이전 x축 값과 현재 x축 값은 같아야 함
                    let diffHeading = Float(TJLabsUtilFunctions.shared.compensateDegree(Double(abs(result.absolute_heading) - linkDirs[0])))
                    if !((diffHeading > 90-MARGIN && diffHeading <= 90+MARGIN) || (diffHeading > 270-MARGIN && diffHeading <= 270+MARGIN)) {
                        result.x = userCoord[0]
                    }
                }
            }
        }
        
        if isUseHeading && phase == .TRACKING, let curResult = self.curResult {
            let diffX = result.x - curResult.x
            let diffY = result.y - curResult.y
            let diffNorm = sqrt(diffX*diffX + diffY*diffY)
            if diffNorm >= 2 {
                kalmanFilter?.updateTuPosition(coord: [result.x, result.y])
            }
        }
        
        if KalmanState.isKalmanFilterRunning {
            let isInLevelChangeArea = buildingLevelChanger!.checkInLevelChangeArea(sectorId: sectorId, building: buildingName, level: levelName, x: result.x, y: result.y, mode: mode)
            PathMatcher.shared.updateNodeAndLinkInfo(sectorId: sectorId, uvdIndex: curIndex, curResult: result, jumpInfo: jumpInfo, isInLevelChangeArea: isInLevelChangeArea)
        }
        
        return result
    }
    
    private func calcJumpedNodes(from: FineLocationTrackingOutput?,
                                 to: FineLocationTrackingOutput,
                                 curLinkInfo: PassedLinkInfo,
                                 jumpedLinkNum: Int) -> JumpInfo? {
        var jumpInfo: JumpInfo?
        
        let building = to.building_name
        let level = to.level_name
        let key = "\(sectorId)_\(building)_\(level)"
        
        guard let linkData = PathMatcher.shared.linkData[key] else { return nil }
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
                if let matchedNodeResult = PathMatcher.shared.getMatchedNodeWithCoord(sectorId: sectorId, fltResult: to, originCoord: point, coordToCheck: point, paddingValues: [1, 1, 1, 1]) {
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
                if let matchedNodeResult = PathMatcher.shared.getMatchedNodeWithCoord(sectorId: sectorId, fltResult: to, originCoord: point, coordToCheck: point, paddingValues: [1, 1, 1, 1]) {
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
    
    func determineUserMode(mode: UserMode) {
        self.curUserModeEnum = mode
        if mode == .MODE_AUTO {
            self.curUserMode = "AUTO"
        } else if mode == .MODE_VEHICLE {
            self.curUserMode = "DR"
        } else if mode == .MODE_PEDESTRIAN {
            self.curUserMode = "PDR"
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
    
    func onVelocityResult(_ generator: UVDGenerator, kmPh: Double) {
        curVelocity = Float(kmPh)
    }
    func onMagNormSmoothingVarResult(_ generator: TJLabsCommon.UVDGenerator, value: Double) {
        //
    }
    
    // MARK: - Bridging
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
}
