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

    private var routes = [NavigationRoute]()
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
//        let ids: [Int] = [24, 23, 22, 6, 7, 23, 21, 301, 8, 4, 2, 1, 30, 29,
//                          34, 40, 54, 55, 59, 63, 68, 72, 80, 82, 84, 87]
        
//        let ids: [Int] = [24, 23, 22, 6, 7, 23, 21, 301, 8, 4, 2, 1, 30, 29,
//                          34, 40, 54, 53, 44, 45, 39]
        
        // Ent4 Following Well
//        let ids: [Int] = [4, 2, 1, 30, 29, 34, 40, 54, 53, 44, 45, 39]
        
        // Ent4 NotFollowing
        var ids: [Int] = [4, 2, 1, 30, 29, 34, 40, 54, 55, 59, 63, 68, 72, 80, 82, 84, 87]
        
        if let scenario = scenario {
            JupiterLogger.i(tag: "NavigationManager", message: "(setNavigationRoute) : scenario= \(scenario)")
            if scenario == 1 {
                ids = [69, 68,46,47,2,3]
            } else if scenario == 3 {
                ids = [24, 21,2 ,1,30, 29, 54, 53, 44,45,39]
            } else if scenario == 4 {
                ids = [4, 2, 1, 30, 29, 71, 72, 80]
            }
        }
        
        var buildingOrder = [String]()
        var levelOrder = [String]()
        var nodeOrder = [Int]()
        var sectionOrder = [Int]()
        var order = [[Float]]()
        
        buildingOrder.append(building)
        levelOrder.append(level)
        nodeOrder.append(-1)
        order.append(start)
        for id in ids {
            guard let matchedNode = nodeData[id] else { continue }
            let coords = matchedNode.coords
            if coords.count != 2 { continue }
            buildingOrder.append(building)
            levelOrder.append(level)
            nodeOrder.append(id)
            order.append(coords)
        }
        buildingOrder.append(building)
        levelOrder.append(level)
        nodeOrder.append(-1)
        order.append(end)
        
        generateNavigationRoute(bOrder: buildingOrder, lOrder: levelOrder, nodeOrder: nodeOrder, coordOrder: order)
        generateNavigationRoute(bOrder: buildingOrder, lOrder: levelOrder, order: order)
    }
    
    func generateNavigationRoute(bOrder: [String], lOrder: [String], order: [[Float]]) {
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

        var lastNaviRoute = denseNaviRoute[denseNaviRoute.count-1]
        lastNaviRoute.turnPoint = true
        denseNaviRoute[denseNaviRoute.count-1] = lastNaviRoute
        
        self.routes = denseNaviRoute
        delegate?.isNavigationRouteChanged()
        
        for route in self.routes {
            JupiterLogger.i(tag: "NavigationManager", message: "(generateNavigationRoute) : [section:\(route.section), turPoint:\(route.turnPoint), x:\(route.x), y:\(route.y), h:\(route.heading)]")
        }
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
//        JupiterLogger.i(tag: "NavigationManager", message: "(setStartPointInNaviRoute) : sections= \(routes.map{$0.section})")
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
        JupiterLogger.i(tag: "NavigationManager", message: "(calcNaviRouteResult) : index= \(curResult.index), section= \(matchedRoute?.section),matchedRoute= [\(matchedRoute?.x),\(matchedRoute?.y),\(matchedRoute?.heading)]")
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
            self.curRoute?.heading = newH
        }
        JupiterLogger.i(tag: "NavigationManager", message: "(calcNaviRouteResult) : index= \(curResult.index), section= \(self.curRoute?.section), route= [\(self.curRoute?.x),\(self.curRoute?.y),\(self.curRoute?.heading)]")
        return self.curRoute
    }
    
    func headingDelta(_ a: Float, _ b: Float) -> Float {
        var d = a - b
        d = fmod(d + 540.0, 360.0) - 180.0
        return abs(d)
    }
}
