import SystemConfiguration
import Foundation

class OlympusNetworkChecker {
    
    static let shared = OlympusNetworkChecker()
    private let reachability = SCNetworkReachabilityCreateWithName(nil, "NetworkCheck")
    
    private init() {}
    
    func isConnectedToInternet() -> Bool {
        var flags = SCNetworkReachabilityFlags()
        SCNetworkReachabilityGetFlags(self.reachability!, &flags)
        let isReachable = flags.contains(.reachable)
        let needsConnection = flags.contains(.connectionRequired)
        return (isReachable && !needsConnection)
    }
}
