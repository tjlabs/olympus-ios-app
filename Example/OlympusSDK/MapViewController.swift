
import UIKit
import SnapKit
import Then
import OlympusSDK
import TJLabsCommon
import TJLabsResource
import TJLabsMap


class MapViewController: UIViewController, JupiterManagerDelegate {
    func report(flag: Int) {
        // TODO
    }
    
    func onJupiterReport(_ flag: Int) {
        //
    }
    
    func onJupiterSuccess(_ isSuccess: Bool) {
        // TODO
    }
    
    func onJupiterError(_ code: Int, _ msg: String) {
        // TODO
    }
    
    func onJupiterResult(_ result: JupiterResult) {
        let userCoord = TJLabsUserCoordinate(building: result.building_name, level: result.level_name, x: result.x, y: result.y, heading: result.absolute_heading, velocity: result.velocity)
        
        if result.level_name == "B0" && !isParkingGuideRendered {
            DispatchQueue.main.async { [self] in
                self.guideView = TJLabsParkingGuideView()
                UIView.animate(withDuration: 0.2, animations: {
                    containerView.addSubview(self.guideView!)
                    self.guideView!.snp.makeConstraints { make in
                        make.top.bottom.leading.trailing.equalToSuperview()
                    }
                })
            }
            isParkingGuideRendered = true
        }
        
        if result.level_name == "B2" && isParkingGuideRendered {
            DispatchQueue.main.async { [self] in
                self.guideView?.removeFromSuperview()
            }
        }
        
        mapView.updateResultInMap(result: userCoord)
        print("(MapVC) : userCoord = \(userCoord)")
    }
    
    var region: String = JupiterRegion.KOREA.rawValue
    var sectorId: Int = 6
    var userId: String = ""
    
    var serviceManager: JupiterManager?
    var jupiterResult: JupiterResult?
    
    private let containerView = UIView().then {
        $0.backgroundColor = .clear
    }
    
    private let mainView = UIView().then {
        $0.backgroundColor = .clear
    }
    
    let topView = TJLabsTopView()
    var guideView: TJLabsParkingGuideView?
    let mapView = TJLabsMapView()
    var isParkingGuideRendered: Bool = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupLayout()
        startService()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: false)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: false)
    }
    
    func startService() {
        let uniqueId = makeUniqueId(uuid: self.userId)
        
        serviceManager = JupiterManager(id: uniqueId)
        serviceManager?.delegate = self
//        serviceManager?.setSimulationMode(flag: true, bleFileName: "ble_coex_01_03_1007.csv", sensorFileName: "sensor_coex_01_03_1007.csv")
//        serviceManager?.setSimulationMode(flag: true, bleFileName: "ble_coex_02_05_1007.csv", sensorFileName: "sensor_coex_02_05_1007.csv")
        serviceManager?.setSimulationMode(flag: true, bleFileName: "ble_coex_03_05_1007.csv", sensorFileName: "sensor_coex_03_05_1007.csv")
//        serviceManager?.setSimulationMode(flag: true, bleFileName: "ble_coex_05_04_1007.csv", sensorFileName: "sensor_coex_05_04_1007.csv")
        serviceManager?.startJupiter(sectorId: sectorId, mode: .MODE_AUTO)
    }
    
    func stopSerivce() {
        serviceManager?.stopJupiter(completion: { [self] isSuccess, msg in
        })
    }
    
    func setupLayout() {
        view.addSubview(topView)
        topView.snp.makeConstraints{ make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(120)
        }
        
        view.addSubview(containerView)
        containerView.snp.makeConstraints { make in
            make.top.equalTo(topView.snp.bottom)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom)
//            make.edges.equalToSuperview()
        }

        containerView.addSubview(mainView)
        mainView.snp.makeConstraints { make in
            make.top.bottom.leading.trailing.equalToSuperview()
        }
        
        setupNaviView()
        mapView.setPointOffset(offset: CGFloat(40))
        mapView.setDebugOption(flag: false)
    }
    
    func setupNaviView() {
        mapView.initialize(region: self.region, sectorId: self.sectorId)
        mapView.configureFrame(to: mainView)
        mainView.addSubview(mapView)
    }
    
    private func makeUniqueId(uuid: String) -> String {
        let currentTime: Int = TJLabsUtilFunctions.shared.getCurrentTimeInMilliseconds(as: .int) as! Int
        let unique_id: String = "\(uuid)_\(currentTime)"
        
        return unique_id
    }
    
}
