
struct ixyhs {
    var index: Int = -1
    var x: Float = 0
    var y: Float = 0
    var heading: Float = 0
    var scale: Float = 1.0
}

typealias WardId = String

struct UserPeak {
    let id: WardId
    
    /// Peak 검출에 사용한 Buffer의 시작 uvd Index
    let start_index: Int
    /// Peak 검출에 사용한 Buffer의 마지막 uvd Index
    let end_index: Int
    /// Peak가 존재하는 시점의 uvd Index
    let peak_index: Int

    /// Peak 검출에 사용한 Buffer의 시작 rssi
    let start_rssi: Float
    /// Peak 검출에 사용한 Buffer의 마지막 rssi
    let end_rssi: Float
    /// Peak rssi (buffer 내 max)
    let peak_rssi: Float

    /// 당시 적용된 adaptive threshold
    let threshold: Float
}

struct PassedNodeInfo {
    var id: Int
    var coord: [Float]
    var headings: [Float]
    var matched_index: Int
    var user_heading: Float
}

struct PassedLinkInfo {
    var id: Int
    var start_node: Int
    var end_node: Int
    var distance: Float
    var included_heading: [Float]
    var group_id: Int
    var user_coord: [Float]
    var user_heading: Float
    var matched_heading: Float
    var oppsite_heading: Float
}

struct PassingLink {
    var uvd_index: Int
    var link_id: Int
    var link_group_Id: Int
}

public struct RecoveryTrajectory: Codable {
    var index: Int
    var x: Float
    var y: Float
    var heading: Float
}

struct BuildingLevelTagResult {
    let building: String
    let level: String
    let x: Float
    let y: Float
}

struct JumpInfo {
    var link_id: Int
    var jumped_nodes: [PassedNodeInfo]
}

enum LimitationType {
    case X_LIMIT, Y_LIMIT, SMALL_LIMIT, NO_LIMIT
}
