import Foundation
import TJLabsCommon
import TJLabsResource

protocol NavigationManagerDelegate: AnyObject {
    
    // 사용자가 경로를 이탈했다고 판단한 경우
    func isUserGuidanceOut()
    
    // 사용자의 navigation route가 변경된 경우
    func isNavigationRouteChanged()
    
    func isNavigationRouteFailed()
    
    func isWaypointsChanged()
}

class NavigationManager {
    
    private var id: String = ""
    private var sectorId: Int = 0
    
    var buildingsAndLevelsMap = [String: [String]]()
    var buildingIdMap = [String: Int]()
    var buildingNameMap = [Int: String]()
    var levelIdMap = [String: Int]()
    var levelNameMap = [Int: String]()
    var levelToBuildingIdMap = [Int: Int]()
    
    private var routes = [NavigationRoute]()
    private var routeNodeData = [Int: NodeData]()
    private var routeSectionData = [Int: SectionRange]()
    private var routeIndex: Int?
    private var curRoute: NavigationRoute?
    private var isRequesting: Bool = false
    
    private var routesForDisplay = [(String, String, Int, Float, Float)]()
    private var waypointsForDisplay = [[Double]]()
    
    weak var delegate: NavigationManagerDelegate?
    
    // MARK: - init & deinit
    init(id: String, sectorId: Int) {
        self.id = id
        self.sectorId = sectorId
    }
    
    deinit { }
    
    func setBuildingsData(buildingsData: [BuildingOutput]) {
        let buildingLevelData = makeBuildingLevelInfo(buildingsData: buildingsData)
        buildingsAndLevelsMap = buildingLevelData
        makeBuildingIdMap(buildingsData: buildingsData)
        makeLevelIdMap(buildingsData: buildingsData)
    }

    func makeBuildingIdMap(buildingsData: [BuildingOutput]) {
        buildingIdMap.removeAll()
        buildingNameMap.removeAll()
        
        for b in buildingsData {
            buildingIdMap[b.name] = b.id
            buildingNameMap[b.id] = b.name
        }
    }
    
    func makeLevelIdMap(buildingsData: [BuildingOutput]) {
        levelIdMap.removeAll()
        levelNameMap.removeAll()
        levelToBuildingIdMap.removeAll()
        
        let buildings = buildingsData
        for b in buildings {
            let levels = b.levels
            for l in levels {
                levelIdMap[l.name] = l.id
                levelNameMap[l.id] = l.name
                levelToBuildingIdMap[l.id] = b.id
            }
        }
    }
    
    func getBuildingIdWithName(buildingName: String) -> Int? {
        return buildingIdMap[buildingName]
    }
    
    func getBuildingNameWithId(building_id: Int) -> String? {
        return buildingNameMap[building_id]
    }
    
    func getBuildingIdHasLevelId(level_id: Int) -> Int? {
        return levelToBuildingIdMap[level_id]
    }
    
    func getLevelIdWithName(levelName: String) -> Int? {
        return self.levelIdMap[levelName]
    }
    
    func getLevelNameWithId(level_id: Int) -> String? {
        return levelNameMap[level_id]
    }
    
    private func makeBuildingLevelInfo(buildingsData: [BuildingOutput]) -> [String: [String]] {
        var infoBuildingLevel = [String: [String]]()
        for building in buildingsData {
            let buildingName = building.name
            for level in building.levels {
                let levelName = level.name
                if var levels = infoBuildingLevel[buildingName] {
                    levels.append(levelName)
                    infoBuildingLevel[buildingName] = levels.sorted(by: { lhs, rhs in
                        return compareFloorNames(lhs: lhs, rhs: rhs)
                    })
                } else {
                    let levels = [levelName]
                    infoBuildingLevel[buildingName] = levels
                }
            }
        }
        return infoBuildingLevel
    }
    
    private func compareFloorNames(lhs: String, rhs: String) -> Bool {
        func floorValue(_ floor: String) -> Int {
            if floor.starts(with: "B"), let number = Int(floor.dropFirst()) {
                return -number
            } else if floor.hasSuffix("F"), let number = Int(floor.dropLast()) {
                return number
            }
            return 0
        }
            
        return floorValue(lhs) > floorValue(rhs)
    }
    
