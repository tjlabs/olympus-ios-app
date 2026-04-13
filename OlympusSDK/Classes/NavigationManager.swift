import Foundation
import TJLabsCommon
import TJLabsResource

public protocol NavigationManagerDelegate: AnyObject {
    func onJupiterSuccess(_ isSuccess: Bool, _ code: JupiterErrorCode?)
    func onJupiterResult(_ result: JupiterResult)
    func onJupiterReport(_ code: JupiterServiceCode, _ msg: String)
    func isJupiterInOutStateChanged(_ state: InOutState)
    
    func isUserGuidanceOut()
    func isNavigationRouteChanged(_ routes: [(String, String, Int, Float, Float)])
    func isNavigationRouteFailed()
    func isWaypointChanged(_ waypoints: [[Double]])
}

public class NavigationManager: JupiterManagerDelegate, RoutingManagerDelegate {
    public func onRfdResult(receivedForce: TJLabsCommon.ReceivedForce) {
        // TODO
    }
    
    public func onEntering(userVelocity: UserVelocity, peakIndex: Int?, key: String, level_id: Int) {
        if let origin = routingManager?.getEntRoutingOrigin(key: key, level_id: level_id), let to = self.naviDestination {
            let from: RoutingStart = RoutingStart(level_id: origin.level_id, x: origin.x, y: origin.y, absolute_heading: origin.absolute_heading)
            routingManager?.requestRouting(start: from, end: to, completion: { [self] routingResult in
                if let result = routingResult {
                    JupiterLogger.i(tag: "NavigationManager", message: "(requestRouting) routingResult= \(result)")
                    routingManager?.setRoutingRoutes(routes: result.routes)
                } else {
                    JupiterLogger.i(tag: "NavigationManager", message: "(requestRouting) routingResult is nil")
                }
            })
        }
    }
    
