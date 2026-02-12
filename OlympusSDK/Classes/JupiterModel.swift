
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

enum JupiterResultMode {
    case NAVI, CALC, NONE
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
    
    public var calc_xyh: [Float]
    public var tu_xyh: [Float]
    public var landmark: LandmarkData?
    public var best_landmark: PeakData?
    public var recon_raw_traj: [[Double]]?
    public var recon_corr_traj: [FineLocationTrackingOutput]?
    public var recovery_result: RecoveryResult?
    public var recovery_result3Peaks: RecoveryResult3Peaks?
    public var ratio: Float?
    public var navi_route: [NavigationRoute]?
    public var navi_xyh: [Float]
}

public struct RecoveryResult: Codable {
    public let traj: [[Double]]
    public let shiftedTraj: [RecoveryTrajectory]
    public let loss: Float
    public var bestRecentCand: PeakData
    public let bestOlder: [Int]
    public let bestResult: FineLocationTrackingOutput?
    public var curLinkId: Int?
    public var curGroupId: Int?
    
    public init(traj: [[Double]],
                shiftedTraj: [RecoveryTrajectory],
                loss: Float,
                bestRecentCand: PeakData,
                bestOlder: [Int],
                bestResult: FineLocationTrackingOutput?,
                curLinkId: Int? = nil,
                curGroupId: Int? = nil) {
        self.traj = traj
        self.shiftedTraj = shiftedTraj
        self.loss = loss
        self.bestRecentCand = bestRecentCand
        self.bestOlder = bestOlder
        self.bestResult = bestResult
        self.curLinkId = curLinkId
        self.curGroupId = curGroupId
    }
}

public struct RecoveryResult3Peaks: Codable {
    public let traj: [[Double]]
    public let shiftedTraj: [RecoveryTrajectory]
    public let loss: Float
    public let bestThird: [Int]
    public let bestSecond: [Int]
    public let bestFirst: [Int]
    public let bestResult: FineLocationTrackingOutput?
}

struct _RecoveryCandidate {
    let loss: Float
    let shiftedTraj: [RecoveryTrajectory]
    let recentCand: PeakData
    let olderCand: PeakData?
    let tail: FineLocationTrackingOutput?
    let head: FineLocationTrackingOutput?
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
    public var building: String = ""
    public var level: String = ""
    public var x: Float = 0
    public var y: Float = 0
    public var direction: [Float] = []
    
    public init(type: Int, wardId: String, building: String, level: String, x: Float, y: Float, direction: [Float]) {
        self.type = type
        self.wardId = wardId
        self.building = building
        self.level = level
        self.x = x
        self.y = y
        self.direction = direction
    }
}