    // MARK: - New with Server
    func requestRouting(start: RoutingStart, end: Point, waypoints: [Point] = [], completion: @escaping (RoutingResult?) -> Void) {
        let from: Origin = Origin(level_id: start.level_id, x: start.x, y: start.y, absolute_heading: start.absolute_heading)
        let to: Point = Point(level_id: end.level_id, x: end.x, y: end.y)
        
        let currentTime = TJLabsUtilFunctions.shared.getCurrentTimeInMilliseconds(as: .int) as! Int
        let input = DirectionsRequest(tenant_user_name: self.id, mobile_time: currentTime, origin: from, destination: to, waypoints: waypoints)
        let successRange = 200..<300
        JupiterNetworkManager.shared.postCalcDirs(url: JupiterNetworkConstants.getCalcDirsURL(), input: input, completion: { [self] statusCode, returnedString, inputDirs in
            if successRange.contains(statusCode)  {
                if let decoded = decodeCalcDirs(from: returnedString) {
                    completion(RoutingResult(code: statusCode, routes: decoded.routes))
                } else {
                    JupiterLogger.e(tag: "NavigationManager", message: "(requestRouting) : fail decoding")
                    completion(nil)
                }
            } else {
                JupiterLogger.e(tag: "NavigationManager", message: "(requestRouting) : \(statusCode) error")
                completion(nil)
            }
        })
    }
    
    func setRoutingRoutes(routes: [Route]) {
        if routes.isEmpty { return }
        let route = routes[0]
        
        var buildingOrder = [String]()
        var levelOrder = [String]()
        var nodeOrder = [Int]()
        var order = [[Float]]()
        
        let start = route.origin
        guard let start_building_id = getBuildingIdHasLevelId(level_id: start.level_id),
              let start_building_name = getBuildingNameWithId(building_id: start_building_id),
              let start_level_name = getLevelNameWithId(level_id: start.level_id) else { return }
        buildingOrder.append(start_building_name)
        levelOrder.append(start_level_name)
        nodeOrder.append(-1)
        let startCoord: [Float] = [Float(start.x), Float(start.y)]
        order.append(startCoord)
        
        for n in route.nodes {
            guard let node_building_id = getBuildingIdHasLevelId(level_id: n.level_id),
                  let node_building_name = getBuildingNameWithId(building_id: node_building_id),
                  let node_level_name = getLevelNameWithId(level_id: n.level_id) else { return }
            let key = "\(sectorId)_\(node_building_name)_\(node_level_name)"
            guard let nodeData = PathMatcher.shared.nodeData[key] else { return }
            guard let matchedNode = nodeData[n.number] else { return }
            if self.routeNodeData.isEmpty {
                self.routeNodeData = nodeData
            }
            
            let coords = matchedNode.coords
            if coords.count != 2 { continue }
            
            buildingOrder.append(node_building_name)
            levelOrder.append(node_level_name)
            nodeOrder.append(n.number)
            order.append(coords)
        }
        
        let end = route.destination
        guard let end_building_id = getBuildingIdHasLevelId(level_id: end.level_id),
              let end_building_name = getBuildingNameWithId(building_id: end_building_id),
              let end_level_name = getLevelNameWithId(level_id: end.level_id) else { return }
        buildingOrder.append(end_building_name)
        levelOrder.append(end_level_name)
        nodeOrder.append(-1)
        let endCoord: [Float] = [Float(end.x), Float(end.y)]
        order.append(endCoord)
        
        JupiterLogger.e(tag: "NavigationManager", message: "(requestRouting) start:\(start) -> end:\(end)")
        
        generateNavigationRoute(bOrder: buildingOrder, lOrder: levelOrder, nodeOrder: nodeOrder, coordOrder: order) // display
        generateNavigationRoute(bOrder: buildingOrder, lOrder: levelOrder, nodeOrder: nodeOrder, order: order)
        let sectionMap = makeSectionMap(routes: self.routes)
        self.routeSectionData = sectionMap
    }
    
    // MARK: - Previous
    func requestNavigationRoute(start: [Float], end: [Float], scenario: Int? = nil) {
        setNavigationRoute(start: start, end: end, scenario: scenario)
        setNavigationWaypoints()
        JupiterLogger.i(tag: "NavigationManager", message: "(requestNavigationRoute) start:\(start) -> end:\(end)")
    }
    
