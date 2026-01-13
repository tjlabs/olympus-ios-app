import UIKit
import SnapKit
import Then
import OlympusSDK
import TJLabsAuth
import TJLabsCommon
import TJLabsResource
import TJLabsMap

class MapViewController: UIViewController, Observer {
    
    func update(result: OlympusSDK.FineLocationTrackingResult) {
        if result.level_name == "B0" && !isParkingGuideRendered {
            DispatchQueue.main.async { [self] in
                self.guideView = TJLabsParkingGuideView()
                UIView.animate(withDuration: 0.2, animations: {
                    print("(DEBUG) Parking guide rendered")
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
        
        
        let userCoord = TJLabsUserCoordinate(building: result.building_name, level: result.level_name, x: Float(result.x), y: Float(result.y), heading: Float(result.absolute_heading), velocity: Float(result.velocity))
        mapView.updateResultInMap(result: userCoord)
        print("(MapVC) : userCoord = \(userCoord)")
    }
    
    func report(flag: Int) {
        // TODO
    }
    
    var region: String = "Korea"
    var sectorId: Int = 6
    var userId: String = ""
    
    let serviceManager = OlympusServiceManager()
    
    private let containerView = UIView().then {
        $0.backgroundColor = .clear
    }
    
    private let mainView = UIView().then {
        $0.backgroundColor = .clear
    }
    
    let topView = TJLabsTopView()
    let mapView = TJLabsMapView()
    var isParkingGuideRendered: Bool = false
    var guideView: TJLabsParkingGuideView?

    var reportedTime: Int = 0
    
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
        serviceManager.setSimulationMode(flag: true, bleFileName: "ble_coex_01_2_0811.csv", sensorFileName: "sensor_coex_01_2_0811.csv")
        
        let uniqueId = makeUniqueId(uuid: self.userId)
        serviceManager.addObserver(self)
        serviceManager.startService(user_id: uniqueId, region: self.region, sector_id: sectorId, service: "FLT", mode: "auto", completion: { [self] isStart, returnedString in
            print(returnedString)
        })
    }
    
    func stopSerivce() {
        serviceManager.removeObserver(self)
        serviceManager.stopService(completion: { [self] isSuccess, message in
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
        let currentTime: Int = getCurrentTimeInMilliseconds()
        let unique_id: String = "\(uuid)_\(currentTime)"
        
        return unique_id
    }
}
