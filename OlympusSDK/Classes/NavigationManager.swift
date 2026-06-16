import Foundation
import TJLabsAuth
import TJLabsCommon
import TJLabsResource

public protocol NavigationManagerDelegate: AnyObject {
    func onInitSuccess(_ isSuccess: Bool, _ code: InitErrorCode?)
    func onJupiterSuccess(_ isSuccess: Bool, _ code: JupiterErrorCode?)
    func onJupiterResult(_ result: JupiterResult)
    func onJupiterReport(_ code: JupiterServiceCode, _ msg: String)
    func isJupiterInOutStateChanged(_ state: InOutState)
    
    func isUserArrived()
    func isUserGuidanceOut()
    func isNavigationRouteChanged(_ routes: [(String, String, Float, Float)])
    func isNavigationRouteFailed(_ reason: NavigationRouteFailureReason)
    func isWaypointChanged(_ waypoints: [[Double]])
}

public class NavigationManager: JupiterManagerDelegate, RoutingManagerDelegate {
    
    private let routeChangeWarmupSampleCount: Int = 10
    
    public func onRfdResult(receivedForce: TJLabsCommon.ReceivedForce) {
        // TODO
    }
    
    public func onEntering(userVelocity: UserVelocity, peakIndex: Int?, key: String, level_id: Int) {
        if !naviMode {
            JupiterLogger.i(tag: "NavigationManager", message: "(onEntering) do not request routing when naviMode \(naviMode)")
            return
        }
        
        if let origin = routingManager?.getEntRoutingOrigin(key: key, level_id: level_id), let to = self.naviDestination {
            let from: RoutingStart = RoutingStart(level_id: origin.level_id, x: origin.x, y: origin.y, absolute_heading: origin.absolute_heading)
            routingManager?.requestRouting(type: .INITIAL, start: from, end: to, is_vehicle: true, completion: { [self] routingResult, failureReason in
                if let result = routingResult {
                    JupiterLogger.i(tag: "NavigationManager", message: "(requestRouting) routingResult= \(result)")
                    updateRouteInfo(requestId: result.request_id, totalDistance: result.route.distance)
                    routingManager?.setRoutingRoutes(routes: result.route)
                } else {
                    JupiterLogger.i(tag: "NavigationManager", message: "(requestRouting) routingResult is nil, failureReason=\(failureReason?.rawValue ?? "nil")")
                    resetRouteInfo()
                    handleRoutingFailure(failureReason)
                }
            })
        }
    }
    
    public func mockTracking(jupiterResult: JupiterResult) {
        if !hasNaviRoute { return }
        if naviRouteChanged {
            routingManager?.setStartPointInNaviRoute(xyh: [jupiterResult.jupiter_pos.x, jupiterResult.jupiter_pos.y, jupiterResult.jupiter_pos.heading])
            naviRouteChanged = false
        }
        
        let mockResult = FineLocationTrackingOutput(mobile_time: jupiterResult.mobile_time,
                                                     index: jupiterResult.index,
                                                     building_name: jupiterResult.building_name,
                                                     level_name: jupiterResult.level_name,
                                                     x: jupiterResult.jupiter_pos.x,
                                                     y: jupiterResult.jupiter_pos.y,
                                                     absolute_heading: jupiterResult.jupiter_pos.heading)
    
        guard let naviRouteResult = calcNaviRouteResultInMock(jupiterResult: jupiterResult) else { return }
        self.curRoutingRouteResult = naviRouteResult
        stackManager.stackMockAndNaviRouteResultInMock(mockResult: mockResult, naviRouteResult: naviRouteResult)
        let mockAndNaviRouteResultBuffer = stackManager.getMockAndNaviRouteResultBufferInMock(size: 10)
        
        if pendingRouteChangeWarmupSamples > 0 {
            pendingRouteChangeWarmupSamples -= 1
            self.curRoutingRouteResult = naviRouteResult
            curNaviCase = .CASE_1
            resultMode = .NAVI
            feedbackCount = 0

            JupiterLogger.i(
                tag: "NavigationManager",
                message: "(mockTracking) skip CASE evaluation during reroute warmup: remaining=\(pendingRouteChangeWarmupSamples), route=[\(naviRouteResult.building), \(naviRouteResult.level), section:\(naviRouteResult.section), x:\(naviRouteResult.x), y:\(naviRouteResult.y), h:\(naviRouteResult.heading)]"
            )

            if pendingRouteChangeWarmupSamples > 0 {
                return
            }
        }
        
        let mockResultBuffer = mockAndNaviRouteResultBuffer.map { $0.0 }
        let naviRouteResultBuffer = mockAndNaviRouteResultBuffer.map { $0.1 }
        guard let followingResult = isFollowingNavigationRoute(curNaviCase: curNaviCase, travelingLinkDist: 20, naviRouteResultBuffer: naviRouteResultBuffer, curPmResultBuffer: mockResultBuffer) else { return }
        
        let estimatedNaviCase = followingResult.naviCase
        curNaviCase = estimatedNaviCase
        self.curRoutingRouteResult = naviRouteResult
        if curNaviCase == .CASE_3 && !guidanceOutReported {
            guidanceOutReported = true
            self.isUserGuidanceOut()
        }

        let nextResultMode = determineIndoorResultMode(resultMode: resultMode, naviCase: curNaviCase)
        self.resultMode = nextResultMode
        return
    }
    