    func setNavigationRoute(start: [Float], end: [Float], scenario: Int?) {
        let building = "COEX"
        let level = "B2"
        
        let key = "\(sectorId)_\(building)_\(level)"
        guard let nodeData = PathMatcher.shared.nodeData[key] else { return }
        self.routeNodeData = nodeData
        var nums = [Int]()
        
        if let scenario = scenario {
            JupiterLogger.i(tag: "NavigationManager", message: "(setNavigationRoute) : scenario= \(scenario)")
            if scenario == 1 {
                nums = [68, 67, 45, 46, 2, 3]
            } else if scenario == 3 {
                nums = [23, 20, 2, 1, 29, 28, 53, 52, 43, 44, 38]
            } else if scenario == 4 {
                nums = [4, 2, 1, 29, 28, 70, 71, 77]
            }
        }
        
        var buildingOrder = [String]()
        var levelOrder = [String]()
        var nodeOrder = [Int]()
        var order = [[Float]]()
        
        buildingOrder.append(building)
        levelOrder.append(level)
        nodeOrder.append(-1)
        order.append(start)
        for n in nums {
            guard let matchedNode = nodeData[n] else { continue }
            let coords = matchedNode.coords
            if coords.count != 2 { continue }
            buildingOrder.append(building)
            levelOrder.append(level)
            nodeOrder.append(n)
            order.append(coords)
        }
        buildingOrder.append(building)
        levelOrder.append(level)
        nodeOrder.append(-1)
        order.append(end)
        
        generateNavigationRoute(bOrder: buildingOrder, lOrder: levelOrder, nodeOrder: nodeOrder, coordOrder: order) // display
        generateNavigationRoute(bOrder: buildingOrder, lOrder: levelOrder, nodeOrder: nodeOrder, order: order)
        let sectionMap = makeSectionMap(routes: self.routes)
        self.routeSectionData = sectionMap
    }
    
