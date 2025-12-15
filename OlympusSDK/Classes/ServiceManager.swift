
import Foundation

public class ServiceManager {
    public static let sdkVersion: String = "0.4.0"
    
    public init() {
        self.deviceIdentifier = UIDevice.modelIdentifier
        self.deviceModel = UIDevice.modelName
        let deviceOs = UIDevice.current.systemVersion
        let arr = deviceOs.components(separatedBy: ".")
        self.deviceOsVersion = Int(arr[0]) ?? 0
    }
    
    deinit { }
    
    private var deviceModel: String
    private var deviceIdentifier: String
    private var deviceOsVersion: Int

    
    public func startService() {
        
    }
    
    public func stopService() {
        
    }
    
    public func reset() {
        
    }
}
