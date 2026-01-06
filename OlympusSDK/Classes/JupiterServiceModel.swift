
struct xyhs {
    var x: Float = 0
    var y: Float = 0
    var heading: Float = 0
    var scale: Float = 0
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