    func generateNavigationRoute(bOrder: [String], lOrder: [String], nodeOrder: [Int], order: [[Float]]) {
        // order: [[x,y], [x,y], ...]
        // Build a dense polyline by walking each segment with step=1.0 (same unit as x/y).
        // Output routes as [[x, y, headingDeg]] where headingDeg is 0~360 from +X axis (atan2(dy, dx)).
        guard order.count >= 2 else {
            delegate?.isNavigationRouteFailed()
            return
        }
        
        var sectionCount: Int = 1
        
        let step: Float = 1.0
        var denseNaviRoute = [NavigationRoute]()
        denseNaviRoute.reserveCapacity(order.count * 10)
        let rad2deg: Float = 180.0 / .pi
        
        let turnHeadingThreshold: Float = 1.0 // degrees
        let headingMatchThreshold: Float = 5.0 // degrees
        var curSectionRouteStart = 0
        
        for i in 0..<(order.count - 1) {
            let building = bOrder[i]
            let level = lOrder[i]
            
            let a = order[i]
            let b = order[i + 1]
            guard a.count >= 2, b.count >= 2 else { continue }
            
            let ax = a[0], ay = a[1]
            let bx = b[0], by = b[1]
            let dx = bx - ax
            let dy = by - ay
            let dist = sqrt(dx * dx + dy * dy)

            // If the segment is too small, just append the end point with previous heading if possible.
            if dist <= 1e-6 {
                let fallbackHeading: Float = denseNaviRoute.last?.heading ?? 0.0
                if denseNaviRoute.isEmpty {
                    let naviRoute = NavigationRoute(building: building, level: level, section: sectionCount, turnPoint: false, x: ax, y: ay, heading: fallbackHeading)
                    denseNaviRoute.append(naviRoute)
                }
                if let last = denseNaviRoute.last, last.x != bx || last.y != by {
                    let naviRoute = NavigationRoute(building: building, level: level, section: sectionCount, turnPoint: false, x: bx, y: by, heading: fallbackHeading)
                    denseNaviRoute.append(naviRoute)
                }
                continue
            }

            // Heading for this segment (degrees, normalized to 0~360).
            var headingDeg = atan2(dy, dx) * rad2deg
            if headingDeg < 0 { headingDeg += 360 }
            
            // Detect a turn at the shared waypoint between segments.
            // The previous segment's end point is already the last element in `denseNaviRoute`.
            if !denseNaviRoute.isEmpty {
                let prevHeading = denseNaviRoute[denseNaviRoute.count - 1].heading
                let dH = headingDelta(prevHeading, headingDeg)
                if dH > turnHeadingThreshold {
                    var last = denseNaviRoute[denseNaviRoute.count - 1]
                    last.turnPoint = true
                    denseNaviRoute[denseNaviRoute.count - 1] = last
                    
                    let curSectionNodeNum: Int = nodeOrder[i]
                    let sectionPassable = isSectionPassable(sectionHeading: prevHeading,
                                                            nodeNum: curSectionNodeNum,
                                                            headingThreshold: headingMatchThreshold)
                    JupiterLogger.i(tag: "NavigationManager", message: "(isSectionPassable) : [prevHeading:\(prevHeading), curSectionNodeNum:\(curSectionNodeNum), headingThreshold:\(headingMatchThreshold)] -> sectionPassable= \(sectionPassable)")
                    for idx in curSectionRouteStart..<denseNaviRoute.count {
                        var data = denseNaviRoute[idx]
                        data.passable = sectionPassable
                        denseNaviRoute[idx] = data
                    }
                    curSectionRouteStart = denseNaviRoute.count

                    sectionCount += 1
                }
            }

            let ux = dx / dist
            let uy = dy / dist

            // Always include the start point of the first segment.
            if denseNaviRoute.isEmpty {
                let naviRoute = NavigationRoute(building: building, level: level, section: sectionCount, turnPoint: false, x: ax, y: ay, heading: headingDeg)
                denseNaviRoute.append(naviRoute)
            }

            // Number of full `step` moves we can take.
            let n = Int(floor(dist / step))
            if n > 0 {
                // Start from 1 to avoid duplicating the segment start (already appended).
                for k in 1...n {
                    let px = ax + Float(k) * step * ux
                    let py = ay + Float(k) * step * uy
                    let naviRoute = NavigationRoute(building: building, level: level, section: sectionCount, turnPoint: false, x: px, y: py, heading: headingDeg)
                    denseNaviRoute.append(naviRoute)
                }
            }

            // Ensure we end exactly at the waypoint.
            if let last = denseNaviRoute.last, last.x != bx || last.y != by {
                let naviRoute = NavigationRoute(building: building, level: level, section: sectionCount, turnPoint: false, x: bx, y: by, heading: headingDeg)
                denseNaviRoute.append(naviRoute)
            } else {
                // If the last point is already the endpoint, keep its existing turnPoint flag and update heading.
                if var last = denseNaviRoute.last {
                    last.heading = headingDeg
                    denseNaviRoute[denseNaviRoute.count - 1] = last
                }
            }
            
            
        }
        
        if !denseNaviRoute.isEmpty {
            let lastHeading = denseNaviRoute[denseNaviRoute.count-1].heading
            let curSectionNodeNum = nodeOrder[nodeOrder.count-1]
            let sectionPassable = isSectionPassable(sectionHeading: lastHeading, nodeNum: curSectionNodeNum, headingThreshold: headingMatchThreshold)
            for idx in curSectionRouteStart..<denseNaviRoute.count {
                var data = denseNaviRoute[idx]
                data.passable = sectionPassable
                denseNaviRoute[idx] = data
            }
            
            var lastNaviRoute = denseNaviRoute[denseNaviRoute.count-1]
            lastNaviRoute.turnPoint = true
            denseNaviRoute[denseNaviRoute.count-1] = lastNaviRoute
        }
        
        self.routes = denseNaviRoute
        delegate?.isNavigationRouteChanged()
        
        for route in self.routes {
            JupiterLogger.i(tag: "NavigationManager", message: "(generateNavigationRoute) : [section:\(route.section), turPoint:\(route.turnPoint), x:\(route.x), y:\(route.y), h:\(route.heading), passable:\(route.passable)]")
        }
    }
    
    typealias XY = (x: Float, y: Float)
    typealias SectionRange = (start: XY, end: XY)
    func makeSectionMap(routes: [NavigationRoute]) -> [Int: SectionRange] {
        var map: [Int: SectionRange] = [:]
        guard let first = routes.first else { return map }

        var curSection = first.section
        var start: XY = (first.x, first.y)
        var end: XY = (first.x, first.y)

        for r in routes.dropFirst() {
            if r.section != curSection {
                // 섹션 종료 확정
                map[curSection] = (start: start, end: end)

                curSection = r.section
                start = (r.x, r.y)
                end = (r.x, r.y)
            } else {
                end = (r.x, r.y)
            }
        }

        map[curSection] = (start: start, end: end)
        return map
    }
    
