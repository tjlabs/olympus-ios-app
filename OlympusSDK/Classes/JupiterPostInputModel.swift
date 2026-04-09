
import Foundation
import TJLabsCommon

public struct LoginInput: Codable {
    public var name: String = ""
}

// MARK: - MobileResult & Report
struct MobileResult: Codable {
    let tenant_user_name: String
    let is_vehicle: Bool
    let mobile_time: Int
    let index: Int
    let level_id: Int
    let jupiter_pos: Position
    let navi_pos: Position?
    let phase: Int
    let is_indoor: Bool
    let latitude: Double?
    let longitude: Double?
    let azimuth: Double?
    let velocity: Float
    let validity_flag: Int
}

struct MobileReport: Encodable {
    let tenant_user_name: String
    let mobile_time: Int
    let code: Int
}

struct S3Input: Codable {
    let file_name: String
    let content_type: String
}
