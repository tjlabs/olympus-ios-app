
import TJLabsResource

public struct NavigationResult {
    
}

enum IndoorResultMode {
    case NAVI, CALC, NONE
}

public struct Route: Codable {
    let origin: Origin
    let destination: Point
    let nodes: [RouteNode]
}

public struct RouteNode: Codable {
    let level_id: Int
    let x: Int
    let y: Int
    let number: Int
    let out_heading: Int?
}

struct DirectionsResponse: Codable {
    let routes: [Route]
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
    let request_type: String
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
    public let routes: [Route]
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