    public func provideTrackingCorrection(mode: TJLabsCommon.UserMode,
                                          userVelocity: TJLabsCommon.UserVelocity,
                                          peakIndex: Int?,
                                          recentLandmarkPeaks: [PeakData]?,
                                          travelingLinkDist: Float,
                                          indexForEdit: Int,
                                          curPmResult: FineLocationTrackingOutput?) -> (NaviCorrectionInfo, [StackEditInfo])? {
        if !hasNaviRoute || curUserModeEnum == .MODE_PEDESTRIAN { return nil }
        if naviRouteChanged, let curPmResult = curPmResult {
            routingManager?.setStartPointInNaviRoute(xyh: [curPmResult.x, curPmResult.y, curPmResult.absolute_heading])
            naviRouteChanged = false
        }
        guard let jupiterManager = self.jupiterManager else { return nil }
        guard let naviRouteResult = calcNaviRouteResult(uvd: userVelocity, jupiterResult: jupiterResult) else { return nil }
        self.curRoutingRouteResult = naviRouteResult
        stackManager.stackIndexAndNaviRouteResult(naviRouteResult: naviRouteResult, peakIndex: peakIndex, uvd: userVelocity)
        let indexAndNaviRouteResultBuffer = stackManager.getIndexAndNaviRouteResultBuffer(size: 10)
        let naviRouteResultBuffer = indexAndNaviRouteResultBuffer.map { $0.1 }
        guard let curPmResultBuffer = jupiterManager.getCurPmResultBuffer(size: 10) else { return nil }
        
        if pendingRouteChangeWarmupSamples > 0 {
            pendingRouteChangeWarmupSamples -= 1
            self.curRoutingRouteResult = naviRouteResult
            curNaviCase = .CASE_1
            resultMode = .NAVI
            feedbackCount = 0

            JupiterLogger.i(
                tag: "NavigationManager",
                message: "(provideTrackingCorrection) skip CASE evaluation during reroute warmup: remaining=\(pendingRouteChangeWarmupSamples), route=[\(naviRouteResult.building), \(naviRouteResult.level), section:\(naviRouteResult.section), x:\(naviRouteResult.x), y:\(naviRouteResult.y), h:\(naviRouteResult.heading)]"
            )

            if pendingRouteChangeWarmupSamples > 0 {
                return nil
            }
        }
        
        guard let followingResult = isFollowingNavigationRoute(curNaviCase: curNaviCase, travelingLinkDist: travelingLinkDist, naviRouteResultBuffer: naviRouteResultBuffer, curPmResultBuffer: curPmResultBuffer) else { return nil }
        
        let estimatedNaviCase = followingResult.naviCase
        curNaviCase = estimatedNaviCase
        self.curRoutingRouteResult = naviRouteResult
        if curNaviCase == .CASE_3 && !guidanceOutReported {
            guidanceOutReported = true
            self.isUserGuidanceOut()
        } else if curNaviCase == .CASE_2 {
//            let diffSectionCorrIndex = userVelocity.index - sectionCorrectionIndex
//            if diffSectionCorrIndex < 10 {
//                JupiterLogger.i(tag: "NavigationManager", message: "(onTracking) isFollowingNavigationRoute: section correction is applied at \(sectionCorrectionIndex) index (curIndex = \(userVelocity.index))")
//                return nil
//            }
//            let curNaviSection = naviRouteResult.section
//            let curPmResult = curPmResultBuffer[curPmResultBuffer.count-1]
//            guard let curPmSection = routingManager?.findSectionContaining(x: curPmResult.x, y: curPmResult.y) else {
//                return nil
//            }
//            if curNaviSection == curPmSection {
//                JupiterLogger.i(tag: "NavigationManager", message: "(onTracking) isFollowingNavigationRoute: findSectionContaining // jupiter and navi result are in same section \(curPmSection)")
//                routingManager?.updateCurRoutePos(curSection: curPmSection, curResult: curPmResult)
//                sectionCorrectionIndex = userVelocity.index
//            }
        }
        
        JupiterLogger.i(tag: "NavigationManager", message: "(onTracking) isFollowingNavigationRoute: followingResult= \(followingResult) // curNaviCase= \(curNaviCase)")
        let nextResultMode = determineIndoorResultMode(resultMode: resultMode, naviCase: curNaviCase)
        self.resultMode = nextResultMode
        let canFeedback = feedbackWhenFollowing(naviCase: curNaviCase, naviRouteResultBuffer: naviRouteResultBuffer)
        JupiterLogger.i(tag: "NavigationManager", message: "(onTracking) feedbackWhenFollowing: canFeedback= \(canFeedback)")
        if canFeedback {
            feedbackCount += 1
            JupiterLogger.i(tag: "NavigationManager", message: "(onTracking) feedbackCount: \(feedbackCount)")
            if feedbackCount >= 10 {
                feedbackCount = 0
                let indexAndNaviRouteResultBuffer = stackManager.getIndexAndNaviRouteResultBuffer(index: indexForEdit)
                var editInfoBuffer = [StackEditInfo]()
                for buf in indexAndNaviRouteResultBuffer {
                    editInfoBuffer.append(StackEditInfo(index: buf.0, building: buf.1.building, level: buf.1.level, x: buf.1.x, y: buf.1.y, heading: buf.1.heading))
                }
                // Feedback 하기 윈한 정보 JupiterManager로 전달
                let naviCorrectionInfo = NaviCorrectionInfo(x: naviRouteResult.x, y: naviRouteResult.y, heading: naviRouteResult.heading)
                let stackEditInfoBuffer = editInfoBuffer
                return (naviCorrectionInfo, stackEditInfoBuffer)
            }
        } else {
            feedbackCount = 0
        }
        return nil
    }
    
