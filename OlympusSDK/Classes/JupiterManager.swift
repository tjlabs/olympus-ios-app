import Foundation
import TJLabsCommon
import TJLabsResource
import UIKit

public class JupiterManager: JupiterCalcManagerDelegate {
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
    
    public static let sdkVersion: String = "0.0.1"
    
    var id: String = ""
    var sectorId: Int = 0
    var region: JupiterRegion = .KOREA
    var deviceModel: String
    var deviceIdentifier: String
    var deviceOsVersion: Int
    
    var jupiterCalcManager: JupiterCalcManager?
    private var jupiterPhase: JupiterPhase = .NONE
    public weak var delegate: JupiterManagerDelegate?
    
    private var isStartService = false
    private var sendRfdLength = 2
    private var sendUvdLength = 4
    
    private var mockingMode = false
    
    // MARK: - JupiterResult Timer
    var outputTimer: DispatchSourceTimer?
    
    public init(id: String) {
        self.id = id
        self.deviceIdentifier = UIDevice.modelIdentifier
        self.deviceModel = UIDevice.modelName
        let deviceOs = UIDevice.current.systemVersion
        let arr = deviceOs.components(separatedBy: ".")
        self.deviceOsVersion = Int(arr[0]) ?? 0
    }
    
    deinit {
        jupiterCalcManager = nil
    }

    // MARK: - Start & Stop Jupiter Service
    public func startJupiter(region: String = JupiterRegion.KOREA.rawValue, sectorId: Int, mode: UserMode, debugOption: Bool = false) {
        JupiterNetworkConstants.setServerURL(region: region)
        
        let (isNetworkAvailable, msgCheckNetworkAvailable) = JupiterNetworkManager.shared.isConnectedToInternet()
        let (isIdAvailable, msgCheckIdAvailable) = checkIdIsAvailable(id: id)
        
        if !isNetworkAvailable {
            delegate?.onJupiterError(0, msgCheckNetworkAvailable)
            delegate?.onJupiterSuccess(false)
            return
        }
        
        if !isIdAvailable {
            delegate?.onJupiterError(0, msgCheckIdAvailable)
            delegate?.onJupiterSuccess(false)
            return
        }
        
        if isStartService {
            delegate?.onJupiterError(0, "The service is already starting.")
            delegate?.onJupiterSuccess(false)
            return
        }
        
        let loginInput = LoginInput(name: self.id)
        let tasks: [(_ group: DispatchGroup, _ reportError: @escaping (String) -> Void) -> Void] = [
            { group, reportError in
                group.enter()
                let loginURL = JupiterNetworkConstants.getUserLoginURL()
                JupiterNetworkManager.shared.postUserLogin(url: loginURL, input: loginInput) { success, msg in
                    JupiterLogger.i(tag: "JupiterManager", message: "(login) - url \(loginURL)")
                    if success != 200 {
                        reportError(msg)
                        self.delegate?.onJupiterError(success, msg)
                    }
                    group.leave()
                }
            }
        ]
        
        performTasksWithCounter(tasks: tasks, onComplete: { [self] in
            jupiterCalcManager = JupiterCalcManager(region: region, id: self.id, sectorId: sectorId)
            jupiterCalcManager?.start(completion: { [self] isSuccess, msg in
                if isSuccess {
                    if debugOption {
                        self.uploadSimulationFiles()
                        JupiterFileManager.shared.setDebugOption(flag: debugOption)
                        JupiterFileManager.shared.createFiles(id: self.id, os: "iOS")
                    }
                    
                    jupiterCalcManager?.delegate = self
                    jupiterCalcManager?.setSendRfdLength(sendRfdLength)
                    jupiterCalcManager?.setSendUvdLength(sendUvdLength)
                    startGenerator(mode: mode, completion: { [self] isSuccess, msg in
                        if isSuccess {
                            isStartService = true
                            startTimer()
                            let currentTime = TJLabsUtilFunctions.shared.getCurrentTimeInMilliseconds(as: .int) as! Int
                            JupiterFileManager.shared.writeEvent(event: JupiterEvent(mobile_time: currentTime, event_code: .START_SERVICE))
                            delegate?.onJupiterSuccess(true)
                        } else {
                            delegate?.onJupiterError(0, msg)
                            delegate?.onJupiterSuccess(false)
                        }
                    })
                } else {
                    delegate?.onJupiterError(0, msg)
                    delegate?.onJupiterSuccess(false)
                }
            })
        }, onError: { msg in
            self.delegate?.onJupiterError(0, msg)
            self.delegate?.onJupiterSuccess(false)
        })
    }
    
