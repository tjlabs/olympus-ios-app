class OlympusConstants {
    static let OPERATING_SYSTEM: String = "iOS"
    static let MODE_DR = "dr"
    static let MODE_PDR = "pdr"
    static let MODE_AUTO = "auto"
    static let OLYMPUS_SERVICES: [String] = ["SD", "BD", "CLD", "FLD", "CLE", "FLT", "FLT+", "OSA"]
    static let SERVICE_FLT = "FLT"
    
    static let R2D: Double = 180 / Double.pi
    static let D2R: Double = Double.pi / 180

    static let SAMPLE_HZ: Double = 40

    static let G: Double = 9.81
    static let SENSOR_INTERVAL: TimeInterval = 1/100
    static let ABNORMAL_MAG_THRESHOLD: Double = 2000
    static let ABNORMAL_MAG_COUNT = 500
    
    // Mag Heading Compensation
    static var MAG_HEADING_COMPENSATION: Double = 158.75
    
    // Validity
    static let VALID_SOLUTION: Int = 1
    static let RECOVERING_SOLUTION: Int = 2
    static let INVALID_OUTDOOR: Int = 3
    static let INVALID_VENUS: Int = 4
    static let INVALID_BLE: Int = 5
    static let INVALID_NETWORK: Int = 6
    static let INVALID_STATE: Int = 7

    
    // Phase
    static let PHASE_0: Int = 0
    static let PHASE_1: Int = 1
    static let PHASE_2: Int = 2
    static let PHASE_3: Int = 3
    static let PHASE_4: Int = 4
    static let PHASE_5: Int = 5
    static let PHASE_6: Int = 6
    static let PHASE_BECOME3_SCC: Double = 0.62
    static let PHASE_BREAK_SCC_PDR: Double = 0.45
//    static let PHASE_BREAK_SCC_DR: Double = 0.45
//    static let PHASE5_RECOVERY_SCC: Double = 0.5 // 0.55
    static let PHASE_BREAK_SCC_DR: Double = 0.42
    static let PHASE5_RECOVERY_SCC: Double = 0.5 // 0.55
    static let PHASE_BREAK_IN_PHASE2_SCC: Double = 0.26
    static let PHASE2_RESULT_USE_SCC: Double = 0.6
    static let STABLE_ENTER_LENGTH: Double = 20
    
    
    // Sector Info //
    static var STANDARD_MIN_RSS: Double = -99
    static var STANDARD_MAX_RSS: Double = -60
    
    static var USER_TRAJECTORY_LENGTH: Double = 60
    static var USER_TRAJECTORY_LENGTH_DR: Double = 60
    static var USER_TRAJECTORY_LENGTH_PDR: Double = 20
    static let DR_LENGTH_MARGIN: Int = 10
    static let PDR_LENGTH_MARGIN: Int = 5
    
    static var NUM_STRAIGHT_IDX_DR: Int = 10
    static var NUM_STRAIGHT_IDX_PDR: Int = 10
    
    static var NORMALIZATION_SCALE: Double = 1.0
    static var PRE_NORMALIZATION_SCALE: Double = 1.0
    
    
    // RFD //
    static var BLE_VALID_TIME: Double = 1000 // miliseconds
    static var BLE_VALID_TIME_INT: Int = 500 // miliseconds
//    static var BLE_VALID_TIME: Double = 1500 // miliseconds
    static let RFD_INTERVAL: TimeInterval = 1/2 //second
    static var RFD_INPUT_NUM: Int = 4
    static var DEVICE_MIN_RSSI: Double = -99.0
    static let EST_RC_INTERVAL: Double = 5.0
    static let REQUIRED_RC_CONVERGENCE_TIME: Double = 180 // seconds
    static let OUTDOOR_THRESHOLD: Double = 10 // seconds
    static let DEVICE_MIN_UPDATE_THRESHOLD: Double = -97.0
    
    // UVD //
    static var UVD_INTERVAL: TimeInterval = 1/40 // seconds
    static var RQ_IDX: Int = 10
    static var RQ_IDX_PDR: Int = 4
    static var RQ_IDX_DR: Int = 10
    static let USER_MASK_INPUT_NUM: Int = 5
    static var UVD_INPUT_NUM: Int = 3
    static var VALUE_INPUT_NUM: Int = 5
    static var INIT_INPUT_NUM: Int = 3
    static var INDEX_THRESHOLD: Int = 11
    static let UVD_BUFFER_SIZE: Int = 10
    static let DR_INFO_BUFFER_SIZE: Int = 60 // 30
    static let DR_BUFFER_SIZE_FOR_STRAIGHT: Int = 10 // COEX 12 // DS 6 // LG 10
    static let DR_BUFFER_SIZE_FOR_HEAD_STRAIGHT: Int = 3
    static let DR_HEADING_CORR_NUM_IDX: Int = 10
    
    // SLEEP
    static let SLEEP_THRESHOLD: Double = 600 // seconds
    static let STOP_THRESHOLD: Double = 2 // seconds
    
    // Request
    static let MINIMUM_RQ_TIME: Double = 2 // seconds
    static var REQUIRED_LENGTH_PHASE2: Double = 40
    
    // DR & PDR //
    static let LOOKING_FLAG_STEP_CHECK_SIZE: Int = 3
    static let AVG_ATTITUDE_WINDOW: Int = 20
    static let AVG_NORM_ACC_WINDOW: Int = 20
    static let ACC_PV_QUEUE_SIZE: Int = 3
    static let ACC_NORM_EMA_QUEUE_SIZE: Int = 3
    static let STEP_LENGTH_QUEUE_SIZE: Int = 5
    static let NORMAL_STEP_LOSS_CHECK_SIZE: Int = 3
    static let MODE_AUTO_NORMAL_STEP_COUNT_SET = 19
    static let AUTO_MODE_NORMAL_STEP_LOSS_CHECK_SIZE: Int = MODE_AUTO_NORMAL_STEP_COUNT_SET + 1
    
    static let ALPHA: Double = 0.45
    static let DIFFERENCE_PV_STANDARD: Double = 0.83
    static let MID_STEP_LENGTH: Double = 0.5
//    static let DEFAULT_STEP_LENGTH: Double = 0.60
    static let DEFAULT_STEP_LENGTH: Double = 0.7 // 0.625
    static let MIN_STEP_LENGTH: Double = 0.01
    static let MAX_STEP_LENGTH: Double = 0.93
    static let MIN_DIFFERENCE_PV: Double = 0.2
    static let COMPENSATION_WEIGHT: Double = 0.85
    static let COMPENSATION_BIAS: Double = 0.1
    static let DIFFERENCE_PV_THRESHOLD: Double = (MID_STEP_LENGTH - DEFAULT_STEP_LENGTH) / ALPHA + DIFFERENCE_PV_STANDARD
    static let STEP_LENGTH_RANGE_BOTTOM: Double = 0.5
    static let STEP_LENGTH_RANGE_TOP: Double = 0.7
    
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
    static let RF_SC_THRESHOLD_DR: Double = 0.67
    
    static let AMP_THRESHOLD: Double = 0.18
    static let TIME_THRESHOLD: Double = 100.0
    static let STOP_TIME_THRESHOLD: Double = 2000
    static let STEP_VALID_TIME: Double = 1000
    static let RF_SC_THRESHOLD_PDR: Double = 0.55
    
    static let MODE_CHANGE_TIME_CONDITION: Double = 10*1000 // miliseconds
    static let MODE_CHANGE_RFLOW_TIME_OVER: Double = 0.1
    static let MODE_CHANGE_RFLOW_FORCE: Double = 0.065
    
    // OnSpotRecognition
    static let OSR_INTERVAL: TimeInterval = 2 // seconds
    static let DEFAULT_SPOT_DISTANCE: Double = 80
    static let MINIMUM_BUILDING_LEVEL_CHANGE_TIME = 7000 // miliseconds
    
    // Output Update
    static let OUTPUT_INTERVAL: TimeInterval = 1/5 // seconds
    static let MR_INPUT_NUM = 20
    
    // Threshold //
    static let BLE_OFF_THRESHOLD: Double = 4 // seconds
    static var TIME_INIT_THRESHOLD: Double = 25 // seconds
    static var UNKNOWN_TRAJ_CUT_IDX: Int = 25
    static let OUTERWARD_SCAN_THRESHOLD: Double = -85.0
    static var REQUIRED_LENGTH_FOR_MAJOR_HEADING: Double = 10
    static let COUNT_FOR_PHASE_BREAK_IN_PHASE2: Int = 7
    static let HEADING_BUFFER_SIZE: Int = 5
    static let REQUIRED_PATH_TRAJ_MATCHING_INDEX: Int = 3 // 5
    static let SECTION_STRAIGHT_ANGLE: Double = 10 // degree
    static let SAME_COORD_THRESHOLD: Int = 4
    static let STRAIGHT_SAME_COORD_THRESHOLD: Int = 6
    static let REQUIRED_SECTION_STRAIGHT_LENGTH: Double = 8
    static let REQUIRED_SECTION_REQUEST_LENGTH: Double = 25 // 25
    static let REQUIRED_SECTION_REQUEST_LENGTH_IN_DR: Double = 10
    static let PIXEL_LENGTH_TO_FIND_NODE: Double = 20
    static let OUTPUT_AMBIGUITY_RATIO: Double = 0.88
    static let MODE_CHANGE_TIME_AFTER_ROUTE_TRACK: Double = 30*1000 // 30 seconds
    
    // Path-Matching
    static let HEADING_RANGE: Double = 46
    static var PADDING_VALUE: Double = 15
    static var PADDING_VALUE_SMALL: Double = 15
    static var PADDING_VALUE_LARGE: Double = 20
    static var PADDING_VALUES: [Double] = [10, 10, 10, 10]
    
    public func setSectorInfoConstants(sector_info: SectorInfo) {
        OlympusConstants.STANDARD_MIN_RSS = sector_info.standard_min_rss
        OlympusConstants.STANDARD_MAX_RSS = sector_info.standard_max_rss
        OlympusConstants.USER_TRAJECTORY_LENGTH = sector_info.user_traj_length
        OlympusConstants.USER_TRAJECTORY_LENGTH_DR = sector_info.user_traj_length_dr
        OlympusConstants.USER_TRAJECTORY_LENGTH_PDR = sector_info.user_traj_length_pdr
        OlympusConstants.NUM_STRAIGHT_IDX_DR = sector_info.num_straight_idx_dr
        OlympusConstants.NUM_STRAIGHT_IDX_PDR = sector_info.num_straight_idx_pdr
        
        if (OlympusConstants.REQUIRED_LENGTH_PHASE2 >= sector_info.user_traj_length_dr) {
            OlympusConstants.REQUIRED_LENGTH_PHASE2 = round(sector_info.user_traj_length_dr/2)
        }
    }
    
    public func setNormalizationScale(cur: Double, pre: Double) {
        OlympusConstants.NORMALIZATION_SCALE     = cur
        OlympusConstants.PRE_NORMALIZATION_SCALE = pre
    }
}
