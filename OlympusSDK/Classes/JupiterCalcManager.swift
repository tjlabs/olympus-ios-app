import Foundation
import UIKit
import simd
import TJLabsCommon
import TJLabsResource

class JupiterCalcManager: RFDGeneratorDelegate, UVDGeneratorDelegate, TJLabsResourceManagerDelegate, BuildingLevelChangerDelegate {
    func isBuildingLevelChanged(isChanged: Bool, newBuilding: String, newLevel: String, newCoord: [Float]) {
        // TODO
    }
    
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
    private var recoveryManager: RecoveryManager?
    
    // MARK: - User Properties
    var id: String = ""
    var sectorId: Int = 0
    var region: String = JupiterRegion.KOREA.rawValue
    var os: String = JupiterNetworkConstants.OPERATING_SYSTEM
    
    // MARK: - Generator
    private var rfdGenerator: RFDGenerator?
    private var uvdGenerator: UVDGenerator?
    private var uvdStopTimestamp: Double = 0
    private var rfdEmptyMillis: Double = 0
    private var pressure: Float = 0
    
    var curRfd = ReceivedForce(tenant_user_name: "", mobile_time: 0, rfs: [String: Float](), pressure: 0)
    var curUvd = UserVelocity(tenant_user_name: "", mobile_time: 0, index: 0, length: 0, heading: 0, looking: false)
    var pastUvd = UserVelocity(tenant_user_name: "", mobile_time: 0, index: 0, length: 0, heading: 0, looking: false)
    var curVelocity: Float = 0
    var curUserMode: String = "AUTO"
    var curUserModeEnum: UserMode = .MODE_AUTO
    
    // MARK: - Constants
    private let AVG_BUFFER_SIZE = 10
    
    // MARK: - Landmark Correction
    private var correctionIndex: Int = 0
    var paddingValues = JupiterMode.PADDING_VALUES_DR
    
    // MARK: - Etc..
    private var pathMatchingCondition = PathMatchingCondition()
    private var report = -1
    
    // MARK: - Result
    var jupiterPhase: JupiterPhase = .NONE
    var curResult: FineLocationTrackingOutput?
    var preResult: FineLocationTrackingOutput?
    
    var curPathMatchingResult: FineLocationTrackingOutput?
    var prePathMatchingResult: FineLocationTrackingOutput?
    
    // MARK: - Debuging
    var debug_tu_xyh: [Float] = [0, 0, 0]
    var debug_landmark: LandmarkData?
    var debug_best_landmark: PeakData?
    var debug_recon_raw_traj: [[Double]]?
    var debug_recon_corr_traj: [FineLocationTrackingOutput]?
    var debug_recovery_result: RecoveryResult?
    var debug_recovery_result_v2: RecoveryResult_v2?
    
    // MARK: - init & deinit
    init(region: String, id: String, sectorId: Int) {
        self.id = id
        self.sectorId = sectorId
        self.region = region
        
        self.entManager = EntranceManager(sectorId: sectorId)
        self.buildingLevelChanger = BuildingLevelChanger(sectorId: sectorId)
        self.wardAvgManager = WardAveragingManager(bufferSize: AVG_BUFFER_SIZE)
        self.kalmanFilter = KalmanFilter(stackManager: stackManager)
        self.landmarkTagger = LandmarkTagger(sectorId: sectorId)
        self.recoveryManager = RecoveryManager(sectorId: sectorId)
        
        tjlabsResourceManager.delegate = self
        buildingLevelChanger?.delegate = self
    }
    
    deinit { }
    
    // MARK: - Functions
    func start(completion: @escaping (Bool, String) -> Void) {
        tjlabsResourceManager.loadJupiterResource(region: region, sectorId: sectorId, completion: { isSuccess in
            let msg: String = isSuccess ? "JupiterCalcManager start success" : "JupiterCalcManager start failed"
            completion(isSuccess, msg)
        })
    }
    
    // MARK: - Set REC length
    public func setSendRfdLength(_ length: Int = 10) {
        DataBatchSender.shared.sendRfdLength = length
    }
    
    public func setSendUvdLength(_ length: Int = 10) {
        DataBatchSender.shared.sendUvdLength = length
    }
    
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

        rfdGenerator?.generateRfd()
        rfdGenerator?.delegate = self
        rfdGenerator?.pressureProvider = { [self] in
            return self.pressure
        }

        uvdGenerator?.setUserMode(mode: mode)
        uvdGenerator?.generateUvd()
        uvdGenerator?.delegate = self

