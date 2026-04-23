
import UIKit
import TJLabsResource
import TJLabsMap

class TJLabsIndoorNaviView: UIView, TJLabsNaviViewDelegate, NavigationManagerDelegate {
    
    
    var parkingGuideStart: (() -> Void)?
    var parkingGuideFinish: (() -> Void)?
    
    func onNavigationRoute(_ view: TJLabsMap.TJLabsNaviView, routes: [(String, String, Int, Float, Float)]) {
        JupiterLogger.i(tag: "TJLabsIndoorNaviView", message: "route len= \(routes.count)")
        self.isNaviRouteLoaded = true
    }
    
    func report(flag: Int) {
        // TODO
    }
    
    func onJupiterReport(_ code: JupiterServiceCode, _ msg: String) {
        // TODO
    }
    
    func onInitSuccess(_ isSuccess: Bool, _ code: InitErrorCode?) {
        // TODO
        if isSuccess {
            serviceManager?.startService(mode: .MODE_AUTO)
        }
    }
    
    func onJupiterSuccess(_ isSuccess: Bool, _ code: JupiterErrorCode?) {
        // TODO
    }
    
    func onJupiterResult(_ result: JupiterResult) {
        let userCoord = TJLabsUserCoordinate(building: result.building_name, level: result.level_name, x: result.jupiter_pos.x, y: result.jupiter_pos.y, heading: result.jupiter_pos.heading, velocity: result.velocity)
        
        if result.level_name == "B0" && !isParkingGuideRendered {
            parkingGuideStart?()
            isParkingGuideRendered = true
        }
        
        if result.level_name != "B0" && isParkingGuideRendered {
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
    
    func isJupiterInOutStateChanged(_ state: InOutState) {
        JupiterLogger.i(tag: "TJLabsIndoorNaviView", message: "(isJupiterInOutStateChanged) : state= \(state)")
    }
    
    func isUserGuidanceOut() {
        if isSafeDriving { return }
        JupiterLogger.i(tag: "TJLabsIndoorNaviView", message: "(isUserGuidanceOut) : guidance out!!")
        isGuidanceOutReported = true
        
        DispatchQueue.main.async { [self] in
            print("(NaviVC) navigation route removed")
            UIView.animate(withDuration: 0.2, animations: {
                self.naviView.removeRouteAll()
            })
            self.showToastWithIcon(image: TJLabsAssets.image(named: "ic_warning"), message: "길안내 경로를 벗어났습니다.\n경로를 재탐색 합니다.", duration: 3)
        }
    }
    
    func isNavigationRouteChanged(_ routes: [(String, String, Int, Float, Float)]) {
        JupiterLogger.i(tag: "TJLabsIndoorNaviView", message: "route len= \(routes.count)")
        JupiterLogger.i(tag: "TJLabsIndoorNaviView", message: "routes= \(routes)")
        naviView.setNaviRoutes(routes: routes)
        isNaviRouteRendered = false
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
    private var didSetupLayout = false

    var cloud: String?
    var region: String?
    var sectorId: Int?
    var userId: String?
    
    // Service
    var serviceManager: NavigationManager?
    var jupiterResult: JupiterResult?
    
    // routing
    var naviMode: Bool = false
    var naviDestination: Point?
    
    var isParkingGuideRendered: Bool = false
    var isNaviRouteLoaded: Bool = false
    var isNaviRouteRendered: Bool = false
    var isSafeDriving: Bool = false
    
    var isGuidanceOutReported: Bool = false
    var gOutReportedTime: Int = 0

    // MARK: - Simulation
    var simulationMode: Bool = false
    var bleFileName: String = ""
    var sensorFileName: String = ""
    
    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    let naviView = TJLabsNaviView()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    deinit {
        self.stopSerivce()
        serviceManager = nil
    }
    
    private func commonInit() {
        setupLayoutIfNeeded()
        startService()
    }

    private func setupLayoutIfNeeded() {
        guard !didSetupLayout else { return }
        didSetupLayout = true
        setupLayout()
        bindActions()
    }
    
    public func initialize(region: String, sectorId: Int, userId: String) {
        self.region = region
        self.sectorId = sectorId
        self.userId = userId
        self.commonInit()
    }

    public func configureFrame(to matchView: UIView) {
        setupLayoutIfNeeded()

        if self.superview !== matchView {
            matchView.addSubview(self)
        }

        self.translatesAutoresizingMaskIntoConstraints = true
        self.frame = matchView.bounds
        self.autoresizingMask = [.flexibleWidth, .flexibleHeight]
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
        guard let cloud = self.cloud, let region = self.region, let sectorId = self.sectorId else { return }
        
        naviView.initialize(cloud: cloud, region: region, sectorId: sectorId)
        naviView.setPointOffset(offset: 200)
        naviView.setZoomAndMarkerScale(zoom: 2.0)
        containerView.addSubview(naviView)
        naviView.configureFrame(to: containerView)
    }
    
    func setNavigationDestination(dest: Point) {
        self.naviDestination = dest
        JupiterLogger.i(tag: "TJLabsIndoorNaviView", message: "dest= \(dest)")
    }
    
    func startService() {
        guard let _ = self.region, let sectorId = self.sectorId, let userId = self.userId else { return }
        serviceManager = NavigationManager(id: userId, sectorId: sectorId, debugOption: true)
        serviceManager?.delegate = self
        naviView.delegate = self
        
        if let dest = self.naviDestination {
            serviceManager?.setNaviDestination(dest: dest)
        }
//        serviceManager?.setSimulationMode(flag: <#T##Bool#>, rfdFileName: <#T##String#>, uvdFileName: <#T##String#>, eventFileName: <#T##String#>)
//        serviceManager?.setSimulationModeLegacy(flag: self.simulationMode, bleFileName: self.bleFileName, sensorFileName: self.sensorFileName)
    }
    
    func stopSerivce() {
        serviceManager?.stopService(completion: { [self] isSuccess, msg in
        })
    }
    
    public func setSimulationMode(flag: Bool, bleFileName: String, sensorFileName: String) {
        self.simulationMode = flag
        self.bleFileName = bleFileName
        self.sensorFileName = sensorFileName
    }
}