    public func onInitSuccess(_ isSuccess: Bool, _ code: InitErrorCode?) {
        JupiterLogger.i(tag: "NavigationManager", message: "onInitSuccess : isSuccess= \(isSuccess), code= \(code)")
        if isSuccess, let blData = jupiterManager?.getBuildingsData() {
            JupiterLogger.i(tag: "NavigationManager", message: "onInitSuccess : buildingsData= \(blData)")
            self.tenant_user_name = TJLabsAuthManager.shared.getTenantUserName()
            routingManager?.setTenantUserName(name: self.tenant_user_name)
            routingManager?.setBuildingsData(buildingsData: blData)
        }
        delegate?.onInitSuccess(isSuccess, code)
    }
    
    // MARK: - Jupiter
    public func onJupiterSuccess(_ isSuccess: Bool, _ code: JupiterErrorCode?) {
        delegate?.onJupiterSuccess(isSuccess, code)
    }
    
    public func onJupiterResult(_ result: JupiterResult) {
        self.jupiterResult = result
        var copied = result
        if resultMode == .NAVI {
            if let routingRoute = self.curRoutingRouteResult {
                copied.building_name = routingRoute.building
                copied.level_name = routingRoute.level
                copied.jupiter_pos.x = routingRoute.x
                copied.jupiter_pos.y = routingRoute.y
                copied.jupiter_pos.heading = routingRoute.heading
                copied.llh = makeLLH(x: routingRoute.x, y: routingRoute.y, heading: routingRoute.heading) ?? result.llh
            }
        }

        let hasGuidanceRoute = !(routingManager?.getRoutingRoutes().isEmpty ?? true)
        if hasGuidanceRoute {
            let displayedRemainingDistance = calculateRemainingDistance(building: copied.building_name,
                                                                       level: copied.level_name,
                                                                       x: copied.jupiter_pos.x,
                                                                       y: copied.jupiter_pos.y)
            remainingDistance = displayedRemainingDistance ?? 0
            copied.remaining_distance = displayedRemainingDistance
        } else {
            copied.passed_point_id = nil
            copied.remaining_distance = nil
            remainingDistance = 0
        }
        
        let shouldNotifyArrival = hasGuidanceRoute && isUserArrived(building: copied.building_name,
                                                                    level: copied.level_name,
                                                                    x: copied.jupiter_pos.x,
                                                                    y: copied.jupiter_pos.y)

        delegate?.onJupiterResult(copied)
        if shouldNotifyArrival {
            finishNavigation()
            delegate?.isUserArrived()
        }
    }
    
    public func onJupiterReport(_ code: JupiterServiceCode, _ msg: String) {
        delegate?.onJupiterReport(code, msg)
    }
    
    public func isJupiterInOutStateChanged(_ state: InOutState) {
        delegate?.isJupiterInOutStateChanged(state)
        JupiterLogger.i(tag: "NavigationManager", message: "(isJupiterInOutStateChanged) : state= \(state)")
    }
    
    public func isJupiterPhaseChanged(index: Int, phase: JupiterPhase, xyh: [Float]?) {
        if phase == .TRACKING, let xyh = xyh {
            self.jupiterPhase = phase
            self.trackingIndex = index
            if hasNaviRoute {
                routingManager?.setStartPointInNaviRoute(xyh: xyh)
            }
        }
    }
    
    // MARK: - Navigation
    func isUserGuidanceOut() {
        JupiterLogger.i(tag: "NavigationManager", message: "(isUserGuidanceOut) user guidance out")
        hasNaviRoute = false
        curRoutingRouteResult = nil
        resetRouteInfo()
        routingManager?.clearRoutes()
        self.jupiterResult?.passed_point_id = nil
        self.jupiterResult?.remaining_distance = nil
        delegate?.isUserGuidanceOut()
        guard let curResult = self.jupiterResult else { return }
        guard let curLevelId = routingManager?.getLevelIdWithName(levelName: curResult.level_name) else { return }
        let from = RoutingStart(level_id: curLevelId, x: Int(curResult.jupiter_pos.x), y: Int(curResult.jupiter_pos.y), absolute_heading: Int(curResult.jupiter_pos.heading))
        guard let to = self.naviDestination else { return }
        routingManager?.requestRouting(type: .REROUTE, start: from, end: to, is_vehicle: self.isVehicle, completion: { [self] routingResult, failureReason in
            if let result = routingResult {
                JupiterLogger.i(tag: "NavigationManager", message: "(requestRouting) routingResult= \(result)")
                updateRouteInfo(requestId: result.request_id, totalDistance: result.route.distance)
                routingManager?.setRoutingRoutes(routes: result.route)
            } else {
                JupiterLogger.i(tag: "NavigationManager", message: "(requestRouting) routingResult is nil")
                resetRouteInfo()
                handleRoutingFailure(failureReason)
            }
        })
    }
    
