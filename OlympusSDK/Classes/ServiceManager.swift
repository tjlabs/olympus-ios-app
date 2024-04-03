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
    var pmCalculator = PathMatchingCalculator()
    
    // ----- Sector Param ----- //
    var isSaveMobileResult: Bool = false

    var EntranceArea = [String: [[Double]]]()
    var EntranceMatchingArea = [String: [[Double]]]()
    var LevelChangeArea = [String: [[Double]]]()
    var PathPixelVersion = [String: String]()
    var isLoadPp = [String: Bool]()
    var EntranceRouteVersion = [String: String]()
    var EntranceRouteLevel = [String: [String]]()
    var EntranceRouteCoord = [String: [[Double]]]()
    var isLoadEr = [String: Bool]()
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
                                self.setSectorInfo(sector_id: sector_id, sectorInfo: sectorInfoFromServer.1)
                                
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
    
    private func setSectorInfo(sector_id: Int, sectorInfo: SectorInfoFromServer) {
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
                    for entrance in element.entrance_list {
                        let entranceKey = "\(key)_\(entrance.spot_number)"
                        self.EntranceNetworkStatus[entranceKey] = entrance.network_status
                        self.EntranceVelocityScales[entranceKey] = entrance.scale
                        self.EntranceRouteVersion[entranceKey] = entrance.route_version
                        entranceOuterWards.append(entrance.outermost_ward_id)
                    }
                    self.EntranceOuterWards = entranceOuterWards
                }
                self.PathPixelVersion[key] = element.path_pixel_version
            }
        }
        // Entrance Route 버전 확인
        self.loadEntranceRoute(sector_id: sector_id, RouteVersion: self.EntranceRouteVersion)
        // PP 버전 확인
        self.loadPathPixel(sector_id: sector_id, PathPixelVersion: self.PathPixelVersion)
    }
    
    private func saveEntranceRouteLocalUrl(key: String, url: String) {
        let currentTime = getCurrentTimeInMilliseconds()
        print(getLocalTimeString() + " , (Olympus) Save \(key) Entrance Route Local URL : \(url)")
        
        do {
            let key: String = "OlympusEntranceRouteLocalUrl_\(key)"
            UserDefaults.standard.set(url, forKey: key)
        }
    }
    
    private func loadEntranceRouteLocalUrl(key: String) -> (Bool, String?) {
        let keyEntranceRouteUrl: String = "OlympusEntranceRouteLocalUrl_\(key)"
        if let loadedEntranceRouteUrl: String = UserDefaults.standard.object(forKey: keyEntranceRouteUrl) as? String {
            return (true, loadedEntranceRouteUrl)
        } else {
            return (false, nil)
        }
    }
    
    private func saveEntranceRouteVersion(key: String, routeVersion: String) {
        let currentTime = getCurrentTimeInMilliseconds()
        print(getLocalTimeString() + " , (Olympus) Save \(key) Entrance Route Version : \(routeVersion)")
        do {
            let key: String = "OlympusEntranceRouteVersion_\(key)"
            UserDefaults.standard.set(routeVersion, forKey: key)
        }
    }
    
    private func loadEntranceRoute(sector_id: Int, RouteVersion: [String: String]) {
        for (key, value) in RouteVersion {
            // Cache를 통해 PP 버전을 확인
            let keyRouteVersion: String = "OlympusEntranceRouteVersion_\(key)"
            if let loadedRouteVersion: String = UserDefaults.standard.object(forKey: keyRouteVersion) as? String {
                if value == loadedRouteVersion {
                    // 만약 버전이 같다면 파일을 가져오기
                    let routeLocalUrl = loadEntranceRouteLocalUrl(key: key)
                    if (routeLocalUrl.0) {
                        do {
                            let contents = routeLocalUrl.1!
                            let parsedData = parseEntrance(data: contents)
                            EntranceRouteLevel[key] = parsedData.0
                            EntranceRouteCoord[key] = parsedData.1
                            isLoadEr[key] = true
                        }
                    } else {
                        // 첫 시작과 동일하게 다운로드 받아오기
                        let building_level_entrance = key.split(separator: "_")
                        let routeUrl: String = CSV_URL + "/entrance-route/\(sector_id)/\(building_level_entrance[0])/\(building_level_entrance[1])/\(building_level_entrance[2])/\(value)/\(OlympusConstants.OPERATING_SYSTEM).csv"
                        let urlComponents = URLComponents(string: routeUrl)
                        fileDownloader.downloadCSVFile(from: (urlComponents?.url)!, fname: key, completion: { [self] url, error in
                            if error == nil {
                                do {
                                    let contents = try String(contentsOf: url!)
                                    let parsedData = parseEntrance(data: contents)
                                    EntranceRouteLevel[key] = parsedData.0
                                    EntranceRouteCoord[key] = parsedData.1
                                    saveEntranceRouteVersion(key: key, routeVersion: value)
                                    saveEntranceRouteLocalUrl(key: key, url: contents)
                                    isLoadEr[key] = true
                                } catch {
                                    isLoadEr[key] = false
                                    print("Error reading file:", error.localizedDescription)
                                }
                            } else {
                                isLoadEr[key] = false
                            }
                        })
                    }
                } else {
                    // 만약 버전이 다르면 다운로드 받아오기
                    // 첫 시작과 동일하게 다운로드 받아오기
                    let building_level_entrance = key.split(separator: "_")
                    let routeUrl: String = CSV_URL + "/entrance-route/\(sector_id)/\(building_level_entrance[0])/\(building_level_entrance[1])/\(building_level_entrance[2])/\(value)/\(OlympusConstants.OPERATING_SYSTEM).csv"
                    let urlComponents = URLComponents(string: routeUrl)
                    fileDownloader.downloadCSVFile(from: (urlComponents?.url)!, fname: key, completion: { [self] url, error in
                        if error == nil {
                            do {
                                let contents = try String(contentsOf: url!)
                                let parsedData = parseEntrance(data: contents)
                                EntranceRouteLevel[key] = parsedData.0
                                EntranceRouteCoord[key] = parsedData.1
                                saveEntranceRouteVersion(key: key, routeVersion: value)
                                saveEntranceRouteLocalUrl(key: key, url: contents)
                                isLoadEr[key] = true
                            } catch {
                                isLoadEr[key] = false
                                print("Error reading file:", error.localizedDescription)
                            }
                        } else {
                            isLoadEr[key] = false
                        }
                    })
                }
            } else {
                // 첫 시작이면 다운로드 받아오기
                let building_level_entrance = key.split(separator: "_")
                let routeUrl: String = CSV_URL + "/entrance-route/\(sector_id)/\(building_level_entrance[0])/\(building_level_entrance[1])/\(building_level_entrance[2])/\(value)/\(OlympusConstants.OPERATING_SYSTEM).csv"
                let urlComponents = URLComponents(string: routeUrl)
                fileDownloader.downloadCSVFile(from: (urlComponents?.url)!, fname: key, completion: { [self] url, error in
                    if error == nil {
                        do {
                            let contents = try String(contentsOf: url!)
                            let parsedData = parseEntrance(data: contents)
                            EntranceRouteLevel[key] = parsedData.0
                            EntranceRouteCoord[key] = parsedData.1
                            saveEntranceRouteVersion(key: key, routeVersion: value)
                            saveEntranceRouteLocalUrl(key: key, url: contents)
                            isLoadEr[key] = true
                        } catch {
                            isLoadEr[key] = false
                            print("Error reading file:", error.localizedDescription)
                        }
                    } else {
                        isLoadEr[key] = false
                    }
                })
            }
        }
    }
    
    private func parseEntrance(data: String) -> ([String], [[Double]]) {
        var entracneLevelArray = [String]()
        var entranceArray = [[Double]]()

        let entranceString = data.components(separatedBy: .newlines)
        for i in 0..<entranceString.count {
            if (entranceString[i] != "") {
                let lineData = entranceString[i].components(separatedBy: ",")
                
                let entrance: [Double] = [(Double(lineData[1])!), (Double(lineData[2])!), (Double(lineData[3])!)]
                
                entracneLevelArray.append(lineData[0])
                entranceArray.append(entrance)
            }
        }
        
        return (entracneLevelArray, entranceArray)
    }
    
    
    private func savePathPixelLocalUrl(key: String, url: String) {
        let currentTime = getCurrentTimeInMilliseconds()
        print(getLocalTimeString() + " , (Olympus) Save \(key) Path-Pixel Local URL : \(url)")
        
        do {
            let key: String = "OlympusPathPixelLocalUrl_\(key)"
            UserDefaults.standard.set(url, forKey: key)
        }
    }
    
    private func loadPathPixelLocalUrl(key: String) -> (Bool, String?) {
        let keyPpLocalUrl: String = "OlympusPathPixelLocalUrl_\(key)"
        if let loadedPpLocalUrl: String = UserDefaults.standard.object(forKey: keyPpLocalUrl) as? String {
            return (true, loadedPpLocalUrl)
        } else {
            return (false, nil)
        }
    }
    
    private func savePathPixelVersion(key: String, ppVersion: String) {
        let currentTime = getCurrentTimeInMilliseconds()
        print(getLocalTimeString() + " , (Olympus) Save \(key) Path-Pixel Version : \(ppVersion)")
        do {
            let key: String = "OlympusPathPixelVersion_\(key)"
            UserDefaults.standard.set(ppVersion, forKey: key)
        }
    }
    
    private func loadPathPixel(sector_id: Int, PathPixelVersion: [String: String]) {
        for (key, value) in PathPixelVersion {
            // Cache를 통해 PP 버전을 확인
            let keyPpVersion: String = "OlympusPathPixelVersion_\(key)"
            if let loadedPpVersion: String = UserDefaults.standard.object(forKey: keyPpVersion) as? String {
                if value == loadedPpVersion {
                    // 만약 버전이 같다면 파일을 가져오기
                    let ppLocalUrl = loadPathPixelLocalUrl(key: key)
                    if (ppLocalUrl.0) {
                        do {
                            let contents = ppLocalUrl.1!
                            ( pmCalculator.PpType[key], pmCalculator.PpCoord[key], pmCalculator.PpMagScale[key], pmCalculator.PpHeading[key] ) = pmCalculator.parseRoad(data: contents)
                            isLoadPp[key] = true
                        }
                    } else {
                        // 첫 시작과 동일하게 다운로드 받아오기
                        let building_n_level = key.split(separator: "_")
                        let ppUrl: String = CSV_URL + "/path-pixel/\(sector_id)/\(building_n_level[0])/\(building_n_level[1])/\(value)/\(OlympusConstants.OPERATING_SYSTEM).csv"
                        let urlComponents = URLComponents(string: ppUrl)
                        fileDownloader.downloadCSVFile(from: (urlComponents?.url)!, fname: key, completion: { [self] url, error in
                            if error == nil {
                                do {
                                    let contents = try String(contentsOf: url!)
                                    ( pmCalculator.PpType[key], pmCalculator.PpCoord[key], pmCalculator.PpMagScale[key], pmCalculator.PpHeading[key] ) = pmCalculator.parseRoad(data: contents)
                                    savePathPixelVersion(key: key, ppVersion: value)
                                    savePathPixelLocalUrl(key: key, url: contents)
                                    isLoadPp[key] = true
                                } catch {
                                    isLoadPp[key] = false
                                    print("Error reading file:", error.localizedDescription)
                                }
                            } else {
                                isLoadPp[key] = false
                            }
                        })
                    }
                } else {
                    // 만약 버전이 다르면 다운로드 받아오기
                    // 첫 시작과 동일하게 다운로드 받아오기
                    let building_n_level = key.split(separator: "_")
                    let ppUrl: String = CSV_URL + "/path-pixel/\(sector_id)/\(building_n_level[0])/\(building_n_level[1])/\(value)/\(OlympusConstants.OPERATING_SYSTEM).csv"
                    let urlComponents = URLComponents(string: ppUrl)
                    fileDownloader.downloadCSVFile(from: (urlComponents?.url)!, fname: key, completion: { [self] url, error in
                        if error == nil {
                            do {
                                let contents = try String(contentsOf: url!)
                                ( pmCalculator.PpType[key], pmCalculator.PpCoord[key], pmCalculator.PpMagScale[key], pmCalculator.PpHeading[key] ) = pmCalculator.parseRoad(data: contents)
                                savePathPixelVersion(key: key, ppVersion: value)
                                savePathPixelLocalUrl(key: key, url: contents)
                                isLoadPp[key] = true
                            } catch {
                                isLoadPp[key] = false
                                print("Error reading file:", error.localizedDescription)
                            }
                        } else {
                            isLoadPp[key] = false
                        }
                    })
                }
            } else {
                // 첫 시작이면 다운로드 받아오기
                let building_n_level = key.split(separator: "_")
                let ppUrl: String = CSV_URL + "/path-pixel/\(sector_id)/\(building_n_level[0])/\(building_n_level[1])/\(value)/\(OlympusConstants.OPERATING_SYSTEM).csv"
                let urlComponents = URLComponents(string: ppUrl)
                fileDownloader.downloadCSVFile(from: (urlComponents?.url)!, fname: key, completion: { [self] url, error in
                    if error == nil {
                        do {
                            let contents = try String(contentsOf: url!)
                            ( pmCalculator.PpType[key], pmCalculator.PpCoord[key], pmCalculator.PpMagScale[key], pmCalculator.PpHeading[key] ) = pmCalculator.parseRoad(data: contents)
                            savePathPixelVersion(key: key, ppVersion: value)
                            savePathPixelLocalUrl(key: key, url: contents)
                            isLoadPp[key] = true
                        } catch {
                            isLoadPp[key] = false
                            print("Error reading file:", error.localizedDescription)
                        }
                    } else {
                        isLoadPp[key] = false
                    }
                })
            }
        }
    }
    
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
                                            if let closest = self.findClosestOs(to: os_version, in: rcDeviceResult.1.rss_compensations) {
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
    
    private func findClosestOs(to myOsVersion: Int, in array: [RcInfo]) -> RcInfo? {
        guard let first = array.first else {
            return nil
        }
        var closest = first
        var closestDistance = closest.os_version - myOsVersion
        for d in array {
            let distance = d.os_version - myOsVersion
            if abs(distance) < abs(closestDistance) {
                closest = d
                closestDistance = distance
            }
        }
        return closest
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
