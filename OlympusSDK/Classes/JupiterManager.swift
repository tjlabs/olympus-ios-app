import Foundation
import TJLabsAuth
import TJLabsCommon
import TJLabsResource
import UIKit

public class JupiterManager: JupiterCalcManagerDelegate, MockResultDelegate {
    func onMockResult(_ manager: JupiterMockManager, result: MockResult) {
        let currentTime = TJLabsUtilFunctions.shared.getCurrentTimeInMilliseconds(as: .int) as! Int
        let isVehicle = curUserModeEnum == .MODE_VEHICLE ? true : false
        let mockResult = JupiterResult(mobile_time: currentTime,
                                          index: result.index,
                                          building_name: result.building_name,
                                          level_name: result.level_name,
                                          jupiter_pos: result.jupiter_pos,
                                          llh: result.llh,
                                          velocity: result.velocity,
                                          is_vehicle: isVehicle,
                                          is_indoor: result.is_indoor,
                                          validity_flag: result.validity_flag)
        if curUserModeEnum == .MODE_VEHICLE {
            delegate?.mockTracking(jupiterResult: mockResult)
        }
        self.mockJupiterResult = mockResult
    }
    
    func onSimulationData(_ data: [TJLabsResource.SimulationInfo]) {
        JupiterMockManager.shared.setSimulationInfo(data: data)
    }
    
    func provideTrackingCorrection(mode: TJLabsCommon.UserMode, userVelocity: TJLabsCommon.UserVelocity, peakIndex: Int?, recentLandmarkPeaks: [TJLabsResource.PeakData]?, travelingLinkDist: Float, indexForEdit: Int, curPmResult: FineLocationTrackingOutput?) -> (NaviCorrectionInfo, [StackEditInfo])? {
        return delegate?.provideTrackingCorrection(mode: mode, userVelocity: userVelocity, peakIndex: peakIndex, recentLandmarkPeaks: recentLandmarkPeaks, travelingLinkDist: travelingLinkDist, indexForEdit: indexForEdit, curPmResult: curPmResult)
    }
    
    func onRfdResult(receivedForce: TJLabsCommon.ReceivedForce) {
        delegate?.onRfdResult(receivedForce: receivedForce)
    }
    
    func onEntering(userVelocity: UserVelocity, peakIndex: Int?, key: String, level_id: Int) {
        delegate?.onEntering(userVelocity: userVelocity, peakIndex: peakIndex, key: key, level_id: level_id)
    }
    
    func isJupiterPhaseChanged(index: Int, phase: JupiterPhase, xyh: [Float]?) {
        delegate?.isJupiterPhaseChanged(index: index, phase: phase, xyh: xyh)
        if phase == .ENTERING {
            delegate?.isJupiterInOutStateChanged(.OUT_TO_IN)
        } else if phase == .SEARCHING {
            delegate?.isJupiterInOutStateChanged(.INDOOR)
        } else if phase == .TRACKING && jupiterPhase != .SEARCHING {
            delegate?.isJupiterInOutStateChanged(.INDOOR)
        } else if phase == .EXITING {
            delegate?.isJupiterInOutStateChanged(.IN_TO_OUT)
        } else {
            delegate?.isJupiterInOutStateChanged(.OUTDOOR)
        }
        self.jupiterPhase = phase
    }
    
    func onStateReported(_ code: JupiterServiceCode) {
        switch(code) {
        case .SERVICE_FAIL:
            delegate?.onJupiterReport(code, "Service Fail")
        case .SERVICE_SUCCESS:
            delegate?.onJupiterReport(code, "Service Success")
        case .BECOME_BACKGROUND:
            delegate?.onJupiterReport(code, "Become Background")
        case .BECOME_FOREGROUND:
            delegate?.onJupiterReport(code, "Become Foreground")
        case .BLUETOOTH_UNAVAILABLE:
            delegate?.onJupiterReport(code, "Bluetooth is unavailable")
        case .BLUETOOTH_OFF:
            delegate?.onJupiterReport(code, "Bluetooth Off")
        case .BLUETOOTH_SCAN_STOP:
            delegate?.onJupiterReport(code, "Bluetooth Scan Stop (over 6s)")
        case .NETWORK_DISCONNECT:
            delegate?.onJupiterReport(code, "Newtork is disconnected")
        case .GET_FIRST_RESULT:
            delegate?.onJupiterReport(code, "Get First Result")
        }
    }
    
