import Foundation
import CoreMotion
import UIKit

public class OlympusServiceManager: NSObject {
    public static let sdkVersion: String = "0.1.0"
    var deviceModel: String
    var deviceOsVersion: Int
    
    var sensorManager = OlympusSensorManager()
    var bleManager = OlympusBluetoothManager()
    var rssCompensator = OlympusRssCompensator()
    var phaseController = OlympusPhaseController()
    var fileDownloader = OlympusFileDownloader()
    var pmCalculator = OlympusPathMatchingCalculator()
    var routeTracker = OlympusRouteTracker()
    
    // ----- Sector Param ----- //
    var isSaveMobileResult: Bool = false

    var EntranceArea = [String: [[Double]]]()
    var EntranceMatchingArea = [String: [[Double]]]()
    var LevelChangeArea = [String: [[Double]]]()
    
    
    var PathPixelVersion = [String: String]()
    var isLoadPp = [String: Bool]()
    
    var EntranceRouteVersion = [String: String]()
    var isLoadEr = [String: Bool]()
    var EntranceOuterWards = [String]()
    
    var receivedForceTimer: DispatchSourceTimer?
    var RFD_INTERVAL: TimeInterval = 1/2 // second
    
    // ----- Rss Compensation ----- //
//    var normalizationScale: Double = 1.0
//    var preNormalizationScale: Double = 1.0
    
    // ----- State Observer ----- //
    var runMode: String = "dr"
    var currentMode: String = "dr"
    
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
    
