
import Foundation

public class NavigationNetworkConstants {
    static let TIMEOUT_VALUE_PUT: TimeInterval = 5.0
    static let TIMEOUT_VALUE_POST: TimeInterval = 5.0

    static let CALC_DIRECTIONS_SERVER_VERSION = "2026-03-23"
    
    static let OPERATING_SYSTEM: String = "iOS"
    private static let HTTP_PREFIX = "https://"
    private static let JUPITER_SUFFIX = ".jupiter.tjlabs.dev"
    
    private(set) static var REGION_PREFIX = "ap-northeast-2."
    private(set) static var REGION_NAME = "Korea"
    
    private(set) static var USER_URL = HTTP_PREFIX + REGION_PREFIX + "user" + JUPITER_SUFFIX
    private(set) static var IMAGE_URL = HTTP_PREFIX + REGION_PREFIX + "img" + JUPITER_SUFFIX
    private(set) static var CSV_URL = HTTP_PREFIX + REGION_PREFIX + "csv" + JUPITER_SUFFIX
    private(set) static var REC_URL = HTTP_PREFIX + REGION_PREFIX + "rec" + JUPITER_SUFFIX
    private(set) static var CALC_URL = HTTP_PREFIX + REGION_PREFIX + "calc" + JUPITER_SUFFIX
    private(set) static var CLIENT_URL = HTTP_PREFIX + REGION_PREFIX + "client" + JUPITER_SUFFIX
    
    public static func setServerURL(region: String) {
        switch region {
        case JupiterRegion.KOREA.rawValue:
            REGION_PREFIX = "ap-northeast-2."
            REGION_NAME = "Korea"
        case JupiterRegion.KOREA.rawValue:
            REGION_PREFIX = "ca-central-1."
            REGION_NAME = "Canada"
        case JupiterRegion.KOREA.rawValue:
            REGION_PREFIX = "us-east-1."
            REGION_NAME = "US"
        default:
            REGION_PREFIX = "ap-northeast-2."
            REGION_NAME = "Korea"
        }
        
        USER_URL = HTTP_PREFIX + REGION_PREFIX + "user" + JUPITER_SUFFIX
        IMAGE_URL = HTTP_PREFIX + REGION_PREFIX + "img" + JUPITER_SUFFIX
        CSV_URL = HTTP_PREFIX + REGION_PREFIX + "csv" + JUPITER_SUFFIX
        REC_URL = HTTP_PREFIX + REGION_PREFIX + "rec" + JUPITER_SUFFIX
        CALC_URL = HTTP_PREFIX + REGION_PREFIX + "calc" + JUPITER_SUFFIX
        CLIENT_URL = HTTP_PREFIX + REGION_PREFIX + "client" + JUPITER_SUFFIX
    }
    
    public static func getUserBaseURL() -> String {
        return USER_URL
    }
    
    public static func getRecBaseURL() -> String {
        return REC_URL
    }
    
    public static func getCalcBaseURL() -> String {
        return CALC_URL
    }
    
    public static func getClientBaseURL() -> String {
        return CLIENT_URL
    }
    
    public static func getCalcDirsServerVersion() -> String {
        return CALC_DIRECTIONS_SERVER_VERSION
    }
    
    public static func getCalcDirsURL() -> String {
        return CALC_URL + "/" + CALC_DIRECTIONS_SERVER_VERSION + "/directions"
    }
}
