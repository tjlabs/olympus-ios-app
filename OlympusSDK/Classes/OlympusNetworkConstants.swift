let TIMEOUT_VALUE_PUT: Double = 5.0
let TIMEOUT_VALUE_POST: Double = 5.0

let USER_SERVER_VERSION = "2024-06-12"
let USER_SCALE_SERVER_VERSION = "2024-11-14"
let USER_LEVEL_SERVER_VERSION = "2024-11-13"
let USER_UNIT_SERVER_VERSION = "2024-11-13"
let USER_PARAM_SERVER_VERSION = "2024-11-13"
let USER_PATH_SERVER_VERSION = "2024-11-14"
let USER_GEO_SERVER_VERSION = "2024-11-15"
let USER_ENTERANCE_SERVER_VERSION = "2024-11-14"

let CALC_FLT_SERVER_VERSION = "2024-11-18"  // 10-08
let CALC_OSR_SERVER_VERSION = "2024-08-30"
let REC_SERVER_VERSION = "2024-04-19"
let BLACK_LIST_URL = "https://ap-northeast-2.client.olympus.tjlabs.dev/black"

let HTTP_PREFIX = "https://"
var REGION_PREFIX = "ap-northeast-2."
let OLYMPUS_SUFFIX = ".olympus.tjlabs.dev"
var REGION_NAME = "Korea"

var USER_URL = "user"
var IMAGE_URL = "img"
var CSV_URL = "csv"
var REC_URL = "rec"
var CALC_URL = "calc"
var TEST_URL = "test"

var USER_LOGIN_URL = ""
var USER_CARD_URL = ""
var USER_ORDER_URL = ""
var USER_SCALE_URL = ""
var USER_RC_URL = ""

var USER_LEVEL_URL = ""
var USER_UNIT_URL = ""
var USER_PARAM_URL = ""
var USER_PATH_URL = ""
var USER_GEO_URL = ""
var USER_ENTRANCE_URL = ""

var REC_RFD_URL = ""
var REC_UVD_URL = ""
var REC_UMD_URL = ""
var REC_RESULT_URL = ""
var REC_REPORT_URL = ""
var REC_RC_URL = ""

var CALC_OSR_URL = ""
var CALC_FLT_URL = ""

public func setServerURL(region: String) {
    switch (region) {
    case "Korea":
        REGION_PREFIX = "ap-northeast-2."
        REGION_NAME = "Korea"
    case "Canada":
        REGION_PREFIX = "ca-central-1."
        REGION_NAME = "Canada"
    case "US-East":
        REGION_PREFIX = "us-east-1."
        REGION_NAME = "US-East"
    default:
        REGION_PREFIX = "ap-northeast-2."
        REGION_NAME = "Korea"
    }
    
    USER_URL = HTTP_PREFIX + REGION_PREFIX + "user" + OLYMPUS_SUFFIX
    IMAGE_URL = HTTP_PREFIX + REGION_PREFIX + "img" + OLYMPUS_SUFFIX
    CSV_URL = HTTP_PREFIX + REGION_PREFIX + "csv" + OLYMPUS_SUFFIX
    REC_URL = HTTP_PREFIX + REGION_PREFIX + "rec" + OLYMPUS_SUFFIX
    CALC_URL = HTTP_PREFIX + REGION_PREFIX + "calc" + OLYMPUS_SUFFIX
    TEST_URL = HTTP_PREFIX + REGION_PREFIX + "test" + OLYMPUS_SUFFIX
    
    USER_LOGIN_URL = USER_URL + "/" + USER_SERVER_VERSION + "/user"
    USER_CARD_URL = USER_URL + "/" + USER_SERVER_VERSION + "/card"
    USER_ORDER_URL = USER_URL + "/" + USER_SERVER_VERSION + "/order"
    USER_SCALE_URL = USER_URL + "/" + USER_SCALE_SERVER_VERSION + "/scale"
    
    USER_LEVEL_URL = USER_URL + "/" + USER_LEVEL_SERVER_VERSION + "/level"
    USER_UNIT_URL = USER_URL + "/" + USER_UNIT_SERVER_VERSION + "/unit"
    USER_PARAM_URL = USER_URL + "/" + USER_PARAM_SERVER_VERSION + "/parameter"
    USER_PATH_URL = USER_URL + "/" + USER_PATH_SERVER_VERSION + "/path"
    USER_GEO_URL = USER_URL + "/" + USER_GEO_SERVER_VERSION + "/geofence"
    USER_ENTRANCE_URL = USER_URL + "/" + USER_ENTERANCE_SERVER_VERSION + "/entrance"
    USER_RC_URL = USER_URL + "/" + USER_SERVER_VERSION + "/rc"
    
    REC_RFD_URL = REC_URL + "/" + REC_SERVER_VERSION + "/rf"
    REC_UVD_URL = REC_URL + "/" + REC_SERVER_VERSION + "/uv"
    REC_UMD_URL = REC_URL + "/" + REC_SERVER_VERSION + "/um"
    REC_RESULT_URL  = REC_URL + "/" + REC_SERVER_VERSION + "/mr"
    REC_REPORT_URL  = REC_URL + "/" + REC_SERVER_VERSION + "/mt"
    REC_RC_URL = REC_URL + "/" + REC_SERVER_VERSION + "/rc"
    
    CALC_OSR_URL = CALC_URL + "/" + CALC_OSR_SERVER_VERSION + "/osr"
    CALC_FLT_URL = CALC_URL + "/" + CALC_FLT_SERVER_VERSION + "/flt"
}