    public static let sdkVersion: String = "2.0.2"
    
    var tenantUserName: String = ""
    var id: String = ""
    var cloud: String = ""
    var region: String = ""
    var sectorId: Int = 0
    var deviceModel: String
    var deviceIdentifier: String
    var deviceOsVersion: Int
    
    var jupiterCalcManager: JupiterCalcManager?
    private var jupiterPhase: JupiterPhase = .NONE
    private var curUserModeEnum: UserMode = .MODE_VEHICLE
    
    public weak var delegate: JupiterManagerDelegate?
    private let debugOption: Bool
    
    private var isInitService = false
    private var isStartJupiter = false
    private var isGetFirstResult: Bool = false
    
    private var mockMode = false
    private var isStartMock = false
    private var mockJupiterResult: JupiterResult?
    
    // MARK: - JupiterResult Timer
    var outputTimer: DispatchSourceTimer?
    
    public init(id: String, cloud: String, region: String = JupiterRegion.KOREA.rawValue, sectorId: Int, debugOption: Bool = false) {
        self.id = id
        self.cloud = cloud
        self.region = region
        self.sectorId = sectorId
        self.debugOption = debugOption
        
        self.deviceIdentifier = UIDevice.modelIdentifier
        self.deviceModel = UIDevice.modelName
        let deviceOs = UIDevice.current.systemVersion
        let arr = deviceOs.components(separatedBy: ".")
        self.deviceOsVersion = Int(arr[0]) ?? 0
        
        JupiterMockManager.shared.sectorId = sectorId
        initialize(cloud: cloud, region: region, sectorId: sectorId, debugOption: debugOption)
    }
    
    deinit {
        JupiterMockManager.shared.delegate = nil
        jupiterCalcManager?.delegate = nil
        stopJupiter(completion: { _,_ in })
    }

    // MARK: - Start & Stop Jupiter Service
    func initialize(cloud: String, region: String, sectorId: Int, debugOption: Bool) {
        JupiterNetworkConstants.setServerURL(cloud: cloud, region: region)
        let (isNetworkAvailable, _) = JupiterNetworkManager.shared.isConnectedToInternet()
        let (isIdAvailable, _) = checkIdIsAvailable(id: id)
        
        if !TJLabsAuthManager.shared.isAuthorized {
            delegate?.onInitSuccess(false, .NOT_AUTHORIZED)
            return
        }
        
        if !isNetworkAvailable {
            delegate?.onInitSuccess(false, .NETWORK_DISCONNECT)
            return
        }
        
        if !isIdAvailable {
            delegate?.onInitSuccess(false, .INVALID_ID)
            return
        }
        
        self.tenantUserName = TJLabsAuthManager.shared.getTenantUserName()
        let loginInput = LoginInput(tenant_user_name: self.tenantUserName, external_name: self.id)
        let tasks: [(_ group: DispatchGroup, _ reportError: @escaping (String) -> Void) -> Void] = [
            { group, reportError in
                group.enter()
                let loginURL = JupiterNetworkConstants.getUserLoginURL()
                JupiterNetworkManager.shared.postUserLogin(url: loginURL, input: loginInput) { statusCode, msg in
                    JupiterLogger.i(tag: "JupiterManager", message: "(login) - url \(loginURL), statusCode=\(statusCode), msg=\(msg)")
                    let successRange = 200..<300
                    if !successRange.contains(statusCode) {
                        reportError(msg)
                    }
                    group.leave()
                }
            }
        ]
        
        performTasksWithCounter(tasks: tasks, onComplete: { [self] in
            let calcManager = makeJupiterCalcManager()
            calcManager.initialize(completion: { [self] isSuccess, msg in
                if isSuccess {
                    // File Save Setting
                    if debugOption {
                        self.uploadReplayFiles()
                        JupiterFileManager.shared.setDebugOption(flag: debugOption)
                        JupiterFileManager.shared.createFiles(id: self.id, os: "iOS")
                    }
                    jupiterCalcManager = calcManager
                    JupiterMockManager.shared.delegate = self
                    isInitService = true
                    delegate?.onInitSuccess(true, nil)
                } else {
                    delegate?.onInitSuccess(false, .LOAD_RESOURCE_FAIL)
                }
            })
        }, onError: { msg in
            JupiterLogger.e(tag: "JupiterManager", message: "init failed during login: \(msg)")
            self.delegate?.onInitSuccess(false, .LOGIN_FAIL)
        })
    }
    
