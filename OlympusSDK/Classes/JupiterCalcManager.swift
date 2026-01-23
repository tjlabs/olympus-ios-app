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
    private var correctionId: String = ""
    private var correctionIndex: Int = 0
    private var uvdIndexWhenCorrection: Int = 0
    var paddingValues = JupiterMode.PADDING_VALUES_DR
    
    // MARK: - Recovery
    private var recoveryIndex: Int = 0
    private var recentUserPeakIndex: Int = 0
    private var recentLandmarkPeaks: [PeakData]?
    
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
    var debug_ratio: Float?
    
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
        tjlabsResourceManager.loadJupiterResource(region: region, sectorId: sectorId, landmarkTh: -85, completion: { isSuccess in
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
            recovery_result_v2: self.debug_recovery_result_v2,
            ratio: self.debug_ratio
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
        
        let windowSize = jupiterPhase == .NONE ? 10 : 50
        if let userPeak = peakDetector.updateEpoch(uvdIndex: curIndex, bleAvg: avgBleData, windowSize: windowSize) {
            self.debug_recovery_result = nil
            self.debug_ratio = nil
            peakHandling: do {
                JupiterLogger.i(tag: "JupiterCalcManager", message: "(onUvdResult) PEAK detected : id=\(userPeak.id) // peak_idx=\(userPeak.peak_index), peak_rssi=\(userPeak.peak_rssi), detected_idx = \(userPeak.end_index), detected_rssi = \(userPeak.end_rssi)")
                startEntranceTracking(currentTime: currentTime, entManager: entManager, uvd: userVelocity, userPeak: userPeak, bleData: bleData)
                
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
                if userPeak.peak_index - correctionIndex < 1 {
                    JupiterLogger.i(tag: "JupiterCalcManager", message: "(onUvdResult) PEAK is too close with previous landmark correction at \(userVelocity.index) uvd index")
                    break peakHandling
                } else if userPeak.id == correctionId {
                    JupiterLogger.i(tag: "JupiterCalcManager", message: "(onUvdResult) same PEAK detected just before id:\(userPeak.id)")
                    break peakHandling
                } else if userPeak.peak_index <= recoveryIndex {
                    JupiterLogger.i(tag: "JupiterCalcManager", message: "(onUvdResult) Recovery worked at \(recoveryIndex) uvd index")
                    break peakHandling
                }
                
                // MARK: - With 3 Peaks
//                let curResultBuffer = stackManager.getCurResultBuffer()
//                if let matchedWithUserPeak = landmarkTagger.findMatchedLandmarkWithUserPeak(userPeak: userPeak, curResult: self.curResult, curResultBuffer: curResultBuffer) {
//                    self.debug_landmark = matchedWithUserPeak.landmark
//                    if let linkInfoWhenPeak = PathMatcher.shared.getLinkInfoWithResult(sectorId: sectorId, result: matchedWithUserPeak.matchedResult) {
//                        stackManager.stackUserPeakAndLink(userPeakAndLink: (userPeak, linkInfoWhenPeak))
//                    }
//                }
//                
//                if jupiterPhase != .ENTERING {
//                    guard let curResult = self.curResult, let curPmResult = self.curPathMatchingResult else { break peakHandling }
//                    JupiterResultState.isInRecoveryProcess = true
//                    let userPeakAndLinkBuffer = stackManager.getUserPeakAndLinkBuffer()
//                    if userPeakAndLinkBuffer.count < 3 { return }
//                    let thirdUserPeak = userPeakAndLinkBuffer[userPeakAndLinkBuffer.count-3].0
//                    let secondUserPeak = userPeakAndLinkBuffer[userPeakAndLinkBuffer.count-2].0
//                    let firstUserPeak = userPeakAndLinkBuffer[userPeakAndLinkBuffer.count-1].0
//                    
//                    let uvdBufferForRecovery = recoveryManager.getUvdBufferForRecovery(startIndex: thirdUserPeak.peak_index, endIndex: userVelocity.index, uvdBuffer: uvdBuffer)
//                    let headingSearchRange = recoveryManager.getRecoveryRange(olderPeakIndex: thirdUserPeak.peak_index, curIndex: curIndex)
//                    let pathHeadings = PathMatcher.shared.getPathMatchingHeadings(sectorId: sectorId,
//                                                                                  building: curPmResult.building_name,
//                                                                                  level: curPmResult.level_name,
//                                                                                  x: curPmResult.x, y: curPmResult.y,
//                                                                                  paddingValue: headingSearchRange, mode: mode)
//                    if let tuResultWhenThirdPeak = kalmanFilter?.getTuResultWithUvdIndex(index: thirdUserPeak.peak_index) {
//                        let curResultBuffer = stackManager.getCurResultBuffer()
//                        if let matchedWithThirdPeak = landmarkTagger.findMatchedLandmarkWithUserPeak(userPeak: thirdUserPeak, curResult: curResult, curResultBuffer: curResultBuffer),
//                           let matchedWithSecondPeak = landmarkTagger.findMatchedLandmarkWithUserPeak(userPeak: secondUserPeak, curResult: curResult, curResultBuffer: curResultBuffer),
//                           let matchedWithFirstPeak = landmarkTagger.findMatchedLandmarkWithUserPeak(userPeak: firstUserPeak, curResult: curResult, curResultBuffer: curResultBuffer) {
//                            let hasMajorDirection = stackManager.checkHasMajorDirection(uvdBuffer: uvdBufferForRecovery)
//                            JupiterLogger.i(tag: "JupiterCalcManager", message: "(onUvdResult) BadCase: hasMajorDirection = \(hasMajorDirection)")
//                            if hasMajorDirection {
//                                let majorSection = stackManager.extractSectionWithLeastChange(inputArray: uvdBufferForRecovery.map{ Float($0.heading) })
//                                JupiterLogger.i(tag: "JupiterCalcManager", message: "(onUvdResult) BadCase: majorSection= \(majorSection)")
//                                let recoveryTrajList = recoveryManager.makeMultipleRecoveryTrajectory(uvdBuffer: uvdBufferForRecovery, majorSection: majorSection, pathHeadings: pathHeadings, endHeading: curResult.absolute_heading)
//                                if let recoveryResult = recoveryManager.recoverWithMultipleTraj_v2(recoveryTrajList: recoveryTrajList,
//                                                                                                userPeakAndLinkBuffer: userPeakAndLinkBuffer,
//                                                                                                landmarks: (matchedWithThirdPeak.0, matchedWithSecondPeak.0, matchedWithFirstPeak.0),
//                                                                                                tuResultWhenThirdPeak: tuResultWhenThirdPeak,
//                                                                                                resultWhenFisrtPeak: matchedWithFirstPeak.1,
//                                                                                                curPmResult: curPmResult, mode: mode),
//                                let bestResult = recoveryResult.bestResult {
//                                    self.debug_recovery_result_v2 = recoveryResult
//                                    let recoveryCoord: [Float] = [bestResult.x, bestResult.y]
//                                    kalmanFilter?.updateTuPosition(coord: recoveryCoord)
//                                    self.curResult? = bestResult
//                                    
//                                    if let matchedLink = PathMatcher.shared.getLinkInfoWithResult(sectorId: sectorId, result: bestResult, checkAll: true) {
//                                        let jumpInfo = JumpInfo(link_id: matchedLink.id, jumped_nodes: [])
//                                        PathMatcher.shared.updateNodeAndLinkInfo(sectorId: sectorId, uvdIndex: curIndex, curResult: bestResult, mode: mode, jumpInfo: jumpInfo)
//                                    } else {
//                                        PathMatcher.shared.initPassedLinkInfo()
//                                    }
//                                    correctionId = userPeak.id
//                                    correctionIndex = userPeak.peak_index
//                                }
//                            }
//                        }
//                    }
//                }
                
                // MARK: - With 3 Peaks v2
//                let curResultBuffer = stackManager.getCurResultBuffer()
//                if let matchedWithUserPeak = landmarkTagger.findMatchedLandmarkWithUserPeak(userPeak: userPeak, curResult: self.curResult, curResultBuffer: curResultBuffer) {
//                    self.debug_landmark = matchedWithUserPeak.landmark
//                    if let linkInfoWhenPeak = PathMatcher.shared.getLinkInfoWithResult(sectorId: sectorId, result: matchedWithUserPeak.matchedResult, checkAll: true) {
//                        stackManager.stackUserPeakAndLink(userPeakAndLink: (userPeak, linkInfoWhenPeak))
//                    }
//                }
//
//                if jupiterPhase != .ENTERING {
//                    guard let curResult = self.curResult, let curPmResult = self.curPathMatchingResult else { break peakHandling }
//                    JupiterResultState.isInRecoveryProcess = true
//                    let userPeakAndLinkBuffer = stackManager.getUserPeakAndLinkBuffer()
//                    if userPeakAndLinkBuffer.count < 3 { return }
//                    olderPeakIndex = stackManager.getOlderPeakIndex()
//                    let thirdUserPeak = userPeakAndLinkBuffer[userPeakAndLinkBuffer.count-3].0
//                    let secondUserPeak = userPeakAndLinkBuffer[userPeakAndLinkBuffer.count-2].0
//                    let firstUserPeak = userPeakAndLinkBuffer[userPeakAndLinkBuffer.count-1].0
//
//                    let uvdBufferForRecovery = recoveryManager.getUvdBufferForRecovery(startIndex: thirdUserPeak.peak_index, endIndex: userVelocity.index, uvdBuffer: uvdBuffer)
//                    let pmResultBuffer = stackManager.getCurPmResultBuffer(from: thirdUserPeak.peak_index)
//                    let pathHeadings = stackManager.makeHeadingSet(resultBuffer: pmResultBuffer)
//                    
//                    if let tuResultWhenThirdPeak = kalmanFilter?.getTuResultWithUvdIndex(index: thirdUserPeak.peak_index) {
//                        let curResultBuffer = stackManager.getCurResultBuffer()
//                        if let matchedWithThirdPeak = landmarkTagger.findMatchedLandmarkWithUserPeak(userPeak: thirdUserPeak, curResult: curResult, curResultBuffer: curResultBuffer),
//                           let matchedWithSecondPeak = landmarkTagger.findMatchedLandmarkWithUserPeak(userPeak: secondUserPeak, curResult: curResult, curResultBuffer: curResultBuffer),
//                           let matchedWithFirstPeak = landmarkTagger.findMatchedLandmarkWithUserPeak(userPeak: firstUserPeak, curResult: curResult, curResultBuffer: curResultBuffer) {
//                            let hasMajorDirection = stackManager.checkHasMajorDirection(uvdBuffer: uvdBufferForRecovery)
//                            if hasMajorDirection {
//                                let majorSection = stackManager.extractSectionWithLeastChange(inputArray: uvdBufferForRecovery.map{ Float($0.heading) })
//                                let recoveryTrajList = recoveryManager.makeMultipleRecoveryTrajectory(uvdBuffer: uvdBufferForRecovery, majorSection: majorSection, pathHeadings: pathHeadings, endHeading: curResult.absolute_heading)
//                                if let recoveryResult = recoveryManager.recoverWithMultipleTraj_v2(recoveryTrajList: recoveryTrajList,
//                                                                                                userPeakAndLinkBuffer: userPeakAndLinkBuffer,
//                                                                                                landmarks: (matchedWithThirdPeak.0, matchedWithSecondPeak.0, matchedWithFirstPeak.0),
//                                                                                                tuResultWhenThirdPeak: tuResultWhenThirdPeak,
//                                                                                                resultWhenFisrtPeak: matchedWithFirstPeak.1,
//                                                                                                   curPmResult: curPmResult, mode: mode, inSameLink: true),
//                                
//                                let bestResult = recoveryResult.bestResult {
//                                    self.debug_recovery_result_v2 = recoveryResult
//                                    let recoveryCoord: [Float] = [bestResult.x, bestResult.y]
//                                    self.correctionIndex = userPeak.peak_index
//                                    stackManager.editCurResultBuffer(sectorId: sectorId, mode: mode, from: secondUserPeak.peak_index, shifteTraj: recoveryResult.shiftedTraj)
//                                    stackManager.editCurPmResultBuffer(sectorId: sectorId, mode: mode, from: secondUserPeak.peak_index, shifteTraj: recoveryResult.shiftedTraj)
//                                    kalmanFilter?.editTuResultBuffer(sectorId: sectorId, mode: mode, from: secondUserPeak.peak_index, shifteTraj: recoveryResult.shiftedTraj, curResult: curResult)
//                                    
//                                    // curResultBuffer, tuResultBuffer에서 recentPeak이 발생한 index부터 현재 index까지 수정하기
//                                    if let pmResult = PathMatcher.shared.pathMatching(sectorId: sectorId, building: curResult.building_name, level: curResult.level_name, x: bestResult.x, y: bestResult.y, heading: bestResult.absolute_heading, isUseHeading: true, mode: mode, paddingValues: JupiterMode.PADDING_VALUES_DR) {
//                                        curPathMatchingResult = bestResult
//                                        curPathMatchingResult?.x = pmResult.x
//                                        curPathMatchingResult?.y = pmResult.y
//                                        curPathMatchingResult?.absolute_heading = pmResult.heading
//                                        JupiterLogger.i(tag: "JupiterCalcManager", message: "(onUvdResult) 3 Peaks : best= \(bestResult.x),\(bestResult.y),\(bestResult.absolute_heading)")
//                                        kalmanFilter?.updateTuPosition(coord: [pmResult.x, pmResult.y])
//                                        self.curResult? = curPathMatchingResult!
//                                    } else {
//                                        kalmanFilter?.updateTuPosition(coord: recoveryCoord)
//                                        self.curResult? = bestResult
//                                    }
//
//                                    if let matchedLink = PathMatcher.shared.getLinkInfoWithResult(sectorId: sectorId, result: bestResult, checkAll: true) {
//                                        let jumpInfo = JumpInfo(link_id: matchedLink.id, jumped_nodes: [])
//                                        PathMatcher.shared.updateNodeAndLinkInfo(sectorId: sectorId, uvdIndex: curIndex, curResult: bestResult, mode: mode, jumpInfo: jumpInfo)
//                                    } else {
//                                        PathMatcher.shared.initPassedLinkInfo()
//                                    }
//                                }
//                            }
//                        } else {
//                            JupiterLogger.i(tag: "JupiterCalcManager", message: "(onUvdResult) 3 Peaks : matchedWithPeak fail")
//                        }
//                    } else {
//                        JupiterLogger.i(tag: "JupiterCalcManager", message: "(onUvdResult) 3 Peaks : tuResultWhenThirdPeak fail")
//                    }
//                }
                
                // MARK: - Use only one
//                let curResultBuffer = stackManager.getCurResultBuffer()
//                if let matchedWithUserPeak = landmarkTagger.findMatchedLandmarkWithUserPeak(userPeak: userPeak, curResult: self.curResult, curResultBuffer: curResultBuffer) {
//                    self.debug_landmark = matchedWithUserPeak.landmark
//                    let uvdBufferForStraight = stackManager.getUvdBuffer(from: userPeak.peak_index)
//                    if let linkInfoWhenPeak = PathMatcher.shared.getLinkInfoWithResult(sectorId: sectorId, result: matchedWithUserPeak.matchedResult) {
//                        stackManager.stackUserPeakAndLink(userPeakAndLink: (userPeak, linkInfoWhenPeak))
//                        // Stack 까지는 해야한다
//                        let isDrStraight = stackManager.isDrBufferStraightCircularStd(uvdBuffer: uvdBufferForStraight, condition: 5)
//                        if !isDrStraight.0 { break peakHandling }
//                        
//                        olderPeakIndex = stackManager.getOlderPeakIndex()
//                        if let bestResult = landmarkTagger.findBestLandmark(userPeak: userPeak, landmark: matchedWithUserPeak.landmark, matchedResult: matchedWithUserPeak.matchedResult, peakLinkId: linkInfoWhenPeak.id, peakLinkGroupId: linkInfoWhenPeak.group_id) {
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
                
                // MARK: - Use Two peaks In Straight
//                let curResultBuffer = stackManager.getCurResultBuffer()
//                if let matchedWithUserPeak = landmarkTagger.findMatchedLandmarkWithUserPeak(userPeak: userPeak, curResult: self.curResult, curResultBuffer: curResultBuffer) {
//                    self.debug_landmark = matchedWithUserPeak.landmark
//                    let uvdBufferForStraight = stackManager.getUvdBuffer(from: userPeak.peak_index)
//                    if let linkInfoWhenPeak = PathMatcher.shared.getLinkInfoWithResult(sectorId: sectorId, result: matchedWithUserPeak.matchedResult, checkAll: true) {
//                        stackManager.stackUserPeakAndLink(userPeakAndLink: (userPeak, linkInfoWhenPeak))
//                        // Stack 까지는 해야한다
//                        let isDrStraight = stackManager.isDrBufferStraightCircularStd(uvdBuffer: uvdBufferForStraight, condition: 5)
//                        if !isDrStraight.0 { break peakHandling }
//                        let userPeakAndLinkBuffer = stackManager.getUserPeakAndLinkBuffer()
//                        if userPeakAndLinkBuffer.count < 2 {
//                            olderPeakIndex = stackManager.getOlderPeakIndex()
//                            if let bestResult = landmarkTagger.findBestLandmark(userPeak: userPeak, landmark: matchedWithUserPeak.landmark, matchedResult: matchedWithUserPeak.matchedResult, peakLinkId: linkInfoWhenPeak.id, peakLinkGroupId: linkInfoWhenPeak.group_id) {
//                                let bestPeak = bestResult.0
//                                self.debug_best_landmark = bestPeak
//                                if let matchedTuResult = kalmanFilter?.getTuResultWithUvdIndex(index: userPeak.peak_index) {
//                                    if let reconstructResult = landmarkTagger.reconstructTrajectory(peakIndex: userPeak.peak_index, bestLandmark: bestPeak, matchedResult: matchedWithUserPeak.matchedResult, startHeading: Double(matchedTuResult.heading), uvdBuffer: uvdBuffer, curResultBuffer: curResultBuffer, mode: mode) {
//                                        self.debug_recon_raw_traj = reconstructResult.0
//                                        self.debug_recon_corr_traj = reconstructResult.1
//                                        let resultForCorrection = reconstructResult.1[reconstructResult.1.count-1]
//                                        if let muResult = kalmanFilter?.measurementUpdate(sectorId: sectorId, resultForCorrection: resultForCorrection, mode: mode) {
//                                            self.correctionIndex = userPeak.peak_index
//                                            self.curResult = muResult
//                                            reconCurResultBuffer = reconstructResult.1
//                                            
//                                            // Landmark를 이용한 Correction 이후에 위치 Jump 판단 -> PassedNode와 Link 정보 업데이트
//                                            if let curLinkInfo = PathMatcher.shared.getCurPassedLinkInfo() {
//                                                jumpInfo = calcJumpedNodes(from: curPathMatchingResult, to: muResult, curLinkInfo: curLinkInfo, jumpedLinkId: bestResult.1, mode: mode)
//                                            }
//                                        }
//                                    } else {
//                                        self.debug_recon_raw_traj = nil
//                                        self.debug_recon_corr_traj = nil
//                                        break peakHandling
//                                    }
//                                } else {
//                                    break peakHandling
//                                }
//                            } else {
//                                self.debug_best_landmark = nil
//                                break peakHandling
//                            }
//                        } else {
//                            guard let curResult = self.curResult, let curPmResult = self.curPathMatchingResult else { break peakHandling }
//                            let olderUserPeak = userPeakAndLinkBuffer[userPeakAndLinkBuffer.count-2].0
//                            let recentUserPeak = userPeakAndLinkBuffer[userPeakAndLinkBuffer.count-1].0
//                            let uvdBufferForLandmark = recoveryManager.getUvdBufferForRecovery(startIndex: olderUserPeak.peak_index, endIndex: userVelocity.index, uvdBuffer: uvdBuffer)
//                            
//                            if let tuResultWhenOlderPeak = kalmanFilter?.getTuResultWithUvdIndex(index: olderUserPeak.peak_index) {
//                                JupiterLogger.i(tag: "JupiterCalcManager", message: "(onUvdResult) 2 Peaks : tuResultWhenOlderPeak=[\(tuResultWhenOlderPeak.x),\(tuResultWhenOlderPeak.y),\(tuResultWhenOlderPeak.heading)]")
//                                let curResultBuffer = stackManager.getCurResultBuffer()
//                                if let matchedWithOlderPeak = landmarkTagger.findMatchedLandmarkWithUserPeak(userPeak: olderUserPeak, curResult: curResult, curResultBuffer: curResultBuffer),
//                                   let matchedWithRecentPeak = landmarkTagger.findMatchedLandmarkWithUserPeak(userPeak: recentUserPeak, curResult: curResult, curResultBuffer: curResultBuffer) {
//                                    let majorSection = stackManager.extractSectionWithLeastChange(inputArray: uvdBufferForStraight.map{ Float($0.heading) })
//                                    
//                                    let alignDir = PathMatcher.shared.closestHeading(to: matchedWithRecentPeak.matchedResult.absolute_heading, candidates: linkInfoWhenPeak.included_heading)
//                                    let landmarkTraj = recoveryManager.makeLandmarkTrajectory(uvdBuffer: uvdBufferForLandmark, majorSection: majorSection, alignDir: alignDir.0)
//                                    JupiterLogger.i(tag: "JupiterCalcManager", message: "(onUvdResult) 2 Peaks : alignDir=\(alignDir), landmarkTraj= \(landmarkTraj)")
//                                    if let recoveryResult = recoveryManager.recoverWithLandmarkTraj(landmarkTraj: landmarkTraj,
//                                                                                                    userPeakAndLinkBuffer: userPeakAndLinkBuffer,
//                                                                                                    landmarks: (matchedWithOlderPeak.0, matchedWithRecentPeak.0),
//                                                                                                    tuResultWhenOlderPeak: tuResultWhenOlderPeak,
//                                                                                                    curPmResult: curPmResult, mode: mode),
//                                    let bestResult = recoveryResult.bestResult {
//                                        self.debug_recovery_result = recoveryResult
//                                        let recoveryCoord: [Float] = [bestResult.x, bestResult.y]
//                                        self.correctionIndex = userPeak.peak_index
//                                        if let pmResult = PathMatcher.shared.pathMatching(sectorId: sectorId, building: curResult.building_name, level: curResult.level_name, x: bestResult.x, y: bestResult.y, heading: bestResult.absolute_heading, isUseHeading: true, mode: mode, paddingValues: JupiterMode.PADDING_VALUES_DR) {
//                                            curPathMatchingResult = bestResult
//                                            curPathMatchingResult?.x = pmResult.x
//                                            curPathMatchingResult?.y = pmResult.y
//                                            curPathMatchingResult?.absolute_heading = pmResult.heading
//                                            JupiterLogger.i(tag: "JupiterCalcManager", message: "(onUvdResult) 2 Peaks : best= \(bestResult.x),\(bestResult.y),\(bestResult.absolute_heading)")
//                                            kalmanFilter?.updateTuPosition(coord: [pmResult.x, pmResult.y])
//                                            self.curResult? = curPathMatchingResult!
//                                        } else {
//                                            kalmanFilter?.updateTuPosition(coord: recoveryCoord)
//                                            self.curResult? = bestResult
//                                        }
//
//                                        if let matchedLink = PathMatcher.shared.getLinkInfoWithResult(sectorId: sectorId, result: bestResult, checkAll: true) {
//                                            let jumpInfo = JumpInfo(link_id: matchedLink.id, jumped_nodes: [])
//                                            PathMatcher.shared.updateNodeAndLinkInfo(sectorId: sectorId, uvdIndex: curIndex, curResult: bestResult, mode: mode, jumpInfo: jumpInfo)
//                                        } else {
//                                            PathMatcher.shared.initPassedLinkInfo()
//                                        }
//                                    } else {
//                                        // One peak
//                                        olderPeakIndex = stackManager.getOlderPeakIndex()
//                                        if let bestResult = landmarkTagger.findBestLandmark(userPeak: userPeak, landmark: matchedWithUserPeak.landmark, matchedResult: matchedWithUserPeak.matchedResult, peakLinkId: linkInfoWhenPeak.id, peakLinkGroupId: linkInfoWhenPeak.group_id) {
//                                            let bestPeak = bestResult.0
//                                            self.debug_best_landmark = bestPeak
//                                            if let matchedTuResult = kalmanFilter?.getTuResultWithUvdIndex(index: userPeak.peak_index) {
//                                                if let reconstructResult = landmarkTagger.reconstructTrajectory(peakIndex: userPeak.peak_index, bestLandmark: bestPeak, matchedResult: matchedWithUserPeak.matchedResult, startHeading: Double(matchedTuResult.heading), uvdBuffer: uvdBuffer, curResultBuffer: curResultBuffer, mode: mode) {
//                                                    self.debug_recon_raw_traj = reconstructResult.0
//                                                    self.debug_recon_corr_traj = reconstructResult.1
//                                                    let resultForCorrection = reconstructResult.1[reconstructResult.1.count-1]
//                                                    if let muResult = kalmanFilter?.measurementUpdate(sectorId: sectorId, resultForCorrection: resultForCorrection, mode: mode) {
//                                                        self.correctionIndex = userPeak.peak_index
//                                                        self.curResult = muResult
//                                                        reconCurResultBuffer = reconstructResult.1
//                                                        
//                                                        // Landmark를 이용한 Correction 이후에 위치 Jump 판단 -> PassedNode와 Link 정보 업데이트
//                                                        if let curLinkInfo = PathMatcher.shared.getCurPassedLinkInfo() {
//                                                            jumpInfo = calcJumpedNodes(from: curPathMatchingResult, to: muResult, curLinkInfo: curLinkInfo, jumpedLinkId: bestResult.1, mode: mode)
//                                                        }
//                                                    }
//                                                } else {
//                                                    self.debug_recon_raw_traj = nil
//                                                    self.debug_recon_corr_traj = nil
//                                                    break peakHandling
//                                                }
//                                            } else {
//                                                break peakHandling
//                                            }
//                                        } else {
//                                            self.debug_best_landmark = nil
//                                            break peakHandling
//                                        }
//                                    }
//                                }
//                            }
//                        }
//                    } else {
//                        JupiterLogger.i(tag: "JupiterCalcManager", message: "(onUvdResult) 2 Peaks : linkInfoWhenPeak failed // \(matchedWithUserPeak.matchedResult)")
//                        break peakHandling
//                    }
//                }
                
                // MARK: - Use Two peaks anytime
                let curResultBuffer = stackManager.getCurResultBuffer()
                if let matchedWithUserPeak = landmarkTagger.findMatchedLandmarkWithUserPeak(userPeak: userPeak, curResult: self.curResult, curResultBuffer: curResultBuffer) {
                    self.debug_landmark = matchedWithUserPeak.landmark
                    if let linkInfoWhenPeak = PathMatcher.shared.getLinkInfoWithResult(sectorId: sectorId, result: matchedWithUserPeak.matchedResult, checkAll: true) {
                        stackManager.stackUserPeakAndLink(userPeakAndLink: (userPeak, linkInfoWhenPeak))
                    }
                }
                
                if jupiterPhase != .ENTERING {
                    let userPeakAndLinkBuffer = stackManager.getUserPeakAndLinkBuffer()
                    if userPeakAndLinkBuffer.count < 2 { return }
                    guard let curResult = self.curResult, let curPmResult = self.curPathMatchingResult, let tuResult = kalmanFilter?.getTuResult() else { break peakHandling }
                    let olderUserPeak = userPeakAndLinkBuffer[userPeakAndLinkBuffer.count-2].0
                    let recentUserPeak = userPeakAndLinkBuffer[userPeakAndLinkBuffer.count-1].0
                    JupiterLogger.i(tag: "JupiterCalcManager", message: "(onUvdResult) 2 Peaks : older= \(olderUserPeak.id), recent= \(recentUserPeak.id)")
                    let uvdBufferForRecovery = recoveryManager.getUvdBufferForRecovery(startIndex: olderUserPeak.peak_index, endIndex: userVelocity.index, uvdBuffer: uvdBuffer)
                      let pmResultBuffer = stackManager.getCurPmResultBuffer(from: olderUserPeak.peak_index)
                    let pathHeadings = stackManager.makeHeadingSet(resultBuffer: pmResultBuffer)
                    
                    let uvdBufferForStraight = stackManager.getUvdBuffer(from: userPeak.peak_index)
                    let isDrStraight = stackManager.isDrBufferStraightCircularStd(uvdBuffer: uvdBufferForStraight, condition: 5)
                    
                    if let tuResultWhenOlderPeak = kalmanFilter?.getTuResultWithUvdIndex(index: olderUserPeak.peak_index),
                       let tuResultWhenRecentPeak = kalmanFilter?.getTuResultWithUvdIndex(index: recentUserPeak.peak_index) {
                        let curResultBuffer = stackManager.getCurResultBuffer()
                        if let matchedWithOlderPeak = landmarkTagger.findMatchedLandmarkWithUserPeak(userPeak: olderUserPeak, curResult: curResult, curResultBuffer: curResultBuffer),
                           let matchedWithRecentPeak = landmarkTagger.findMatchedLandmarkWithUserPeak(userPeak: recentUserPeak, curResult: curResult, curResultBuffer: curResultBuffer) {
                            let hasMajorDirection = stackManager.checkHasMajorDirection(uvdBuffer: uvdBufferForRecovery)
                            JupiterLogger.i(tag: "JupiterCalcManager", message: "(onUvdResult) 2 Peaks : hasMajorDirection= \(hasMajorDirection)")
                            if hasMajorDirection {
                                let majorSection = stackManager.extractSectionWithLeastChange(inputArray: uvdBufferForRecovery.map{ Float($0.heading) })
                                JupiterLogger.i(tag: "JupiterCalcManager", message: "(onUvdResult) 2 Peaks : majorSection= \(majorSection)")
                                let recoveryTrajList = recoveryManager.makeMultipleRecoveryTrajectory(uvdBuffer: uvdBufferForRecovery, majorSection: majorSection, pathHeadings: pathHeadings, endHeading: tuResult.absolute_heading)
                                let recoveryResultList = recoveryManager.recoverWithMultipleTrajWide(recoveryTrajList: recoveryTrajList,
                                                                                                     userPeakAndLinkBuffer: userPeakAndLinkBuffer,
                                                                                                     landmarks: (matchedWithOlderPeak.0, matchedWithRecentPeak.0),
                                                                                                     tuResultWhenOlderPeak: tuResultWhenOlderPeak,
                                                                                                     tuResultWhenRecentPeak: tuResultWhenRecentPeak,
                                                                                                     curPmResult: curPmResult, mode: mode)
//                                let isAlwaysFirst = isDrStraight.0 ? true : false
                                if let selectResult = recoveryManager.selectRecoveryResult(list: recoveryResultList) {
                                    let recoveryResult = selectResult.0
                                    self.debug_ratio = selectResult.1
                                    if let bestResult = recoveryResult.bestResult {
                                        var recoveryCoord = [Float]()
                                        var paddings = JupiterMode.PADDING_VALUES_DR
                                        if isDrStraight.0 {
                                            let key = "\(sectorId)_\(curResult.building_name)_\(curResult.level_name)"
                                            if let linkData = PathMatcher.shared.linkData[key],
                                               let bestCandLinkId = recoveryResult.recentCandLinkId,
                                               let matchedLink = linkData[bestCandLinkId] {
                                                let limitType = PathMatcher.shared.getLimitationTypeWithLink(link: matchedLink)
                                                paddings = PathMatcher.shared.getLimitationRangeWithType(limitType: limitType)
                                            }
                                            recoveryCoord = [recoveryResult.shiftedTraj[recoveryResult.shiftedTraj.count-1].x, recoveryResult.shiftedTraj[recoveryResult.shiftedTraj.count-1].y]
                                        } else {
                                            recoveryCoord = [bestResult.x, bestResult.y]
                                        }
                                        self.debug_recovery_result = recoveryResult
                                        self.correctionIndex = userPeak.peak_index
                                        self.uvdIndexWhenCorrection = userVelocity.index
                                        stackManager.editCurResultBuffer(sectorId: sectorId, mode: mode, from: userPeak.peak_index, shifteTraj: recoveryResult.shiftedTraj,
                                                                         paddings: paddings)
                                        stackManager.editCurPmResultBuffer(sectorId: sectorId, mode: mode, from: recentUserPeak.peak_index, shifteTraj: recoveryResult.shiftedTraj, paddings: paddings)
                                        kalmanFilter?.editTuResultBuffer(sectorId: sectorId, mode: mode, from: userPeak.peak_index, shifteTraj: recoveryResult.shiftedTraj, curResult: curResult, paddings: paddings)
                                        
                                        if let pmResult = PathMatcher.shared.pathMatching(sectorId: sectorId, building: curResult.building_name, level: curResult.level_name, x: recoveryCoord[0], y: recoveryCoord[1], heading: bestResult.absolute_heading, isUseHeading: true, mode: mode, paddingValues: paddings) {
                                            curPathMatchingResult = bestResult
                                            curPathMatchingResult?.x = pmResult.x
                                            curPathMatchingResult?.y = pmResult.y
                                            curPathMatchingResult?.absolute_heading = pmResult.heading
                                            JupiterLogger.i(tag: "JupiterCalcManager", message: "(onUvdResult) 2 Peaks : best= \(bestResult.x),\(bestResult.y),\(bestResult.absolute_heading)")
                                            JupiterLogger.i(tag: "JupiterCalcManager", message: "(onUvdResult) 2 Peaks : pm= \(pmResult.x),\(pmResult.y),\(pmResult.heading)")
                                            kalmanFilter?.updateTuPosition(coord: [pmResult.x, pmResult.y])
                                            self.curResult? = curPathMatchingResult!
                                        } else {
                                            kalmanFilter?.updateTuPosition(coord: recoveryCoord)
                                            self.curResult? = bestResult
                                        }

                                        if let curPmResult = curPathMatchingResult,
                                           let matchedLink = PathMatcher.shared.getLinkInfoWithResult(sectorId: sectorId, result: curPmResult, checkAll: true) {
                                            let jumpInfo = JumpInfo(link_id: matchedLink.id, jumped_nodes: [])
                                            PathMatcher.shared.updateNodeAndLinkInfo(sectorId: sectorId, uvdIndex: curIndex, curResult: curPmResult, mode: mode, jumpInfo: jumpInfo)
                                        } else {
                                            PathMatcher.shared.initPassedLinkInfo()
                                        }
                                    }
                                }
                            }
                            recentUserPeakIndex = recentUserPeak.peak_index
                            recentLandmarkPeaks = matchedWithRecentPeak.landmark.peaks
                        }
                    }
                }
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
        
        // Bad Case 확인
        // 1. 같은 좌표 20개
        if stackManager.checkIsBadCase(jupiterPhase: jupiterPhase, uvdIndexWhenCorrection: self.uvdIndexWhenCorrection) {
            // 2. 최근 Peak발생 Index ~ 현재 Index 까지 길이
            // 3. 에서 결정된 길이만큼 현 위치 기준으로 landmark들 간의 거리 검사
            // 4. 범위 내에 Landmark가 있으면 스킵
            let diffIndex = userVelocity.index - recentUserPeakIndex
            let searchRange: Float = Float(max(diffIndex, 25))
            let isPossible = self.checkPossibleBadCase(landmarkPeaks: recentLandmarkPeaks, curPmResult: curPmResult, searchRange: searchRange)
            JupiterLogger.i(tag: "JupiterCalcManager", message: "(onUvdResult) BadCase : index= \(userVelocity.index), isPossible= \(isPossible)")
            if !isPossible { return }
            let userPeakAndLinkBuffer = stackManager.getUserPeakAndLinkBuffer()
            if userPeakAndLinkBuffer.count < 2 { return }
            JupiterResultState.isInRecoveryProcess = true
            let olderUserPeak = userPeakAndLinkBuffer[userPeakAndLinkBuffer.count-2].0
            let recentUserPeak = userPeakAndLinkBuffer[userPeakAndLinkBuffer.count-1].0
            let uvdBufferForRecovery = recoveryManager.getUvdBufferForRecovery(startIndex: olderUserPeak.peak_index, endIndex: userVelocity.index, uvdBuffer: uvdBuffer)
            let headingSearchRange = recoveryManager.getRecoveryRange(olderPeakIndex: olderUserPeak.peak_index, curIndex: curIndex)
            let pathHeadings = PathMatcher.shared.getPathMatchingHeadings(sectorId: sectorId,
                                                                          building: curPmResult.building_name,
                                                                          level: curPmResult.level_name,
                                                                          x: curPmResult.x, y: curPmResult.y,
                                                                          paddingValue: headingSearchRange, mode: mode)
            if let tuResultWhenOlderPeak = kalmanFilter?.getTuResultWithUvdIndex(index: olderUserPeak.peak_index), let tuResult = kalmanFilter?.getTuResult() {
                let curResultBuffer = stackManager.getCurResultBuffer()
                if let matchedWithOlderPeak = landmarkTagger.findMatchedLandmarkWithUserPeak(userPeak: olderUserPeak, curResult: curResult, curResultBuffer: curResultBuffer),
                   let matchedWithRecentPeak = landmarkTagger.findMatchedLandmarkWithUserPeak(userPeak: recentUserPeak, curResult: curResult, curResultBuffer: curResultBuffer) {
                    let hasMajorDirection = stackManager.checkHasMajorDirection(uvdBuffer: uvdBufferForRecovery)
                    JupiterLogger.i(tag: "JupiterCalcManager", message: "(onUvdResult) BadCase: hasMajorDirection= \(hasMajorDirection)")
                    if hasMajorDirection {
                        let majorSection = stackManager.extractSectionWithLeastChange(inputArray: uvdBufferForRecovery.map{ Float($0.heading) })
                        JupiterLogger.i(tag: "JupiterCalcManager", message: "(onUvdResult) BadCase: majorSection= \(majorSection)")
                        let recoveryTrajList = recoveryManager.makeMultipleRecoveryTrajectory(uvdBuffer: uvdBufferForRecovery, majorSection: majorSection, pathHeadings: pathHeadings, endHeading: tuResult.absolute_heading)
                        if let recoveryResult = recoveryManager.recoverWithMultipleTraj(recoveryTrajList: recoveryTrajList,
                                                                                        userPeakAndLinkBuffer: userPeakAndLinkBuffer,
                                                                                        landmarks: (matchedWithOlderPeak.0, matchedWithRecentPeak.0),
                                                                                        tuResultWhenOlderPeak: tuResultWhenOlderPeak,
                                                                                        curPmResult: curPmResult, mode: mode),
                        let bestResult = recoveryResult.bestResult {
                            self.debug_recovery_result = recoveryResult
                            let recoveryCoord: [Float] = [bestResult.x, bestResult.y]
                            self.recoveryIndex = userVelocity.index
                            let paddings = JupiterMode.PADDING_VALUES_DR
                            stackManager.editCurResultBuffer(sectorId: sectorId, mode: mode, from: recentUserPeak.peak_index, shifteTraj: recoveryResult.shiftedTraj, paddings: paddings)
                            stackManager.editCurPmResultBuffer(sectorId: sectorId, mode: mode, from: recentUserPeak.peak_index, shifteTraj: recoveryResult.shiftedTraj, paddings: paddings)
                            kalmanFilter?.editTuResultBuffer(sectorId: sectorId, mode: mode, from: recentUserPeak.peak_index, shifteTraj: recoveryResult.shiftedTraj, curResult: curResult, paddings: paddings)
                            
                            if let pmResult = PathMatcher.shared.pathMatching(sectorId: sectorId, building: curResult.building_name, level: curResult.level_name, x: bestResult.x, y: bestResult.y, heading: bestResult.absolute_heading, isUseHeading: true, mode: mode, paddingValues: JupiterMode.PADDING_VALUES_DR) {
                                curPathMatchingResult = bestResult
                                curPathMatchingResult?.x = pmResult.x
                                curPathMatchingResult?.y = pmResult.y
                                curPathMatchingResult?.absolute_heading = pmResult.heading
                                JupiterLogger.i(tag: "JupiterCalcManager", message: "(onUvdResult) BadCase: best= \(bestResult.x),\(bestResult.y),\(bestResult.absolute_heading)")
                                kalmanFilter?.updateTuPosition(coord: [pmResult.x, pmResult.y])
                                self.curResult? = curPathMatchingResult!
                            } else {
                                kalmanFilter?.updateTuPosition(coord: recoveryCoord)
                                self.curResult? = bestResult
                            }

                            if let matchedLink = PathMatcher.shared.getLinkInfoWithResult(sectorId: sectorId, result: bestResult, checkAll: true) {
                                let jumpInfo = JumpInfo(link_id: matchedLink.id, jumped_nodes: [])
                                PathMatcher.shared.updateNodeAndLinkInfo(sectorId: sectorId, uvdIndex: curIndex, curResult: bestResult, mode: mode, jumpInfo: jumpInfo)
                            } else {
                                PathMatcher.shared.initPassedLinkInfo()
                            }
                        }
                    } else {
                        
                    }
                }
            }
            JupiterResultState.isInRecoveryProcess = false
        }
    }
    
    private func startEntranceTracking(currentTime: Int, entManager: EntranceManager, uvd: UserVelocity, userPeak: UserPeak, bleData: [String: Float]) {
        let peakId = userPeak.id
        if !JupiterResultState.isIndoor && jupiterPhase != .ENTERING {
            guard let entKey = entManager.checkStartEntTrack(wardId: peakId, sec: 3) else { return }
//            peakDetector.setBufferSize(size: 50)
            jupiterPhase = .ENTERING
            JupiterResultState.isIndoor = true
            let entTrackData = entKey.split(separator: "_")
            JupiterLogger.i(tag: "JupiterCalcManager", message: "(onUvdResult) index:\(uvd.index) - entTrackData = \(entTrackData) ")
        }
        
        if jupiterPhase == .ENTERING {
//            if let stopEntTrackResult = entManager.stopEntTrack(curResult: curResult, wardId: peakId) {
//                JupiterLogger.i(tag: "JupiterCalcManager", message: "(onUvdResult) index:\(uvd.index) - EntTrack Finished : \(stopEntTrackResult.building_name) \(stopEntTrackResult.level_name) , [\(stopEntTrackResult.x),\(stopEntTrackResult.y),\(stopEntTrackResult.absolute_heading)]")
//                // Entrance Tracking Finshid (Normal)
//                startIndoorTracking(fltResult: stopEntTrackResult)
//            }
            
            if let entPeak = entManager.stopEntTrack_v2(curResult: curResult, wardId: peakId) {
                JupiterLogger.i(tag: "JupiterCalcManager", message: "(onUvdResult) index:\(uvd.index) - EntTrack Finished : peak \(entPeak)")
                let uvdBuffer = stackManager.getUvdBuffer()
                if entPeak.inner_ward.type == 1 {
                    // Straight
                    var length: Double = 0
                    for uvd in uvdBuffer {
                        if uvd.index >= userPeak.peak_index {
                            length += uvd.length
                        }
                    }
                    let dir = TJLabsUtilFunctions.shared.degree2radian(degree: Double(entPeak.inner_ward.direction[0]))
                    let dx = length*cos(dir)
                    let dy = length*sin(dir)
                    
                    let x = entPeak.inner_ward.x + Float(dx)
                    let y = entPeak.inner_ward.y + Float(dy)
                    if let curResult = curResult {
                        var tempResult = curResult
                        tempResult.building_name = entPeak.inner_ward.building
                        tempResult.level_name = entPeak.inner_ward.level
                        tempResult.x = x
                        tempResult.y = y
                        tempResult.absolute_heading = entPeak.inner_ward.direction[0]
                        JupiterLogger.i(tag: "JupiterCalcManager", message: "(onUvdResult) index:\(uvd.index) - EntTrack Finished : tempResult \(tempResult)")
                        startIndoorTracking(fltResult: tempResult)
                    }
                } else {
                    // Turn
                    let uvdBuffer = stackManager.getUvdBuffer(from: uvd.index-50)
                    let majorSection = stackManager.extractSectionWithLeastChange(inputArray: uvdBuffer.map{ Float($0.heading) })
                    
                    if !majorSection.isEmpty {
                        let headingForCompensation = majorSection.average - uvdBuffer[0].heading
                        let pathHeadings = entPeak.inner_ward.direction
                        var resultDict = [Float: [[Float]]]()
                        for pathHeading in pathHeadings {
                            let startHeading = Float(TJLabsUtilFunctions.shared.compensateDegree(Double(pathHeading) - Double(headingForCompensation)))
                            var coord: [Float] = [0, 0]
                            var heading: Float = startHeading
                            
                            var offset: [Float] = [0, 0]
                            var resultBuffer = [[Float]]()
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
                                    offset[0] = entPeak.inner_ward.x - coord[0]
                                    offset[1] = entPeak.inner_ward.y - coord[1]
                                }
                                
                                resultBuffer.append([coord[0], coord[1], heading])
                            }
                            
                            var compensatedBuffer = [[Float]]()
                            for value in resultBuffer {
                                let new: [Float] = [value[0] + offset[0], value[1] + offset[1], value[2]]
                                compensatedBuffer.append(new)
                            }
                            resultDict[pathHeading] = compensatedBuffer
                            
//                            let lastHeading = TJLabsUtilFunctions.shared.compensateDegree(Double(resultBuffer[resultBuffer.count-1][2]))
                        }
                        
                        var minDist: Float = 1000
                        if let curResult = curResult {
                            var tempResult = curResult
                            JupiterLogger.i(tag: "JupiterCalcManager", message: "(onUvdResult) index:\(uvd.index) - EntTrack Finished (2) : major=\(pathHeadings) ")
                            for pathHeading in pathHeadings {
                                guard let result = resultDict[pathHeading] else { continue }
                                let lastX = result[result.count-1][0]
                                let lastY = result[result.count-1][1]
                                let lastHeading = TJLabsUtilFunctions.shared.compensateDegree(Double(result[result.count-1][2]))
                                var lastResult = curResult
                                lastResult.x = lastX
                                lastResult.y = lastY
                                lastResult.absolute_heading = Float(lastHeading)
                                
                                guard let lastPm = PathMatcher.shared.pathMatching(sectorId: sectorId,
                                                                                   building: lastResult.building_name,
                                                                                   level: lastResult.level_name,
                                                                                   x: lastResult.x, y: lastResult.y, heading: lastResult.absolute_heading, isUseHeading: true, mode: .MODE_VEHICLE, paddingValues: JupiterMode.PADDING_VALUES_DR) else { continue }
                                let dist0 = abs(lastX - lastPm.x) + abs(lastY - lastPm.y)
                                
                                let firstX = result[0][0]
                                let firstY = result[0][1]
                                let firstHeading = TJLabsUtilFunctions.shared.compensateDegree(Double(result[0][2]))
                                var firstResult = curResult
                                firstResult.x = firstX
                                firstResult.y = firstY
                                firstResult.absolute_heading = Float(firstHeading)
                                guard let firstPm = PathMatcher.shared.pathMatching(sectorId: sectorId,
                                                                                   building: firstResult.building_name,
                                                                                   level: firstResult.level_name,
                                                                                   x: firstResult.x, y: firstResult.y, heading: firstResult.absolute_heading, isUseHeading: true, mode: .MODE_VEHICLE, paddingValues: JupiterMode.PADDING_VALUES_DR) else { continue }
                                let dist1 = abs(firstX - firstPm.x) + abs(firstY - firstPm.y)
                                
                                let dist = dist0+dist1
                                if dist < minDist {
                                    lastResult.x = lastPm.x
                                    lastResult.y = lastPm.y
                                    tempResult = lastResult
                                    minDist = dist
                                    JupiterLogger.i(tag: "JupiterCalcManager", message: "(onUvdResult) index:\(uvd.index) - EntTrack Finished (2) : dist \(dist) // tempResult \(tempResult)")
                                }
                            }
                            tempResult.building_name = entPeak.inner_ward.building
                            tempResult.level_name = entPeak.inner_ward.level
                            startIndoorTracking(fltResult: tempResult)
                        }
                    }
                }
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
//        JupiterLogger.i(tag: "JupiterCalcManager", message: "(calcEntranceResult) index:\(uvd.index) - entTrackResult // \(entTrackResult.building_name) \(entTrackResult.level_name) , x = \(entTrackResult.x) , y = \(entTrackResult.y) , h = \(entTrackResult.absolute_heading)")
    }
    
    private func startIndoorTracking(fltResult: FineLocationTrackingOutput?) {
//        peakDetector.setBufferSize(size: 50)
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
        if mode == .MODE_PEDESTRIAN {
            // PDR
            if pathMatchingType == .NARROW {
                isUseHeading = true
                headingRange -= 10
            }
            let paddings = (!isPdrMode && levelName == "B0") ? JupiterMode.PADDING_VALUES_PDR : self.paddingValues
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
            
            let paddings = (!isPdrMode && levelName == "B0") ? JupiterMode.PADDING_VALUES_DR : self.paddingValues
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