    func isNavigationRouteChanged() {
        if !hasNaviRoute {
            hasNaviRoute = true
            curRoutingRouteResult = nil
            if let naviRouteForDisplay = routingManager?.getNaviRoutesForDisplay() {
                delegate?.isNavigationRouteChanged(naviRouteForDisplay)
                naviRouteChanged = true
                pendingRouteChangeWarmupSamples = routeChangeWarmupSampleCount
                guidanceOutReported = false
                feedbackCount = 0
                curNaviCase = .CASE_1
                resultMode = .NAVI
            }
        }
    }
    
    func isNavigationRouteFailed(_ reason: NavigationRouteFailureReason) {
        JupiterLogger.i(tag: "NavigationManager", message: "(isNavigationRouteFailed) navigation route failed")
        delegate?.isNavigationRouteFailed(reason)
    }
    
    func isWaypointsChanged() {
        if let waypoints = routingManager?.getNavigationWaypoints() {
            JupiterLogger.i(tag: "NavigationManager", message: "(isWaypointsChanged) waypoints= \(waypoints)")
            delegate?.isWaypointChanged(waypoints)
        }
    }
    
    private var id: String = ""
    private var tenant_user_name: String = ""
    private var cloud: String = ""
    private var region: String = ""
    private var sectorId: Int = 0
    public weak var delegate: NavigationManagerDelegate?
    
    // MARK: - Classes
    var jupiterManager: JupiterManager?
    var routingManager: RoutingManager?
    let stackManager = NavigationStackManager()
    
    // MARK: - Navigation
    private var naviMode: Bool = false
    private var naviDestination: Point?
    private var isVehicle: Bool = false
    var curRoutingRouteResult: RoutingRoute?
    var guidanceOutReported: Bool = false
    private var waypoints: [[Double]] = []
    
    // MARK: - Routing
    private var hasNaviRoute: Bool = false
    private var naviRouteChanged: Bool = false
    private var pendingRouteChangeWarmupSamples: Int = 0
    private var feedbackIndex: Int = 0
    private var feedbackCount: Int = 0
    private var curNaviCase: NaviCase = .NONE
    private var sectionCorrectionIndex: Int = 0
    private var requestId: String = ""
    private var totalDistance: Int = 0
    private var remainingDistance: Int = 0
    private var reason: NavigationRouteFailureReason?
    
    // MARK: - Variables
    private var jupiterResult: JupiterResult?
    private var routingResult: JupiterResult?
    private var trackingIndex: Int = 0
    var resultMode: IndoorResultMode = .NONE
    private var jupiterPhase: JupiterPhase = .NONE
    private var curUserModeEnum: UserMode = .MODE_VEHICLE
    private var recentLandmarkPeaks: [PeakData]?
    private var mockMode: Bool = false
    public var isUseOSHeading: Bool = false {
        didSet {
            jupiterManager?.isUseOSHeading = isUseOSHeading
        }
    }
    
    // MARK: - init & deinit
    public init(id: String, cloud: String = JupiterCloud.GCP.rawValue, region: String = JupiterRegion.KOREA.rawValue, sectorId: Int, debugOption: Bool = false) {
        self.id = id
        self.cloud = cloud
        self.region = region
        self.sectorId = sectorId
        
        self.jupiterManager = JupiterManager(id: id, cloud: cloud, region: region, sectorId: sectorId, debugOption: debugOption)
        self.jupiterManager?.isUseOSHeading = isUseOSHeading
        self.jupiterManager?.delegate = self
        
        self.routingManager = RoutingManager(id: id, sectorId: sectorId)
        self.routingManager?.delegate = self
    }
    
    deinit {
        JupiterLogger.i(tag: "NavigationManager", message: "deinit")
        jupiterManager?.delegate = nil
        routingManager?.delegate = nil
        delegate = nil

        jupiterManager?.stopJupiter { _, _ in }
        jupiterManager = nil
        routingManager = nil
    }
    
    public func startService(mode: UserMode) {
        PathMatcher.shared.setGraphMode(mode)
        routingManager?.setGraphMode(mode)
        jupiterManager?.startJupiter(mode: mode)
    }
    
//    public func startService(region: String = JupiterRegion.KOREA.rawValue, sectorId: Int, mode: UserMode, debugOption: Bool = false) {
//        jupiterManager?.startJupiter(region: region, sectorId: sectorId, mode: mode, debugOption: debugOption)
//    }
    
    public func stopService(completion: @escaping (Bool, String) -> Void) {
        jupiterManager?.stopJupiter(completion: completion)
    }
    
    public func setNaviDestination(dest: Point) {
        self.naviMode = true
        self.naviDestination = dest
        routingManager?.setNaviDestination(dest: dest)
    }
    
    public func setNaviWaypoints(waypoints: [[Double]]) {
        routingManager?.setNavigationWaypoints(waypoints: waypoints)
    }
    
