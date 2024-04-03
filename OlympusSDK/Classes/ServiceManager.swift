import Foundation
import CoreMotion
import UIKit

public class ServiceManager: NSObject {
    public static let sdkVersion: String = "0.1.0"
    var deviceModel: String
    var deviceOsVersion: Int
    
    var sensorManager = SensorManager()
    var bleManager = BLECentralManager()
    var rssCompensator = RssCompensator()
    var phaseController = PhaseController()
    var fileDownloader = OlympusFileDownloader()
    
    // ----- Sector Param ----- //
    var isSaveMobileResult: Bool = false

    var EntranceArea = [String: [[Double]]]()
    var EntranceMatchingArea = [String: [[Double]]]()
    var LevelChangeArea = [String: [[Double]]]()
    var PathPixelVersion = [String: String]()
    var isLoadPp = [String: Bool]()
    var EntranceRouteVersion = [String: String]()
    var EntranceNetworkStatus = [String: Bool]()
    var EntranceOuterWards = [String]()
    var EntranceVelocityScales = [String: Double]()
    
    // ----- Rss Compensation ----- //
    var normalizationScale: Double = 1.0
    var preNormalizationScale: Double = 1.0
    
    // ----- State Observer ----- //
    var isVenusMode: Bool = false
    private var venusObserver: Any!
    private var jupiterObserver: Any!
    
    public override init() {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"
        dateFormatter.locale = Locale(identifier:"ko_KR")
        let nowDate = Date()
        
        self.deviceModel = UIDevice.modelName
        let deviceOs = UIDevice.current.systemVersion
        let arr = deviceOs.components(separatedBy: ".")
        self.deviceOsVersion = Int(arr[0]) ?? 0
    }
    
    public func startService(user_id: String, region: String, sector_id: Int, completion: @escaping (Bool, String) -> Void) {
        if (user_id.isEmpty || user_id.contains(" ")) {
            let msg: String = getLocalTimeString() + " , (Olympus) Error : User ID(input = \(user_id)) cannot be empty or contain space"
            completion(false, msg)
        } else {
            setServerURL(region: region)
            let loginInput = LoginInput(user_id: user_id, device_model: self.deviceModel, os_version: self.deviceOsVersion, sdk_version: ServiceManager.sdkVersion)
            NetworkManager.shared.postUserLogin(url: USER_LOGIN_URL, input: loginInput, completion: { statusCode, returnedString in
                if (statusCode == 200) {
                    let sectorInput = SectorInput(sector_id: sector_id, operating_system: OlympusConstants.OPERATING_SYSTEM)
                    NetworkManager.shared.postUserSector(url: USER_SECTOR_URL, input: sectorInput, completion: { statusCode, returnedString in
                        if (statusCode == 200) {
                            let sectorInfoFromServer = jsonToSectorInfoFromServer(jsonString: returnedString)
                            if (sectorInfoFromServer.0) {
                                self.setSectorInfo(sectorInfo: sectorInfoFromServer.1)
                                
                                completion(true, returnedString)
                            } else {
                                let msg: String = getLocalTimeString() + " , (Olympus) Error : Decode SectorInfo"
                                completion(false, returnedString)
                            }
                        } else {
                            let msg: String = getLocalTimeString() + " , (Olympus) Error : Load Sector Info (id = \(sector_id))"
                            completion(false, msg)
                        }
                    })
                } else {
                    let msg: String = getLocalTimeString() + " , (Olympus) Error : User ID(input = \(user_id)) Login Error"
                    completion(false, msg)
                }
            })
        }
    }
    