    func findSectionContaining(x: Float, y: Float, threshold: Float = 1.0) -> Int? {
        func pointToSegmentDistance(
            p: (x: Float, y: Float),
            a: (x: Float, y: Float),
            b: (x: Float, y: Float)
        ) -> Float {

            let abx = b.x - a.x
            let aby = b.y - a.y
            let apx = p.x - a.x
            let apy = p.y - a.y

            let ab2 = abx*abx + aby*aby
            if ab2 == 0 {
                let dx = p.x - a.x
                let dy = p.y - a.y
                return sqrt(dx*dx + dy*dy)
            }

            var t = (apx*abx + apy*aby) / ab2
            t = max(0, min(1, t))

            let cx = a.x + t * abx
            let cy = a.y + t * aby

            let dx = p.x - cx
            let dy = p.y - cy

            return sqrt(dx*dx + dy*dy)
        }
        
        let p = (x: x, y: y)
        for (section, range) in routeSectionData {
            let a = range.start
            let b = range.end
            
            let dist = pointToSegmentDistance(p: p, a: a, b: b)
            if dist <= threshold {
                return section
            }
        }

        return nil
    }
    
    private func isSectionPassable(sectionHeading: Float, nodeNum: Int, headingThreshold: Float) -> Bool {
        guard let node = routeNodeData[nodeNum] else { return true }
        for dir in node.directions {
            if (dir.is_end && headingDelta(sectionHeading, dir.heading) <= headingThreshold) {
                return false
            }
        }
        return true
    }
    
    func getNaviRoutes() -> [NavigationRoute] {
        return self.routes
    }
    
    func generateNavigationRoute(bOrder: [String], lOrder: [String], nodeOrder: [Int], coordOrder: [[Float]]) {
        if bOrder.count != lOrder.count || lOrder.count != nodeOrder.count || nodeOrder.count != coordOrder.count { return }
        
        for i in 0..<bOrder.count {
            let route = (bOrder[i], lOrder[i], nodeOrder[i], coordOrder[i][0], coordOrder[i][1])
            self.routesForDisplay.append(route)
        }
    }
    
    func getNaviRoutesForDisplay() -> [(String, String, Int, Float, Float)] {
        return self.routesForDisplay
    }
    
    func setStartPointInNaviRoute(fltResult: FineLocationTrackingOutput) {
        let resultX = fltResult.x
        let resultY = fltResult.y
        let resultH = fltResult.absolute_heading // 0 ~ 360도

        var matchedIndex: Int = -1
        var bestDist: Float = .greatestFiniteMagnitude

        let maxPosDiff: Float = 2.0
        let maxHeadingDiff: Float = 46.0

        for (index, route) in routes.enumerated() {
            let rx = route.x
            let ry = route.y
            let rh = route.heading

            let dx = rx - resultX
            let dy = ry - resultY
            let dist = sqrt(dx * dx + dy * dy)

            guard dist < maxPosDiff else { continue }
            let hDiff = headingDelta(resultH, rh)
            guard hDiff <= maxHeadingDiff else { continue }

            if dist < bestDist {
                bestDist = dist
                matchedIndex = index
            }
        }
        guard matchedIndex >= 0 else {
            delegate?.isUserGuidanceOut()
            return
        }
        
        self.routeIndex = matchedIndex
        self.curRoute = self.routes[matchedIndex]
        JupiterLogger.i(tag: "NavigationManager", message: "(setStartPointInNaviRoute) : started at \(matchedIndex) in routes // route= \(routes[matchedIndex])")
    }
    
    func setNavigationWaypoints() {
//        let waypoints: [[Double]] = [
//            [861, 2014],
//            [806, 2081],
//            [642, 1999],
//            [560, 2029],
//            [560, 2243],
//            [765, 2335]
//        ]
        
        let waypoints: [[Double]] = [
            [1257, 689],
            [1333, 529],
            [1003, 447],
            [925, 810],
            [644, 1396],
            [315, 1233]
        ]
        self.waypointsForDisplay = waypoints
        delegate?.isWaypointsChanged()
    }
    
    func getNavigationWaypoints() -> [[Double]] {
        return self.waypointsForDisplay
    }
    