    public func getJupiterDebugResult() -> JupiterDebugResult? {
        guard var jupiterDebugResult = jupiterManager?.getJupiterDebugResult() else { return nil }
        if let routingResult = self.curRoutingRouteResult {
            jupiterDebugResult.navi_xyh = [routingResult.x, routingResult.y, routingResult.heading]
        }
        return jupiterDebugResult
    }
    
    func changeUserMode(mode: UserMode) {
        self.curUserModeEnum = mode
        self.routingManager?.setGraphMode(mode)
        self.jupiterManager?.changeUserMode(mode: mode)
    }
    
    public func requestRouting(start: RoutingStart, end: Point, waypoints: [Point] = [], is_vehicle: Bool, completion: @escaping (RoutingResult?, [NavigationLevelRoute]) -> Void) {
        requestRouting(start: start, end: end, waypoints: waypoints, is_vehicle: is_vehicle, completion: { result, levelRoutes, _ in
            completion(result, levelRoutes)
        })
    }

    public func requestRouting(start: RoutingStart, end: Point, waypoints: [Point] = [], is_vehicle: Bool, completion: @escaping (RoutingResult?, [NavigationLevelRoute], NavigationRouteFailureReason?) -> Void) {
        guard let routingManager else {
            completion(nil, [], nil)
            return
        }
        
        self.isVehicle = is_vehicle
        let userMode: UserMode = is_vehicle ? .MODE_VEHICLE : .MODE_PEDESTRIAN
        changeUserMode(mode: userMode)
        routingManager.requestRouting(type: .INITIAL, start: start, end: end, waypoints: waypoints, is_vehicle: is_vehicle, completion: { result, failureReason in
            var levelRoutes = [NavigationLevelRoute]()
            if let routingResult = result {
                self.naviMode = true
                self.naviDestination = end
                self.routingManager?.setRoutingRoutes(routes: routingResult.route)
                levelRoutes = self.routingManager?.getLevelRoutes() ?? []
            } else {
                self.resetRouteInfo()
                self.handleRoutingFailure(failureReason)
            }
            completion(result, levelRoutes, failureReason)
        })
    }
    
    public func getRoutingInfo() -> (requestId: String, totalDistance: Int, routes: [NavigationLevelRoute], reason: NavigationRouteFailureReason?) {
        return (requestId, totalDistance, routingManager?.getLevelRoutes() ?? [], reason)
    }
    
    public func getLevelRoutes() -> [NavigationLevelRoute] {
        return routingManager?.getLevelRoutes() ?? []
    }
    
    //MARK: - Replay Mode
    public func setReplayMode(flag: Bool, rfdFileName: String, uvdFileName: String, eventFileName: String) {
        jupiterManager?.setReplayMode(flag: flag, rfdFileName: rfdFileName, uvdFileName: uvdFileName, eventFileName: eventFileName)
    }
    
    public func setReplayModeLegacy(flag: Bool, bleFileName: String, sensorFileName: String) {
        jupiterManager?.setReplayModeLegacy(flag: flag, bleFileName: bleFileName, sensorFileName: sensorFileName)
    }
    
    public func saveFilesForReplay(completion: @escaping (Bool) -> Void) {
        jupiterManager?.saveFilesForReplay(completion: completion)
    }
    
    //MARK: - Mock Mode
    public func setMockMode(mode: JupiterMockMode, completion: @escaping (Bool) -> Void) {
        guard let jupiterManager else {
            completion(false)
            return
        }

        jupiterManager.setMockMode(mode: mode, completion: { [self] isSuccess in
            mockMode = isSuccess
            completion(isSuccess)
        })
    }
    
    // MARK: - Private
    private func calcNaviRouteResult(uvd: UserVelocity, jupiterResult: JupiterResult?) -> RoutingRoute? {
        guard let jupiterResult = jupiterResult else { return nil }
        if uvd.index <= trackingIndex { return nil }
        return routingManager?.calcNaviRouteResult(uvd: uvd, jupiterResult: jupiterResult)
    }
    
    private func calcNaviRouteResultInMock(jupiterResult: JupiterResult) -> RoutingRoute? {
        return routingManager?.calcNaviRoutResultInMock(jupiterResult: jupiterResult)
    }

    private func makeLLH(x: Float, y: Float, heading: Float) -> LLH? {
        guard let affineParam = AffineConverter.shared.getAffineParam(sectorId: sectorId) else { return nil }
        let converted = AffineConverter.shared.convertPpToLLH(x: Double(x), y: Double(y), heading: Double(heading), param: affineParam)
        return LLH(lat: converted.lat, lon: converted.lon, azimuth: converted.azimuth)
    }

    private func updateRouteInfo(requestId: String, totalDistance: Int) {
        self.requestId = requestId
        self.totalDistance = max(totalDistance, 0)
        self.remainingDistance = max(totalDistance, 0)
    }

    private func resetRouteInfo() {
        requestId = ""
        totalDistance = 0
        remainingDistance = 0
    }

