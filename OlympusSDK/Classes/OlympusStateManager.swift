
public class OlympusStateManager: NSObject {
    
    override init() {
        super.init()
        self.notificationCenterAddObserver()
    }
    
    deinit {
        self.notificationCenterRemoveObserver()
    }
    
    private var observers = [StateTrackingObserver]()
    func addObserver(_ observer: StateTrackingObserver) {
            observers.append(observer)
    }
        
    func removeObserver(_ observer: StateTrackingObserver) {
        observers = observers.filter { $0 !== observer }
    }
    
    private func notifyObservers(state: Int) {
        observers.forEach { $0.isStateDidChange(newValue: state) }
    }
    
    public var EntranceOuterWards = [String]()
    public var lastScannedEntranceOuterWardTime: Double = 0
    
    public var isGetFirstResponse: Bool = false
    public var isIndoor: Bool = false
    public var isBleOff: Bool = false
    public var isBackground: Bool = false
    public var isBecomeForeground: Bool = false
    
    public var timeForInit: Double = 0
    public var timeBleOff: Double = 0
    public var timeBecomeForeground: Double = 0
    public var timeEmptyRF: Double = 0
    public var timeTrimFailRF: Double = 0
    public var timeSleepRF: Double = 0
    
    var isActiveService: Bool = true
    var isActiveRF: Bool = true
    var isActiveUV: Bool = true
    
    public var timeIndexNotChanged: Double = 0
    public var timeSleepUV: Double = 0
    public var isStop: Bool = false
    
    private var venusObserver: Any!
    private var jupiterObserver: Any!
    private var rfdErrorObserver: Any!
    private var uvdErrorObserver: Any!
    private var backgroundObserver: Any!
    private var foregroundObserver: Any!
    private var trajEditedObserver: Any!
    
    public var isVenusMode: Bool = false
    
    public var networkCount: Int = 0
    public var isNetworkConnectReported: Bool = false
    
    public func setVariblesWhenBleIsNotEmpty() {
        self.timeBleOff = 0
        self.timeEmptyRF = 0
        self.timeSleepRF = 0
        
        self.isActiveRF = true
        self.isBleOff = false
    }
    
    public func checkBleOff(bluetoothReady: Bool, bleLastScannedTime: Double) {
        let currentTime: Double = getCurrentTimeInMillisecondsDouble()
        if (!bluetoothReady) {
            self.timeBleOff += OlympusConstants.RFD_INTERVAL
            if (self.timeBleOff >= OlympusConstants.BLE_OFF_THRESHOLD) {
                if (!self.isBleOff) {
                    self.isBleOff = true
                    self.timeBleOff = 0
                    notifyObservers(state: BLE_OFF_FLAG)
//                    self.reporting(input: BLE_OFF_FLAG)
                }
            }
        } else {
            let bleLastScannedTime = (currentTime - bleLastScannedTime)*1e-3
            if (bleLastScannedTime >= 6) {
                // 스캔이 동작안한지 6초 이상 지남
                notifyObservers(state: BLE_SCAN_STOP_FLAG)
//                self.reporting(input: BLE_SCAN_STOP_FLAG)
            }
        }
    }
    
    public func checkBleError(olympusResult: FineLocationTrackingResult) -> Bool {
        var isNeedClearBle: Bool = false
        let currentTime: Double = getCurrentTimeInMillisecondsDouble()
        if (self.isIndoor && self.isGetFirstResponse && !self.isBackground) {
            let diffTime = (currentTime - self.timeBecomeForeground)*1e-3
            if (!self.isBleOff && diffTime > 5) {
                notifyObservers(state: BLE_ERROR_FLAG)
//                self.reporting(input: BLE_ERROR_FLAG)
                let isFailTrimBle = self.determineIsOutdoor(olympusResult: olympusResult, currentTime: currentTime, inFailCondition: true)
                if (isFailTrimBle) {
                    isNeedClearBle = true
//                    self.bleAvg = [String: Double]()
                }
            }
        }
        
        return isNeedClearBle
    }
    
    public func checkOutdoorBleEmpty(lastBleDiscoveredTime: Double, olympusResult: FineLocationTrackingResult) {
        let currentTime = getCurrentTimeInMillisecondsDouble()
        
        if (currentTime - lastBleDiscoveredTime > OlympusConstants.BLE_VALID_TIME && lastBleDiscoveredTime != 0) {
            self.timeEmptyRF += OlympusConstants.RFD_INTERVAL
        } else {
            self.timeEmptyRF = 0
        }
        
        if (self.timeEmptyRF >= OlympusConstants.OUTDOOR_THRESHOLD) {
            self.isActiveRF = false
            if (self.isIndoor && self.isGetFirstResponse) {
                if (!self.isBleOff) {
                    let isOutdoor = self.determineIsOutdoor(olympusResult: olympusResult, currentTime: currentTime, inFailCondition: false)
                    if (isOutdoor) {
//                        self.initVariables()
//                        self.currentLevel = "B0"
                        self.isIndoor = false
                        notifyObservers(state: OUTDOOR_FLAG)
                    }
                }
            }
        }
    }
    
