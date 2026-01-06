
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
    
//    public init() {
//        self.mobile_time = 0
//        self.index = 0
//        self.building_name = ""
//        self.level_name = ""
//        self.scc = 0
//        self.x = 0
//        self.y = 0
//        self.absolute_heading = 0
//    }
}

// MARK: - RSSI Compensation
public struct RcInfo: Codable {
    let os_version: Int
    let normalization_scale: Float
}

public struct RcInfoOutputList: Codable {
    let rss_compensations: [RcInfo]
}