    public func startJupiter(mode: UserMode) {
        if !isInitService {
            delegate?.onJupiterSuccess(false, .NOT_INITIALIZED)
            return
        }
        
        if isStartMock {
            delegate?.onJupiterSuccess(false, .DUPLICATED_SERVICE)
            return
        }
        
        if mockMode {
            isStartMock = true
            startTimer()
            JupiterMockManager.shared.generateMockResult()
            delegate?.onJupiterSuccess(true, nil)
            return
        }
        
        if isStartJupiter {
            delegate?.onJupiterSuccess(false, .DUPLICATED_SERVICE)
            return
        }

        guard let jupiterCalcManager else {
            delegate?.onJupiterSuccess(false, .NOT_INITIALIZED)
            return
        }

        jupiterCalcManager.delegate = self
        jupiterCalcManager.resetRuntimeState()

        startGenerator(mode: mode, completion: { [self] isSuccess, msg in
            if isSuccess {
                self.curUserModeEnum = mode
                isStartJupiter = true
                startTimer()
                let currentTime = TJLabsUtilFunctions.shared.getCurrentTimeInMilliseconds(as: .int) as! Int
                JupiterFileManager.shared.writeEvent(event: JupiterEvent(mobile_time: currentTime, event_code: JupiterServiceCode.SERVICE_SUCCESS.rawValue))
                delegate?.onJupiterSuccess(true, nil)
            } else {
                delegate?.onJupiterSuccess(false, .GENERATOR_FAIL)
            }
        })
    }
    
    private func uploadReplayFiles() {
        let fileInfos = JupiterFileUploader.shared.getReplayFilesInExports()
        JupiterLogger.i(tag: "JupiterManager", message: "uploadReplayFiles : fileInfos= \(fileInfos)")
        let rfdFile = fileInfos.rfdFiles
        let uvdFile = fileInfos.uvdFiles
        let eventFile = fileInfos.eventFiles
        let filePrefix = "\(self.sectorId)/iOS"
        let normalizedFilePrefix = filePrefix.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        
        for r in rfdFile {
            let storageFileName = "\(normalizedFilePrefix)/\(r.name)"
            JupiterFileUploader.shared.requestStorageFileURL(fileName: storageFileName, completion: { output in
                if let s3Output = output {
                    let presigned_url = s3Output.presigned_url
                    JupiterLogger.i(tag: "JupiterManager", message: "uploadReplayFiles rfd : \(r.name)")
                    JupiterFileUploader.shared.uploadFileToStorage(s3Path: presigned_url, filePath: r.path, completion: { isSuccess in
                        if isSuccess { JupiterFileManager.shared.deleteReplayFile(at: r.path) }
                    })
                }
            })
        }
        
        for u in uvdFile {
            let storageFileName = "\(normalizedFilePrefix)/\(u.name)"
            JupiterFileUploader.shared.requestStorageFileURL(fileName: storageFileName, completion: { output in
                if let s3Output = output {
                    let presigned_url = s3Output.presigned_url
                    JupiterLogger.i(tag: "JupiterManager", message: "uploadReplayFiles uvd : \(u.name)")
                    JupiterFileUploader.shared.uploadFileToStorage(s3Path: presigned_url, filePath: u.path, completion: { isSuccess in
                        if isSuccess { JupiterFileManager.shared.deleteReplayFile(at: u.path) }
                    })
                }
            })
        }
        
        for e in eventFile {
            let storageFileName = "\(normalizedFilePrefix)/\(e.name)"
            JupiterFileUploader.shared.requestStorageFileURL(fileName: storageFileName, completion: { output in
                if let s3Output = output {
                    let presigned_url = s3Output.presigned_url
                    JupiterLogger.i(tag: "JupiterManager", message: "uploadReplayFiles event : \(e.name)")
                    JupiterFileUploader.shared.uploadFileToStorage(s3Path: presigned_url, filePath: e.path, completion: { isSuccess in
                        if isSuccess { JupiterFileManager.shared.deleteReplayFile(at: e.path) }
                    })
                }
            })
        }
    }
    
