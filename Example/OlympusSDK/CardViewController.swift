import UIKit
import OlympusSDK

class CardViewController: UIViewController {
    
    var region: String = ""
    var userId: String = ""
    let OPERATING_SYSTEM: String = "iOS"
    
    var serviceManager = OlympusServiceManager()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        var sector_id = 2
        var mode = "pdr"
        
        serviceManager.startService(user_id: self.userId, region: self.region, sector_id: sector_id, service: "FLT", mode: mode, completion: { isStart, returnedString in
            if (isStart) {
//                print(returnedString)
            } else {
                print(returnedString)
            }
        })
    }
    
}
