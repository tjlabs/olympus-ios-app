import Foundation
import CoreMotion
import UIKit

public class ServiceManager: NSObject {
    public static let sdkVersion: String = "0.1.0"
    var deviceModel: String
    var deviceOsVersion: Int
    
    var sensorManager = SensorManager()
    var bleManager = BLECentralManager()
    
    // State Observer
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
    
    public func startService() {
        
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
