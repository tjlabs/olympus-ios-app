class OlympusConstants {
    static let OPERATING_SYSTEM: String = "iOS"
    static let MODE_DR = "dr"
    static let MODE_PDR = "pdr"
    
    static let R2D: Double = 180 / Double.pi
    static let D2R: Double = Double.pi / 180

    static let SAMPLE_HZ: Double = 40

    static let G: Double = 9.81
    static let SENSOR_INTERVAL: TimeInterval = 1/100
    static let ABNORMAL_MAG_THRESHOLD: Double = 2000
    static let ABNORMAL_COUNT = 500
    
    static var STANDARD_MIN_RSS: Double = -99
    static var STANDARD_MAX_RSS: Double = -60
    
    static var USER_TRAJECTORY_ORIGINAL: Double = 60
    static var USER_TRAJECTORY_LENGTH: Double = 60
    static var USER_TRAJECTORY_DIAGONAL: Double = 20
    
    static var NUM_STRAIGHT_INDEX_DR: Int = 10
    static var NUM_STRAIGHT_INDEX_PDR: Int = 10
}
