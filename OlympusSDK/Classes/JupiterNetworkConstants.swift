
import Foundation

public class JupiterNetworkConstants {
    static let TIMEOUT_VALUE_PUT: TimeInterval = 5.0
    static let TIMEOUT_VALUE_POST: TimeInterval = 5.0
    
    static let USER_LOGIN_SERVER_VERSION = "2025-03-26"
    static let USER_RC_SERVER_VERSION = "2024-06-12"
    
    static let REC_RFD_SERVER_VERSION = "2025-04-02"
    static let REC_UVD_SERVER_VERSION = "2025-04-02"
    static let REC_MOBILE_RESULT_SERVER_VERSION = "2025-08-11"
    static let REC_MOBILE_REPORT_SERVER_VERSION = "2025-04-02"

    static let CALC_OPE_SERVER_VERSION = "1994-07-29" // 있다고 가정
    
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
    
    public static func getUserLoginVersion() -> String {
        return USER_LOGIN_SERVER_VERSION
    }
    
    public static func getUserRcVersion() -> String {
        return USER_RC_SERVER_VERSION
    }
    
    public static func getRecRfdServerVersion() -> String {
        return REC_RFD_SERVER_VERSION
    }
    
    public static func getRecUvdServerVersion() -> String {
        return REC_UVD_SERVER_VERSION
    }
    
    public static func getRecMobileResultServerVersion() -> String {
        return REC_MOBILE_RESULT_SERVER_VERSION
    }
    
    public static func getUserLoginURL() -> String {
        return USER_URL + "/" + USER_LOGIN_SERVER_VERSION + "/tenants/user"
    }
    
    public static func getUserRcURL() -> String {
        return USER_URL + "/" + USER_RC_SERVER_VERSION + "/rssi-compensation-result"
    }
    
    public static func getRecRfdURL() -> String {
        return REC_URL + "/" + REC_RFD_SERVER_VERSION + "/received-force"
    }
    
    public static func getRecUvdURL() -> String {
        return REC_URL + "/" + REC_UVD_SERVER_VERSION + "/user-velocity"
    }
    
    public static func getRecMobileResultURL() -> String {
        return REC_URL + "/" + REC_MOBILE_RESULT_SERVER_VERSION + "/mobile-result"
    }
    
    public static func getRecMobileReportURL() -> String {
        return REC_URL + "/" + REC_MOBILE_REPORT_SERVER_VERSION + "/mobile-report"
    }
    
    public static func getCalcOpeURL() -> String {
        return CALC_URL + "/" + CALC_OPE_SERVER_VERSION + "/ope"
    }
    
    public static func getClientBlacklistURL() -> String {
        return CLIENT_URL + "/black"
    }
}
