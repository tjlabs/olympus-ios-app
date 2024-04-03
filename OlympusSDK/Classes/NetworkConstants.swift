let TIMEOUT_VALUE_PUT: Double = 5.0
let TIMEOUT_VALUE_POST: Double = 5.0

let SERVER_VERSION = "2024-03-19"

let HTTP_PREFIX = "https://"
var REGION_PREFIX = "ap-northeast-2."
let OLMPUS_SUFFIX = ".olympus.tjlabs.dev"

var USER_URL = "user"
var IMAGE_URL = "img"
var CSV_URL = "csv"

var USER_LOGIN_URL = ""
var USER_CARD_URL = ""
var USER_ORDER_URL = ""
var USER_SCALE_URL = ""
var USER_SECTOR_URL = ""
var USER_RC_URL = ""


public func setServerURL(region: String) {
    switch (region) {
    case "Korea":
        REGION_PREFIX = "ap-northeast-2."
    case "Canada":
        REGION_PREFIX = "ca-central-1."
    default:
        REGION_PREFIX = "ap-northeast-2."
    }
    
    USER_URL = HTTP_PREFIX + REGION_PREFIX + "user" + OLMPUS_SUFFIX
    IMAGE_URL = HTTP_PREFIX + REGION_PREFIX + "img" + OLMPUS_SUFFIX
    CSV_URL = HTTP_PREFIX + REGION_PREFIX + "csv" + OLMPUS_SUFFIX
    
    USER_LOGIN_URL = USER_URL + "/" + SERVER_VERSION + "/user"
    USER_CARD_URL = USER_URL + "/" + SERVER_VERSION + "/card"
    USER_ORDER_URL = USER_URL + "/" + SERVER_VERSION + "/order"
    USER_SCALE_URL = USER_URL + "/" + SERVER_VERSION + "/scale"
    USER_SECTOR_URL = USER_URL + "/" + SERVER_VERSION + "/sector"
    USER_RC_URL = USER_URL + "/" + SERVER_VERSION + "/rc"
}
