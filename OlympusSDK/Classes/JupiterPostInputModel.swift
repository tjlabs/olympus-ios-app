
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

// MARK: - RSSI Compensation
struct RcDeviceOsInput: Codable {
    let sector_id: Int
    let device_model: String
    let os_version: Int
}

struct RcDeviceInput: Codable {
    let sector_id: Int
    let device_model: String
}

struct RcInfoSave: Codable {
    let sector_id: Int
    let device_model: String
    let os_version: Int
    let normalization_scale: Float
}

// MARK: - UserMask
struct UserMask: Encodable {
    let user_id: String
    let mobile_time: Int
    let section_number: Int
    let index: Int
    let x: Int
    let y: Int
    let absolute_heading: Float
}

struct SectorInfo: Encodable {
    let standard_min_rss: Float
    let standard_max_rss: Float
    let user_traj_length: Float
    let user_traj_length_dr: Float
    let user_traj_length_pdr: Float
    let num_straight_idx_dr: Int
    let num_straight_idx_pdr: Int
}
