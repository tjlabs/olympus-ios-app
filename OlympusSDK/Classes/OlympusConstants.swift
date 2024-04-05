class OlympusConstants {
    static let OPERATING_SYSTEM: String = "iOS"
    static let MODE_DR = "dr"
    static let MODE_PDR = "pdr"
    static let SERVICE_FLT = "FLT"
    
    static let R2D: Double = 180 / Double.pi
    static let D2R: Double = Double.pi / 180

    static let SAMPLE_HZ: Double = 40

    static let G: Double = 9.81
    static let SENSOR_INTERVAL: TimeInterval = 1/100
    static let ABNORMAL_MAG_THRESHOLD: Double = 2000
    static let ABNORMAL_MAG_COUNT = 500
    
    // DR & PDR //
    static let LOOKING_FLAG_STEP_CHECK_SIZE: Int = 3
    static let AVG_ATTITUDE_WINDOW: Int = 20
    static let AVG_NORM_ACC_WINDOW: Int = 20
    static let ACC_PV_QUEUE_SIZE: Int = 3
    static let ACC_NORM_EMA_QUEUE_SIZE: Int = 3
    static let STEP_LENGTH_QUEUE_SIZE: Int = 5
    static let NORMAL_STEP_LOSS_CHECK_SIZE: Int = 3
    static let MODE_AUTO_NORMAL_STEP_COUNT_SET = 19
    static  let AUTO_MODE_NORMAL_STEP_LOSS_CHECK_SIZE: Int = MODE_AUTO_NORMAL_STEP_COUNT_SET + 1
    
    static let ALPHA: Double = 0.45
    static let DIFFERENCE_PV_STANDARD: Double = 0.83
    static let MID_STEP_LENGTH: Double = 0.5
    static let DEFAULT_STEP_LENGTH: Double = 0.60
    static let MIN_STEP_LENGTH: Double = 0.01
    static let MAX_STEP_LENGTH: Double = 0.93
    static let MIN_DIFFERENCE_PV: Double = 0.2
    static let COMPENSATION_WEIGHT: Double = 0.85
    static let COMPENSATION_BIAS: Double = 0.1
    static let DIFFERENCE_PV_THRESHOLD: Double = (MID_STEP_LENGTH - DEFAULT_STEP_LENGTH) / ALPHA + DIFFERENCE_PV_STANDARD
    
    static let OUTPUT_SAMPLE_HZ: Double = 10
    static let OUTPUT_SAMPLE_TIME: Double = 1 / OUTPUT_SAMPLE_HZ
    static let MODE_QUEUE_SIZE: Double = 15
    static let VELOCITY_QUEUE_SIZE: Double = 10
    static let VELOCITY_SETTING: Double = 4.7 / VELOCITY_QUEUE_SIZE
    static let OUTPUT_SAMPLE_EPOCH: Double = SAMPLE_HZ / Double(OUTPUT_SAMPLE_HZ)
    static let FEATURE_EXTRACTION_SIZE: Double = SAMPLE_HZ/2
    static let OUTPUT_DISTANCE_SETTING: Double = 1
    static let SEND_INTERVAL_SECOND: Double = 1 / VELOCITY_QUEUE_SIZE
    static let VELOCITY_MIN: Double = 4
    static let VELOCITY_MAX: Double = 18
    
    static var AMP_THRESHOLD: Double = 0.18
    static var TIME_THRESHOLD: Double = 100.0
    
    // Sector Info //
    static var STANDARD_MIN_RSS: Double = -99
    static var STANDARD_MAX_RSS: Double = -60
    
    static var USER_TRAJECTORY_ORIGINAL: Double = 60
    static var USER_TRAJECTORY_LENGTH: Double = 60
    static var USER_TRAJECTORY_DIAGONAL: Double = 20
    
    static var NUM_STRAIGHT_INDEX_DR: Int = 10
    static var NUM_STRAIGHT_INDEX_PDR: Int = 10
    
    static var NORMALIZATION_SCALE: Double = 0.2
    static var PRE_NORMALIZATION_SCALE: Double = 0.8
    
    
    public func setSectorInfoConstants(sector_info: SectorInfo) {
        OlympusConstants.STANDARD_MIN_RSS = sector_info.standard_min_rss
        OlympusConstants.STANDARD_MAX_RSS = sector_info.standard_max_rss
        OlympusConstants.USER_TRAJECTORY_ORIGINAL = sector_info.user_traj_origin
        OlympusConstants.USER_TRAJECTORY_LENGTH = sector_info.user_traj_length
        OlympusConstants.USER_TRAJECTORY_DIAGONAL = sector_info.user_traj_diag
        OlympusConstants.NUM_STRAIGHT_INDEX_DR = sector_info.num_straight_idx_dr
        OlympusConstants.NUM_STRAIGHT_INDEX_PDR = sector_info.num_straight_idx_pdr
    }
    
    public func setNormalizationScale(cur: Double, pre: Double) {
        OlympusConstants.NORMALIZATION_SCALE     = cur
        OlympusConstants.PRE_NORMALIZATION_SCALE = pre
    }
    
    
}