    public func startService(user_id: String, region: String, sector_id: Int, service: String, mode: String, completion: @escaping (Bool, String) -> Void) {
        let success_msg: String =  " , (Olympus) Success : OlmpusService Start"
        
        if (user_id.isEmpty || user_id.contains(" ")) {
            let msg: String = getLocalTimeString() + " , (Olympus) Error : User ID(input = \(user_id)) cannot be empty or contain space"
            completion(false, msg)
        } else {
            let initService = initService(service: service, mode: mode)
            if (initService.0) {
                if (!OlympusNetworkChecker.shared.isConnectedToInternet()) {
                    let msg: String = getLocalTimeString() + " , (Olympus) Error : Network is not connected"
                    completion(false, msg)
                } else {
                    setServerURL(region: region)
                    let loginInput = LoginInput(user_id: user_id, device_model: self.deviceModel, os_version: self.deviceOsVersion, sdk_version: OlympusServiceManager.sdkVersion)
                    OlympusNetworkManager.shared.postUserLogin(url: USER_LOGIN_URL, input: loginInput, completion: { [self] statusCode, returnedString in
                        if (statusCode == 200) {
                            let sectorInput = SectorInput(sector_id: sector_id, operating_system: OlympusConstants.OPERATING_SYSTEM)
                            OlympusNetworkManager.shared.postUserSector(url: USER_SECTOR_URL, input: sectorInput, completion: { [self] statusCode, returnedString in
                                if (statusCode == 200) {
                                    let sectorInfoFromServer = jsonToSectorInfoFromServer(jsonString: returnedString)
                                    if (sectorInfoFromServer.0) {
                                        self.setSectorInfo(sector_id: sector_id, sector_info_from_server: sectorInfoFromServer.1)
                                        rssCompensator.loadRssiCompensationParam(sector_id: sector_id, device_model: deviceModel, os_version: deviceOsVersion, completion: { [self] isSuccess, loadedParam, returnedString in
                                            if (isSuccess) {
                                                OlympusConstants().setNormalizationScale(cur: loadedParam, pre: loadedParam)
                                                print(getLocalTimeString() + " , (Olmypus) Scale : \(OlympusConstants.NORMALIZATION_SCALE)")
                                                print(getLocalTimeString() + " , (Olmypus) Scale : \(OlympusConstants.PRE_NORMALIZATION_SCALE)")
                                                if (!bleManager.bluetoothReady) {
                                                    let msg: String = getLocalTimeString() + " , (Olympus) Error : Bluetooth is not enabled"
                                                    completion(false, msg)
                                                } else {
                                                    completion(true, getLocalTimeString() + success_msg)
                                                }
                                            } else {
                                                completion(false, returnedString)
                                            }
                                        })
                                        completion(true, returnedString)
                                    } else {
                                        let msg: String = getLocalTimeString() + " , (Olympus) Error : Decode SectorInfo"
                                        completion(false, msg)
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
            } else {
                let msg: String = initService.1
                completion(false, msg)
            }
        }
    }
    
    private func initService(service: String, mode: String) -> (Bool, String) {
        let localTime = getLocalTimeString()
        var isSuccess: Bool = true
        var msg: String = ""
        
        if (service.contains(OlympusConstants.SERVICE_FLT)) {
//            unitDRInfo = UnitDRInfo()
//            unitDRGenerator.setMode(mode: mode)
//            self.notificationCenterAddObserver()

            if (mode == "auto") {
                self.runMode = "dr"
                self.currentMode = "dr"
            } else if (mode == "pdr") {
                self.runMode = "pdr"
            } else if (mode == "dr") {
                self.runMode = "dr"
            } else {
                isSuccess = false
                msg = localTime + " , (Jupiter) Error : Invalid Service Mode"
                return (isSuccess, msg)
            }
//            setModeParam(mode: self.runMode, phase: self.phase)
        }
        
        // Init Sensors
        let initSensors = sensorManager.initSensors()
        if (!initSensors.0) {
            isSuccess = initSensors.0
            msg = initSensors.1
            
            return (isSuccess, msg)
        }
        
        // Init Bluetooth
        let initBle = bleManager.initBle()
        if (!initBle.0) {
            isSuccess = initBle.0
            msg = initBle.1
            
            return (isSuccess, msg)
        }
        
        return (isSuccess, msg)
    }
    
    private func setSectorInfo(sector_id: Int, sector_info_from_server: SectorInfoFromServer) {
        let sector_param: SectorInfoParam = sector_info_from_server.parameter
        self.isSaveMobileResult = sector_param.debug
        let stadard_rss: [Int] = sector_param.standard_rss
        
        let sector_info = SectorInfo(standard_min_rss: Double(stadard_rss[0]), standard_max_rss: Double(stadard_rss[1]), user_traj_origin: Double(sector_param.trajectory_length + 10), user_traj_length: Double(sector_param.trajectory_length + 10), user_traj_diag:  Double(sector_param.trajectory_diagonal + 5), num_straight_idx_dr: Int(ceil(OlympusConstants.USER_TRAJECTORY_LENGTH/6)), num_straight_idx_pdr: Int(ceil(OlympusConstants.USER_TRAJECTORY_DIAGONAL/6)))
        OlympusConstants().setSectorInfoConstants(sector_info: sector_info)
        self.phaseController.setPhaseLengthParam(lengthConditionPdr: Double(sector_param.trajectory_diagonal), lengthConditionDr: Double(sector_param.trajectory_length))
        print(getLocalTimeString() + " , (Olympus) Information : User Trajectory Param \(OlympusConstants.USER_TRAJECTORY_LENGTH) // \(OlympusConstants.USER_TRAJECTORY_DIAGONAL) // \(OlympusConstants.NUM_STRAIGHT_INDEX_DR)")
        
        let sectorLevelList = sector_info_from_server.level_list
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
                        routeTracker.EntranceNetworkStatus[entranceKey] = entrance.network_status
                        routeTracker.EntranceVelocityScales[entranceKey] = entrance.scale
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
        // Path-Pixel 버전 확인
        self.loadPathPixel(sector_id: sector_id, PathPixelVersion: self.PathPixelVersion)
    }
    
    private func saveEntranceRouteLocalUrl(key: String, url: String) {
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
                            routeTracker.EntranceRouteLevel[key] = parsedData.0
                            routeTracker.EntranceRouteCoord[key] = parsedData.1
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
                                    routeTracker.EntranceRouteLevel[key] = parsedData.0
                                    routeTracker.EntranceRouteCoord[key] = parsedData.1
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
                                routeTracker.EntranceRouteLevel[key] = parsedData.0
                                routeTracker.EntranceRouteCoord[key] = parsedData.1
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
                            routeTracker.EntranceRouteLevel[key] = parsedData.0
                            routeTracker.EntranceRouteCoord[key] = parsedData.1
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
    
    func startTimer() {
        if (self.receivedForceTimer == nil) {
            let queueRFD = DispatchQueue(label: Bundle.main.bundleIdentifier! + ".receivedForceTimer")
            self.receivedForceTimer = DispatchSource.makeTimerSource(queue: queueRFD)
            self.receivedForceTimer!.schedule(deadline: .now(), repeating: RFD_INTERVAL)
            self.receivedForceTimer!.setEventHandler(handler: self.receivedForceTimerUpdate)
            self.receivedForceTimer!.resume()
        }
    }
    
    @objc func receivedForceTimerUpdate() {
        print("BLE is ready : \(bleManager.bluetoothReady)")
    }
    
//    private func loadRssiCompensationParam(sector_id: Int, device_model: String, os_version: Int, completion: @escaping (Bool, String) -> Void) {
//        // Check data in cache
//        let loadedScale = rssCompensator.loadNormalizationScale(sector_id: sector_id)
//        
//        if loadedScale.0 {
//            // Scale is in cache
//            self.normalizationScale = loadedScale.1
//            self.preNormalizationScale = loadedScale.1
//            let msg: String = getLocalTimeString() + " , (Olympus) Success : Load RssCompenstaion in cache"
//            completion(true, msg)
//        } else {
//            let rcInputDeviceOs = RcInputDeviceOs(sector_id: sector_id, device_mode: device_model, os_version: os_version)
//            NetworkManager.shared.postUserRssCompensation(url: USER_RC_URL, input: rcInputDeviceOs, isDeviceOs: true, completion: { statusCode, returnedString in
//                if (statusCode == 200) {
//                    let rcResult = jsonToRcInfoFromServer(jsonString: returnedString)
//                    if (rcResult.0) {
//                        if (rcResult.1.rss_compensations.isEmpty) {
//                            let rcInputDevice = RcInputDevice(sector_id: sector_id, device_mode: device_model)
//                            NetworkManager.shared.postUserRssCompensation(url: USER_RC_URL, input: rcInputDevice, isDeviceOs: false, completion: { statusCode, returnedString in
//                                if (statusCode == 200) {
//                                    let rcDeviceResult = jsonToRcInfoFromServer(jsonString: returnedString)
//                                    if (rcDeviceResult.0) {
//                                        if (rcDeviceResult.1.rss_compensations.isEmpty) {
//                                            // Need Normalization-scale Estimation
//                                            print(getLocalTimeString() + " , (Olmypus) Information : Need RssCompensation Estimation")
//                                            let msg: String = getLocalTimeString() + " , (Olympus) Success : RssCompensation"
//                                            completion(true, msg)
//                                        } else {
//                                            // Succes Load Normalization-scale (Device)
//                                            if let closest = self.findClosestOs(to: os_version, in: rcDeviceResult.1.rss_compensations) {
//                                                // Find Closest OS
//                                                let rcFromServer: RcInfo = closest
//                                                self.normalizationScale = rcFromServer.normalization_scale
//                                                self.preNormalizationScale = rcFromServer.normalization_scale
//                                                
//                                                print(getLocalTimeString() + " , (Olmypus) Information : Load RssCompensation from server (Device)")
//                                                let msg: String = getLocalTimeString() + " , (Olympus) Success : RssCompensation"
//                                                completion(true, msg)
//                                            } else {
//                                                // Need Normalization-scale Estimation
//                                                print(getLocalTimeString() + " , (Olmypus) Information : Need RssCompensation Estimation")
//                                                let msg: String = getLocalTimeString() + " , (Olympus) Success : RssCompensation"
//                                                completion(true, msg)
//                                            }
//                                        }
//                                    } else {
//                                        let msg: String = getLocalTimeString() + " , (Olympus) Error : Decode RssCompenstaion (Device)"
//                                        completion(false, msg)
//                                    }
//                                } else {
//                                    let msg: String = getLocalTimeString() + " , (Olympus) Error : Load RssCompenstaion (Device) from server \(statusCode)"
//                                    completion(false, msg)
//                                }
//                            })
//                        } else {
//                            // Succes Load Normalization-scale (Device & OS)
//                            let rcFromServer: RcInfo = rcResult.1.rss_compensations[0]
//                            self.normalizationScale = rcFromServer.normalization_scale
//                            self.preNormalizationScale = rcFromServer.normalization_scale
//                            
//                            print(getLocalTimeString() + " , (Olmypus) Information : Load RssCompensation from server (Device & OS)")
//                            let msg: String = getLocalTimeString() + " , (Olympus) Success : RssCompensation"
//                            completion(true, msg)
//                        }
//                    } else {
//                        let msg: String = getLocalTimeString() + " , (Olympus) Error : Decode RssCompenstaion (Device & OS)"
//                        completion(false, msg)
//                    }
//                } else {
//                    let msg: String = getLocalTimeString() + " , (Olympus) Error : Load RssCompenstaion (Device & OS) from server \(statusCode)"
//                    completion(false, msg)
//                }
//            })
//        }
//    }
    
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