    func updateCurRoutePos(curSection: Int, curResult: FineLocationTrackingOutput) {
        guard let _ = curRoute else { return }
        guard let _ = routeIndex else { return }
        
        var minDist: Float = .greatestFiniteMagnitude
        var closestRoute: NavigationRoute?
        
        for route in routes {
            if route.section != curSection {
                continue
            }
            
            let diffX = route.x - curResult.x
            let diffY = route.y - curResult.y
            
            let dist = sqrt(diffX * diffX + diffY * diffY)
            
            if dist < minDist {
                minDist = dist
                closestRoute = route
            }
        }
        
        if let closestRoute = closestRoute {
            self.curRoute = closestRoute
            JupiterLogger.i(tag: "NavigationManager", message: "(updateCurRoutePos) : curRoute is updated [x:\(closestRoute.x), y:\(closestRoute.y)] in section \(curSection)")
        }
    }
    
    func calcNaviRouteResult(uvd: UserVelocity, curResult: FineLocationTrackingOutput) -> NavigationRoute? {
        guard let curRoute = curRoute else { return nil }
        
        let headingInRadian = TJLabsUtilFunctions.shared.degree2radian(degree: Double(curResult.absolute_heading))
        let dx = Float(uvd.length*cos(headingInRadian))
        let dy = Float(uvd.length*sin(headingInRadian))
        
        let newX = curRoute.x + dx
        let newY = curRoute.y + dy
        let newH = curResult.absolute_heading
        JupiterLogger.i(tag: "NavigationManager", message: "(calcNaviRouteResult) : index= \(curResult.index), section= \(curRoute.section), new= [\(newX),\(newY),\(newH)]")
        
        var matchedRoute: NavigationRoute?
        guard let idx = routeIndex else { return nil }

        var bestDist: Float = .greatestFiniteMagnitude
        var matchedIndex: Int = -1
        let maxHeadingDiff: Float = 46.0

        for (index, route) in routes.enumerated() {
            guard index >= idx else { continue }
            let diffSection = route.section - curRoute.section
            if diffSection > 1 || diffSection < 0 {
                continue
            }
            
            let dxr = route.x - newX
            let dyr = route.y - newY
            let dist = sqrt(dxr * dxr + dyr * dyr)
            
            let hDiff = headingDelta(newH, route.heading)
            JupiterLogger.i(tag: "NavigationManager", message: "(calcNaviRouteResult) : compare route= [\(route.x),\(route.y),\(route.heading)] // dist=\(dist) // hDiff=\(hDiff)")
            
            guard hDiff <= maxHeadingDiff else { continue }

            if dist < bestDist {
                bestDist = dist
                matchedRoute = route
                matchedIndex = index
            }
        }
        JupiterLogger.i(tag: "NavigationManager", message: "(calcNaviRouteResult) : index= \(curResult.index), section= \(matchedRoute?.section), matchedRoute= [\(matchedRoute?.x),\(matchedRoute?.y),\(matchedRoute?.heading)]")
        if let matchedRoute = matchedRoute {
            self.curRoute = matchedRoute
            if !matchedRoute.turnPoint {
                if matchedRoute.heading == 90 || matchedRoute.heading == 270 {
                    // X LIMIT
                    self.curRoute?.y = newY
                } else if matchedRoute.heading == 0 || matchedRoute.heading == 180 {
                    // Y LIMIT
                    self.curRoute?.x = newX
                }
            }
        } else {
//            self.curRoute?.heading = newH
        }
        JupiterLogger.i(tag: "NavigationManager", message: "(calcNaviRouteResult) : index= \(curResult.index), section= \(self.curRoute?.section), route= [\(self.curRoute?.x),\(self.curRoute?.y),\(self.curRoute?.heading)]")
        return self.curRoute
    }
    
    func headingDelta(_ a: Float, _ b: Float) -> Float {
        var d = a - b
        d = fmod(d + 540.0, 360.0) - 180.0
        return abs(d)
    }
    
    // MARK: - Decoding
    private func decodeCalcDirs(from jsonString: String) -> DirectionsResponse? {
        guard let data = jsonString.data(using: .utf8) else {
            JupiterLogger.e(tag: "NavigationManager", message: "utf8 → data fail")
            return nil
        }

        let decoder = JSONDecoder()
        do {
            let result = try decoder.decode(DirectionsResponse.self, from: data)
            return result
        } catch {
            JupiterLogger.e(tag: "NavigationManager", message: "decode DirectionsResponse fail: \(error)")
            return nil
        }
    }
}
