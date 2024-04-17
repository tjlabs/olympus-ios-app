public class OlympusKalmanFilter: NSObject {
    
    override init() {
        
    }
    
    public var isRunning: Bool = false
    
    public func initKalmanFilter() {
        self.isRunning = false
    }
    
    public func activateKalmanFilter() {
        self.isRunning = true
    }
}
