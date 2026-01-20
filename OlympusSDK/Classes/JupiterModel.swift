
import Foundation
import TJLabsCommon
import TJLabsResource

public enum JupiterRegion: String {
    case KOREA = "KOREA"
    case US_EAST = "US_EAST"
    case CANADA = "CANADA"
}

public protocol JupiterManagerDelegate: AnyObject {
    func onJupiterSuccess(_ isSuccess: Bool)
    func onJupiterError(_ code: Int, _ msg: String)
    func onJupiterResult(_ result: JupiterResult)
    func onJupiterReport(_ flag: Int)
}

public enum JupiterPhase {
    case NONE, ENTERING, SEARCHING, TRACKING
}

// MARK: - JupiterResult
public struct JupiterResult: Codable {
    public var mobile_time: Int
    public var building_name: String
    public var level_name: String
    public var scc: Float
    public var x: Float
    public var y: Float
    public var llh: LLH?
    public var absolute_heading: Float
    public var index: Int
    public var velocity: Float
    public var mode: String
    public var ble_only_position: Bool
    public var isIndoor: Bool
    public var validity: Bool
    public var validity_flag: Int
}

public struct LLH: Codable {
    public var lat: Double
    public var lon: Double
    public var heading: Double
}


// MARK: - JupiterDebugResult
public struct JupiterDebugResult: Codable {
    public var mobile_time: Int
    public var building_name: String
    public var level_name: String
    public var scc: Float
    public var x: Float
    public var y: Float
    public var llh: LLH?
    public var absolute_heading: Float
    public var index: Int
    public var velocity: Float
    public var mode: String
    public var ble_only_position: Bool
    public var isIndoor: Bool
    public var validity: Bool
    public var validity_flag: Int
    
    public var tu_xyh: [Float]
    public var landmark: LandmarkData?
    public var best_landmark: PeakData?
    public var recon_raw_traj: [[Double]]?
    public var recon_corr_traj: [FineLocationTrackingOutput]?
    public var recovery_result: RecoveryResult?
    public var recovery_result_v2: RecoveryResult_v2?
}

public struct RecoveryResult: Codable {
    public let traj: [[Double]]
    public let loss: Float
    public let bestOlder: [Int]
    public let bestRecent: [Int]
    public let bestResult: FineLocationTrackingOutput?
}

public struct RecoveryResult_v2: Codable {
    public let traj: [[Double]]
    public let loss: Float
    public let bestThird: [Int]
    public let bestSecond: [Int]
    public let bestFirst: [Int]
    public let bestResult: FineLocationTrackingOutput?
}

// Temp
public struct EntrancePeakData: Codable {
    public var number: Int = 0
    public var velocityScale: Float = 1.0
    public var inner_ward: InnerWardData
    public var outerWardId: String = ""
    
    public init(number: Int, velocityScale: Float, inner_ward: InnerWardData, outerWardId: String) {
        self.number = number
        self.velocityScale = velocityScale
        self.inner_ward = inner_ward
        self.outerWardId = outerWardId
    }
}

public struct InnerWardData: Codable {
    public var type: Int = -1
    public var wardId: String = ""
    public var coord: [Float] = []
    public var direction: [Float] = []
    
    public init(type: Int, wardId: String, coord: [Float], direction: [Float]) {
        self.type = type
        self.wardId = wardId
        self.coord = coord
        self.direction = direction
    }
}
