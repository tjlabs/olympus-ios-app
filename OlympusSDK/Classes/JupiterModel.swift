
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
}
