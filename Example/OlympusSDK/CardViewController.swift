import UIKit
import OlympusSDK

class CardViewController: UIViewController, Observer {
    
    override func viewDidDisappear(_ animated: Bool) {
        serviceManager.removeObserver(self)
    }
    
    func update(result: OlympusSDK.FineLocationTrackingResult) {
        if (result.x != 0 && result.y != 0) {
            print("InnerLabs : Result = \(result)")
        }
        
    }
    
    func report(flag: Int) {
        print("InnerLabs : Flag = \(flag)")
    }
    
    var region: String = ""
    var userId: String = ""
    let OPERATING_SYSTEM: String = "iOS"
    
    var serviceManager = OlympusServiceManager()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        serviceManager.addObserver(self)
        
        var sector_id = 2
        var mode = "pdr"
        
        serviceManager.startService(user_id: self.userId, region: self.region, sector_id: sector_id, service: "FLT", mode: mode, completion: { [self] isStart, returnedString in
            if (isStart) {
                serviceManager.addObserver(self)
//                print(returnedString)
            } else {
                print(returnedString)
            }
        })
    }
    
}