    private func calculateRemainingDistance(building: String, level: String, x: Float, y: Float) -> Int? {
        guard totalDistance > 0 else {
            if let routeRemainingDistance = routingManager?.getRemainingDistance(building: building, level: level, x: x, y: y) {
                return max(Int(routeRemainingDistance.rounded()), 0)
            }
            return nil
        }

        guard let traveledDistance = routingManager?.getTraveledDistance(building: building,
                                                                         level: level,
                                                                         x: x,
                                                                         y: y) else {
            if let routeRemainingDistance = routingManager?.getRemainingDistance(building: building, level: level, x: x, y: y) {
                return max(Int(routeRemainingDistance.rounded()), 0)
            }
            return nil
        }

        let clampedTraveledDistance = min(max(Int(traveledDistance.rounded()), 0), totalDistance)
        return max(totalDistance - clampedTraveledDistance, 0)
    }
    
    private func isUserArrived(building: String, level: String, x: Float, y: Float) -> Bool {
        guard naviMode, hasNaviRoute else { return false }
        guard let remainingDistance = calculateRemainingDistance(building: building,
                                                                level: level,
                                                                x: x,
                                                                y: y) else { return false }
        return remainingDistance <= 10
    }
    
    private func handleRoutingFailure(_ failureReason: NavigationRouteFailureReason?) {
        guard let failureReason else { return }

        self.reason = failureReason
        if failureReason == .tooClose {
            JupiterLogger.i(tag: "NavigationManager", message: "(handleRoutingFailure) report failure and cancel navigation because destination is within 10m")
            isNavigationRouteFailed(failureReason)
            cancelNavigation()
            return
        }

        isNavigationRouteFailed(failureReason)
    }

    private func finishNavigation() {
        naviMode = false
        naviDestination = nil
        isVehicle = false
        curRoutingRouteResult = nil
        guidanceOutReported = false
        hasNaviRoute = false
        naviRouteChanged = false
        pendingRouteChangeWarmupSamples = 0
        feedbackIndex = 0
        feedbackCount = 0
        curNaviCase = .NONE
        sectionCorrectionIndex = 0
        resetRouteInfo()
        resultMode = .NONE
        waypoints = []
        routingManager?.clearNavigationSession()
    }
    
    public func cancelNavigation() {
        self.finishNavigation()
    }
    
    private func determineIndoorResultMode(resultMode: IndoorResultMode, naviCase: NaviCase) -> IndoorResultMode {
        switch naviCase {
        case .CASE_1, .CASE_2:
            return .NAVI
        case .CASE_3:
            return .CALC
        case .INIT:
            return .NAVI
        default:
            return .CALC
        }
    }
    
    private func feedbackWhenFollowing(naviCase: NaviCase, naviRouteResultBuffer: [RoutingRoute]) -> Bool {
        if naviCase != .CASE_1 { return false }
        if naviRouteResultBuffer.count < 5 { return false }

        var canFeedback: Bool = true
        var coordSet = Set<String>()

        for nr in naviRouteResultBuffer.suffix(5) {
            let key = "\(nr.x)_\(nr.y)"

            if coordSet.contains(key) {
                canFeedback = false
                break
            }
            coordSet.insert(key)
        }

        return canFeedback
    }
    
    private func isFollowingNavigationRoute(
        curNaviCase: NaviCase,
        travelingLinkDist: Float,
        naviRouteResultBuffer: [RoutingRoute],
        curPmResultBuffer: [FineLocationTrackingOutput]
    ) -> (naviCase: NaviCase, d: Float, dh: Float)? {

        if curNaviCase == .CASE_3 {
            JupiterLogger.i(tag: "NavigationManager", message: "(isFollowingNavigationRoute) : CASE_3 (sticky) // previous case was CASE_3, awaiting reroute")
            return (.CASE_3, 100, 100)
        }
        guard naviRouteResultBuffer.count == curPmResultBuffer.count else {
            JupiterLogger.i(tag: "NavigationManager", message: "(isFollowingNavigationRoute) : return nil // buffer size mismatch navi=\(naviRouteResultBuffer.count) pm=\(curPmResultBuffer.count)")
            return nil
        }
        if naviRouteResultBuffer.count < 10 {
            JupiterLogger.i(tag: "NavigationManager", message: "(isFollowingNavigationRoute) : INIT // insufficient buffer size=\(naviRouteResultBuffer.count) (need >= 10)")
            return (.INIT, 0, 0)
        }

        let DLOSS_THRESHOLD_15: Float = 15
        let DLOSS_THRESHOLD_45: Float = 45
        let DHLOSS_THRESHOLD_45: Float = 45

        // 1) 거리/헤딩 평균 손실 계산
        let (dAvg, dhAvg) = computeLossAverages(navi: naviRouteResultBuffer, pm: curPmResultBuffer)

        // 2) 빠른 케이스 결정
        if dAvg <= DLOSS_THRESHOLD_15 {
            JupiterLogger.i(tag: "NavigationManager", message: "(isFollowingNavigationRoute) : CASE_1 // dAvg=\(dAvg) <= \(DLOSS_THRESHOLD_15) (within tight threshold), dhAvg=\(dhAvg)")
            return (.CASE_1, dAvg, dhAvg)
        }

        if dhAvg > DHLOSS_THRESHOLD_45 {
            JupiterLogger.i(tag: "NavigationManager", message: "(isFollowingNavigationRoute) : CASE_3 // dhAvg=\(dhAvg) > \(DHLOSS_THRESHOLD_45) (heading deviation exceeds threshold), dAvg=\(dAvg)")
            return (.CASE_3, dAvg, dhAvg)
        }

        let naviResultLast = naviRouteResultBuffer[naviRouteResultBuffer.count-1]
        
        // 3) 동일성 체크
        let isAllSamePmResult = isAllSamePmResult(curPmResultBuffer)
        let isAllSameNaviResult = isAllSameNaviResult(naviRouteResultBuffer)

        JupiterLogger.i(
            tag: "NavigationManager",
            message: "(isFollowingNavigationRoute) : isAllSamePmResult= \(isAllSamePmResult) // isAllSameNaviResult= \(isAllSameNaviResult)"
        )

        // 4) "jupiter가 고정인데 navi는 변함" => CASE_2 (기존 로직 유지)
        if isAllSamePmResult && !isAllSameNaviResult {
            JupiterLogger.i(tag: "NavigationManager", message: "(isFollowingNavigationRoute) : CASE_2 // jupiter buffer static while navi advancing (dAvg=\(dAvg), dhAvg=\(dhAvg))")
            return (.CASE_2, dAvg, dhAvg)
        }

        // 5) CASE_2 or CASE_3 판단
        let shouldCheckEndOfMap = !naviResultLast.passable
        let (case23, adaptiveTh, dhOverride) = decideCase2or3(
            dAvg: dAvg,
            baseThreshold: DLOSS_THRESHOLD_45,
            travelingLinkDist: travelingLinkDist,
            curPmResultBuffer: curPmResultBuffer,
            naviRouteResultBuffer: naviRouteResultBuffer,
            shouldCheckEndOfMap: shouldCheckEndOfMap
        )

        // dhOverride는 현재 코드에서 0으로 조기리턴하던 형태 유지용 (필요 없으면 제거 가능)
        if let dhOverride {
            return (case23, adaptiveTh, dhOverride)
        }

        JupiterLogger.i(tag: "NavigationManager", message: "(isFollowingNavigationRoute) : \(case23) // resolved by decideCase2or3 (dAvg=\(dAvg), dhAvg=\(dhAvg), adaptiveTh=\(adaptiveTh))")
        return (case23, dAvg, dhAvg)
    }