    private func determineIsOutdoor(olympusResult: FineLocationTrackingResult, currentTime: Double, inFailCondition: Bool) -> Bool {
        let isInEntranceMatchingArea = OlympusPathMatchingCalculator.shared.checkInEntranceMatchingArea(x: olympusResult.x, y: olympusResult.y, building: olympusResult.building_name, level: olympusResult.level_name)
        
        let diffEntranceWardTime = currentTime - self.lastScannedEntranceOuterWardTime
        if (olympusResult.building_name != "" && olympusResult.level_name == "B0") {
            return true
        } else if (isInEntranceMatchingArea.0) {
            return true
        } else if (diffEntranceWardTime <= 30*1000) {
            return true
        } else {
            // 3min
            if (inFailCondition) {
                if (self.timeTrimFailRF >= OlympusConstants.OUTDOOR_THRESHOLD) {
                    self.timeEmptyRF = self.timeTrimFailRF
                    self.timeTrimFailRF = 0
                    return true
                }
            } else {
                if (self.timeEmptyRF >= OlympusConstants.OUTDOOR_THRESHOLD*6*3) {
                    // 3 min
                    return true
                }
            }
        }
        return false
    }
    
    public func checkInEntranceLevel(result: FineLocationTrackingResult, isStartRouteTrack: Bool) -> Bool {
        if (!self.isGetFirstResponse) {
            return true
        }
        
        if (isStartRouteTrack) {
            return true
        }
        
        let lastResult = result
        
        let buildingName = lastResult.building_name
        let levelName = removeLevelDirectionString(levelName: result.level_name)
        
        if (levelName == "B0") {
            return true
        } else {
            let key = "\(buildingName)_\(levelName)"
            guard let entranceArea: [[Double]] = OlympusPathMatchingCalculator.shared.EntranceArea[key] else {
                return false
            }
            
            for i in 0..<entranceArea.count {
                if (!entranceArea[i].isEmpty) {
                    let xMin = entranceArea[i][0]
                    let yMin = entranceArea[i][1]
                    let xMax = entranceArea[i][2]
                    let yMax = entranceArea[i][3]
                    
                    if (lastResult.x >= xMin && lastResult.x <= xMax) {
                        if (lastResult.y >= yMin && lastResult.y <= yMax) {
                            return true
                        }
                    }
                }
                
            }
            return false
        }
    }
    
    public func checkEnterSleepMode() -> Bool {
        self.timeSleepRF += OlympusConstants.RFD_INTERVAL
        if (self.timeSleepRF >= OlympusConstants.SLEEP_THRESHOLD) {
//            self.isActiveService = false
            self.timeSleepRF = 0
            return true
        } else {
            return false
        }
    }
    
//    public func wakeUpFromSleepMode() {
//        if (self.service == "FLT" || self.service == "FLT+") {
//            if (self.updateTimer == nil && !self.isBackground) {
//                let queue = DispatchQueue(label: Bundle.main.bundleIdentifier! + ".updateTimer")
//                self.updateTimer = DispatchSource.makeTimerSource(queue: queue)
//                self.updateTimer!.schedule(deadline: .now(), repeating: UPDATE_INTERVAL)
//                self.updateTimer!.setEventHandler(handler: self.outputTimerUpdate)
//                self.updateTimer!.resume()
//            }
//        }
//    }
    
    public func getLastScannedEntranceOuterWardTime(bleAvg: [String: Double], entranceOuterWards: [String]) {
        var scannedTime: Double = 0

        for (key, value) in bleAvg {
            if entranceOuterWards.contains(key) {
                if (value >= OlympusConstants.OUTERWARD_SCAN_THRESHOLD) {
                    scannedTime = getCurrentTimeInMillisecondsDouble()
                    self.lastScannedEntranceOuterWardTime = scannedTime
                }
            }
        }
    }
    
    public func checkEnterInNetworkBadEntrance(bleAvg: [String: Double]) -> (Bool, FineLocationTrackingFromServer) {
        var isEnterInNetworkBadEntrance: Bool = false
        let emptyEntrance = FineLocationTrackingFromServer()
        
        if (!self.isGetFirstResponse) {
            let findResult = self.findNetworkBadEntrance(bleAvg: bleAvg)
            if (!self.isIndoor && (self.timeForInit >= OlympusConstants.TIME_INIT_THRESHOLD) && findResult.0) {
                self.isGetFirstResponse = true
                self.isIndoor = true
                notifyObservers(state: INDOOR_FLAG)
                isEnterInNetworkBadEntrance = true
                return (isEnterInNetworkBadEntrance, findResult.1)
            } else {
                return (isEnterInNetworkBadEntrance, emptyEntrance)
            }
        } else {
            return (isEnterInNetworkBadEntrance, emptyEntrance)
        }
    }
    
