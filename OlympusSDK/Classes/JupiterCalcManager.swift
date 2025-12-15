
import Foundation
import UIKit
import simd
import TJLabsCommon
import TJLabsResource

class JupiterCalcManager: RFDGeneratorDelegate, UVDGeneratorDelegate, TJLabsResourceManagerDelegate, BuildingLevelChangerDelegate {
    
    func isBuildingLevelChanged(isChanged: Bool, newBuilding: String, newLevel: String, newCoord: [Float]) {
        // TODO
    }
    
    init(region: String, id: String, sectorId: Int, rssCompensator: JupiterRssCompensator) {
        self.id = id
        self.sectorId = sectorId
        self.region = region
        
        self.rssCompensator = rssCompensator
        self.entManager = EntranceManager(sector_id: sectorId)
        self.buildingLevelChanger = BuildingLevelChanger(sector_id: sectorId)
        
        tjlabsResourceManager.delegate = self
        buildingLevelChanger?.delegate = self
    }
    
    deinit { }
    
    
    // MARK: - Classes
    private var entManager: EntranceManager?
    private var rssCompensator: JupiterRssCompensator?
    private var buildingLevelChanger: BuildingLevelChanger?
    
    // MARK: - Properties
    var id: String = ""
    var sectorId: Int = 0
    var region: String = JupiterRegion.KOREA.rawValue
    var os: String = JupiterNetworkConstants.OPERATING_SYSTEM
    var phase: Int = 1
    
    var curUvd = UserVelocity(tenant_user_name: "", mobile_time: 0, index: 0, length: 0, heading: 0, looking: false)
    var curUserMask = UserMask(user_id: "", mobile_time: 0, section_number: 0, index: 0, x: 0, y: 0, absolute_heading: 0)
    var pastUvd = UserVelocity(tenant_user_name: "", mobile_time: 0, index: 0, length: 0, heading: 0, looking: false)
    
    var curVelocity: Float = 0
    var curUserMode: String = "AUTO"
    var curUserModeRaw: UserMode = .MODE_AUTO
    private var pressure: Float = 0
    
    private var uvdStopTimestamp: Double = 0
    private var tjlabsResourceManager = TJLabsResourceManager()
    
    private var rfdGenerator: RFDGenerator?
    private var uvdGenerator: UVDGenerator?
    
    private var rfdEmptyMillis: Double = 0
    
//    var paddingValues = JupiterMode.PADDING_VALUES_DR
    private var pathMatchingCondition = PathMatchingCondition()
    
    private var report = -1
    
    
    // Result
    var curResult = FineLocationTrackingOutput()
    var preResult = FineLocationTrackingOutput()
    
    var curPathMatchingResult = FineLocationTrackingOutput()
    var prePathMatchingResult = FineLocationTrackingOutput()
    
    func start(completion: @escaping (Bool, String) -> Void) {
        tjlabsResourceManager.loadJupiterResource(region: region, sectorId: sectorId, completion: { isSuccess in
            let msg: String = isSuccess ? "JupiterCalcManager start success" : "JupiterCalcManager start failed"
            completion(isSuccess, msg)
        })
    }
    
    // MARK: - Set REC length
    public func setSendRfdLength(_ length: Int = 2) {
        JupiterDataBatchSender.shared.sendRfdLength = length
    }
    