    // MARK: - Loss
    private func computeLossAverages(
        navi: [RoutingRoute],
        pm: [FineLocationTrackingOutput]
    ) -> (dAvg: Float, dhAvg: Float) {

        let count = navi.count
        guard count > 0 else { return (0, 0) }

        var dSum: Float = 0
        var dhSum: Float = 0
        var sampleLogs: [String] = []

        for i in 0..<count {
            let dx = navi[i].x - pm[i].x
            let dy = navi[i].y - pm[i].y
            let d = hypotf(dx, dy)
            let dh = angleDiffDeg(navi[i].heading, pm[i].absolute_heading)
            dSum += d
            dhSum += dh
            sampleLogs.append("i=\(i) navi=(x:\(navi[i].x), y:\(navi[i].y), h:\(navi[i].heading)) pm=(x:\(pm[i].x), y:\(pm[i].y), h:\(pm[i].absolute_heading)) d=\(d) dh=\(dh)")
        }

        let dAvg = dSum / Float(count)
        let dhAvg = dhSum / Float(count)

        JupiterLogger.i(tag: "NavigationManager",
                        message: "(computeLossAverages) dAvg=\(dAvg) dhAvg=\(dhAvg) count=\(count) // \(sampleLogs.joined(separator: " ; "))")

        return (dAvg, dhAvg)
    }

    private func angleDiffDeg(_ a: Float, _ b: Float) -> Float {
        var d = abs(a - b)
        if d > 270 { d = 360 - d }
        return d
    }
    
    // MARK: - Same checks
    private func isAllSamePmResult(_ buf: [FineLocationTrackingOutput]) -> Bool {
        guard let first = buf.first else { return true }
        return buf.allSatisfy { $0.x == first.x && $0.y == first.y }
    }

    private func isAllSameNaviResult(_ buf: [RoutingRoute]) -> Bool {
        guard let first = buf.first else { return true }
        return buf.allSatisfy { $0.x == first.x && $0.y == first.y }
    }
    
    // MARK: - Case 2/3 decision
    private func decideCase2or3(
        dAvg: Float,
        baseThreshold: Float,
        travelingLinkDist: Float,
        curPmResultBuffer: [FineLocationTrackingOutput],
        naviRouteResultBuffer: [RoutingRoute],
        shouldCheckEndOfMap: Bool
    ) -> (naviCase: NaviCase, adaptiveTh: Float, dhOverride: Float?) {

        let curPmResult = curPmResultBuffer.last!
        let naviResult = makeNaviResult(curPmResult: curPmResult, naviLast: naviRouteResultBuffer.last!)

        var adaptiveTh = baseThreshold

        // 링크 매칭 결과로 adaptiveTh / 케이스 조기결정
        guard let naviCases = evaluateNaviCases(curPmResult: curPmResult,
                                                naviResult: naviResult,
                                                travelingLinkDist: travelingLinkDist,
                                                shouldCheckEndOfMap: shouldCheckEndOfMap,
                                                dAvg: dAvg,
                                                adaptiveTh: &adaptiveTh) else {
            JupiterLogger.i(tag: "NavigationManager", message: "(decideCase2or3) : CASE_3 // recent landmark data unavailable (cannot evaluate landmark ratio)")
            return (.CASE_3, adaptiveTh, nil)
        }

        let lmCase = naviCases.landmarkCase
        let distCase = naviCases.distanceCase
        let naviCase: NaviCase = lmCase != .CASE_3 && distCase != .CASE_3 ? .CASE_2 : .CASE_3
        JupiterLogger.i(tag: "NavigationManager", message: "(decideCase2or3) : \(naviCase) // landmarkCase=\(lmCase), distanceCase=\(distCase), dAvg=\(dAvg), adaptiveTh=\(adaptiveTh) (CASE_3 if either signal is CASE_3)")
        return (naviCase, adaptiveTh, nil)
    }
    
