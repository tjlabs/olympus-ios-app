
import Foundation
import TJLabsCommon
import TJLabsResource

public enum JupiterRegion: String {
    case KOREA = "KOREA"
    case US_EAST = "US_EAST"
    case CANADA = "CANADA"
}

protocol JupiterCalcManagerDelegate: AnyObject {
    func onRfdResult(receivedForce: ReceivedForce)
    func onEntering(userVelocity: UserVelocity,
                    peakIndex: Int?,
                    key: String,
                    level_id: Int)
    func provideTrackingCorrection(mode: UserMode,
                                   userVelocity: UserVelocity,
                                   peakIndex: Int?,
                                   recentLandmarkPeaks: [PeakData]?,
                                   travelingLinkDist: Float,
                                   indexForEdit: Int,
                                   curPmResult: FineLocationTrackingOutput?) -> (NaviCorrectionInfo, [StackEditInfo])?
    func isJupiterPhaseChanged(index: Int, phase: JupiterPhase, xyh: [Float]?)
}

public protocol JupiterManagerDelegate: AnyObject {
    func onRfdResult(receivedForce: ReceivedForce)
    func onEntering(userVelocity: UserVelocity,
                    peakIndex: Int?,
                    key: String,
                    level_id: Int)
    func provideTrackingCorrection(mode: UserMode,
                                   userVelocity: UserVelocity,
                                   peakIndex: Int?,
                                   recentLandmarkPeaks: [PeakData]?,
                                   travelingLinkDist: Float,
                                   indexForEdit: Int,
                                   curPmResult: FineLocationTrackingOutput?) -> (NaviCorrectionInfo, [StackEditInfo])?
    func onJupiterSuccess(_ isSuccess: Bool)
    func onJupiterError(_ code: Int, _ msg: String)
    func onJupiterResult(_ result: JupiterResult)
    func onJupiterReport(_ flag: Int)
    func isJupiterInOutStateChanged(_ state: InOutState)
    func isJupiterPhaseChanged(index: Int, phase: JupiterPhase, xyh: [Float]?)
}

public enum JupiterPhase {
    case NONE, ENTERING, SEARCHING, TRACKING, EXITING
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
public struct JupiterDebugResult {
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
    public var selected_cand: SelectedCandidate?
    public var selected_search: SelectedSearch?
    public var ratio: Float?
    public var navi_xyh: [Float]
}

public struct RecoveryResult: Codable {
    public let traj: [[Double]]
    public let shiftedTraj: [RecoveryTrajectory]
    public let loss: Float
    public var bestRecentCand: PeakData
    public let bestOlder: [Int]
    public let bestResult: FineLocationTrackingOutput?
    public var curLinkNum: Int?
    public var curGroupNum: Int?
    
    public init(traj: [[Double]],
                shiftedTraj: [RecoveryTrajectory],
                loss: Float,
                bestRecentCand: PeakData,
                bestOlder: [Int],
                bestResult: FineLocationTrackingOutput?,
                curLinkNum: Int? = nil,
                curGroupNum: Int? = nil) {
        self.traj = traj
        self.shiftedTraj = shiftedTraj
        self.loss = loss
        self.bestRecentCand = bestRecentCand
        self.bestOlder = bestOlder
        self.bestResult = bestResult
        self.curLinkNum = curLinkNum
        self.curGroupNum = curGroupNum
    }
}

public struct SearchResult {
    public let older: PeakData?
    public let recent: PeakData?
    public let traj: [CandidateTrajectory]
    public let tail: ixyhs
    public let head: ixyhs
    public let headResult: FineLocationTrackingOutput
    
    public let lossPointResultList: [LossPointResult]
    public let loss_lm: Float
    public let loss_g_d: Float
    public let loss_g_h: Float
}

public struct SelectedSearch {
    public let older: PeakData?
    public let recent: PeakData?
    public let traj: [CandidateTrajectory]
    public let tail: ixyhs
    public let head: ixyhs
    public var headResult: FineLocationTrackingOutput
    
    public let loss: Float
}

public struct CandidateResult {
    public let older: PeakData?
    public let recent: PeakData?
    public let links: [Int]
    public let linkGroups: Set<Int>
    public let traj: [CandidateTrajectory]
    public let tail: ixyhs
    public let head: ixyhs
    public let headResult: FineLocationTrackingOutput
    public let isInSameLinkGroup: Bool
    public let linkGroupSwitchCount: Int
    public let distWithRecentPeakResult: Float?
    
    public let lossPointResultList: [LossPointResult]
    public let loss_lm: Float
    public let loss_g_d: Float
    public let loss_g_h: Float
}

public struct SelectedCandidate {
    public let older: PeakData?
    public let recent: PeakData?
    public let links: [Int]
    public let linkGroups: Set<Int>
    public let traj: [CandidateTrajectory]
    public let tail: ixyhs
    public let head: ixyhs
    public let headResult: FineLocationTrackingOutput

    public let loss: Float
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