    private func performTasksWithCounter(tasks: [(_ group: DispatchGroup, _ reportError: @escaping (String) -> Void) -> Void],
                                         onComplete: @escaping () -> Void,
                                         onError: @escaping (String) -> Void) {
        let dispatchGroup = DispatchGroup()
        let lock = NSLock()
        var isErrorOccurred = false
        var firstErrorMessage: String?
        
        let reportError: (String) -> Void = { msg in
            lock.lock()
            if !isErrorOccurred {
                isErrorOccurred = true
                firstErrorMessage = msg
            }
            lock.unlock()
        }
        
        for task in tasks {
            task(dispatchGroup, reportError)
        }
        
        dispatchGroup.notify(queue: .main) {
            if let msg = firstErrorMessage, isErrorOccurred {
                onError(msg)
            } else {
                onComplete()
            }
        }
    }

    public func stopJupiter(completion: @escaping (Bool, String) -> Void) {
        if isStartJupiter {
            stopTimer()
            stopGenerator()
            jupiterCalcManager?.resetRuntimeState()
            isStartJupiter = false
            isGetFirstResult = false
            completion(true, "Jupiter stopped")
        } else if isStartMock {
            stopTimer()
            JupiterMockManager.shared.cancelPendingMockResults()
            isStartMock = false
            mockJupiterResult = nil
            completion(true, "Jupiter mock stopped")
        } else {
            completion(false, "After the service has fully started, it can be stop")
        }
    }
    
    private func startGenerator(mode: UserMode, completion: @escaping (Bool, String) -> Void) {
        guard let jupiterCalcManager else {
            completion(false, "JupiterCalcManager is nil")
            return
        }

        jupiterCalcManager.startGenerator(mode: mode, completion: { isSuccess, message in
            completion(isSuccess, message)
        })
    }
    
    private func stopGenerator() {
        if isStartJupiter {
            jupiterCalcManager?.stopGenerator()
        }
    }
    
    private func makeJupiterCalcManager() -> JupiterCalcManager {
        let calcManager = JupiterCalcManager(cloud: cloud, region: region, id: id, sectorId: sectorId, tenantUserName: tenantUserName)
        calcManager.debugOption = debugOption
        calcManager.delegate = self
        return calcManager
    }
    
    // MARK: - Bridging
    func getBuildingsData() -> [BuildingData]? {
        let buildingsData = jupiterCalcManager?.buildingsData
        JupiterLogger.i(tag: "JupiterManager", message: "getBuildingsData : buildingsData= \(buildingsData)")
        return buildingsData
    }
    
    func getMatchedLevelId(key: String) -> Int? {
        return jupiterCalcManager?.getMatchedLevelId(key: key)
    }

    func getBuildingName(buildingId: Int) -> String? {
        return jupiterCalcManager?.getBuildingName(buildingId: buildingId)
    }

    func getBuildingId(buildingName: String) -> Int? {
        return jupiterCalcManager?.getBuildingId(buildingName: buildingName)
    }

