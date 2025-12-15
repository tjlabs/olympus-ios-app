
import Foundation

class JupiterTime {
    static let SECONDS_TO_MILLIS: Int = 1000
    static let OUTPUT_INTEVAL: TimeInterval = 1/5 // seconds
    static let LANDMARK_CHECK_INTERVAL: TimeInterval = 2 // seconds
    static let RFD_INTERVAL: TimeInterval = 1/2
    static let UVD_INTERVAL: TimeInterval = 1/40
    
    static let SAMPLE_HZ: Double = 40 // Hz
    
    static let MINIMUM_BUILDING_LEVEL_CHANGE_TIME: Double = 7000
    static let TIME_INIT_THRESHOLD: Double = 25 * 1000 // seconds
    static let TIME_INIT: Double = TIME_INIT_THRESHOLD + 1000
}
