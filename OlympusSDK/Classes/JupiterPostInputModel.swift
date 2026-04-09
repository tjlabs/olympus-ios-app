
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
    let velocity: Float
    let level_id: Int
    let jupiter_position: Position
    let navigation_position: Position?
    let phase: Int
    let is_indoor: Bool
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