    private func makeNaviResult(curPmResult: FineLocationTrackingOutput, naviLast: RoutingRoute) -> FineLocationTrackingOutput {
        var naviResult = curPmResult
        naviResult.x = naviLast.x
        naviResult.y = naviLast.y
        naviResult.absolute_heading = naviLast.heading
        return naviResult
    }

    private func evaluateNaviCases(
        curPmResult: FineLocationTrackingOutput,
        naviResult: FineLocationTrackingOutput,
        travelingLinkDist: Float,
        shouldCheckEndOfMap: Bool,
        dAvg: Float,
        adaptiveTh: inout Float
    ) -> (landmarkCase: NaviCase, distanceCase: NaviCase)? {
        var updatedAdaptiveTh = adaptiveTh
        var landmarkCase: NaviCase = .CASE_2
        var distanceCase: NaviCase = .CASE_2
        
        if let distCur = calDistWithRecentPeakLandmarks(fltResult: curPmResult),
           let distNavi = calDistWithRecentPeakLandmarks(fltResult: naviResult) {
            let ratio = distNavi / distCur
            let ratioTh: Float =  2.5
            if ratio > ratioTh {
                landmarkCase = .CASE_3
            } else {
                landmarkCase = .CASE_2
            }
            JupiterLogger.i(tag: "NavigationManager",
                            message: "(evaluateNaviCases) landmarkCase=\(landmarkCase) // ratio=\(ratio) (distCur=\(distCur), distNavi=\(distNavi)) vs ratioTh=\(ratioTh)")
        } else {
            JupiterLogger.i(tag: "NavigationManager", message: "(evaluateNaviCases) landmark evaluation skipped // no recent landmark data")
            return nil
        }

        let linkScale: Float = shouldCheckEndOfMap ? 0.8 : 0.5
        updatedAdaptiveTh = max(updatedAdaptiveTh, travelingLinkDist * linkScale)

        if dAvg > updatedAdaptiveTh {
            distanceCase = .CASE_3
        } else {
            distanceCase = .CASE_2
        }

        JupiterLogger.i(tag: "NavigationManager",
                        message: "(evaluateNaviCases) distanceCase=\(distanceCase) // dAvg=\(dAvg) vs adaptiveTh=\(updatedAdaptiveTh) (base=\(adaptiveTh), travelingLinkDist=\(travelingLinkDist), shouldCheckEndOfMap=\(shouldCheckEndOfMap), linkScale=\(linkScale))")
        return (landmarkCase, distanceCase)
    }
    
    private func calDistWithRecentPeakLandmarks(fltResult: FineLocationTrackingOutput) -> Float? {
        guard let recentLandmarkPeaks = recentLandmarkPeaks else { return nil }
        var distSum: Float = 0
        for lm in recentLandmarkPeaks {
            let diffX = fltResult.x - Float(lm.x)
            let diffY = fltResult.y - Float(lm.y)
            
            distSum += sqrt(diffX*diffX + diffY*diffY)
        }
        
        return distSum
    }
    
    // MARK: - Bridging
    public func setLSEAppName(name: String) {
        jupiterManager?.setLSEAppName(name: name)
    }
    
    public func getMatchedLevelId(key: String) -> Int? {
        return jupiterManager?.getMatchedLevelId(key: key)
    }
    
    public func getBuildingsData() -> [BuildingData]? {
        return jupiterManager?.getBuildingsData()
    }

    public func getBuildingName(buildingId: Int) -> String? {
        return jupiterManager?.getBuildingName(buildingId: buildingId)
    }

    public func getBuildingId(buildingName: String) -> Int? {
        return jupiterManager?.getBuildingId(buildingName: buildingName)
    }

    public func getLevelName(levelId: Int) -> String? {
        return jupiterManager?.getLevelName(levelId: levelId)
    }

    public func getLevelId(sectorId: Int, buildingName: String, levelName: String) -> Int? {
        return jupiterManager?.getLevelId(sectorId: sectorId, buildingName: buildingName, levelName: levelName)
    }
    
    public func getDefaultPosition(sectorId: Int) -> DefaultPosition? {
        return jupiterManager?.getDefaultPosition(sectorId: sectorId)
    }
    
    public func getWGS84Transform(sectorId: Int) -> WGS84Transform? {
        return jupiterManager?.getWGS84Transform(sectorId: sectorId)
    }
}
