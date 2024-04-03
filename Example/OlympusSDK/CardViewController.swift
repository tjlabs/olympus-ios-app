import UIKit
import OlympusSDK

class CardViewController: UIViewController {
    
    var region: String = ""
    var userId: String = ""
    let OPERATING_SYSTEM: String = "iOS"
    
    var serviceManager = ServiceManager()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        serviceManager.startService(user_id: self.userId, region: self.region, sector_id: 6, completion: { isStart, returnedString in
            if (isStart) {
//                print(returnedString)
            } else {
                print(returnedString)
            }
        })
    }
    
}
