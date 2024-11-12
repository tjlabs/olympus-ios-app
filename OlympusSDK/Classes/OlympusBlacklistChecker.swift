import Foundation
import UIKit

public class OlympusBlacklistChecker: Observation {
    public static let shared = OlympusBlacklistChecker()
    
    var deviceModel: String = "Unknown"
    var deviceIdentifier: String = "Unknown"
    var os: String = "Unknown"
    var osVersion: Int = 0
    
    func reporting(input: Int) {
        for observer in observers {
            observer.report(flag: input)
        }
    }
    
    func setUserDeviceInfo() {
        deviceIdentifier = UIDevice.modelIdentifier
        deviceModel = UIDevice.modelName
        os = UIDevice.current.systemVersion
        let arr = os.components(separatedBy: ".")
        osVersion = Int(arr[0]) ?? 0
    }
    
    public func checkServiceAvailableDevice(completion: @escaping (Bool) -> Void) {
        setUserDeviceInfo()
        OlympusNetworkManager.shared.getBlackList(url: BLACK_LIST_URL) { [self] statusCode, returnedString in
            var isBlacklistUpdated = false
            var isServiceAvailable = false
            var blacklistUpdatedTime = ""
            var requestFailed = false

            let loadedBlacklistInfo = loadBlacklistInfo()
            if statusCode == 200, let blackListDevices = jsonToBlackListDevices(from: returnedString) {
                // Successful communication
                let updatedTime = blackListDevices.updatedTime
                blacklistUpdatedTime = updatedTime

                isBlacklistUpdated = loadedBlacklistInfo.1.isEmpty || loadedBlacklistInfo.1 != updatedTime

                if isBlacklistUpdated {
                    print(getLocalTimeString() + " , (Olympus) Blacklist: iOS Devices = \(blackListDevices.iOS.apple)")
                    print(getLocalTimeString() + " , (Olympus) Blacklist: Updated Time = \(blackListDevices.updatedTime)")
                    
                    isServiceAvailable = !blackListDevices.iOS.apple.contains { $0.contains(deviceIdentifier) }
                } else {
                    isServiceAvailable = loadedBlacklistInfo.0
                }
            } else {
                // Communication failed
                requestFailed = true
            }

            if requestFailed {
                // Check cache if available
                if !loadedBlacklistInfo.1.isEmpty {
                    isServiceAvailable = loadedBlacklistInfo.0
                    blacklistUpdatedTime = loadedBlacklistInfo.1
                }
            }

            if !isServiceAvailable {
                self.reporting(input: BLACK_LIST_FLAG)
            }

            saveBlacklistInfo(isServiceAvailable: isServiceAvailable, updatedTime: blacklistUpdatedTime)
            completion(isServiceAvailable)
        }
    }

    private func loadBlacklistInfo() -> (Bool, String) {
        var isServiceAvailable: Bool = false
        var updatedTime: String = ""
        
        let keyIsServiceAvailable: String = "OlympusIsServiceAvailable"
        if let loadedIsServiceAvailable: Bool = UserDefaults.standard.object(forKey: keyIsServiceAvailable) as? Bool {
            isServiceAvailable = loadedIsServiceAvailable
        }
        
        let keyUpdatedTime: String = "OlympusBlacklistUpdatedTime"
        if let loadedUpdatedTime: String = UserDefaults.standard.object(forKey: keyUpdatedTime) as? String {
            updatedTime = loadedUpdatedTime
        }
        
        return (isServiceAvailable, updatedTime)
    }

    private func saveBlacklistInfo(isServiceAvailable: Bool, updatedTime: String) {
        print(getLocalTimeString() + " , (Olympus) Save Blacklist Info : \(isServiceAvailable) , \(updatedTime)")
        
        do {
            let key: String = "OlympusIsServiceAvailable"
            UserDefaults.standard.set(isServiceAvailable, forKey: key)
        }
        
        do {
            let key: String = "OlympusBlacklistUpdatedTime"
            UserDefaults.standard.set(updatedTime, forKey: key)
        }
    }
}

