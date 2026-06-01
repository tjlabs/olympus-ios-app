
import TJLabsResource

public struct NavigationResult {
    
}

public enum NavigationRoutePointType: String, Codable {
    case ORIGIN
    case NORMAL
    case VERTICAL
    case DESTINATION
}

public struct NavigationRoutePoint: Codable {
    public let pointId: Int
    public let x: Float
    public let y: Float
    public let pointType: NavigationRoutePointType

    public init(pointId: Int, x: Float, y: Float, pointType: NavigationRoutePointType) {
        self.pointId = pointId
        self.x = x
        self.y = y
        self.pointType = pointType
    }
}

public struct NavigationLevelRoute: Codable {
    public let levelId: Int
    public let points: [NavigationRoutePoint]

    public init(levelId: Int, points: [NavigationRoutePoint]) {
        self.levelId = levelId
        self.points = points
    }
}

enum IndoorResultMode {
    case NAVI, CALC, NONE
}

public struct Route: Codable {
    let origin: Origin
    let destination: Point
    let waypoints: [Point]
    let segments: [RouteSegment]
//    let nodes: [RouteNode]
    let distance: Int
}

//public struct RouteNode: Codable {
//    let level_id: Int
//    let x: Int
//    let y: Int
//    let number: Int
//    let out_heading: Int?
//}

struct DirectionsResponse: Codable {
    let request_id: String
    let origin: Origin
    let destination: Point
    let waypoints: [Point]
    let segments: [RouteSegment]
    let distance: Int
}

public struct RouteSegment: Codable {
    let level_id :Int
    let guides: [RouteGuide]
    let distance: Int
}

public struct RouteGuide: Codable {
    let x: Int
    let y: Int
    let out_heading: Int
}

public struct Point: Codable {
    public let level_id: Int
    public let x: Int
    public let y: Int
    
    public init(level_id: Int, x: Int, y: Int) {
        self.level_id = level_id
        self.x = x
        self.y = y
    }
}

struct Origin: Codable {
    let level_id: Int
    let x: Int
    let y: Int
    let absolute_heading: Int
}

struct DirectionsRequest: Encodable {
    let tenant_user_name: String
    let mobile_time: Int
    let request_type: DirRqType
    let is_vehicle: Bool
    let origin: Origin
    let destination: Point
    let waypoints: [Point]
}

enum DirRqType: String, Codable {
    case INITIAL = "initial"
    case REROUTE = "reroute"
    case DEST_CHANGED = "destination_changed"
    case WP_CHANGED = "waypoint_changed"
    case RESUME = "resume"
}

public struct RoutingStart: Codable {
    public let level_id: Int
    public let x: Int
    public let y: Int
    public var absolute_heading: Int
    
    public init(level_id: Int, x: Int, y: Int, absolute_heading: Int) {
        self.level_id = level_id
        self.x = x
        self.y = y
        self.absolute_heading = absolute_heading
    }
}

public struct RoutingResult: Codable {
    public let code: Int
    public let request_id: String
    public let route: Route
}

public enum NavigationRouteFailureReason: String, Codable {
    case serverResponse = "server_response"
    case tooClose = "too_close"
}

struct NaviDestination: Codable {
    let building: String
    let level: String
    let level_id: Int
    let category: TJLabsResource.Category
    let name: String
    let x: Float
    let y: Float
}