    private func setSectorInfo(sectorInfo: SectorInfoFromServer) {
        let sectorParam: SectorInfoParam = sectorInfo.parameter
        self.isSaveMobileResult = sectorParam.debug
        let stadard_rss: [Int] = sectorParam.standard_rss
        
        OlympusConstants.STANDARD_MIN_RSS = Double(stadard_rss[0])
        OlympusConstants.STANDARD_MAX_RSS = Double(stadard_rss[1])
        OlympusConstants.USER_TRAJECTORY_ORIGINAL = Double(sectorParam.trajectory_length + 10)
        OlympusConstants.USER_TRAJECTORY_LENGTH = Double(sectorParam.trajectory_length + 10)
        OlympusConstants.USER_TRAJECTORY_DIAGONAL = Double(sectorParam.trajectory_diagonal + 5)
        OlympusConstants.NUM_STRAIGHT_INDEX_DR = Int(ceil(OlympusConstants.USER_TRAJECTORY_LENGTH/6))
        OlympusConstants.NUM_STRAIGHT_INDEX_PDR = Int(ceil(OlympusConstants.USER_TRAJECTORY_DIAGONAL/6))
        
        self.phaseController.setPhaseLengthParam(lengthConditionPdr: Double(sectorParam.trajectory_diagonal), lengthConditionDr: Double(sectorParam.trajectory_length))
        print(getLocalTimeString() + " , (Olympus) Information : User Trajectory Param \(OlympusConstants.USER_TRAJECTORY_LENGTH) // \(OlympusConstants.USER_TRAJECTORY_DIAGONAL) // \(OlympusConstants.NUM_STRAIGHT_INDEX_DR)")
        
        let sectorLevelList = sectorInfo.level_list
        for element in sectorLevelList {
            let buildingName = element.building_name
            let levelName = element.level_name
            if !levelName.contains("_D") {
                let key = "\(buildingName)_\(levelName)"
                let entranceArea = element.geofence.entrance_area
                let entranceMatcingArea = element.geofence.entrance_matching_area
                let levelChangeArea = element.geofence.level_change_area
                
                if !entranceArea.isEmpty { self.EntranceArea[key] = entranceArea }
                if !entranceMatcingArea.isEmpty { self.EntranceMatchingArea[key] = entranceMatcingArea }
                if !levelChangeArea.isEmpty { self.LevelChangeArea[key] = levelChangeArea }
                
                if (levelName == "B0") {
                    var entranceOuterWards: [String] = []
                    print(element.entrance_list)
                    for entrance in element.entrance_list {
                        let entranceKey = "\(entrance.spot_number)"
                        self.EntranceNetworkStatus[entranceKey] = entrance.network_status
                        self.EntranceVelocityScales[entranceKey] = entrance.scale
                        entranceOuterWards.append(entrance.outermost_ward_id)
                    }
                    self.EntranceOuterWards = entranceOuterWards
                }
                self.PathPixelVersion[key] = element.path_pixel_version
            }
        }
    }
    
    private func loadPathPixel(sector_id: Int) {
        // Cache를 통해 PP 버전을 확인
        let keyPpVersion: String = "OlympusPathPixelVersion_\(sector_id)"
//        if let loadedPpVersion:
        
        // 만약 버전이 다르면 다운로드 받아오기
        // 만약 버전이 같다면 파일을 가져오기
    }
    
//    public func loadNormalizationScale(sector_id: Int) -> (Bool, Double) {
//        var isLoadedFromCache: Bool = false
//        var scale: Double = 1.0
//        
//        let keyScale: String = "OlympusNormalizationScale_\(sector_id)"
//        if let loadedScale: Double = UserDefaults.standard.object(forKey: keyScale) as? Double {
//            scale = loadedScale
//            isLoadedFromCache = true
//            if (scale >= 1.7) {
//                scale = 1.0
//            }
//        }
//        
//        return (isLoadedFromCache, scale)
//    }
    
