
import TJLabsResource

public struct RoutingPoint: Codable {
    public let level_id: Int
    public let x: Int
    public let y: Int
    public let absolute_heading: Int
    
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
