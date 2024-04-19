public struct LoginInfo: Codable {
    public var user_id: String = ""
    public var device_model: String = ""
    public var os_version: Int = 0
    public var sdk_version: String = ""
}

struct CoordToDisplay {
    var x: Double = 0
    var y: Double = 0
    var heading: Double = 0
    var building: String = ""
    var level: String = ""
    var isIndoor: Bool = false
}