    public func provideTrackingCorrection(mode: TJLabsCommon.UserMode,
                                          userVelocity: TJLabsCommon.UserVelocity,
                                          peakIndex: Int?,
                                          recentLandmarkPeaks: [PeakData]?,
                                          travelingLinkDist: Float,
                                          indexForEdit: Int,
                                          curPmResult: FineLocationTrackingOutput?) -> (NaviCorrectionInfo, [StackEditInfo])? {
        if !hasNaviRoute { return nil }
        if naviRouteChanged, let curPmResult = curPmResult { routingManager?.setStartPointInNaviRoute(xyh: [curPmResult.x, curPmResult.y, curPmResult.absolute_heading]) }
        guard let jupiterManager = self.jupiterManager else { return nil }
        guard let naviRouteResult = calcNaviRouteResult(uvd: userVelocity, jupiterResult: jupiterResult) else { return nil }
        self.curRoutingRouteResult = naviRouteResult
        stackManager.stackIndexAndNaviRouteResult(naviRouteResult: naviRouteResult, peakIndex: peakIndex, uvd: userVelocity)
        let indexAndNaviRouteResultBuffer = stackManager.getIndexAndNaviRouteResultBuffer(size: 10)
        let naviRouteResultBuffer = indexAndNaviRouteResultBuffer.map { $0.1 }
        guard let curPmResultBuffer = jupiterManager.getCurPmResultBuffer(size: 10) else { return nil }
        guard let followingResult = isFollowingNavigationRoute(curNaviCase: curNaviCase, travelingLinkDist: travelingLinkDist, naviRouteResultBuffer: naviRouteResultBuffer, curPmResultBuffer: curPmResultBuffer) else { return nil }
        
        let estimatedNaviCase = followingResult.naviCase
        curNaviCase = estimatedNaviCase
        if curNaviCase == .CASE_3 && !guidanceOutReported {
            guidanceOutReported = true
            self.isUserGuidanceOut()
        } else if curNaviCase == .CASE_2 {
            let diffSectionCorrIndex = userVelocity.index - sectionCorrectionIndex
            if diffSectionCorrIndex < 10 {
                JupiterLogger.i(tag: "NavigationManager", message: "(onTracking) isFollowingNavigationRoute: section correction is applied at \(sectionCorrectionIndex) index (curIndex = \(userVelocity.index))")
                return nil
            }
            let curNaviSection = naviRouteResult.section
            let curPmResult = curPmResultBuffer[curPmResultBuffer.count-1]
            guard let curPmSection = routingManager?.findSectionContaining(x: curPmResult.x, y: curPmResult.y) else {
                return nil
            }
            if curNaviSection == curPmSection {
                JupiterLogger.i(tag: "NavigationManager", message: "(onTracking) isFollowingNavigationRoute: findSectionContaining // jupiter and navi result are in same section \(curPmSection)")
                routingManager?.updateCurRoutePos(curSection: curPmSection, curResult: curPmResult)
                sectionCorrectionIndex = userVelocity.index
            }
        }
        
        JupiterLogger.i(tag: "NavigationManager", message: "(onTracking) isFollowingNavigationRoute: followingResult= \(followingResult) // curNaviCase= \(curNaviCase)")
        self.resultMode = determineIndoorResultMode(resultMode: resultMode, naviCase: curNaviCase)
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
    
    // MARK: - Jupiter
    public func onJupiterSuccess(_ isSuccess: Bool, _ code: JupiterErrorCode?) {
        if isSuccess, let blData = jupiterManager?.getBuildingsData() {
            JupiterLogger.i(tag: "NavigationManager", message: "onJupiterSuccess : buildingsData= \(blData)")
            routingManager?.setBuildingsData(buildingsData: blData)
        }
        delegate?.onJupiterSuccess(isSuccess, code)
    }
    
    public func onJupiterResult(_ result: JupiterResult) {
        self.jupiterResult = result
        if resultMode == .NAVI {
            var copied = result
            if let routingRoute = self.curRoutingRouteResult {
                copied.building_name = routingRoute.building
                copied.level_name = routingRoute.level
                copied.jupiter_pos.x = routingRoute.x
                copied.jupiter_pos.y = routingRoute.y
                copied.jupiter_pos.heading = routingRoute.heading
            }
            delegate?.onJupiterResult(copied)
        } else {
            delegate?.onJupiterResult(result)
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
            routingManager?.setStartPointInNaviRoute(xyh: xyh)
        }
    }
    
    // MARK: - Navigation
    func isUserGuidanceOut() {
        JupiterLogger.i(tag: "NavigationManager", message: "(isUserGuidanceOut) user guidance out")
        delegate?.isUserGuidanceOut()
        hasNaviRoute = false
        routingManager?.clearRoutes()
        guard let curResult = self.jupiterResult else { return }
        guard let curLevelId = routingManager?.getLevelIdWithName(levelName: curResult.level_name) else { return }
        let from = RoutingStart(level_id: curLevelId, x: Int(curResult.jupiter_pos.x), y: Int(curResult.jupiter_pos.y), absolute_heading: Int(curResult.jupiter_pos.heading))
        guard let to = self.naviDestination else { return }
        routingManager?.requestRouting(start: from, end: to, completion: { [self] routingResult in
            if let result = routingResult {
                JupiterLogger.i(tag: "NavigationManager", message: "(requestRouting) routingResult= \(result)")
                routingManager?.setRoutingRoutes(routes: result.routes)
            } else {
                JupiterLogger.i(tag: "NavigationManager", message: "(requestRouting) routingResult is nil")
            }
        })
    }
    
    func isNavigationRouteChanged() {
        if !hasNaviRoute {
            hasNaviRoute = true
            if let naviRouteForDisplay = routingManager?.getNaviRoutesForDisplay() {
                JupiterLogger.i(tag: "NavigationManager", message: "(getNaviRoutesForDisplay) naviRouteForDisplay= \(naviRouteForDisplay)")
                JupiterLogger.i(tag: "NavigationManager", message: "(isNavigationRouteChanged) navigation route changed")
                delegate?.isNavigationRouteChanged(naviRouteForDisplay)
                naviRouteChanged = true
                curNaviCase = .CASE_1
            } else {
                JupiterLogger.i(tag: "NavigationManager", message: "(getNaviRoutesForDisplay) naviRouteForDisplay is empty")
            }
        }
    }
    
    func isNavigationRouteFailed() {
        JupiterLogger.i(tag: "NavigationManager", message: "(isNavigationRouteFailed) navigation route failed")
        delegate?.isNavigationRouteFailed()
    }
    
    func isWaypointsChanged() {
        if let waypoints = routingManager?.getNavigationWaypoints() {
            JupiterLogger.i(tag: "NavigationManager", message: "(isWaypointsChanged) waypoints= \(waypoints)")
            delegate?.isWaypointChanged(waypoints)
        }
    }
    
    private var region: String = ""
    private var id: String = ""
    private var sectorId: Int = 0
    public weak var delegate: NavigationManagerDelegate?
    
    // MARK: - Classes
    var jupiterManager: JupiterManager?
    var routingManager: RoutingManager?
    let stackManager = NavigationStackManager()
    
    // MARK: - Navigation
    private var naviMode: Bool = false
    private var naviDestination: Point?
    var curRoutingRouteResult: RoutingRoute?
    var guidanceOutReported: Bool = false
    
    // MARK: - Routing
    private var hasNaviRoute: Bool = false
    private var naviRouteChanged: Bool = false
    private var feedbackIndex: Int = 0
    private var feedbackCount: Int = 0
    private var curNaviCase: NaviCase = .NONE
    private var sectionCorrectionIndex: Int = 0
    
    // MARK: - Variables
    private var jupiterResult: JupiterResult?
    private var trackingIndex: Int = 0
    var resultMode: IndoorResultMode = .NONE
    private var jupiterPhase: JupiterPhase = .NONE
    private var recentLandmarkPeaks: [PeakData]?
    
    // MARK: - init & deinit
    public init(id: String) {
        self.id = id
        self.jupiterManager = JupiterManager(id: id)
        self.jupiterManager?.delegate = self
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
    
    public func startService(region: String = JupiterRegion.KOREA.rawValue, sectorId: Int, mode: UserMode, debugOption: Bool = false) {
        NavigationNetworkConstants.setServerURL(region: region)
        self.routingManager = RoutingManager(id: id, sectorId: sectorId)
        self.routingManager?.delegate = self
        jupiterManager?.startJupiter(region: region, sectorId: sectorId, mode: mode, debugOption: debugOption)
    }
    
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
        guard let jupiterDebugResult = jupiterManager?.getJupiterDebugResult() else { return nil }
        return jupiterDebugResult
    }
    
    func requestRouting(start: RoutingStart, end: Point, waypoints: [Point] = [], completion: @escaping (RoutingResult?) -> Void) {
        routingManager?.requestRouting(start: start, end: end, waypoints: waypoints, completion: completion)
    }
    
    func requestRouting(end: Point, waypoints: [Point] = [], completion: @escaping (RoutingResult?) -> Void) {
//        routingManager?.requestRouting(end: end, waypoints: waypoints, completion: completion)
    }
    
    //MARK: - Simulation Mode
    public func setSimulationMode(flag: Bool, rfdFileName: String, uvdFileName: String, eventFileName: String) {
        jupiterManager?.setSimulationMode(flag: flag, rfdFileName: rfdFileName, uvdFileName: uvdFileName, eventFileName: eventFileName)
    }
    
    public func setSimulationModeLegacy(flag: Bool, bleFileName: String, sensorFileName: String) {
        jupiterManager?.setSimulationModeLegacy(flag: flag, bleFileName: bleFileName, sensorFileName: sensorFileName)
    }
    
    public func saveFilesForSimulation(completion: @escaping (Bool) -> Void) {
        jupiterManager?.saveFilesForSimulation(completion: completion)
    }
    
    // MARK: - Private
    private func calcNaviRouteResult(uvd: UserVelocity, jupiterResult: JupiterResult?) -> RoutingRoute? {
        guard let jupiterResult = jupiterResult else { return nil }
        if uvd.index <= trackingIndex { return nil }
        return routingManager?.calcNaviRouteResult(uvd: uvd, jupiterResult: jupiterResult)
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

        if curNaviCase == .CASE_3 { return (.CASE_3, 100, 100) }
        guard naviRouteResultBuffer.count == curPmResultBuffer.count else { return nil }
        if naviRouteResultBuffer.count < 10 { return (.INIT, 0, 0) }

        let DLOSS_THRESHOLD_15: Float = 15
        let DLOSS_THRESHOLD_45: Float = 45
        let DHLOSS_THRESHOLD_45: Float = 45

        // 1) 거리/헤딩 평균 손실 계산
        let (dAvg, dhAvg) = computeLossAverages(navi: naviRouteResultBuffer, pm: curPmResultBuffer)

        // 2) 빠른 케이스 결정
        if dAvg <= DLOSS_THRESHOLD_15 {
            return (.CASE_1, dAvg, dhAvg)
        }

        if dhAvg > DHLOSS_THRESHOLD_45 {
            JupiterLogger.i(tag: "NavigationManager", message: "(isFollowingNavigationRoute) : CASE_3 // pos & heading error")
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
            JupiterLogger.i(tag: "NavigationManager", message: "(isFollowingNavigationRoute) : CASE_2 // only pos error jupiter is advanced")
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

        JupiterLogger.i(tag: "NavigationManager", message: "(isFollowingNavigationRoute) : CASE_2 or 3 // dSumAvg= \(dAvg)")
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

        for i in 0..<count {
            let dx = navi[i].x - pm[i].x
            let dy = navi[i].y - pm[i].y
            dSum += hypotf(dx, dy)

            dhSum += angleDiffDeg(navi[i].heading, pm[i].absolute_heading)
        }

        return (dSum / Float(count), dhSum / Float(count))
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
                                                adaptiveTh: &adaptiveTh) else { return (.CASE_3, adaptiveTh, nil) }
        
        let lmCase = naviCases.landmarkCase
        let distCase = naviCases.distanceCase
        let naviCase: NaviCase = lmCase != .CASE_3 && distCase != .CASE_3 ? .CASE_2 : .CASE_3
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
            JupiterLogger.i(tag: "NavigationManager",
                            message: "isFollowingNavigationRoute: distWithCurPmResult= \(distCur), distWithNaviResult= \(distNavi) // ratio= \(ratio)")
            let ratioTh: Float =  2.5
            if ratio > ratioTh {
                landmarkCase = .CASE_3
            } else {
                landmarkCase = .CASE_2
            }
        } else {
            return nil
        }

        JupiterLogger.i(tag: "NavigationManager", message: "isFollowingNavigationRoute: shouldCheckEndOfMap= \(shouldCheckEndOfMap)")
        if (shouldCheckEndOfMap) {
            updatedAdaptiveTh = max(updatedAdaptiveTh, travelingLinkDist * 0.8)
        } else {
            updatedAdaptiveTh = max(updatedAdaptiveTh, travelingLinkDist * 0.5)
        }
        JupiterLogger.i(tag: "NavigationManager", message: "isFollowingNavigationRoute: adaptive_th= \(updatedAdaptiveTh)")
        
        if dAvg > updatedAdaptiveTh {
            distanceCase = .CASE_3
        } else {
            distanceCase = .CASE_2
        }
        
        JupiterLogger.i(tag: "NavigationManager", message:"isFollowingNavigationRoute: travelingLinkDist : \(travelingLinkDist) // adaptive_th= \(updatedAdaptiveTh)")
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
