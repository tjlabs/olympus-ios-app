import Foundation
import CoreMotion
import UIKit

public class OlympusServiceManager: NSObject, RouteTrackingObserver, StateTrackingObserver {
    public static let sdkVersion: String = "0.1.0"
    
    var deviceModel: String
    var deviceOsVersion: Int
    
    var sensorManager = OlympusSensorManager()
    var bleManager = OlympusBluetoothManager()
    var rssCompensator = OlympusRssCompensator()
    var phaseController = OlympusPhaseController()
    var stateManager = OlympusStateManager()
    var rflowCorrelator = OlympusRflowCorrelator()
    var unitDRGenerator = OlympusUnitDRGenerator()
    
    var unitDRInfo = UnitDRInfo()
    
    // ----- Sector Param ----- //
    var inputReceivedForce: [ReceivedForce] = [ReceivedForce(user_id: "", mobile_time: 0, ble: [:], pressure: 0)]
    var inputUserVelocity: [UserVelocity] = [UserVelocity(user_id: "", mobile_time: 0, index: 0, length: 0, heading: 0, looking: true)]
    var isSaveMobileResult: Bool = false
    
    // ----- Sector Param ----- //
    var user_id: String = ""
    var service: String = ""
    var mode: String = ""

    
    // ----- Timer ----- //
    var backgroundUpTimer: DispatchSourceTimer?
    var backgroundUvTimer: DispatchSourceTimer?
    var backgroundTaskIdentifier: UIBackgroundTaskIdentifier?
    
    var receivedForceTimer: DispatchSourceTimer?
    var userVelocityTimer: DispatchSourceTimer?
    var outputTimer: DispatchSourceTimer?
    var osrTimer: DispatchSourceTimer?    
    
    // RFD
    var bleTrimed = [String: [[Double]]]()
    var bleAvg = [String: Double]()
    
    
    // ----- State Observer ----- //
    var runMode: String = "dr"
    var currentMode: String = "dr"
    var currentLevel: String = ""
    
    // ----- State Observer ----- //
    var isVenusMode: Bool = false
    
    public override init() {
        self.deviceModel = UIDevice.modelName
        let deviceOs = UIDevice.current.systemVersion
        let arr = deviceOs.components(separatedBy: ".")
        self.deviceOsVersion = Int(arr[0]) ?? 0
        
        super.init()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"
        dateFormatter.locale = Locale(identifier:"ko_KR")
        let nowDate = Date()

        OlympusRouteTracker.shared.addObserver(self)
        stateManager.addObserver(self)
    }
    
    deinit {
        OlympusRouteTracker.shared.removeObserver(self)
        stateManager.removeObserver(self)
    }
    
    func isStartRouteTrackDidChange(newValue: Bool) {
        unitDRGenerator.setIsStartRouteTrack(isStartRoutTrack: newValue)
    }
    