    func getLevelName(levelId: Int) -> String? {
        return jupiterCalcManager?.getLevelName(levelId: levelId)
    }

    func getLevelId(sectorId: Int, buildingName: String, levelName: String) -> Int? {
        return jupiterCalcManager?.getLevelId(sectorId: sectorId, buildingName: buildingName, levelName: levelName)
    }
    
    func getDefaultPosition(sectorId: Int) -> DefaultPosition? {
        return jupiterCalcManager?.getDefaultPosition(sectorId: sectorId)
    }
    
    func getWGS84Transform(sectorId: Int) -> WGS84Transform? {
        return jupiterCalcManager?.getWGS84Transform(sectorId: sectorId)
    }
    
    func getCurPmResultBuffer(from: Int) -> [FineLocationTrackingOutput]? {
        return jupiterCalcManager?.getCurPmResultBuffer(from: from)
    }
    
    func getCurPmResultBuffer(size: Int) -> [FineLocationTrackingOutput]? {
        return jupiterCalcManager?.getCurPmResultBuffer(size: size)
    }
    
    func changeUserMode(mode: UserMode) {
        self.curUserModeEnum = mode
        jupiterCalcManager?.changeUserMode(mode: mode)
    }
    
    // MARK: - ID Validation
    private func checkIdIsAvailable(id: String) -> (Bool, String) {
        if id.isEmpty || id.contains(" ") {
            let msg = TJLabsUtilFunctions.shared.getLocalTimeString() + " , (TJLabsJupiter) Error: User ID (input = \(id)) cannot be empty or contain spaces."
            return (false, msg)
        }
        return (true, "")
    }
    
    // MARK: - Jupiter Timer
    func startTimer() {
        if (self.outputTimer == nil) {
            let queue = DispatchQueue(label: Bundle.main.bundleIdentifier! + ".outputTimer")
            self.outputTimer = DispatchSource.makeTimerSource(queue: queue)
            self.outputTimer!.schedule(deadline: .now(), repeating: JupiterTime.OUTPUT_INTEVAL)
            self.outputTimer!.setEventHandler { [weak self] in
                guard let self = self else { return }
                self.outputTimerUpdate()
            }
            self.outputTimer!.resume()
        }
    }
    
    func stopTimer() {
        self.outputTimer?.cancel()
        self.outputTimer = nil
    }
    
    func outputTimerUpdate() {
        if mockMode {
            guard let jupiterResult = self.mockJupiterResult else { return }
            if jupiterPhase == .NONE {
                self.isJupiterPhaseChanged(index: jupiterResult.index, phase: .TRACKING, xyh: [jupiterResult.jupiter_pos.x, jupiterResult.jupiter_pos.y, jupiterResult.jupiter_pos.heading])
            }
            delegate?.onJupiterResult(jupiterResult)
        } else {
            guard let jupiterResult = jupiterCalcManager?.getJupiterResult(),
                  let jupiterPhase = jupiterCalcManager?.jupiterPhase else { return }
            if !isGetFirstResult {
                let currentTime = TJLabsUtilFunctions.shared.getCurrentTimeInMilliseconds(as: .int) as! Int
                JupiterFileManager.shared.writeEvent(event: JupiterEvent(mobile_time: currentTime, event_code: JupiterServiceCode.GET_FIRST_RESULT.rawValue))
                isGetFirstResult = true
            }
            delegate?.onJupiterResult(jupiterResult)
            makeMobileResult(jupiterPhase: jupiterPhase, jupiterResult: jupiterResult)
        }
    }
    
