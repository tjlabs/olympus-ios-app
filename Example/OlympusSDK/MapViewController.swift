import UIKit
import OlympusSDK

class MapViewController: UIViewController, Observer {
    
    func update(result: OlympusSDK.FineLocationTrackingResult) {
        self.mapView.updateResultInMap(result: result)
    }
    
    func report(flag: Int) {
        // qwer
    }
    
    @IBOutlet weak var topView: UIView!
    @IBOutlet weak var mainView: UIView!
    let mapView = OlympusMapView()
    
    var serviceManager = OlympusServiceManager()
    var sector_id: Int = 6
    var mode: String = "auto"
    var userId: String = ""
    
    var timer: Timer?
    let TIMER_INTERVAL: TimeInterval = 1/10
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(false)
        navigationController?.isNavigationBarHidden = true
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupLayout()
        
        startOlympus()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        stopTimer()
        serviceManager.stopService()
        serviceManager.removeObserver(self)
    }
    
    private func startOlympus() {
        let uniqueId = makeUniqueId(uuid: self.userId)
//        serviceManager.setSimulationMode(flag: true, bleFileName: "ble_coex_05_04_1007.csv", sensorFileName: "sensor_coex_05_04_1007.csv")
        serviceManager.setSimulationMode(flag: true, bleFileName: "ble_coex_dr_03_1030.csv", sensorFileName: "sensor_coex_dr_03_1030.csv")
        
        serviceManager.addObserver(self)
        serviceManager.startService(user_id: uniqueId, region: "Korea", sector_id: sector_id, service: "FLT", mode: mode, completion: { [self] isStart, returnedString in
            if (isStart) {
                self.startTimer()
                OlympusMapManager.shared.loadMap(region: "Korea", sector_id: sector_id, mapView: mapView)
            } else {
                print(returnedString)
            }
        })
        
//        OlympusMapManager.shared.loadMap(region: "Korea", sector_id: sector_id, mapView: mapView)
    }
    
    func startTimer() {
        if (timer == nil) {
            timer = Timer.scheduledTimer(timeInterval: TIMER_INTERVAL, target: self, selector: #selector(self.timerUpdate), userInfo: nil, repeats: true)
            RunLoop.current.add(self.timer!, forMode: .common)
        }
    }
    
    func stopTimer() {
        if (timer != nil) {
            self.timer!.invalidate()
            self.timer = nil
        }
    }
    
    @objc func timerUpdate() {
        
    }
    
    private func makeUniqueId(uuid: String) -> String {
        let currentTime: Int = getCurrentTimeInMilliseconds()
        let unique_id: String = "\(uuid)_\(currentTime)"
        return unique_id
    }
    
    @IBAction func tapBackButton(_ sender: UIButton) {
        serviceManager.removeObserver(self)
        self.navigationController?.popViewController(animated: true)
    }
}

extension MapViewController {
    func setupLayout() {
        mapView.configureFrame(to: mainView)
        mainView.addSubview(mapView)
    }
}
