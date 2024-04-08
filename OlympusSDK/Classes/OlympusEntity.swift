public struct OlympusSensorData {
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

public struct OlympusCollectData {
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

public struct Attitude: Equatable {
    public var Roll: Double = 0
    public var Pitch: Double = 0
    public var Yaw: Double = 0
}

public struct SensorAxisValue: Equatable {
    public var x: Double = 0
    public var y: Double = 0
    public var z: Double = 0
    
    public var norm: Double = 0
}

public struct PeakValleyStruct {
    public var type: Type = Type.NONE
    public var timestamp: Double = 0
    public var pvValue: Double = 0.0
}

public struct StepResult: Equatable {
    public var count: Double = 0
    public var heading: Double = 0
    public var pressure: Double = 0
    public var stepLength: Double = 0
    public var isLooking: Bool = true
}

public struct UnitDistance: Equatable {
    public var index: Int = 0
    public var length: Double = 0
    public var velocity: Double = 0
    public var isIndexChanged: Bool = false
}


public struct TimestampDouble: Equatable {
    public var timestamp: Double = 0
    public var valuestamp: Double = 0
}


public struct StepLengthWithTimestamp: Equatable {
    public var timestamp: Double = 0
    public var stepLength: Double = 0

}

public struct DistanceInfo: Equatable {
    public var index: Int = 0
    public var length: Double = 0
    public var time: Double = 0
    public var isIndexChanged: Bool = true
}

public struct UnitDRInfo {
    public var index: Int = 0
    public var length: Double = 0
    public var heading: Double = 0
    public var velocity: Double = 0
    public var lookingFlag: Bool = false
    public var isIndexChanged: Bool = false
    public var autoMode: Int = 0
    
    public func toString() -> String {
        return "{index : \(index), length : \(length), heading : \(heading), velocity : \(velocity), lookingFlag : \(lookingFlag), isStepDetected : \(isIndexChanged), autoMode : \(autoMode)}"
    }
}

// ---------------- Login ---------------- //
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

public struct SectorInfo: Codable {
    let standard_min_rss: Double
    let standard_max_rss: Double
    let user_traj_origin: Double
    let user_traj_length: Double
    let user_traj_diag: Double
    let num_straight_idx_dr: Int
    let num_straight_idx_pdr: Int
}

// ---------------- RC ---------------- //
public struct RcInputDeviceOs: Codable {
    let sector_id: Int
    let device_model: String
    let os_version: Int
}

public struct RcInputDevice: Codable {
    let sector_id: Int
    let device_model: String
}

public struct RcInfo: Codable {
    let os_version: Int
    let normalization_scale: Double
}

public struct RcInfoFromServer: Codable {
    let rss_compensations: [RcInfo]
}

// ---------------- RC ---------------- //

// ---------------- REC DATA ---------------- //
struct ReceivedForce: Encodable {
    let user_id: String
    let mobile_time: Int
    let ble: [String: Double]
    let pressure: Double
}

struct UserVelocity: Encodable {
    let user_id: String
    let mobile_time: Int
    let index: Int
    let length: Double
    let heading: Double
    let looking: Bool
}

public struct MobileResult: Encodable {
    public var user_id: String
    public var mobile_time: Int
    public var sector_id: Int
    public var building_name: String
    public var level_name: String
    public var scc: Double
    public var x: Double
    public var y: Double
    public var absolute_heading: Double
    public var phase: Int
    public var calculated_time: Double
    public var index: Int
    public var velocity: Double
    public var ble_only_position: Bool
    public var normalization_scale: Double
    public var device_min_rss: Int
    public var sc_compensation: Double
    public var is_indoor: Bool
}

public struct MobileReport: Encodable {
    public var user_id: String
    public var mobile_time: Int
    public var report: Int
}

// Recent
struct RecentResult: Encodable {
    var user_id: String
    var mobile_time: Int
}


// ---------------- REC DATA ---------------- //


// ---------------- Service ---------------- //

// Building Detection
public struct BuildingDetectionResult: Codable {
    public var mobile_time: Int
    public var building_name: String
    public var calculated_time: Double
    
    public init() {
        self.mobile_time = 0
        self.building_name = ""
        self.calculated_time = 0
    }
}

// Coarse Level Detection
struct CoarseLevelDetection: Encodable {
    var user_id: String
    var mobile_time: Int
    var normalization_scale: Double
    var device_min_rss: Int
    var standard_min_rss: Int
}

public struct CoarseLevelDetectionResult: Codable {
    public var mobile_time: Int
    public var sector_name: String
    public var building_name: String
    public var level_name: String
    public var calculated_time: Double
    
    public init() {
        self.mobile_time = 0
        self.sector_name = ""
        self.building_name = ""
        self.level_name = ""
        self.calculated_time = 0
    }
}

// Fine Level Detection
public struct FineLevelDetectionResult: Codable {
    public var mobile_time: Int
    public var building_name: String
    public var level_name: String
    public var scc: Double
    public var scr: Double
    public var calculated_time: Double
    
    public init() {
        self.mobile_time = 0
        self.building_name = ""
        self.level_name = ""
        self.scc = 0
        self.scr = 0
        self.calculated_time = 0
    }
}


// Coarse Location Estimation
struct CoarseLocationEstimation: Encodable {
    var user_id: String
    var mobile_time: Int
    var sector_id: Int
    var search_direction_list: [Int]
    var normalization_scale: Double
    var device_min_rss: Int
}

public struct CoarseLocationEstimationResult: Codable {
    public var mobile_time: Int
    public var building_name: String
    public var level_name: String
    public var scc: Double
    public var scr: Double
    public var x: Int
    public var y: Int
    public var calculated_time: Double
    
    public init() {
        self.mobile_time = 0
        self.building_name = ""
        self.level_name = ""
        self.scc = 0
        self.scr = 0
        self.x = 0
        self.y = 0
        self.calculated_time = 0
    }
}

// Fine Location Tracking
public struct FineLocationTrackingResult: Codable {
    public var mobile_time: Int
    public var building_name: String
    public var level_name: String
    public var scc: Double
    public var x: Double
    public var y: Double
    public var absolute_heading: Double
    public var phase: Int
    public var calculated_time: Double
    public var index: Int
    public var velocity: Double
    public var mode: String
    public var ble_only_position: Bool
    public var isIndoor: Bool
    public var validity: Bool
    public var validity_flag: Int
    
    public init() {
        self.mobile_time = 0
        self.building_name = ""
        self.level_name = ""
        self.scc = 0
        self.x = 0
        self.y = 0
        self.absolute_heading = 0
        self.phase = 0
        self.calculated_time = 0
        self.index = 0
        self.velocity = 0
        self.mode = ""
        self.ble_only_position = false
        self.isIndoor = false
        self.validity = false
        self.validity_flag = 0
    }
}

public struct FineLocationTrackingFromServer: Codable {
    public var mobile_time: Int
    public var building_name: String
    public var level_name: String
    public var scc: Double
    public var x: Double
    public var y: Double
    public var absolute_heading: Double
    public var calculated_time: Double
    public var index: Int
    public var sc_compensation: Double
    public var search_direction: Int
    public var cumulative_length: Double
    public var channel_condition: Bool
    
    public init() {
        self.mobile_time = 0
        self.building_name = ""
        self.level_name = ""
        self.scc = 0
        self.x = 0
        self.y = 0
        self.absolute_heading = 0
        self.calculated_time = 0
        self.index = 0
        self.sc_compensation = 0
        self.search_direction = 0
        self.cumulative_length = 0
        self.channel_condition = false
    }
}

// On Spot Recognition
struct OnSpotRecognition: Encodable {
    var user_id: String
    var mobile_time: Int
    var normalization_scale: Double
    var device_min_rss: Int
    var standard_min_rss: Int
}

public struct OnSpotRecognitionResult: Codable {
    public var mobile_time: Int
    public var building_name: String
    public var level_name: String
    public var linked_level_name: String
    public var spot_id: Int
    public var spot_distance: Double
    public var spot_range: [Int]
    public var spot_direction_down: [Int]
    public var spot_direction_up: [Int]

    public init() {
        self.mobile_time = 0
        self.building_name = ""
        self.level_name = ""
        self.linked_level_name = ""
        self.spot_id = 0
        self.spot_distance = 0
        self.spot_range = []
        self.spot_direction_down = []
        self.spot_direction_up = []
    }
}

// On Spot Authorizationds
struct OnSpotAuthorization: Encodable {
    var user_id: String
    var mobile_time: Int
}


public struct OnSpotAuthorizationResult: Codable {
    public var spots: [Spot]
    
    public init() {
        self.spots = []
    }
}

public struct Spot: Codable {
    public var mobile_time: Int
    public var sector_name: String
    public var building_name: String
    public var level_name: String
    public var spot_id: Int
    public var spot_number: Int
    public var spot_name: String
    public var spot_feature_id: Int
    public var spot_x: Int
    public var spot_y: Int
    public var ccs: Double
    
    public init() {
        self.mobile_time = 0
        self.sector_name = ""
        self.building_name = ""
        self.level_name = ""
        self.spot_id = 0
        self.spot_number = 0
        self.spot_name = ""
        self.spot_feature_id = 0
        self.spot_x = 0
        self.spot_y = 0
        self.ccs = 0
    }
}