    private func makeMobileResult(jupiterPhase: JupiterPhase, jupiterResult: JupiterResult) {
        let is_vehicle = jupiterResult.is_vehicle
        let currentTime = TJLabsUtilFunctions.shared.getCurrentTimeInMilliseconds(as: .int) as! Int
        guard let levelId = self.getLevelId(sectorId: self.sectorId, buildingName: jupiterResult.building_name, levelName: jupiterResult.level_name) else {
            JupiterLogger.e(tag: "JupiterManager", message: "(makeMobileResult) level_id find fail \(self.sectorId):\(jupiterResult.building_name):\(jupiterResult.level_name)")
            return
        }
        
        var phase = 0
        switch jupiterPhase {
        case .ENTERING:
            phase = 1
        case .SEARCHING:
            phase = 2
        case .TRACKING:
            phase = 3
        case .EXITING:
            phase = 4
        case .NONE:
            phase = 0
        }
            
        let mobileResult = MobileResult(tenant_user_name: self.tenantUserName,
                                        is_vehicle: is_vehicle,
                                        mobile_time: currentTime,
                                        index: jupiterResult.index,
                                        velocity: jupiterResult.velocity,
                                        level_id: levelId,
                                        jupiter_position: jupiterResult.jupiter_pos,
                                        navigation_position: jupiterResult.navi_pos,
                                        phase: phase,
                                        is_indoor: jupiterResult.is_indoor,
                                        validity_flag: jupiterResult.validity_flag)
        DataBatchSender.shared.sendMobileResult(mobileResult: mobileResult)
    }
    
    public func getJupiterDebugResult() -> JupiterDebugResult? {
        if mockMode {
            guard let mockResult = self.mockJupiterResult else { return nil }
            let jupiterDebugResult = JupiterDebugResult(mobile_time: mockResult.mobile_time,
                                                        building_name: mockResult.building_name,
                                                        level_name: mockResult.level_name,
                                                        x: mockResult.jupiter_pos.x,
                                                        y: mockResult.jupiter_pos.y,
                                                        llh: mockResult.llh,
                                                        absolute_heading: mockResult.jupiter_pos.heading,
                                                        index: mockResult.index,
                                                        velocity: mockResult.velocity,
                                                        mode: "DR",
                                                        ble_only_position: false,
                                                        isIndoor: mockResult.is_indoor,
                                                        validity: true,
                                                        validity_flag: mockResult.validity_flag,
                                                        calc_xyh: [mockResult.jupiter_pos.x, mockResult.jupiter_pos.y, mockResult.jupiter_pos.heading],
                                                        tu_xyh: [mockResult.jupiter_pos.x, mockResult.jupiter_pos.y, mockResult.jupiter_pos.heading],
                                                        navi_xyh: [mockResult.jupiter_pos.x, mockResult.jupiter_pos.y, mockResult.jupiter_pos.heading])
            return jupiterDebugResult
        } else {
            guard let jupiterDebugResult = jupiterCalcManager?.getJupiterDebugResult() else { return nil }
            return jupiterDebugResult
        }
    }
    
    //MARK: - Simulation Mode
    public func setReplayMode(flag: Bool, rfdFileName: String, uvdFileName: String, eventFileName: String) {
        JupiterReplayer.shared.setReplayMode(flag: flag, rfdFileName: rfdFileName, uvdFileName: uvdFileName, eventFileName: eventFileName)
    }
    
    public func setReplayModeLegacy(flag: Bool, bleFileName: String, sensorFileName: String) {
        JupiterReplayer.shared.setReplayModeLegacy(flag: flag, bleFileName: bleFileName, sensorFileName: sensorFileName)
    }
    
    public func saveFilesForReplay(completion: @escaping (Bool) -> Void) {
        JupiterFileManager.shared.saveFilesForReplay(completion: { isSuccess in
            completion(isSuccess)
        })
    }
    
    // MARK: - Mock Mode
    public func setMockMode(mode: JupiterMockMode, completion: @escaping (Bool) -> Void) {
        if mode == .NONE {
            JupiterMockManager.shared.initialize()
            self.mockMode = false
            DispatchQueue.main.async {
                completion(false)
            }
        } else {
            JupiterMockManager.shared.setMockMode(mode: mode) { [weak self] isSuccess in
                guard let self = self else { return }
                self.mockMode = isSuccess
                completion(isSuccess)
            }
        }
    }
}