    private func loadRssiCompensationParam(sector_id: Int, device_model: String, os_version: Int, completion: @escaping (Bool, String) -> Void) {
        // Check data in cache
        let loadedScale = rssCompensator.loadNormalizationScale(sector_id: sector_id)
        
        if loadedScale.0 {
            // Scale is in cache
            self.normalizationScale = loadedScale.1
            self.preNormalizationScale = loadedScale.1
            let msg: String = getLocalTimeString() + " , (Olympus) Success : Load RssCompenstaion in cache"
            completion(true, msg)
        } else {
            let rcInputDeviceOs = RcInputDeviceOs(sector_id: sector_id, device_mode: device_model, os_version: os_version)
            NetworkManager.shared.postUserRssCompensation(url: USER_RC_URL, input: rcInputDeviceOs, isDeviceOs: true, completion: { statusCode, returnedString in
                if (statusCode == 200) {
                    let rcResult = jsonToRcInfoFromServer(jsonString: returnedString)
                    if (rcResult.0) {
                        if (rcResult.1.rss_compensations.isEmpty) {
                            let rcInputDevice = RcInputDevice(sector_id: sector_id, device_mode: device_model)
                            NetworkManager.shared.postUserRssCompensation(url: USER_RC_URL, input: rcInputDevice, isDeviceOs: false, completion: { statusCode, returnedString in
                                if (statusCode == 200) {
                                    let rcDeviceResult = jsonToRcInfoFromServer(jsonString: returnedString)
                                    if (rcDeviceResult.0) {
                                        if (rcDeviceResult.1.rss_compensations.isEmpty) {
                                            // Need Normalization-scale Estimation
                                            print(getLocalTimeString() + " , (Olmypus) Information : Need RssCompensation Estimation")
                                            let msg: String = getLocalTimeString() + " , (Olympus) Success : RssCompensation"
                                            completion(true, msg)
                                        } else {
                                            // Succes Load Normalization-scale (Device)
                                            if let closest = findClosestOs(to: os_version, in: rcDeviceResult.1.rss_compensations) {
                                                // Find Closest OS
                                                let rcFromServer: RcInfo = closest
                                                self.normalizationScale = rcFromServer.normalization_scale
                                                self.preNormalizationScale = rcFromServer.normalization_scale
                                                
                                                print(getLocalTimeString() + " , (Olmypus) Information : Load RssCompensation from server (Device)")
                                                let msg: String = getLocalTimeString() + " , (Olympus) Success : RssCompensation"
                                                completion(true, msg)
                                            } else {
                                                // Need Normalization-scale Estimation
                                                print(getLocalTimeString() + " , (Olmypus) Information : Need RssCompensation Estimation")
                                                let msg: String = getLocalTimeString() + " , (Olympus) Success : RssCompensation"
                                                completion(true, msg)
                                            }
                                        }
                                    } else {
                                        let msg: String = getLocalTimeString() + " , (Olympus) Error : Decode RssCompenstaion (Device)"
                                        completion(false, msg)
                                    }
                                } else {
                                    let msg: String = getLocalTimeString() + " , (Olympus) Error : Load RssCompenstaion (Device) from server \(statusCode)"
                                    completion(false, msg)
                                }
                            })
                        } else {
                            // Succes Load Normalization-scale (Device & OS)
                            let rcFromServer: RcInfo = rcResult.1.rss_compensations[0]
                            self.normalizationScale = rcFromServer.normalization_scale
                            self.preNormalizationScale = rcFromServer.normalization_scale
                            
                            print(getLocalTimeString() + " , (Olmypus) Information : Load RssCompensation from server (Device & OS)")
                            let msg: String = getLocalTimeString() + " , (Olympus) Success : RssCompensation"
                            completion(true, msg)
                        }
                    } else {
                        let msg: String = getLocalTimeString() + " , (Olympus) Error : Decode RssCompenstaion (Device & OS)"
                        completion(false, msg)
                    }
                } else {
                    let msg: String = getLocalTimeString() + " , (Olympus) Error : Load RssCompenstaion (Device & OS) from server \(statusCode)"
                    completion(false, msg)
                }
            })
        }
    }
    
    func notificationCenterAddObserver() {
        self.venusObserver = NotificationCenter.default.addObserver(self, selector: #selector(onDidReceiveNotification), name: .didBecomeVenus, object: nil)
        self.jupiterObserver = NotificationCenter.default.addObserver(self, selector: #selector(onDidReceiveNotification), name: .didBecomeJupiter, object: nil)
    }
    
    func notificationCenterRemoveObserver() {
        NotificationCenter.default.removeObserver(self.venusObserver)
        NotificationCenter.default.removeObserver(self.jupiterObserver)
    }
    
    @objc func onDidReceiveNotification(_ notification: Notification) {
        if notification.name == .didBecomeVenus {
            self.isVenusMode = true
        }
    
        if notification.name == .didBecomeJupiter {
            self.isVenusMode = false
        }
    }
}
