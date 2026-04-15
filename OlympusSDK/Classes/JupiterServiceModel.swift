
public struct ixyhs {
    var index: Int = -1
    var x: Float = 0
    var y: Float = 0
    var heading: Float = 0
    var scale: Float = 1.0
    var headingFail: Bool = false
}

public typealias WardId = String

public struct UserPeak {
    public let id: WardId
    
    /// Peak 검출에 사용한 Buffer의 시작 uvd Index
    public let start_index: Int
    /// Peak 검출에 사용한 Buffer의 마지막 uvd Index
    public let end_index: Int
    /// Peak가 존재하는 시점의 uvd Index
    public let peak_index: Int

    /// Peak 검출에 사용한 Buffer의 시작 rssi
    public let start_rssi: Float
    /// Peak 검출에 사용한 Buffer의 마지막 rssi
    public let end_rssi: Float
    /// Peak rssi (buffer 내 max)
    public let peak_rssi: Float

    /// 당시 적용된 adaptive threshold
    public let threshold: Float
}

struct PathMatchingResult {
    let xyhs: ixyhs
    let matchedHeadings: [Float]
}

struct PassedNodeInfo {
    var number: Int
    var coord: [Float]
    var headings: [Float]
    var matched_index: Int
    var user_heading: Float
}

struct PassedLinkInfo {
    var number: Int
    var start_node: Int
    var end_node: Int
    var distance: Float
    var included_heading: [Float]
    var group_number: Int
    var user_coord: [Float]
    var user_heading: Float
    var matched_heading: Float
    var oppsite_heading: Float
}

struct PassingLink {
    var uvd_index: Int
    var link_number: Int
    var link_group_number: Int
}

public struct RecoveryTrajectory: Codable {
    var index: Int
    var x: Float
    var y: Float
    var heading: Float
}

public struct CandidateTrajectory: Codable {
    public var index: Int
    public var x: Float
    public var y: Float
    public var heading: Float
}

public struct LossPointResult: Codable {
    let index: Int
    let traj: [Float]
    let pm: [Float]
    let lossDist: Float
    let lossHeading: Float
}

struct BuildingLevelTagResult {
    let building: String
    let level: String
    let x: Float
    let y: Float
}

struct JumpInfo {
    var link_number: Int
    var jumped_nodes: [PassedNodeInfo]
}

struct EntWardArea {
    var x: Float
    var y: Float
    var heading: [Float]
}

enum LimitationType {
    case X_LIMIT, Y_LIMIT, SMALL_LIMIT, NO_LIMIT
}

public struct NaviCorrectionInfo {
    public let x: Float
    public let y: Float
    public let heading: Float
    
    public init(x: Float, y: Float, heading: Float) {
        self.x = x
        self.y = y
        self.heading = heading
    }
}

public struct StackEditInfo: Codable {
    public let index: Int
    public let building: String
    public let level: String
    public var x: Float
    public var y: Float
    public var heading: Float
    
    public init(index: Int, building: String, level: String, x: Float, y: Float, heading: Float) {
        self.index = index
        self.building = building
        self.level = level
        self.x = x
        self.y = y
        self.heading = heading
    }
}
