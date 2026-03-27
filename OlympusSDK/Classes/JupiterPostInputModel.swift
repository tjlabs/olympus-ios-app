
import Foundation
import TJLabsCommon

public struct LoginInput: Codable {
    public var name: String = ""
    public var device_model: String = ""
    public var os_version: Int = 0
    public var sdk_version: String = ""
}

// MARK: - MobileResult & Report
struct MobileResult: Codable {
    let tenant_user_name: String
    let mobile_time: Int
    let index: Int
    let sector_id: Int
    let building_name: String
    let level_name: String
    let x: Float
    let y: Float
    let scc: Float
    let phase: Int
    let absolute_heading: Float
    let normalization_scale: Float
    let device_min_rss: Int
    let sc_compensation: Double
    let ble_only_position: Bool
    let is_indoor: Bool
    let in_out_state: Int
    let latitude: Double?
    let longitude: Double?
    let velocity: Float
    let calculated_time: Float
}

struct MobileReport: Encodable {
    let tenant_user_name: String
    let mobile_time: Int
    let code: Int
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
    let origin: Origin
    let destination: Point
    let waypoints: [Point]
}
