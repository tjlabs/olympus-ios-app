
import TJLabsCommon

class JupiterMode {
    static var REQUIRED_LENGTH_FOR_MAJOR_HEADING: Double = 10
    
    static var HEADING_RANGE: Double = 46
    static var DEFAULT_HEADINGS: [Float] = [0, 90, 180, 270]

    static var PADDING_VALUE_SMALL: Float = 10
    static var PADDING_VALUE_MEDIUM: Float = 20

    static var PADDING_VALUES_SMALL: [Float] = Array(repeating: PADDING_VALUE_SMALL, count: 4)
    static var PADDING_VALUES_MEDIUM: [Float] = Array(repeating: PADDING_VALUE_MEDIUM, count: 4)
    static var PADDING_VALUES_LARGE: [Float] = Array(repeating: PADDING_VALUE_MEDIUM*2, count: 4)
    static var PADDING_VALUES_HUGE: [Float] = Array(repeating: PADDING_VALUE_MEDIUM*3, count: 4)
    
    static let HEADING_UNCERTANTIY: Float = 2.0
    
    static let SLEEP_THRESHOLD: Double = 600 * 1000
}

