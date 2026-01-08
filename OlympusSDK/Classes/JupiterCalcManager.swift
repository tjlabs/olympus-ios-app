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
    var curUserMask = UserMask(user_id: "", mobile_time: 0, section_number: 0, index: 0, x: 0, y: 0, absolute_heading: 0)
    var curVelocity: Float = 0
    var curUserMode: String = "AUTO"
    var curUserModeEnum: UserMode = .MODE_AUTO
    
    // MARK: - Constants
    private let AVG_BUFFER_SIZE = 10
    
    // MARK: - Etc..
//    var paddingValues = JupiterMode.PADDING_VALUES_DR
    private var pathMatchingCondition = PathMatchingCondition()

    private var report = -1
    
    // Result
    var jupiterPhase: JupiterPhase = .NONE
    var curResult: FineLocationTrackingOutput?
    var preResult: FineLocationTrackingOutput?
    
    var curPathMatchingResult: FineLocationTrackingOutput?
    var prePathMatchingResult: FineLocationTrackingOutput?
    
    var paddingValues = JupiterMode.PADDING_VALUES_DR
    
    // Debuging
    var debug_tu_xyh: [Float] = [0, 0, 0]
    var debug_landmark: LandmarkData?
    var debug_best_landmark: PeakData?
    var debug_recon_raw_traj: [[Double]]?
    var debug_recon_corr_traj: [FineLocationTrackingOutput]?
    
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
    public func setSendRfdLength(_ length: Int = 2) {
        DataBatchSender.shared.sendRfdLength = length
    }
    
    public func setSendUvdLength(_ length: Int = 4) {
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
            recon_corr_traj: self.debug_recon_corr_traj
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
        //
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
        // TODO: Handle UVD error
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
        guard let landmarkTagger = self.landmarkTagger else { return }
        stackManager.stackUvd(uvd: userVelocity)
        
        let capturedRfd = self.curRfd
        let bleData = capturedRfd.rfs // [String: Float] BLE_ID: RSSI
        
        // Moving Averaging
        guard let wardAvgManager = wardAvgManager else { return }
        let avgBleData: [String: Float] = wardAvgManager.updateEpoch(bleData: bleData)
        if let userPeak = peakDetector.updateEpoch(uvdIndex: curIndex, bleAvg: avgBleData) {
            JupiterLogger.i(tag: "JupiterCalcManager", message: "(onUvdResult) PEAK detected : id=\(userPeak.id) // peak_idx=\(userPeak.peak_index), peak_rssi=\(userPeak.peak_rssi), detected_idx = \(userPeak.end_index), detected_rssi = \(userPeak.end_rssi)")
            startEntranceTracking(currentTime: currentTime, entManager: entManager, uvd: userVelocity, peakId: userPeak.id, bleData: bleData)
            
            let uvdBuffer = stackManager.getUvdBuffer()
            let curResultBuffer = stackManager.getCurResultBuffer()
            if let matchedWithUserPeak = landmarkTagger.findMatchedLandmarkWithUserPeak(userPeak: userPeak, curResult: self.curResult, curResultBuffer: curResultBuffer) {
                self.debug_landmark = matchedWithUserPeak.landmark
                
                if let bestPeak = landmarkTagger.findBestLandmark(userPeak: userPeak, landmark: matchedWithUserPeak.landmark, matchedResult: matchedWithUserPeak.matchedResult) {
                    self.debug_best_landmark = bestPeak
                    if let matchedTuResult = kalmanFilter?.getTuResultWithUvdIndex(index: userPeak.peak_index) {
                        if let reconstructResult = landmarkTagger.recontructTrajectory(peakIndex: userPeak.peak_index, bestLandmark: bestPeak, matchedResult: matchedWithUserPeak.matchedResult, startHeading: Double(matchedTuResult.heading), uvdBuffer: uvdBuffer, curResultBuffer: curResultBuffer, mode: mode) {
                            self.debug_recon_raw_traj = reconstructResult.0
                            self.debug_recon_corr_traj = reconstructResult.1
                        } else {
                            self.debug_recon_raw_traj = nil
                            self.debug_recon_corr_traj = nil
                        }
                    }
                } else {
                    self.debug_best_landmark = nil
                }
            }
        }
        
        switch (jupiterPhase) {
        case .ENTERING:
            calcEntranceResult(currentTime: currentTime, entManager: entManager, uvd: userVelocity)
        case .TRACKING:
            calcIndoorResult(mode: mode, uvd: userVelocity)
        case .SEARCHING:
            print("Searching")
        case .NONE:
            print("None")
        }
        self.pastUvd = userVelocity
        
        // MARK: - Update CurPathMatchingResult
        guard let curResult = self.curResult else { return }
        stackManager.stackCurResult(curResult: curResult)
        
        guard let pmResult = PathMatcher.shared.pathMatching(sectorId: sectorId, building: curResult.building_name, level: curResult.level_name, x: curResult.x, y: curResult.y, heading: curResult.absolute_heading, isUseHeading: true, mode: mode, paddingValues: paddingValues) else { return }
        curPathMatchingResult = curResult
        curPathMatchingResult?.x = pmResult.x
        curPathMatchingResult?.y = pmResult.y
        curPathMatchingResult?.absolute_heading = pmResult.heading
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
    
    private func calcIndoorResult(mode: UserMode, uvd: UserVelocity) {
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
        kalmanFilter?.updateTuInformation(uvd: uvd)
        if let tuResult = kalmanFilter?.getTuResult() {
            self.debug_tu_xyh = [tuResult.x, tuResult.y, tuResult.absolute_heading]
        }
        
        let indoorResult = makeCurrentResult(input: tuResult, mustInSameLink: mustInSameLink, pathMatchingType: .NARROW, phase: .TRACKING, mode: mode)
        self.curResult = indoorResult
//        self.curPathMatchingResult = indoorResult
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
    
    private func makeCurrentResult(input: FineLocationTrackingOutput, mustInSameLink: Bool, pathMatchingType: PathMatchingType, phase: JupiterPhase, mode: UserMode) -> FineLocationTrackingOutput {
//        JupiterLogger.i(tag: "JupiterCalcManager", message: "(makeCurrentResult) - input: \(input.building_name), \(input.level_name), [\(input.x),\(input.y),\(input.absolute_heading)]")
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
//                JupiterLogger.i(tag: "JupiterCalcManager", message: "(makeCurrentResult) - result: \(result.building_name), \(result.level_name), [\(result.x),\(result.y),\(result.absolute_heading)]")
            } else {
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
            PathMatcher.shared.updateNodeAndLinkInfo(sectorId: sectorId, uvdIndex: curIndex, curResult: result, mode: mode)
        }
        
        return result
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
        // TO-DO
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
        // TO-DO
    }
    
    func onAffineParam(_ manager: TJLabsResource.TJLabsResourceManager, data: TJLabsResource.AffineTransParamOutput) {
        AffineConverter.shared.setAffineParam(sectorId: sectorId, data: data)
    }
    
    func onSpotsData(_ manager: TJLabsResource.TJLabsResourceManager, key: Int, type: TJLabsResource.SpotType, data: Any) {
        if type == .BUILDING_LEVEL_TAG {
            let blChangerTagData = data as! [TJLabsResource.BuildingLevelTag]
            guard let blChanger = self.buildingLevelChanger else { return }
            blChanger.blChangerTagMap[key] = blChangerTagData
        }
    }
    func onError(_ manager: TJLabsResource.TJLabsResourceManager, error: TJLabsResource.ResourceError, key: String) {
        // TO-DO
    }
}
