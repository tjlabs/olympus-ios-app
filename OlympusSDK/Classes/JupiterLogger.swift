
import Foundation

public class JupiterLogger {
    static let TJ_RESULT_TAG = "TJLabsOlympusResult"
    static let TJ_NETWORK_TAG = "TJLabsNetworkResult"
    static let TJ_DEFAULT_TAG = "TJLabsOlympusSDK"
    static let TJ_CALC_TAG = "TJLabsCalc"
    static let TJ_UNIT_DR_TAG = "TJLabsUnitDR"
    static let TJ_BLE_TAG = "TJLabsBluetooth"
    static let TJ_KALMAN_FILTER_TAG = "TJLabsKalman"
    static let TJ_BUILDING_LEVEL_TAG = "TJLabsBuildingLevel"
    static let TJ_PATH_MATCHING_TAG = "TJLabsPathMatching"
    static let TJ_ROUTE_TAG = "TJLabsRouteTracking"
    static let TJ_RSS_COMPENSATOR_TAG = "TJLabsRssCompensate"
    static let TJ_SENSOR_TAG = "TJLabsSensor"
    static let TJ_SERVICE_MANAGER_TAG = "TJLabsServiceManager"
    static let TJ_TRAJECTORY_TAG = "TJLabsTrajectory"
    static let TJ_USEFUL_FUNC_TAG = "TJLabsUsefulFunction"
    static let TJ_RETURN_RESULT_TAG = "TJLabsUpdateResult"
    
    static var debugOption = true
    static var infoOption = true
    
    public static func setDebugOption(set: Bool) {
        debugOption = set
    }
    
    public static func setInfoOption(set: Bool) {
        infoOption = set
    }
    
    static func d(tag: String, message: String) {
        if debugOption {
            print("[DEBUG] [\(tag)] \(message)")
        }
    }
    
    static func i(tag: String, message: String) {
        if debugOption {
            print("[INFO]  [\(tag)] \(message)")
        }
    }
    
    static func w(tag: String, message: String) {
        if debugOption {
            print("[WARN]  [\(tag)] \(message)")
        }
    }
    
    static func e(tag: String, message: String) {
        if debugOption {
            print("[ERROR] [\(tag)] \(message)")
        }
    }
}
