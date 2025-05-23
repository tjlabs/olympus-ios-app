//import UIKit
//import OlympusSDK
//
//class MapViewController: UIViewController, Observer {
//    
//    func update(result: OlympusSDK.FineLocationTrackingResult) {
//        self.mapView.updateResultInMap(result: result)
//    }
//    
//    func report(flag: Int) {
//        
//    }
//    
//    @IBOutlet weak var topView: UIView!
//    @IBOutlet weak var mainView: UIView!
//    let mapView = OlympusMapView()
//    
//    var serviceManager = OlympusServiceManager()
////    var sector_id: Int = 2
////    var mode: String = "pdr"
//    var sector_id: Int = 6
//    var mode: String = "auto"
//    var userId: String = ""
//    
//    var timer: Timer?
//    let TIMER_INTERVAL: TimeInterval = 1/10
//    
//    private var foregroundObserver: Any!
//    private var backgroundObserver: Any!
//    
//    override func viewWillAppear(_ animated: Bool) {
//        super.viewWillAppear(false)
//        navigationController?.isNavigationBarHidden = true
//        self.notificationCenterAddObserver()
//    }
//    
//    override func viewDidLoad() {
//        super.viewDidLoad()
//        setupLayout()
//        
//        startOlympus()
//    }
//    
//    override func viewDidDisappear(_ animated: Bool) {
//        self.notificationCenterRemoveObserver()
//        stopTimer()
//        serviceManager.stopService()
//        serviceManager.removeObserver(self)
//    }
//    
//    private func startOlympus() {
////        let uniqueId = makeUniqueId(uuid: self.userId)
//////        serviceManager.setSimulationMode(flag: true, bleFileName: "ble_coex_05_04_1007.csv", sensorFileName: "sensor_coex_05_04_1007.csv")
////        serviceManager.setSimulationMode(flag: true, bleFileName: "ble_coex_03_03_1007.csv", sensorFileName: "sensor_coex_03_03_1007.csv")
//////        serviceManager.setSimulationMode(flag: true, bleFileName: "ble_coex_dr_03_1030.csv", sensorFileName: "sensor_coex_dr_03_1030.csv")
////        serviceManager.addObserver(self)
////        serviceManager.startService(user_id: uniqueId, region: "Korea", sector_id: sector_id, service: "FLT", mode: mode, completion: { [self] isStart, returnedString in
////            if (isStart) {
////                self.startTimer()
////                OlympusMapManager.shared.loadMap(region: "Korea", sector_id: sector_id, mapView: mapView)
////            } else {
////                print(returnedString)
////            }
////        })
//        
//        OlympusMapManager.shared.loadMap(region: "Korea", sector_id: sector_id, mapView: mapView)
//    }
//    
//    func startTimer() {
//        if (timer == nil) {
//            timer = Timer.scheduledTimer(timeInterval: TIMER_INTERVAL, target: self, selector: #selector(self.timerUpdate), userInfo: nil, repeats: true)
//            RunLoop.current.add(self.timer!, forMode: .common)
//        }
//    }
//    
//    func stopTimer() {
//        if (timer != nil) {
//            self.timer!.invalidate()
//            self.timer = nil
//        }
//    }
//    
//    @objc func timerUpdate() {
//        
//    }
//    
//    private func makeUniqueId(uuid: String) -> String {
//        let currentTime: Int = getCurrentTimeInMilliseconds()
//        let unique_id: String = "\(uuid)_\(currentTime)"
//        return unique_id
//    }
//    
//    @IBAction func tapBackButton(_ sender: UIButton) {
//        serviceManager.removeObserver(self)
//        self.navigationController?.popViewController(animated: true)
//    }
//    
//    func notificationCenterAddObserver() {
//        self.backgroundObserver = NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { _ in
//            self.serviceManager.setBackgroundMode(flag: true)
//        }
//        
//        self.foregroundObserver = NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { _ in
//            self.serviceManager.setBackgroundMode(flag: false)
//        }
//    }
//    
//    func notificationCenterRemoveObserver() {
//        NotificationCenter.default.removeObserver(self.backgroundObserver)
//        NotificationCenter.default.removeObserver(self.foregroundObserver)
//    }
//}
//
//extension MapViewController {
//    func setupLayout() {
//        mapView.configureFrame(to: mainView)
//        mainView.addSubview(mapView)
//    }
//}
