import Foundation

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
        print(getLocalTimeString() + " , (Olympus) Information : state = \(state)")
        observers.forEach { $0.isStateDidChange(newValue: state) }
    }
    
    public func initialize(isStopService: Bool) {
        self.lastScannedEntranceOuterWardTime = 0
        self.isGetFirstResponse = false
        self.isIndoor = false
        self.isBleOff = false
        self.isBackground = false
        self.isBecomeForeground = false
        self.isStop = false
        self.isVenusMode = false
        self.isNetworkConnectReported = false
        
        self.timeBleOff = 0
        self.timeBecomeForeground = 0
        self.timeEmptyRF = 0
        self.timeTrimFailRF = 0
        
        self.isSleepMode = true
        self.timeSleepRF = 0
        self.timeSleepUV = 0
        self.timeIndexNotChanged = 0
        self.networkCount = 0
        
        if (isStopService) {
            self.timeForInit = OlympusConstants.TIME_INIT_THRESHOLD+1
        } else {
            self.timeForInit = 0
        }
    }
    
    private var sector_id: Int = -1
    public var EntranceOuterWards = [String]()
    public var lastScannedEntranceOuterWardTime: Double = 0
    
    public var isGetFirstResponse: Bool = false
    public var isIndoor: Bool = false
    public var isBleOff: Bool = false
    public var isBackground: Bool = false
    public var isBecomeForeground: Bool = false
    public var isStop: Bool = false
    public var isVenusMode: Bool = false
    private var isNetworkConnectReported: Bool = false
    
    public var timeForInit: Double = OlympusConstants.TIME_INIT_THRESHOLD+1
    private var timeBleOff: Double = 0
    private var timeBecomeForeground: Double = 0
    private var timeEmptyRF: Double = 0
    private var timeTrimFailRF: Double = 0
    
    public var isSleepMode: Bool = true
    private var timeSleepRF: Double = 0
    private var timeSleepUV: Double = 0
    private var timeIndexNotChanged: Double = 0
    public var networkCount: Int = 0

    private var startObserver: Any!
    private var venusObserver: Any!
    private var jupiterObserver: Any!
    private var rfdErrorObserver: Any!
    private var uvdErrorObserver: Any!
    private var backgroundObserver: Any!
    private var foregroundObserver: Any!
    private var trajEditedObserver: Any!
    
    public func setSectorID(sector_id: Int) {
        self.sector_id = sector_id
    }
    
    public func setVariblesWhenBleIsNotEmpty() {
        self.timeBleOff = 0
        self.timeEmptyRF = 0
        self.timeSleepRF = 0
        self.isBleOff = false
        self.isSleepMode = false
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
                }
            }
        } else {
            let bleLastScannedTime = (currentTime - bleLastScannedTime)*1e-3
            if (bleLastScannedTime >= 6) {
                // 스캔이 동작안한지 6초 이상 지남
                notifyObservers(state: BLE_SCAN_STOP_FLAG)
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
//        print(getLocalTimeString() + " , (Olympus) checkOutdoorBleEmpty : dTime = \(currentTime - lastBleDiscoveredTime) // timeEmptyRF = \(timeEmptyRF)")
        if (currentTime - lastBleDiscoveredTime > OlympusConstants.BLE_VALID_TIME && lastBleDiscoveredTime != 0) {
            self.timeEmptyRF += OlympusConstants.RFD_INTERVAL
        } else {
            self.timeEmptyRF = 0
        }
        
        if (self.timeEmptyRF >= OlympusConstants.OUTDOOR_THRESHOLD) {
            if (self.isIndoor && self.isGetFirstResponse) {
                if (!self.isBleOff) {
                    let isOutdoor = self.determineIsOutdoor(olympusResult: olympusResult, currentTime: currentTime, inFailCondition: false)
                    if (isOutdoor) {
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
            let key = "\(self.sector_id)_\(buildingName)_\(levelName)"
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
    
    public func checkEnterSleepMode(service: String, type: Int) {
        if (service.contains(OlympusConstants.SERVICE_FLT)) {
            if (type == 0) {
                self.timeSleepRF += OlympusConstants.RFD_INTERVAL
            } else {
                self.timeSleepUV += OlympusConstants.UVD_INTERVAL
            }
            
            if (self.timeSleepRF >= OlympusConstants.SLEEP_THRESHOLD || self.timeSleepUV >= OlympusConstants.SLEEP_THRESHOLD) {
                self.isSleepMode = true
            }
        }
    }
    
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
        let emptyEntrance = FineLocationTrackingFromServer()
        
        if (!self.isGetFirstResponse) {
            let findResult = self.findNetworkBadEntrance(bleAvg: bleAvg)
            let networkStatus = findResult.0
            if (!self.isIndoor && (self.timeForInit >= OlympusConstants.TIME_INIT_THRESHOLD) && !networkStatus) {
                setIsGetFirstResponse(isGetFirstResponse: true)
                setIsIndoor(isIndoor: true)
                return (true, findResult.1)
            } else {
                return (false, emptyEntrance)
            }
        } else {
            return (false, emptyEntrance)
        }
    }
    
    private func findNetworkBadEntrance(bleAvg: [String: Double]) -> (Bool, FineLocationTrackingFromServer) {
        var networkStatus: Bool = true
        var entrance = FineLocationTrackingFromServer()
        
        let networkBadEntranceWards = ["TJ-00CB-00000386-0000"]
        for (key, value) in bleAvg {
            if networkBadEntranceWards.contains(key) {
                let rssi = value
                if (rssi >= -82.0) {
                    networkStatus = false
                    
                    entrance.building_name = "COEX"
                    entrance.level_name = "B0"
                    entrance.x = 270
                    entrance.y = 10
                    entrance.absolute_heading = 270
                    
                    return (networkStatus, entrance)
                }
            }
        }
        
        return (networkStatus, entrance)
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
        self.isSleepMode = false
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
    
    public func checkStopWhenIsIndexNotChanaged() -> Bool {
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
        startObserver = NotificationCenter.default.addObserver(forName: .serviceStarted, object: nil, queue: .main) { [weak self] _ in
            self?.notifyObservers(state: START_FLAG)
        }
        
        venusObserver = NotificationCenter.default.addObserver(forName: .didBecomeVenus, object: nil, queue: .main) { [weak self] _ in
            guard let self = self else { return }
            self.isVenusMode = true
            self.notifyObservers(state: VENUS_FLAG)
        }
        
        jupiterObserver = NotificationCenter.default.addObserver(forName: .didBecomeJupiter, object: nil, queue: .main) { [weak self] _ in
            guard let self = self else { return }
            self.isVenusMode = false
            self.notifyObservers(state: JUPITER_FLAG)
        }
        
        rfdErrorObserver = NotificationCenter.default.addObserver(forName: .errorSendRfd, object: nil, queue: .main) { [weak self] _ in
            self?.notifyObservers(state: RFD_FLAG)
        }
        
        uvdErrorObserver = NotificationCenter.default.addObserver(forName: .errorSendUvd, object: nil, queue: .main) { [weak self] _ in
            self?.notifyObservers(state: UVD_FLAG)
        }
        
        trajEditedObserver = NotificationCenter.default.addObserver(forName: .trajEditedBecomeForground, object: nil, queue: .main) { [weak self] _ in
            self?.isBecomeForeground = false
        }
    }

    func notificationCenterRemoveObserver() {
        NotificationCenter.default.removeObserver(startObserver)
        NotificationCenter.default.removeObserver(venusObserver)
        NotificationCenter.default.removeObserver(jupiterObserver)
        NotificationCenter.default.removeObserver(rfdErrorObserver)
        NotificationCenter.default.removeObserver(uvdErrorObserver)
        NotificationCenter.default.removeObserver(trajEditedObserver)
    }

    
    func onDidReceiveNotification(_ notification: Notification) {
        if notification.name == .serviceStarted {
            notifyObservers(state: START_FLAG)
        }
        
        if notification.name == .didBecomeVenus {
            isVenusMode = true
            notifyObservers(state: VENUS_FLAG)
        }
    
        if notification.name == .didBecomeJupiter {
            isVenusMode = false
            notifyObservers(state: JUPITER_FLAG)
        }
        
        if notification.name == .errorSendRfd {
            notifyObservers(state: RFD_FLAG)
        }
        
        if notification.name == .errorSendUvd {
            notifyObservers(state: UVD_FLAG)
        }
        
        if notification.name == .trajEditedBecomeForground {
            isBecomeForeground = false
        }
    }
}