    private func findNetworkBadEntrance(bleAvg: [String: Double]) -> (Bool, FineLocationTrackingFromServer) {
        var isInNetworkBadEntrance: Bool = false
        var entrance = FineLocationTrackingFromServer()
        
        let networkBadEntranceWards = ["TJ-00CB-00000386-0000"]
        for (key, value) in bleAvg {
            if networkBadEntranceWards.contains(key) {
                let rssi = value
                if (rssi >= -82.0) {
                    isInNetworkBadEntrance = true
                    
                    entrance.building_name = "COEX"
                    entrance.level_name = "B0"
                    entrance.x = 270
                    entrance.y = 10
                    entrance.absolute_heading = 270
                    
                    return (isInNetworkBadEntrance, entrance)
                }
            }
        }
        
        return (isInNetworkBadEntrance, entrance)
    }
    
    public func updateTimeForInit() {
        if (!self.isIndoor) {
            self.timeForInit += OlympusConstants.RFD_INTERVAL
        }
    }
    
    public func setVariblesWhenIsIndexChanged() {
        self.timeIndexNotChanged = 0
        self.timeSleepUV = 0
        
        self.isStop = false
//        self.isActiveService = true
    }
    
    public func checkNetworkConnection() {
        if (self.networkCount >= 5 && OlympusNetworkChecker.shared.isConnectedToInternet()) {
            self.notifyObservers(state: NETWORK_WAITING_FLAG)
        }
        if (OlympusNetworkChecker.shared.isConnectedToInternet()) {
            self.isNetworkConnectReported = false
        } else {
            if (!self.isNetworkConnectReported) {
                self.isNetworkConnectReported = true
                print(getLocalTimeString() + " , (Olympus) Network : Connection Lost")
                self.notifyObservers(state: NETWORK_CONNECTION_FLAG)
            }
        }
    }
    
    public func setNetworkCount(value: Int) {
        self.networkCount = value
    }
    
    public func checkStopWhenIsIndexNotChanage() -> Bool {
        var isStop: Bool = false
        self.timeIndexNotChanged += OlympusConstants.UVD_INTERVAL
        if (self.timeIndexNotChanged >= OlympusConstants.STOP_THRESHOLD) {
            if (self.isVenusMode) {
                isStop = false
            } else {
                isStop = true
            }
            self.timeIndexNotChanged = 0
        }
        self.isStop = isStop
        return isStop
    }
    
    public func setIsBackground(isBackground: Bool) {
        self.isBackground = isBackground
        if (isBackground) {
            self.notifyObservers(state: BACKGROUND_FLAG)
        } else {
            self.notifyObservers(state: FOREGROUND_FLAG)
        }
    }
    
    public func setIsIndoor(isIndoor: Bool) {
        self.isIndoor = isIndoor
        if (isIndoor) {
            self.notifyObservers(state: INDOOR_FLAG)
        } else {
            self.notifyObservers(state: OUTDOOR_FLAG)
        }
    }
    
    public func setIsGetFirstResponse(isGetFirstResponse: Bool) {
        self.isGetFirstResponse = isGetFirstResponse
    }
    
    public func setBecomeForeground(isBecomeForeground: Bool, time: Double) {
        self.isBecomeForeground = isBecomeForeground
        self.timeBecomeForeground = time
    }
    
    func notificationCenterAddObserver() {
        self.venusObserver = NotificationCenter.default.addObserver(self, selector: #selector(onDidReceiveNotification), name: .didBecomeVenus, object: nil)
        self.jupiterObserver = NotificationCenter.default.addObserver(self, selector: #selector(onDidReceiveNotification), name: .didBecomeJupiter, object: nil)
        self.rfdErrorObserver = NotificationCenter.default.addObserver(self, selector: #selector(onDidReceiveNotification), name: .errorSendRfd, object: nil)
        self.uvdErrorObserver = NotificationCenter.default.addObserver(self, selector: #selector(onDidReceiveNotification), name: .errorSendUvd, object: nil)
        self.trajEditedObserver = NotificationCenter.default.addObserver(self, selector: #selector(onDidReceiveNotification), name: .trajEditedBecomeForground, object: nil)
    }
    
    func notificationCenterRemoveObserver() {
        NotificationCenter.default.removeObserver(self.venusObserver)
        NotificationCenter.default.removeObserver(self.jupiterObserver)
        NotificationCenter.default.removeObserver(self.rfdErrorObserver)
        NotificationCenter.default.removeObserver(self.uvdErrorObserver)
        NotificationCenter.default.removeObserver(self.trajEditedObserver)
    }
    
    @objc func onDidReceiveNotification(_ notification: Notification) {
        if notification.name == .didBecomeVenus {
            self.isVenusMode = true
            self.notifyObservers(state: VENUS_FLAG)
        }
    
        if notification.name == .didBecomeJupiter {
            self.isVenusMode = false
            self.notifyObservers(state: JUPITER_FLAG)
        }
        
        if notification.name == .errorSendRfd {
            self.notifyObservers(state: RFD_FLAG)
        }
        
        if notification.name == .errorSendUvd {
            self.notifyObservers(state: UVD_FLAG)
        }
        
        if notification.name == .trajEditedBecomeForground {
            self.isBecomeForeground = false
        }
    }
}
