
import Foundation

// MARK: - FineLocationTracking
public struct FineLocationTrackingOutput: Codable, Equatable {
    public var mobile_time: Int
    public var index: Int
    public var building_name: String
    public var level_name: String
    public var x: Float
    public var y: Float
    public var absolute_heading: Float
}

struct StorageOutput: Codable {
    let presigned_url: String
    let expires_in: Int
}
