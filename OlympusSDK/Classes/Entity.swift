public struct SensorData {
    public var time: Double = 0
    public var acc = [Double](repeating: 0, count: 3)
    public var userAcc = [Double](repeating: 0, count: 3)
    public var gyro = [Double](repeating: 0, count: 3)
    public var mag = [Double](repeating: 0, count: 3)
    public var grav = [Double](repeating: 0, count: 3)
    public var att = [Double](repeating: 0, count: 3)
    public var quaternion: [Double] = [0,0,0,0]
    public var rotationMatrix = [[Double]](repeating: [Double](repeating: 0, count: 3), count: 3)
    
    public var gameVector: [Float] = [0,0,0,0]
    public var rotVector: [Float] = [0,0,0,0,0]
    public var pressure: [Double] = [0]
    
    public func toString() -> String {
        return "acc=\(self.acc), gyro=\(self.gyro), mag=\(self.mag), grav=\(self.grav)"
    }
}

public struct CollectData {
    public var time: Int = 0
    public var acc = [Double](repeating: 0, count: 3)
    public var userAcc = [Double](repeating: 0, count: 3)
    public var gyro = [Double](repeating: 0, count: 3)
    public var mag = [Double](repeating: 0, count: 3)
    public var grav = [Double](repeating: 0, count: 3)
    public var att = [Double](repeating: 0, count: 3)
    public var quaternion: [Double] = [0,0,0,0]
    public var rotationMatrix = [[Double]](repeating: [Double](repeating: 0, count: 3), count: 3)
    
    public var gameVector: [Float] = [0,0,0,0]
    public var rotVector: [Float] = [0,0,0,0,0]
    public var pressure: [Double] = [0]
    
    public var index: Int = 0
    public var length: Double = 0
    public var heading: Double = 0
    public var lookingFlag: Bool = false
    public var isIndexChanged: Bool = false
    
    public var bleRaw = [String: Double]()
    public var bleAvg = [String: Double]()
}

public struct LoginInput: Codable {
    public var user_id: String = ""
    public var device_model: String = ""
    public var os_version: Int = 0
    public var sdk_version: String = ""
}

// ---------------- Sector ---------------- //
public struct SectorInput: Codable {
    public var sector_id: Int = 0
    public var operating_system: String = "iOS"
}

public struct SectorInfoParam: Codable  {
    let trajectory_length: Int
    let trajectory_diagonal: Int
    let debug: Bool
    let standard_rss: [Int]
}

public struct SectorInfoGeofence: Codable {
    let entrance_area: [[Double]]
    let entrance_matching_area: [[Double]]
    let level_change_area: [[Double]]
}

public struct SectorInfoEntrance: Codable {
    let spot_number: Int
    let network_status: Bool
    let outermost_ward_id: String
    let scale: Double
    let route_version: String
}

public struct SectorInfoLevel: Codable {
    let building_name: String
    let level_name: String
    let geofence: SectorInfoGeofence
    let entrance_list: [SectorInfoEntrance]
    let path_pixel_version: String
}


public struct SectorInfoFromServer: Codable {
    let parameter: SectorInfoParam
    let level_list: [SectorInfoLevel]
}

// ---------------- RC ---------------- //
public struct RcInputDeviceOs: Codable {
    let sector_id: Int
    let device_mode: String
    let os_version: Int
}

public struct RcInputDevice: Codable {
    let sector_id: Int
    let device_mode: String
}

public struct RcInfo: Codable {
    let os_version: Int
    let normalization_scale: Double
}

public struct RcInfoFromServer: Codable {
    let rss_compensations: [RcInfo]
}

// ---------------- RC ---------------- //