        completion(true, "")
    }
    
    func stopGenerator() {
        rfdGenerator?.stopRfdGeneration()
        uvdGenerator?.stopUvdGeneration()
    }

    
    func isPossibleReturnJupiterResult() -> Bool {
//        let buildingName = curJupiterResult.building_name
//        let levelName = curJupiterResult.level_name
//        let x = curJupiterResult.x
//        let y = curJupiterResult.y
//
//        return x != 0.0 && y != 0.0 && !buildingName.isEmpty && !levelName.isEmpty
        return true
    }
    
    func getJupiterResult() -> JupiterResult? {
        let currentTime = TJLabsUtilFunctions.shared.getCurrentTimeInMilliseconds(as: .int) as! Int
        guard let curPathMatchingResult = self.curPathMatchingResult else { return nil }
        let buildingName = curPathMatchingResult.building_name
        let levelName = curPathMatchingResult.level_name
        let scc = curPathMatchingResult.scc
        let x = curPathMatchingResult.x
        let y = curPathMatchingResult.y
        let absoluteHeading = curPathMatchingResult.absolute_heading
        
        var llh: LLH?
        if let affineParam = AffineConverter.shared.getAffineParam(sectorId: sectorId) {
            let converted = AffineConverter.shared.convertPpToLLH(x: Double(x), y: Double(y), heading: Double(absoluteHeading), param: affineParam)
            llh?.lat = converted.lat
            llh?.lon = converted.lon
            llh?.heading = converted.heading
        }
        
        let jupiterResult = JupiterResult(
            mobile_time: currentTime,
            building_name: buildingName,
            level_name: levelName,
            scc: scc,
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
            validity_flag: 0
        )
        
        return jupiterResult
    }
    
    func getJupiterDebugResult() -> JupiterDebugResult? {
        let currentTime = TJLabsUtilFunctions.shared.getCurrentTimeInMilliseconds(as: .int) as! Int
        guard let curPathMatchingResult = self.curPathMatchingResult else { return nil }
        let buildingName = curPathMatchingResult.building_name
        let levelName = curPathMatchingResult.level_name
        let scc = curPathMatchingResult.scc
        let x = curPathMatchingResult.x
        let y = curPathMatchingResult.y
        let absoluteHeading = curPathMatchingResult.absolute_heading
        
        var llh: LLH?
        if let affineParam = AffineConverter.shared.getAffineParam(sectorId: sectorId) {
            let converted = AffineConverter.shared.convertPpToLLH(x: Double(x), y: Double(y), heading: Double(absoluteHeading), param: affineParam)
            llh?.lat = converted.lat
            llh?.lon = converted.lon
            llh?.heading = converted.heading
        }
        
        let jupiterDebugResult = JupiterDebugResult(
            mobile_time: currentTime,
            building_name: buildingName,
            level_name: levelName,
            scc: scc,
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
            tu_xyh: self.debug_tu_xyh,
            landmark: self.debug_landmark,
            best_landmark: self.debug_best_landmark,
            recon_raw_traj: self.debug_recon_raw_traj,
            recon_corr_traj: self.debug_recon_corr_traj,
            recovery_result: self.debug_recovery_result,
            recovery_result_v2: self.debug_recovery_result_v2
        )
        
        return jupiterDebugResult
    }

    // MARK: - RFDGeneratorDelegate Methods
    func onRfdResult(_ generator: TJLabsCommon.RFDGenerator, receivedForce: TJLabsCommon.ReceivedForce) {
        handleRfd(rfd: receivedForce)
    }
    
    func handleRfd(rfd: ReceivedForce) {
        let currentTime = TJLabsUtilFunctions.shared.getCurrentTimeInMilliseconds(as: .int) as! Int
        DataBatchSender.shared.sendRfd(rfd: rfd)
        
        // Update Current RFD
        self.curRfd = rfd
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
        let currentTime = TJLabsUtilFunctions.shared.getCurrentTimeInMilliseconds(as: .int) as! Int
        DataBatchSender.shared.sendUvd(uvd: userVelocity)
        determineUserMode(mode: mode)
        
        // Update Current UVD
        self.curUvd = userVelocity
        let curIndex = userVelocity.index
        
        guard let entManager = self.entManager else { return }
        guard let blChanger = self.buildingLevelChanger else { return }
        guard let landmarkTagger = self.landmarkTagger else { return }
        guard let recoveryManager = self.recoveryManager else { return }
        stackManager.stackUvd(uvd: userVelocity)
        let uvdBuffer = stackManager.getUvdBuffer()
        
        let capturedRfd = self.curRfd
        let bleData = capturedRfd.rfs // [String: Float] BLE_ID: RSSI
//        var bleData = [String: Float]() // [String: Float] BLE_ID: RSSI
//        for (key, value) in capturedRfd.rfs {
//            let rssi = value*1.25
//            if rssi > -100 {
//                bleData[key] = rssi
//            }
//        }
        
        var reconCurResultBuffer: [FineLocationTrackingOutput]?
        var olderPeakIndex: Int?
        
        // Moving Averaging
        guard let wardAvgManager = wardAvgManager else { return }
        let avgBleData: [String: Float] = wardAvgManager.updateEpoch(bleData: bleData)
        
        var jumpInfo: JumpInfo?
        var blTagResult: BuildingLevelTagResult?
        if let userPeak = peakDetector.updateEpoch(uvdIndex: curIndex, bleAvg: avgBleData) {
            peakHandling: do {
                JupiterLogger.i(tag: "JupiterCalcManager", message: "(onUvdResult) PEAK detected : id=\(userPeak.id) // peak_idx=\(userPeak.peak_index), peak_rssi=\(userPeak.peak_rssi), detected_idx = \(userPeak.end_index), detected_rssi = \(userPeak.end_rssi)")
                startEntranceTracking(currentTime: currentTime, entManager: entManager, uvd: userVelocity, peakId: userPeak.id, bleData: bleData)
                
                // Building & Level Changer
                if let blTag = blChanger.isBuildingLevelChangerTagged(userPeak: userPeak, curResult: curResult, mode: mode),
                   let destinations = blChanger.getBuildingLevelDestination(tag: blTag, curResult: curResult),
                   let detectionResult = blChanger.determineTagDetection(time: currentTime, tag: blTag, buildingDestination: destinations.buildingDestination, levelDestination: destinations.levelDestination, tagCoord: [Float(blTag.x), Float(blTag.y)], curResult: curResult),
                   !JupiterResultState.isEntTrack {
                    blTagResult = detectionResult
                    if let kf = kalmanFilter {
                        kf.updateTuBuildingLevel(building: detectionResult.building, level: detectionResult.level)
                    }
                    break peakHandling
                }
                
                // LandmarkTag
                if userPeak.peak_index - correctionIndex < 10 {
                    JupiterLogger.i(tag: "JupiterCalcManager", message: "(onUvdResult) PEAK is too close with previous landmark correction")
                    break peakHandling
                }
                
                let curResultBuffer = stackManager.getCurResultBuffer()
                if let matchedWithUserPeak = landmarkTagger.findMatchedLandmarkWithUserPeak(userPeak: userPeak, curResult: self.curResult, curResultBuffer: curResultBuffer) {
                    self.debug_landmark = matchedWithUserPeak.landmark
                    if let linkInfoWhenPeak = PathMatcher.shared.getLinkInfoWithResult(sectorId: sectorId, result: matchedWithUserPeak.matchedResult) {
                        stackManager.stackUserPeakAndLink(userPeakAndLink: (userPeak, linkInfoWhenPeak))
                    }
                }
                
                if !JupiterResultState.isEntTrack {
                    guard let curResult = self.curResult, let curPmResult = self.curPathMatchingResult else { break peakHandling }
                    JupiterResultState.isInRecoveryProcess = true
                    let userPeakAndLinkBuffer = stackManager.getUserPeakAndLinkBuffer()
                    if userPeakAndLinkBuffer.count < 3 { return }
                    let thirdUserPeak = userPeakAndLinkBuffer[userPeakAndLinkBuffer.count-3].0
                    let secondUserPeak = userPeakAndLinkBuffer[userPeakAndLinkBuffer.count-2].0
                    let firstUserPeak = userPeakAndLinkBuffer[userPeakAndLinkBuffer.count-1].0
                    
                    let uvdBufferForRecovery = recoveryManager.getUvdBufferForRecovery(startIndex: thirdUserPeak.peak_index, endIndex: userVelocity.index, uvdBuffer: uvdBuffer)
                    let headingSearchRange = recoveryManager.getRecoveryRange(olderPeakIndex: thirdUserPeak.peak_index, curIndex: curIndex)
                    let pathHeadings = PathMatcher.shared.getPathMatchingHeadings(sectorId: sectorId,
                                                                                  building: curPmResult.building_name,
                                                                                  level: curPmResult.level_name,
                                                                                  x: curPmResult.x, y: curPmResult.y,
                                                                                  paddingValue: headingSearchRange, mode: mode)
                    if let tuResultWhenThirdPeak = kalmanFilter?.getTuResultWithUvdIndex(index: thirdUserPeak.peak_index) {
                        let curResultBuffer = stackManager.getCurResultBuffer()
                        if let matchedWithThirdPeak = landmarkTagger.findMatchedLandmarkWithUserPeak(userPeak: thirdUserPeak, curResult: curResult, curResultBuffer: curResultBuffer),
                           let matchedWithSecondPeak = landmarkTagger.findMatchedLandmarkWithUserPeak(userPeak: secondUserPeak, curResult: curResult, curResultBuffer: curResultBuffer),
                           let matchedWithFirstPeak = landmarkTagger.findMatchedLandmarkWithUserPeak(userPeak: firstUserPeak, curResult: curResult, curResultBuffer: curResultBuffer) {
                            let hasMajorDirection = stackManager.checkHasMajorDirection(uvdBuffer: uvdBufferForRecovery)
                            JupiterLogger.i(tag: "JupiterCalcManager", message: "(onUvdResult) BadCase: hasMajorDirection= \(hasMajorDirection)")
                            if hasMajorDirection {
                                let majorSection = stackManager.extractSectionWithLeastChange(inputArray: uvdBufferForRecovery.map{ Float($0.heading) })
                                JupiterLogger.i(tag: "JupiterCalcManager", message: "(onUvdResult) BadCase: majorSection= \(majorSection)")
                                let recoveryTrajList = recoveryManager.makeMultipleRecoveryTrajectory(uvdBuffer: uvdBufferForRecovery, majorSection: majorSection, pathHeadings: pathHeadings, endHeading: curResult.absolute_heading)
                                if let recoveryResult = recoveryManager.recoverWithMultipleTraj_v2(recoveryTrajList: recoveryTrajList,
                                                                                                userPeakAndLinkBuffer: userPeakAndLinkBuffer,
                                                                                                landmarks: (matchedWithThirdPeak.0, matchedWithSecondPeak.0, matchedWithFirstPeak.0),
                                                                                                tuResultWhenThirdPeak: tuResultWhenThirdPeak,
                                                                                                resultWhenFisrtPeak: matchedWithFirstPeak.1,
                                                                                                curPmResult: curPmResult, mode: mode),
                                let bestResult = recoveryResult.bestResult {
                                    self.debug_recovery_result_v2 = recoveryResult
                                    let recoveryCoord: [Float] = [bestResult.x, bestResult.y]
                                    kalmanFilter?.updateTuPosition(coord: recoveryCoord)
                                    self.curResult? = bestResult
                                    
                                    if let matchedLink = PathMatcher.shared.getLinkInfoWithResult(sectorId: sectorId, result: bestResult, checkAll: true) {
                                        let jumpInfo = JumpInfo(link_id: matchedLink.id, jumped_nodes: [])
                                        PathMatcher.shared.updateNodeAndLinkInfo(sectorId: sectorId, uvdIndex: curIndex, curResult: bestResult, mode: mode, jumpInfo: jumpInfo)
                                    } else {
                                        PathMatcher.shared.initPassedLinkInfo()
                                    }
                                    correctionIndex = userPeak.peak_index
                                }
                            }
                        }
                    }
                }
                
//                let curResultBuffer = stackManager.getCurResultBuffer()
//                if let matchedWithUserPeak = landmarkTagger.findMatchedLandmarkWithUserPeak(userPeak: userPeak, curResult: self.curResult, curResultBuffer: curResultBuffer) {
//                    self.debug_landmark = matchedWithUserPeak.landmark
//                    if let linkInfoWhenPeak = PathMatcher.shared.getLinkInfoWithResult(sectorId: sectorId, result: matchedWithUserPeak.matchedResult) {
//                        stackManager.stackUserPeakAndLink(userPeakAndLink: (userPeak, linkInfoWhenPeak))
//                        olderPeakIndex = stackManager.getOlderPeakIndex()
//                        if let bestResult = landmarkTagger.findBestLandmark(userPeak: userPeak, landmark: matchedWithUserPeak.landmark, matchedResult: matchedWithUserPeak.matchedResult, peakLinkGroupId: linkInfoWhenPeak.group_id) {
//                            let bestPeak = bestResult.0
//                            self.debug_best_landmark = bestPeak
//                            if let matchedTuResult = kalmanFilter?.getTuResultWithUvdIndex(index: userPeak.peak_index) {
//                                if let reconstructResult = landmarkTagger.reconstructTrajectory(peakIndex: userPeak.peak_index, bestLandmark: bestPeak, matchedResult: matchedWithUserPeak.matchedResult, startHeading: Double(matchedTuResult.heading), uvdBuffer: uvdBuffer, curResultBuffer: curResultBuffer, mode: mode) {
//                                    self.debug_recon_raw_traj = reconstructResult.0
//                                    self.debug_recon_corr_traj = reconstructResult.1
//                                    let resultForCorrection = reconstructResult.1[reconstructResult.1.count-1]
//                                    if let muResult = kalmanFilter?.measurementUpdate(sectorId: sectorId, resultForCorrection: resultForCorrection, mode: mode) {
//                                        self.correctionIndex = userPeak.peak_index
//                                        self.curResult = muResult
//                                        reconCurResultBuffer = reconstructResult.1
//                                        
//                                        // Landmark를 이용한 Correction 이후에 위치 Jump 판단 -> PassedNode와 Link 정보 업데이트
//                                        if let curLinkInfo = PathMatcher.shared.getCurPassedLinkInfo() {
//                                            jumpInfo = calcJumpedNodes(from: curPathMatchingResult, to: muResult, curLinkInfo: curLinkInfo, jumpedLinkId: bestResult.1, mode: mode)
//                                        }
//                                    }
//                                } else {
//                                    self.debug_recon_raw_traj = nil
//                                    self.debug_recon_corr_traj = nil
//                                    break peakHandling
//                                }
//                            } else {
//                                break peakHandling
//                            }
//                        } else {
//                            self.debug_best_landmark = nil
//                            break peakHandling
//                        }
//                    } else {
//                        break peakHandling
//                    }
//                }
            }
        }
        
        switch (jupiterPhase) {
        case .ENTERING:
            calcEntranceResult(currentTime: currentTime, entManager: entManager, uvd: userVelocity)
        case .TRACKING:
            calcIndoorResult(mode: mode, uvd: userVelocity, olderPeakIndex: olderPeakIndex, jumpInfo: jumpInfo)
        case .SEARCHING:
            print("Searching")
        case .NONE:
            print("None")
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
        
        // Bad Case 확인 (같은 좌표 20개)
//        if stackManager.checkIsBadCase() && !JupiterResultState.isEntTrack {
//            JupiterResultState.isInRecoveryProcess = true
//            let userPeakAndLinkBuffer = stackManager.getUserPeakAndLinkBuffer()
//            if userPeakAndLinkBuffer.count < 2 { return }
//            let olderUserPeak = userPeakAndLinkBuffer[userPeakAndLinkBuffer.count-2].0
//            let recentUserPeak = userPeakAndLinkBuffer[userPeakAndLinkBuffer.count-1].0
//            let uvdBufferForRecovery = recoveryManager.getUvdBufferForRecovery(startIndex: olderUserPeak.peak_index, endIndex: userVelocity.index, uvdBuffer: uvdBuffer)
//            let headingSearchRange = recoveryManager.getRecoveryRange(olderPeakIndex: olderUserPeak.peak_index, curIndex: curIndex)
//            let pathHeadings = PathMatcher.shared.getPathMatchingHeadings(sectorId: sectorId,
//                                                                          building: curPmResult.building_name,
//                                                                          level: curPmResult.level_name,
//                                                                          x: curPmResult.x, y: curPmResult.y,
//                                                                          paddingValue: headingSearchRange, mode: mode)
//            if let tuResultWhenOlderPeak = kalmanFilter?.getTuResultWithUvdIndex(index: olderUserPeak.peak_index) {
//                let curResultBuffer = stackManager.getCurResultBuffer()
//                if let matchedWithOlderPeak = landmarkTagger.findMatchedLandmarkWithUserPeak(userPeak: olderUserPeak, curResult: curResult, curResultBuffer: curResultBuffer),
//                   let matchedWithRecentPeak = landmarkTagger.findMatchedLandmarkWithUserPeak(userPeak: recentUserPeak, curResult: curResult, curResultBuffer: curResultBuffer) {
//                    let hasMajorDirection = stackManager.checkHasMajorDirection(uvdBuffer: uvdBufferForRecovery)
//                    JupiterLogger.i(tag: "JupiterCalcManager", message: "(onUvdResult) BadCase: hasMajorDirection= \(hasMajorDirection)")
//                    if hasMajorDirection {
//                        let majorSection = stackManager.extractSectionWithLeastChange(inputArray: uvdBufferForRecovery.map{ Float($0.heading) })
//                        JupiterLogger.i(tag: "JupiterCalcManager", message: "(onUvdResult) BadCase: majorSection= \(majorSection)")
//                        let recoveryTrajList = recoveryManager.makeMultipleRecoveryTrajectory(uvdBuffer: uvdBufferForRecovery, majorSection: majorSection, pathHeadings: pathHeadings, endHeading: curResult.absolute_heading)
//                        if let recoveryResult = recoveryManager.recoverWithMultipleTraj(recoveryTrajList: recoveryTrajList,
//                                                                                        userPeakAndLinkBuffer: userPeakAndLinkBuffer,
//                                                                                        landmarks: (matchedWithOlderPeak.0, matchedWithRecentPeak.0),
//                                                                                        tuResultWhenOlderPeak: tuResultWhenOlderPeak,
//                                                                                        curPmResult: curPmResult, mode: mode),
//                        let bestResult = recoveryResult.bestResult {
//                            self.debug_recovery_result = recoveryResult
//                            let recoveryCoord: [Float] = [bestResult.x, bestResult.y]
//                            kalmanFilter?.updateTuPosition(coord: recoveryCoord)
//                            self.curResult? = bestResult
//                            
//                            if let matchedLink = PathMatcher.shared.getLinkInfoWithResult(sectorId: sectorId, result: bestResult, checkAll: true) {
//                                let jumpInfo = JumpInfo(link_id: matchedLink.id, jumped_nodes: [])
//                                PathMatcher.shared.updateNodeAndLinkInfo(sectorId: sectorId, uvdIndex: curIndex, curResult: bestResult, mode: mode, jumpInfo: jumpInfo)
//                            } else {
//                                PathMatcher.shared.initPassedLinkInfo()
//                            }
//                        }
//                    } else {
//                        
//                    }
//                }
//            }
//        }
    }
    
    private func startEntranceTracking(currentTime: Int, entManager: EntranceManager, uvd: UserVelocity, peakId: String, bleData: [String: Float]) {
        if !JupiterResultState.isIndoor && jupiterPhase != .ENTERING {
            guard let entKey = entManager.checkStartEntTrack(wardId: peakId, sec: 3) else { return }
            jupiterPhase = .ENTERING
            JupiterResultState.isIndoor = true
            let entTrackData = entKey.split(separator: "_")
            JupiterLogger.i(tag: "JupiterCalcManager", message: "(onUvdResult) index:\(uvd.index) - entTrackData = \(entTrackData) ")
        }
        
        if jupiterPhase == .ENTERING {
            if let stopEntTrackResult = entManager.stopEntTrack(curResult: curResult, wardId: peakId) {
                JupiterLogger.i(tag: "JupiterCalcManager", message: "(onUvdResult) index:\(uvd.index) - EntTrack Finished : \(stopEntTrackResult.building_name) \(stopEntTrackResult.level_name) , [\(stopEntTrackResult.x),\(stopEntTrackResult.y),\(stopEntTrackResult.absolute_heading)]")
                // Entrance Tracking Finshid (Normal)
                startIndoorTracking(fltResult: stopEntTrackResult)
            }
            
            if entManager.forcedStopEntTrack(bleAvg: bleData, sec: 30) {
                // Entrance Tracking Finshid (Force)
                JupiterLogger.i(tag: "JupiterCalcManager", message: "(calcEntranceResult) index:\(uvd.index) - forcedStopEntTrack")
                startIndoorTracking(fltResult: nil)
                entManager.setEntTrackFinishedTimestamp(time: currentTime)
            }
        }
    }
    
    private func calcEntranceResult(currentTime: Int, entManager: EntranceManager, uvd: UserVelocity) {
        guard let entTrackResult = entManager.startEntTrack(currentTime: currentTime, uvd: uvd) else { return }
        self.curResult = entTrackResult
        JupiterLogger.i(tag: "JupiterCalcManager", message: "(calcEntranceResult) index:\(uvd.index) - entTrackResult // \(entTrackResult.building_name) \(entTrackResult.level_name) , x = \(entTrackResult.x) , y = \(entTrackResult.y) , h = \(entTrackResult.absolute_heading)")
    }
    
    private func startIndoorTracking(fltResult: FineLocationTrackingOutput?) {
        peakDetector.setBufferSize(size: 50)
        jupiterPhase = .TRACKING
        
        guard let fltResult = fltResult else { return }
        curResult = fltResult
//        curPathMatchingResult = fltResult
        kalmanFilter?.activateKalmanFilter(fltResult: fltResult)
        JupiterResultState.isIndoor = true
    }
    
    private func calcIndoorResult(mode: UserMode, uvd: UserVelocity, olderPeakIndex: Int?, jumpInfo: JumpInfo?) {
        let (tuResult, isDidPathTrajMatching) = updateResultFromTimeUpdate(mode: mode, uvd: uvd, pastUvd: pastUvd, pathMatchingCondition: self.pathMatchingCondition)
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
        if let tuResult = kalmanFilter?.getTuResult() {
            self.debug_tu_xyh = [tuResult.x, tuResult.y, tuResult.absolute_heading]
        }
        
        let indoorResult = makeCurrentResult(input: tuResult, mustInSameLink: mustInSameLink, pathMatchingType: .NARROW, phase: .TRACKING, jumpInfo: jumpInfo, mode: mode)
        self.curResult = indoorResult
    }
    
    private func updateResultFromTimeUpdate(mode: UserMode, uvd: UserVelocity, pastUvd: UserVelocity,
                                            pathMatchingCondition: PathMatchingCondition) -> (FineLocationTrackingOutput?, Bool) {
        guard let kalmanFilter = self.kalmanFilter else { return (nil, false) }
        if mode == .MODE_PEDESTRIAN {
//            result = kalmanFilter.pdrTimeUpdate(region: region, sectorId: sectorId, uvd: uvd, pastUvd: pastUvd, pathMatchingCondition: pathMatchingCondition)
            return (nil, false)
        } else {
            guard let drTuResult = kalmanFilter.drTimeUpdate(region: region, sectorId: sectorId, uvd: uvd, pastUvd: pastUvd) else { return (nil, false) }
            return (drTuResult, false)
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
        let paddings = (!isPdrMode && levelName == "B0") ? JupiterMode.PADDING_VALUES_DR : self.paddingValues
        if mode == .MODE_PEDESTRIAN {
            // PDR
            if pathMatchingType == .NARROW {
                isUseHeading = true
                headingRange -= 10
            }
            
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
            PathMatcher.shared.updateNodeAndLinkInfo(sectorId: sectorId, uvdIndex: curIndex, curResult: result, mode: mode, jumpInfo: jumpInfo, isInLevelChangeArea: isInLevelChangeArea)
        }
        
        return result
    }
    
    private func checkResultJumpV2(jumpedResult: FineLocationTrackingOutput, jumpedLinkId: Int) -> [[Float]]  {
        var intermediatePoints: [[Float]] = []
        
        let building = jumpedResult.building_name
        let level = jumpedResult.level_name
        let key = "\(sectorId)_\(building)_\(level)"
        
        let userX = round(jumpedResult.x)
        let userY = round(jumpedResult.y)
        
        guard let linkData = PathMatcher.shared.linkData[key] else { return intermediatePoints }
        guard let jumpedLinkInfo = linkData[jumpedLinkId] else { return intermediatePoints }
        
        let userDir = jumpedResult.absolute_heading
        let oppDir = PathMatcher.shared.oppositeOf(userDir)
        let oppLinkDir = PathMatcher.shared.closestHeading(to: oppDir, candidates: jumpedLinkInfo.included_heading).0
        
        let deltaDir = abs(oppDir - oppLinkDir).truncatingRemainder(dividingBy: 360)
        let angleDiff = deltaDir > 180 ? 360 - deltaDir : deltaDir
        let isDirectionAligned = angleDiff <= 10.0
        
        let headingRad = oppLinkDir * .pi / 180.0
        let dirVector = SIMD2(x: cos(headingRad), y: sin(headingRad))
        
        let unitVector = simd_normalize(dirVector)
        let stepCount = 100
        for i in 1..<stepCount {
            let step = Float(i)
            let x = userX + step * unitVector.x
            let y = userY + step * unitVector.y
            intermediatePoints.append([x, y])
        }
        return intermediatePoints
    }
    
    private func calcJumpedNodes(from: FineLocationTrackingOutput?,
                                 to: FineLocationTrackingOutput,
                                 curLinkInfo: PassedLinkInfo,
                                 jumpedLinkId: Int,
                                 mode: UserMode) -> JumpInfo? {
        var jumpInfo: JumpInfo?
        
        let building = to.building_name
        let level = to.level_name
        let key = "\(sectorId)_\(building)_\(level)"
        
        guard let linkData = PathMatcher.shared.linkData[key] else { return nil }
        guard let jumpedLinkInfo = linkData[jumpedLinkId] else { return nil }
        guard let from = from else { return nil }
        
        if jumpedLinkInfo.group_id == curLinkInfo.group_id {
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
                let pathType = mode == .MODE_PEDESTRIAN ? 0 : 1
                if let matchedNodeResult = PathMatcher.shared.getMatchedNodeWithCoord(sectorId: sectorId, fltResult: to, originCoord: point, coordToCheck: point, pathType: pathType, paddingValues: [1, 1, 1, 1]) {
                    let nodeInfo = PassedNodeInfo(id: matchedNodeResult.0, coord: point, headings: matchedNodeResult.1, matched_index: to.index, user_heading: to.absolute_heading)
                    jumpedNodes.append(nodeInfo)
                }
            }
            jumpInfo = JumpInfo(link_id: jumpedLinkId, jumped_nodes: jumpedNodes)
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
                let pathType = mode == .MODE_PEDESTRIAN ? 0 : 1
                if let matchedNodeResult = PathMatcher.shared.getMatchedNodeWithCoord(sectorId: sectorId, fltResult: to, originCoord: point, coordToCheck: point, pathType: pathType, paddingValues: [1, 1, 1, 1]) {
                    let nodeId = matchedNodeResult.0
                    let nodeInfo = PassedNodeInfo(id: nodeId, coord: point, headings: matchedNodeResult.1, matched_index: to.index, user_heading: to.absolute_heading)
                    jumpedNodes.append(nodeInfo)
                    if nodeId == jumpedLinkInfo.start_node || nodeId == jumpedLinkInfo.end_node {
                        jumpInfo = JumpInfo(link_id: jumpedLinkId, jumped_nodes: jumpedNodes)
                        return jumpInfo
                    }
                }
            }
        }

        return jumpInfo
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
    
    func onVelocityResult(_ generator: UVDGenerator, kmPh: Double) {
        curVelocity = Float(kmPh)
    }
    func onMagNormSmoothingVarResult(_ generator: TJLabsCommon.UVDGenerator, value: Double) {
        //
    }
    
    // MARK: - TJLabsResourceManagerDelegate Methods
    func onSectorData(_ manager: TJLabsResource.TJLabsResourceManager, data: TJLabsResource.SectorOutput) {
        // TO-DO
    }
    
    func onSectorError(_ manager: TJLabsResource.TJLabsResourceManager, error: TJLabsResource.ResourceError) {
        // TO-DO
    }
    
    func onBuildingsData(_ manager: TJLabsResource.TJLabsResourceManager, data: [TJLabsResource.BuildingOutput]) {
        guard let blChanger = self.buildingLevelChanger else { return }
        blChanger.setBuildingsData(buildingsData: data)
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
        }
    }
    
    func onLandmarkData(_ manager: TJLabsResource.TJLabsResourceManager, key: String, data: [String : TJLabsResource.LandmarkData]) {
        landmarkTagger?.setLandmarkData(key: key, data: data)
    }
    
    func onUnitData(_ manager: TJLabsResource.TJLabsResourceManager, key: String, data: [TJLabsResource.UnitData]) {
        // TO-DO
    }
    
    func onGeofenceData(_ manager: TJLabsResource.TJLabsResourceManager, key: String, data: TJLabsResource.GeofenceData) {
        let levelChangeArea = data.level_change_area
        let drModeArea = data.dr_mode_area
        
        if let blChnager = self.buildingLevelChanger {
            blChnager.setLevelChangeArea(key: key, data: levelChangeArea)
        }
        PathMatcher.shared.setEntranceMatchingArea(key: key, data: data.entrance_matching_area)
        PathMatcher.shared.setEntranceArea(key: key, data: data.entrance_area)
    }
    
    func onEntranceData(_ manager: TJLabsResource.TJLabsResourceManager, key: String, data: TJLabsResource.EntranceData) {
        entManager?.setEntData(key: key, data: data)
        landmarkTagger?.setExceptionalTagInfo(id: data.innerWardId)
    }
    
    func onEntranceRouteData(_ manager: TJLabsResource.TJLabsResourceManager, key: String, data: TJLabsResource.EntranceRouteData) {
        entManager?.setEntRouteData(key: key, data: data)
    }
    
    func onImageData(_ manager: TJLabsResource.TJLabsResourceManager, key: String, data: UIImage?) {
        // NONE
    }
    
    func onSectorParam(_ manager: TJLabsResource.TJLabsResourceManager, data: TJLabsResource.SectorParameterOutput) {

    }
    
    func onLevelParam(_ manager: TJLabsResource.TJLabsResourceManager, key: String, data: TJLabsResource.LevelParameterOutput) {

    }
    
    func onLevelWardsData(_ manager: TJLabsResource.TJLabsResourceManager, key: String, data: [TJLabsResource.LevelWard]) {
        guard let blChanger = self.buildingLevelChanger else { return }
        blChanger.setLevelWards(levelKey: key, levelWardsData: data)
    }
    
    func onAffineParam(_ manager: TJLabsResource.TJLabsResourceManager, data: TJLabsResource.AffineTransParamOutput) {
        AffineConverter.shared.setAffineParam(sectorId: sectorId, data: data)
    }
    
    func onSpotsData(_ manager: TJLabsResource.TJLabsResourceManager, key: Int, type: TJLabsResource.SpotType, data: Any) {
        if type == .BUILDING_LEVEL_TAG {
            let blChangerTagData = data as! [TJLabsResource.BuildingLevelTag]
            guard let blChanger = self.buildingLevelChanger else { return }
            blChanger.setBuildingLevelTagData(key: key, blChangerTagData: blChangerTagData)
        }
    }
    func onError(_ manager: TJLabsResource.TJLabsResourceManager, error: TJLabsResource.ResourceError, key: String) {
        // TO-DO
    }
}
