
import TJLabsCommon

class JupiterMode {
    static var REQUIRED_LENGTH_FOR_MAJOR_HEADING: Double = 10
    
    static var HEADING_RANGE: Double = 46
    static var DEFAULT_HEADINGS: [Float] = [0, 90, 180, 270]

    static var PADDING_VALUE_SMALL: Float = 10
    static var PADDING_VALUE_LARGE: Float = 20

    static var PADDING_VALUES_PDR: [Float] = Array(repeating: PADDING_VALUE_SMALL, count: 4)
    static var PADDING_VALUES_DR: [Float] = Array(repeating: PADDING_VALUE_LARGE, count: 4)
    static var PADDING_VALUES_LARGE: [Float] = Array(repeating: PADDING_VALUE_LARGE*2, count: 4)
    static var PADDING_VALUES_VERY_LARGE: [Float] = Array(repeating: PADDING_VALUE_LARGE*3, count: 4)
    
    static let HEADING_UNCERTANTIY: Float = 2.0
    
    static let SLEEP_THRESHOLD: Double = 600 * 1000
}

