import Foundation
import TJLabsCommon
import UIKit

public class JupiterManager {
    public static let sdkVersion: String = "0.0.1"
    
    var id: String = ""
    var sectorId: Int = 0
    var region: JupiterRegion = .KOREA
    var deviceModel: String
    var deviceIdentifier: String
    var deviceOsVersion: Int
    
    var jupiterCalcManager: JupiterCalcManager?
    private var naviMode: Bool = false
    public weak var delegate: JupiterManagerDelegate?
    
    private var isStartService = false
    private var sendRfdLength = 2
    private var sendUvdLength = 4
    
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
        
        let loginInput = LoginInput(name: self.id, device_model: self.deviceModel, os_version: self.deviceOsVersion, sdk_version: JupiterManager.sdkVersion)
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
            JupiterFileManager.shared.set(region: region, sectorId: sectorId, deviceModel: self.deviceModel, osVersion: self.deviceOsVersion)
            jupiterCalcManager = JupiterCalcManager(region: region, id: self.id, sectorId: sectorId)
            jupiterCalcManager?.start(completion: { [self] isSuccess, msg in
                if isSuccess {
                    // File Save Setting
                    if debugOption {
                        JupiterFileManager.shared.setDebugOption(flag: debugOption)
                        JupiterFileManager.shared.createFiles(region: region, sector_id: sectorId, deviceModel: deviceModel, osVersion: deviceOsVersion)
                        JupiterFileManager.shared.createFileWithName(region: region, sector_id: sectorId, deviceModel: deviceModel, osVersion: deviceOsVersion, fileName: "_")
                    }
                    jupiterCalcManager?.navigationMode(flag: self.naviMode)
                    jupiterCalcManager?.setSendRfdLength(sendRfdLength)
                    jupiterCalcManager?.setSendUvdLength(sendUvdLength)
                    startGenerator(mode: mode, completion: { [self] isSuccess, msg in
                        if isSuccess {
                            isStartService = true
                            startTimer()
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
    
    public func navigationMode(flag: Bool) {
        self.naviMode = flag
        jupiterCalcManager?.navigationMode(flag: self.naviMode)
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
        guard let jupiterResult = jupiterCalcManager?.getJupiterResult() else { return }
        delegate?.onJupiterResult(jupiterResult)
    }
    
    public func getJupiterDebugResult() -> JupiterDebugResult? {
        guard let jupiterDebugResult = jupiterCalcManager?.getJupiterDebugResult() else { return nil }
        return jupiterDebugResult
    }
    
    //MARK: - Simulation Mode
    public func setSimulationMode(flag: Bool, bleFileName: String, sensorFileName: String) {
        JupiterSimulator.shared.setSimulationMode(flag: flag, bleFileName: bleFileName, sensorFileName: sensorFileName)
    }
    
    public func saveFilesForSimulation(completion: @escaping (Bool) -> Void) {
        JupiterFileManager.shared.saveFilesForSimulation(completion: { isSuccess in
            completion(isSuccess)
        })
    }
    
    public func saveDebugFile(completion: @escaping (Bool) -> Void) {
        JupiterFileManager.shared.saveDebugFile(completion: { isSuccess in
            completion(isSuccess)
        })
    }
}
