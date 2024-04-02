import Foundation

public class NetworkManager {
    static let shared = NetworkManager()
    
    init() {
        let uvdConfig = URLSessionConfiguration.default
        uvdConfig.timeoutIntervalForResource = TIMEOUT_VALUE_PUT
        uvdConfig.timeoutIntervalForRequest = TIMEOUT_VALUE_PUT
//        self.uvdSession1 = URLSession(configuration: uvdConfig)
//        self.uvdSession2 = URLSession(configuration: uvdConfig)
//        self.uvdSessions.append(self.uvdSession1)
//        self.uvdSessions.append(self.uvdSession2)
        
        let fltConfig = URLSessionConfiguration.default
        fltConfig.timeoutIntervalForResource = TIMEOUT_VALUE_POST
        fltConfig.timeoutIntervalForRequest = TIMEOUT_VALUE_POST
//        self.fltSession = URLSession(configuration: fltConfig)
    }
}