    public func setSendUvdLength(_ length: Int = 4) {
        JupiterDataBatchSender.shared.sendUvdLength = length
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
        rssCompensator?.saveNormalizationScaleToCache(sector_id: sectorId)
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

    // MARK: - RFDGeneratorDelegate Methods
    func onRfdResult(_ generator: TJLabsCommon.RFDGenerator, receivedForce: TJLabsCommon.ReceivedForce) {
        handleRfd(rfd: receivedForce)
    }
    
    func handleRfd(rfd: ReceivedForce) {
        let currentTime = TJLabsUtilFunctions.shared.getCurrentTimeInMilliseconds(as: .int) as! Int
        JupiterDataBatchSender.shared.sendRfd(rfd: rfd)
        
        guard let entManager = self.entManager, let rssCompensator = self.rssCompensator else { return }
        
        // OUTDOOR -> INDOOR 상황에서 진입 판단
        if !JupiterResultState.isIndoor && !JupiterResultState.isEntTrack {
            let entCheckResult = entManager.checkStartEntTrack(bleAvg: rfd.rfs, sec: 3)
            JupiterResultState.isEntTrack = entCheckResult.is_entered
            if JupiterResultState.isEntTrack {
                let entKey = entCheckResult.key
                let entTrackData = entKey.split(separator: "_")
                JupiterLogger.i(tag: "JupiterCalcManager", message: "(handleRfd) - entTrackData = \(entTrackData)")
                let entBuildingName = String(entTrackData[1])
                // Building Update
            }
//            let checkStartRouteTrackResult = JupiterRouteTracker.shared.checkStartRouteTrack(bleAvg: rfd.rfs, sec: 3)
//            JupiterResultState.isRouteTrack = checkStartRouteTrackResult.0
//            if JupiterResultState.isRouteTrack {
//                let key = checkStartRouteTrackResult.1
//                let routeTrackData = key.split(separator: "_")
//                JupiterLogger.i(tag: "JupiterCalcManager", message: "(handleRfd) - routeTrackData = \(routeTrackData)")
//                curJupiterResult.building_name = String(routeTrackData[1])
//            }
        }
        
        // Entrance Tracking 상황에서 위치 정보 제공 및 종료 판단
        if JupiterResultState.isEntTrack {
            let stopEntTrackResult = entManager.stopEntTrack(curResult: curResult, bleAvg: rfd.rfs,
                                    normalizationScale: rssCompensator.normalizationScale,
                                    deviceMinRss: rssCompensator.deviceMinRss,
                                    standardMinRss: rssCompensator.standardMinRss)
            if stopEntTrackResult.0 {
                JupiterLogger.i(tag: "JupiterCalcManager", message: "(handleRfd) - EntTrack Finished : \(stopEntTrackResult.1.building_name) \(stopEntTrackResult.1.level_name) , [\(stopEntTrackResult.1.x),\(stopEntTrackResult.1.y),\(stopEntTrackResult.1.absolute_heading)]")

                // Entrance Tracking Finshid (Normal)
                JupiterResultState.isEntTrack = false
                KalmanState.isKalmanFilterRunning = true
                phase = 6
                curResult = stopEntTrackResult.1
                curPathMatchingResult = stopEntTrackResult.1
//                JupiterKalmanFilter.shared.updateTuResult(result: checkFinishRouteTrackResult.1)
            }
//
            if entManager.forcedStopEntTrack(bleAvg: rfd.rfs, sec: 30) {
                JupiterResultState.isEntTrack = false
                entManager.setEntTrackFinishedTimestamp(time: currentTime)
            }
        }
        
        if !rfd.rfs.isEmpty {
            let bleAvg = rfd.rfs
            rssCompensator.refreshWardMinRssi(bleData: bleAvg)
            rssCompensator.refreshWardMaxRssi(bleData: bleAvg)
            let minRssi = rssCompensator.getMinRssi()
            let maxRssi = rssCompensator.getMaxRssi()
            let diffMinMaxRssi = abs(maxRssi - minRssi)
            if minRssi <= JupiterRssCompensation.DEVICE_MIN_UPDATE_THRESHOLD {
                rssCompensator.deviceMinRss = minRssi
            }
            rssCompensator.stackTimeAfterResponse()
                
            // Estimate Normalization Scale
//                rssCompensator?.estimateNormalizationScale(isGetFirstResponse: <#T##Bool#>, isIndoor: <#T##Bool#>, currentLevel: <#T##String#>, diffMinMaxRssi: diffMinMaxRssi, minRssi: minRssi)
            
            //            JupiterRssCompensator.shared.estimateNormalizationScale(isGetFirstResponse: isPossibleReturnJupiterResult(), isIndoor: JupiterResultState.isIndoor, currentLevel: curJupiterPathMatchingResult.level_name, diffMinMaxRssi: diffMinMaxRssi, minRssi: minRssi)
            
            let isPossibleToSave = rssCompensator.isPossibleToSaveToCache()
            if isPossibleToSave {
                rssCompensator.saveNormalizationScaleToCache(sector_id: sectorId)
                rssCompensator.isScaleSaved = true
            }
        }
        
        if !JupiterResultState.isIndoor {
//            JupiterRssCompensator.shared.initialize()
        }
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
    }
    
    func determineUserMode(mode: UserMode) {
        self.curUserModeRaw = mode
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
    }
    
    func onScaleOffsetData(_ manager: TJLabsResource.TJLabsResourceManager, key: String, data: [Float]) {
        // TO-DO
    }
    
    func onPathPixelData(_ manager: TJLabsResource.TJLabsResourceManager, key: String, data: TJLabsResource.PathPixelData) {
        
    }
    
    func onUnitData(_ manager: TJLabsResource.TJLabsResourceManager, key: String, data: [TJLabsResource.UnitData]) {
        // TO-DO
    }
    
    func onGeofenceData(_ manager: TJLabsResource.TJLabsResourceManager, key: String, data: TJLabsResource.GeofenceData) {
        let levelChangeArea = data.level_change_area
        let drModeArea = data.dr_mode_area
        let entranceMatchingArea = data.entrance_matching_area
        let entranceArea = data.entrance_area
        
    }
    
    func onEntranceData(_ manager: TJLabsResource.TJLabsResourceManager, key: String, data: TJLabsResource.EntranceData) {
        entManager?.setEntData(key: key, data: data)
    }
    
    func onEntranceRouteData(_ manager: TJLabsResource.TJLabsResourceManager, key: String, data: TJLabsResource.EntranceRouteData) {
        entManager?.setEntRouteData(key: key, data: data)
    }
    
    func onImageData(_ manager: TJLabsResource.TJLabsResourceManager, key: String, data: UIImage?) {
        // TO-DO
    }
    
    func onSectorParam(_ manager: TJLabsResource.TJLabsResourceManager, data: TJLabsResource.SectorParameterOutput) {
        let min_max: [Int] = [data.standard_min_rssi, data.standard_max_rssi]
        rssCompensator?.setStandardMinMax(minMax: min_max)
    }
    
    func onLevelParam(_ manager: TJLabsResource.TJLabsResourceManager, key: String, data: TJLabsResource.LevelParameterOutput) {
        let trajLength = data.trajectory_length
        let trajDiagonal = data.trajectory_diagonal
    }
    
    func onLevelWardsData(_ manager: TJLabsResource.TJLabsResourceManager, key: String, data: [TJLabsResource.LevelWard]) {
        // TO-DO
    }
    
    func onAffineParam(_ manager: TJLabsResource.TJLabsResourceManager, data: TJLabsResource.AffineTransParamOutput) {
        // TO-DO
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