    func isStateDidChange(newValue: Int) {
        print("FLAG : \(newValue)")
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
                            self.user_id = user_id
                            let sectorInput = SectorInput(sector_id: sector_id, operating_system: OlympusConstants.OPERATING_SYSTEM)
                            OlympusNetworkManager.shared.postUserSector(url: USER_SECTOR_URL, input: sectorInput, completion: { [self] statusCode, returnedString in
                                if (statusCode == 200) {
                                    let sectorInfoFromServer = jsonToSectorInfoFromServer(jsonString: returnedString)
                                    if (sectorInfoFromServer.0) {
                                        self.setSectorInfo(sector_id: sector_id, sector_info_from_server: sectorInfoFromServer.1)
                                        rssCompensator.loadRssiCompensationParam(sector_id: sector_id, device_model: deviceModel, os_version: deviceOsVersion, completion: { [self] isSuccess, loadedParam, returnedString in
                                            if (isSuccess) {
                                                OlympusConstants().setNormalizationScale(cur: loadedParam, pre: loadedParam)
                                                print(getLocalTimeString() + " , (Olmypus) Scale cur : \(OlympusConstants.NORMALIZATION_SCALE)")
                                                print(getLocalTimeString() + " , (Olmypus) Scale pre : \(OlympusConstants.PRE_NORMALIZATION_SCALE)")
                                                if (!bleManager.bluetoothReady) {
                                                    let msg: String = getLocalTimeString() + " , (Olympus) Error : Bluetooth is not enabled"
                                                    completion(false, msg)
                                                } else {
                                                    self.startTimer()
                                                    completion(true, getLocalTimeString() + success_msg)
                                                }
                                            } else {
                                                completion(false, returnedString)
                                            }
                                        })
//                                        completion(true, returnedString)
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
        
        if (!OlympusConstants.OLMPUS_SERVICES.contains(service)) {
            msg = localTime + " , (Olympus) Error : Invalid Service Name"
            return (isSuccess, msg)
        } else {
            if (service.contains(OlympusConstants.SERVICE_FLT)) {
                unitDRInfo = UnitDRInfo()
                unitDRGenerator.setMode(mode: mode)

                if (mode == "auto") {
                    self.runMode = "dr"
                    self.currentMode = "dr"
                } else if (mode == "pdr") {
                    self.runMode = "pdr"
                } else if (mode == "dr") {
                    self.runMode = "dr"
                } else {
                    isSuccess = false
                    msg = localTime + " , (Olympus) Error : Invalid Service Mode"
                    return (isSuccess, msg)
                }
//                setModeParam(mode: self.runMode, phase: self.phase)
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
        print(getLocalTimeString() + " , (Olympus) Information : User Trajectory Param \(OlympusConstants.USER_TRAJECTORY_LENGTH) // \(OlympusConstants.USER_TRAJECTORY_DIAGONAL) // \(OlympusConstants.NUM_STRAIGHT_IDX_DR)")
        
        let sectorLevelList = sector_info_from_server.level_list
        for element in sectorLevelList {
            let buildingName = element.building_name
            let levelName = element.level_name
            if !levelName.contains("_D") {
                let key = "\(buildingName)_\(levelName)"
                let entranceArea = element.geofence.entrance_area
                let entranceMatcingArea = element.geofence.entrance_matching_area
                let levelChangeArea = element.geofence.level_change_area
                
                if !entranceArea.isEmpty { OlympusPathMatchingCalculator.shared.EntranceArea[key] = entranceArea }
                if !entranceMatcingArea.isEmpty { OlympusPathMatchingCalculator.shared.EntranceMatchingArea[key] = entranceMatcingArea }
                if !levelChangeArea.isEmpty { OlympusPathMatchingCalculator.shared.LevelChangeArea[key] = levelChangeArea }
                
                if (levelName == "B0") {
                    OlympusRouteTracker.shared.EnteranceNumbers = element.entrance_list.count
                    var entranceOuterWards: [String] = []
                    for entrance in element.entrance_list {
                        let entranceKey = "\(key)_\(entrance.spot_number)"
                        OlympusRouteTracker.shared.EntranceNetworkStatus[entranceKey] = entrance.network_status
                        OlympusRouteTracker.shared.EntranceVelocityScales[entranceKey] = entrance.scale
                        OlympusRouteTracker.shared.EntranceRouteVersion[entranceKey] = entrance.route_version
                        entranceOuterWards.append(entrance.outermost_ward_id)
                    }
                    stateManager.EntranceOuterWards = entranceOuterWards
                }
                if (!element.path_pixel_version.isEmpty) {
                    OlympusPathMatchingCalculator.shared.PpVersion[key] = element.path_pixel_version
                }
            }
        }
        // Entrance Route 버전 확인
        OlympusRouteTracker.shared.loadEntranceRoute(sector_id: sector_id, RouteVersion: OlympusRouteTracker.shared.EntranceRouteVersion)
        // Path-Pixel 버전 확인
        OlympusPathMatchingCalculator.shared.loadPathPixel(sector_id: sector_id, PathPixelVersion: OlympusPathMatchingCalculator.shared.PpVersion)
    }
    
    
    public func setMinimumTimeForIndoorReport(time: Double) {
        OlympusConstants.TIME_INIT_THRESHOLD = time
        stateManager.timeForInit = time + 1
    }
    
    func startTimer() {
        if (self.receivedForceTimer == nil) {
            let queueRFD = DispatchQueue(label: Bundle.main.bundleIdentifier! + ".receivedForceTimer")
            self.receivedForceTimer = DispatchSource.makeTimerSource(queue: queueRFD)
            self.receivedForceTimer!.schedule(deadline: .now(), repeating: OlympusConstants.RFD_INTERVAL)
            self.receivedForceTimer!.setEventHandler(handler: self.receivedForceTimerUpdate)
            self.receivedForceTimer!.resume()
        }
        
        if (self.userVelocityTimer == nil) {
            let queueUVD = DispatchQueue(label: Bundle.main.bundleIdentifier! + ".userVelocityTimer")
            self.userVelocityTimer = DispatchSource.makeTimerSource(queue: queueUVD)
            self.userVelocityTimer!.schedule(deadline: .now(), repeating: OlympusConstants.UVD_INTERVAL)
            self.userVelocityTimer!.setEventHandler(handler: self.userVelocityTimerUpdate)
            self.userVelocityTimer!.resume()
        }
        
        
        if (self.outputTimer == nil) {
            let queue = DispatchQueue(label: Bundle.main.bundleIdentifier! + ".updateTimer")
            self.outputTimer = DispatchSource.makeTimerSource(queue: queue)
            self.outputTimer!.schedule(deadline: .now(), repeating: OlympusConstants.OUTPUT_INTERVAL)
            self.outputTimer!.setEventHandler(handler: self.outputTimerUpdate)
            self.outputTimer!.resume()
        }
        
        
        if (self.osrTimer == nil) {
            let queueOSR = DispatchQueue(label: Bundle.main.bundleIdentifier! + ".osrTimer")
            self.osrTimer = DispatchSource.makeTimerSource(queue: queueOSR)
            self.osrTimer!.schedule(deadline: .now(), repeating: OlympusConstants.OSR_INTERVAL)
            self.osrTimer!.setEventHandler(handler: self.osrTimerUpdate)
            self.osrTimer!.resume()
        }
    }
    
    func stopTimer() {
        self.receivedForceTimer?.cancel()
        self.userVelocityTimer?.cancel()
        self.osrTimer?.cancel()
        self.outputTimer?.cancel()
        self.backgroundUpTimer?.cancel()
        
        self.receivedForceTimer = nil
        self.userVelocityTimer = nil
        self.osrTimer = nil
        self.outputTimer = nil
        self.backgroundUvTimer = nil
    }
    
    @objc func receivedForceTimerUpdate() {
        let localTime: String = getLocalTimeString()
        stateManager.checkBleOff(bluetoothReady: bleManager.bluetoothReady, bleLastScannedTime: bleManager.bleLastScannedTime)
        stateManager.updateTimeForInit()
        
        let validTime = OlympusConstants.BLE_VALID_TIME
        let currentTime = getCurrentTimeInMilliseconds() - (Int(validTime)/2)
        let bleDictionary: [String: [[Double]]]? = bleManager.bleDictionary
        if let bleData = bleDictionary {
            let trimmedResult = OlympusRFDFunctions.shared.trimBleData(bleInput: bleData, nowTime: getCurrentTimeInMillisecondsDouble(), validTime: validTime)
            switch trimmedResult {
            case .success(let trimmedData):
                self.bleAvg = OlympusRFDFunctions.shared.avgBleData(bleDictionary: trimmedData)
                stateManager.getLastScannedEntranceOuterWardTime(bleAvg: self.bleAvg, entranceOuterWards: stateManager.EntranceOuterWards)
                let enterInNetworkBadEntrance = stateManager.checkEnterInNetworkBadEntrance(bleAvg: self.bleAvg)
                if (enterInNetworkBadEntrance.0) {
                    OlympusRouteTracker.shared.startRouteTracking(result: enterInNetworkBadEntrance.1)
//                    self.outputResult.phase = 3
//                    self.outputResult.building_name = result.building_name
//                    self.outputResult.level_name = result.level_name
//                    self.outputResult.isIndoor = self.isIndoor
                }
            case .failure(_):
                print("Trim Fail")
//                let isNeedClearBle = stateManager.checkBleError(lastResult: <#T##FineLocationTrackingResult#>)
//                if (isNeedClearBle) {
//                    self.bleAvg = [String: Double]()
//                }
            }
            
            rssCompensator.refreshWardMinRssi(bleData: self.bleAvg)
            rssCompensator.refreshWardMaxRssi(bleData: self.bleAvg)
            let maxRssi = rssCompensator.getMaxRssi()
            let minRssi = rssCompensator.getMinRssi()
            let diffMinMaxRssi = abs(maxRssi - minRssi)
            if (minRssi <= -97) {
                let deviceMin: Double = rssCompensator.getDeviceMinRss()
                OlympusConstants.DEVICE_MIN_RSSI = deviceMin
            }
            rssCompensator.estimateNormalizationScale(isGetFirstResponse: stateManager.isGetFirstResponse, isIndoor: stateManager.isIndoor, currentLevel: self.currentLevel, diffMinMaxRssi: diffMinMaxRssi, minRssi: minRssi)
            
        } else {
            let msg: String = localTime + " , (Olympus) Warnings : Fail to get recent BLE"
            print(msg)
        }
        
        if (!stateManager.isBackground) {
            let isSufficientRfdBuffer = rflowCorrelator.accumulateRfdBuffer(bleData: self.bleAvg)
            let isSufficientRfdVelocityBuffer = rflowCorrelator.accumulateRfdVelocityBuffer(bleData: self.bleAvg)
            let isSufficientRfdAutoMode = rflowCorrelator.accumulateRfdAutoModeBuffer(bleData: self.bleAvg)
            if(!OlympusRouteTracker.shared.isStartRouteTrack) {
                unitDRGenerator.setRflow(rflow: rflowCorrelator.getRflow(), rflowForVelocity: rflowCorrelator.getRflowForVelocityScale(), rflowForAutoMode: rflowCorrelator.getRflowForAutoMode(), isSufficient: isSufficientRfdBuffer, isSufficientForVelocity: isSufficientRfdVelocityBuffer, isSufficientForAutoMode: isSufficientRfdAutoMode)
            }
        }
        
        if (!self.bleAvg.isEmpty) {
            stateManager.setVariblesWhenBleIsNotEmpty()
            let data = ReceivedForce(user_id: self.user_id, mobile_time: currentTime, ble: self.bleAvg, pressure: self.sensorManager.pressure)
            self.inputReceivedForce.append(data)
            if ((inputReceivedForce.count-1) >= OlympusConstants.RFD_INPUT_NUM) {
                inputReceivedForce.remove(at: 0)
                
                OlympusNetworkManager.shared.postReceivedForce(url: REC_RFD_URL, input: inputReceivedForce, completion: { [self] statusCode, returnedString, inputRfd in
                    if (statusCode != 200) {
                        let localTime = getLocalTimeString()
                        let msg: String = localTime + " , (Olympus) Error : RFD \(statusCode) // " + returnedString
                        if (stateManager.isIndoor && stateManager.isGetFirstResponse && !stateManager.isBackground) {
                            NotificationCenter.default.post(name: .errorSendRfd, object: nil, userInfo: nil)
                        }
                    }
                })
                inputReceivedForce = [ReceivedForce(user_id: "", mobile_time: 0, ble: [:], pressure: 0)]
            }
            
        } else if (!stateManager.isBackground) {
//            stateManager.checkOutdoorBleEmpty(lastBleDiscoveredTime: <#T##Double#>, lastResult: <#T##FineLocationTrackingResult#>)
//            stateManager.checkEnterSleepMode()
        }
    }
    
    @objc func userVelocityTimerUpdate() {
//        print(sensorManager.sensorData.pressure)
//        print("BLE is ready : \(bleManager.bluetoothReady)")
    }
    
    @objc func outputTimerUpdate() {
//        print("BLE is ready : \(bleManager.bluetoothReady)")
    }
    
    @objc func osrTimerUpdate() {
//        print("BLE is ready : \(bleManager.bluetoothReady)")
    }
}
