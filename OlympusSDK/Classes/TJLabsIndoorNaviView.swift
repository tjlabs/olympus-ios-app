
import UIKit
import TJLabsResource
import TJLabsMap

class TJLabsIndoorNaviView: UIView, JupiterManagerDelegate, TJLabsNaviViewDelegate {
    var parkingGuideStart: (() -> Void)?
    var parkingGuideFinish: (() -> Void)?
    
    func onNavigationRoute(_ view: TJLabsMap.TJLabsNaviView, routes: [(String, String, Int, Float, Float)]) {
        JupiterLogger.i(tag: "TJLabsIndoorNaviView", message: "route len= \(routes.count)")
        self.isNaviRouteLoaded = true
    }
    
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
            parkingGuideStart?()
            isParkingGuideRendered = true
        }
        
        if result.level_name == "B2" && isParkingGuideRendered {
            parkingGuideFinish?()
        }
        
        if result.level_name != "B0" && isNaviRouteLoaded && !isNaviRouteRendered {
            DispatchQueue.main.async { [self] in
                JupiterLogger.i(tag: "TJLabsIndoorNaviView", message: "navigation route rendered")
                UIView.animate(withDuration: 0.2, animations: {
                    self.naviView.plotRouteAll()
                })
            }
            isNaviRouteRendered = true
        }
        
        naviView.updateResultInMap(result: userCoord)
    }
    
    func isUserGuidanceOut() {
        if isSafeDriving { return }
        JupiterLogger.i(tag: "TJLabsIndoorNaviView", message: "isUserGuidanceOut : guidance out!!")
        isGuidanceOutReported = true
        
        DispatchQueue.main.async { [self] in
            print("(NaviVC) navigation route removed")
            UIView.animate(withDuration: 0.2, animations: {
                self.naviView.removeRouteAll()
            })
            self.showToastWithIcon(image: TJLabsAssets.image(named: "ic_warning"), message: "길안내 경로를 벗어났습니다.\n경로를 재탐색 합니다.", duration: 6)
        }
    }
    
    func isNavigationRouteChanged(_ routes: [(String, String, Int, Float, Float)]) {
        JupiterLogger.i(tag: "TJLabsIndoorNaviView", message: "route len= \(routes.count)")
        JupiterLogger.i(tag: "TJLabsIndoorNaviView", message: "routes= \(routes)")
        naviView.setNaviRoutes(routes: routes)
    }
    
    func isNavigationRouteFailed() {
        // TODO
    }
    
    func isWaypointChanged(_ waypoints: [[Double]]) {
        if isSafeDriving { return }
        JupiterLogger.i(tag: "TJLabsIndoorNaviView", message: "waypoints count= \(waypoints.count)")
        JupiterLogger.i(tag: "TJLabsIndoorNaviView", message: "waypoints= \(waypoints)")
        naviView.setNaviWaypoints(waypoints: waypoints)
    }
    

    var region: String?
    var sectorId: Int?
    var userId: String?
    
    // Service
    var serviceManager: JupiterManager?
    var jupiterResult: JupiterResult?
    
    // routing
    var naviMode: Bool = false
    var naviDestination: RoutingPoint?
    
    var isParkingGuideRendered: Bool = false
    var isNaviRouteLoaded: Bool = false
    var isNaviRouteRendered: Bool = false
    var isSafeDriving: Bool = false
    
    var isGuidanceOutReported: Bool = false
    var gOutReportedTime: Int = 0

    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = .white
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    let naviView = TJLabsNaviView()
    
    init(region: String, sectorId: Int, userId: String) {
        super.init(frame: .zero)
        self.region = region
        self.sectorId = sectorId
        self.userId = userId
        commonInit()
    }
    
    deinit {
        self.stopSerivce()
        serviceManager = nil
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func commonInit() {
        setupLayout()
        bindActions()
        startService()
    }
    
    private func setupLayout() {
        addSubview(containerView)
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: topAnchor),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor),
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
        self.setupNaviView()
    }
    
    private func bindActions() {

    }
    
    func setupNaviView() {
        guard let region = self.region, let sectorId = self.sectorId else { return }
        
        naviView.initialize(region: region, sectorId: sectorId)
        naviView.configureFrame(to: containerView)
        naviView.setPointOffset(offset: 200)
        naviView.setZoomAndMarkerScale(zoom: 2.0)
        containerView.addSubview(naviView)
    }
    
    func setNavigationDestination(dest: RoutingPoint) {
        self.naviMode = true
        self.naviDestination = dest
        JupiterLogger.i(tag: "TJLabsIndoorNaviView", message: "setNavigationDestination : naviDestination= \(dest)")
        
        let scenario = 4
        JupiterLogger.i(tag: "TJLabsIndoorNaviView", message: "navigationMode : scenario= \(scenario)")
        serviceManager?.navigationMode(flag: naviMode, scenario: scenario)
//        serviceManager?.setNaviDestination(dest: dest)
    }
    
    func startService() {
        guard let _ = self.region, let sectorId = self.sectorId, let userId = self.userId else { return }

        serviceManager = JupiterManager(id: userId)
        serviceManager?.delegate = self
        naviView.delegate = self
       
        serviceManager?.setSimulationMode(flag: true, bleFileName: "ble_coex_01_0317.csv", sensorFileName: "sensor_coex_01_0317.csv")
        serviceManager?.startJupiter(sectorId: sectorId, mode: .MODE_AUTO, debugOption: true)
    }
    
    func stopSerivce() {
        serviceManager?.stopJupiter(completion: { [self] isSuccess, msg in
        })
    }
}
