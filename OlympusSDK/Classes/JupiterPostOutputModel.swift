
import Foundation

// MARK: - FineLocationTracking
public struct FineLocationTrackingOutput: Codable, Equatable {
    public var mobile_time: Int
    public var index: Int
    public var building_name: String
    public var level_name: String
    public var scc: Float
    public var x: Float
    public var y: Float
    public var absolute_heading: Float
}

public struct Route: Codable {
    let origin: Point
    let destination: Point
    let nodes: [RouteNode]
}

public struct RouteNode: Codable {
    let level_id: Int
    let x: Int
    let y: Int
    let number: Int
    let out_heading: Int
}

struct DirectionsResponse: Codable {
    let routes: [Route]
}