    private func uploadSimulationFiles() {
        let fileInfos = JupiterFileUploader.shared.getSimulationFilesInExports()
        JupiterLogger.i(tag: "JupiterManager", message: "uploadSimulationFiles : fileInfos= \(fileInfos)")
        let rfdFile = fileInfos.rfdFiles
        let uvdFile = fileInfos.uvdFiles
        let eventFile = fileInfos.eventFiles
        
        for r in rfdFile {
            JupiterFileUploader.shared.requestS3FileURL(fileName: r.name, completion: { [self] output in
                if let s3Output = output {
                    let presigned_url = s3Output.presigned_url
                    JupiterLogger.i(tag: "JupiterManager", message: "uploadSimulationFiles rfd : \(r.name)")
                    JupiterFileUploader.shared.uploadFileToS3(s3Path: presigned_url, filePath: r.path, completion: { isSuccess in
                        if isSuccess { JupiterFileManager.shared.deleteSimulationFile(at: r.path) }
                    })
                }
            })
        }
        
        for u in uvdFile {
            JupiterFileUploader.shared.requestS3FileURL(fileName: u.name, completion: { [self] output in
                if let s3Output = output {
                    let presigned_url = s3Output.presigned_url
                    JupiterLogger.i(tag: "JupiterManager", message: "uploadSimulationFiles uvd : \(u.name)")
                    JupiterFileUploader.shared.uploadFileToS3(s3Path: presigned_url, filePath: u.path, completion: { isSuccess in
                        if isSuccess { JupiterFileManager.shared.deleteSimulationFile(at: u.path) }
                    })
                }
            })
        }
        
        for e in eventFile {
            JupiterFileUploader.shared.requestS3FileURL(fileName: e.name, completion: { [self] output in
                if let s3Output = output {
                    let presigned_url = s3Output.presigned_url
                    JupiterLogger.i(tag: "JupiterManager", message: "uploadSimulationFiles event : \(e.name)")
                    JupiterFileUploader.shared.uploadFileToS3(s3Path: presigned_url, filePath: e.path, completion: { isSuccess in
                        if isSuccess { JupiterFileManager.shared.deleteSimulationFile(at: e.path) }
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
        if isStartService {
            stopTimer()
            stopGenerator()
            jupiterCalcManager = nil
            
            isStartService = false
        } else {
            completion(false, "After the service has fully started, it can be stop")
        }
    }
    
    private func startGenerator(mode: UserMode, completion: @escaping (Bool, String) -> Void) {
        jupiterCalcManager?.startGenerator(mode: mode, completion: { isSuccess, message in
            completion(isSuccess, message)
        })
    }
    
    private func stopGenerator() {
        if isStartService {
            jupiterCalcManager?.stopGenerator()
        }
    }
    
    // MARK: - Bridging
    public func getBuildingsData() -> [BuildingData]? {
        return jupiterCalcManager?.getBuildingsData()
    }
    
    public func getLevelId(sectorId: Int, buildingName: String, levelName: String) -> Int? {
        return jupiterCalcManager?.getLevelId(sectorId: sectorId, buildingName: buildingName, levelName: levelName)
    }
    
    public func getCurPmResultBuffer(from: Int) -> [FineLocationTrackingOutput]? {
        return jupiterCalcManager?.getCurPmResultBuffer(from: from)
    }
    
    public func getCurPmResultBuffer(size: Int) -> [FineLocationTrackingOutput]? {
        return jupiterCalcManager?.getCurPmResultBuffer(size: size)
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
        if mockingMode {
            let currentTime = TJLabsUtilFunctions.shared.getCurrentTimeInMilliseconds(as: .int) as! Int
            let mockResult = JupiterResult(mobile_time: currentTime,
                                           index: 1,
                                           building_name: "Underground",
                                           level_name: "B7",
                                           jupiter_pos: Position(x: 1000, y: 1000, heading: 270),
                                           velocity: 7,
                                           is_vehicle: true,
                                           is_indoor: true,
                                           validity_flag: 1)
            delegate?.onJupiterResult(mockResult)
        } else {
            guard let jupiterResult = jupiterCalcManager?.getJupiterResult(),
                  let jupiterPhase = jupiterCalcManager?.jupiterPhase else { return }
            delegate?.onJupiterResult(jupiterResult)
            makeMobileResult(jupiterPhase: jupiterPhase, jupiterResult: jupiterResult)
        }
    }
    
    private func makeMobileResult(jupiterPhase: JupiterPhase, jupiterResult: JupiterResult) {
        let is_vehicle = jupiterResult.is_vehicle
        let has_route = false
        let currentTime = TJLabsUtilFunctions.shared.getCurrentTimeInMilliseconds(as: .int) as! Int
        guard let levelId = self.getLevelId(sectorId: self.sectorId, buildingName: jupiterResult.building_name, levelName: jupiterResult.level_name) else { return }
        
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
        
        let mobileResult = MobileResult(tenant_user_name: self.id,
                                        is_vehicle: is_vehicle,
                                        mobile_time: currentTime,
                                        index: jupiterResult.index,
                                        level_id: levelId,
                                        jupiter_pos: jupiterResult.jupiter_pos,
                                        navi_pos: jupiterResult.navi_pos,
                                        phase: phase,
                                        is_indoor: jupiterResult.is_indoor,
                                        latitude: jupiterResult.llh?.lat,
                                        longitude: jupiterResult.llh?.lon,
                                        azimuth: jupiterResult.llh?.heading,
                                        velocity: jupiterResult.velocity,
                                        validity_flag: jupiterResult.validity_flag)
        DataBatchSender.shared.sendMobileResult(mobileResult: mobileResult)
    }
    
    public func getJupiterDebugResult() -> JupiterDebugResult? {
        guard let jupiterDebugResult = jupiterCalcManager?.getJupiterDebugResult() else { return nil }
        return jupiterDebugResult
    }
    
    //MARK: - Simulation Mode
    public func setSimulationMode(flag: Bool, rfdFileName: String, uvdFileName: String, eventFileName: String) {
        JupiterSimulator.shared.setSimulationMode(flag: flag, rfdFileName: rfdFileName, uvdFileName: uvdFileName, eventFileName: eventFileName)
    }
    
    public func setSimulationModeLegacy(flag: Bool, bleFileName: String, sensorFileName: String) {
        JupiterSimulator.shared.setSimulationModeLegacy(flag: flag, bleFileName: bleFileName, sensorFileName: sensorFileName)
    }
    
    public func saveFilesForSimulation(completion: @escaping (Bool) -> Void) {
        JupiterFileManager.shared.saveFilesForSimulation(completion: { isSuccess in
            completion(isSuccess)
        })
    }
    
    // MARK: - Mocking Mode
    public func setMockingMode() {
        self.mockingMode = true
    }
}
