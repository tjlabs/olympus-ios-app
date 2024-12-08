import UIKit
import OlympusSDK

class MapScaleViewController: UIViewController, Observer, MapSettingViewDelegate, MapViewForScaleDelegate {
    func mapScaleUpdated() {
        plotProducts(products: self.testProducts)
    }

    func sliderValueChanged(index: Int, value: Double) {
        mapView.updateMapAndPpScaleValues(index: index, value: value)
    }
    
    func update(result: OlympusSDK.FineLocationTrackingResult) {
        let currentIndex = result.index
        if currentIndex > preIndex {
            mapView.updateResultInMap(result: result)
        }
        preIndex = currentIndex
    }
    func report(flag: Int) { }
    
    @IBOutlet weak var topView: UIView!
    @IBOutlet weak var mainView: UIView!
    @IBOutlet weak var startButton: UIButton!
    
    let mapView = OlympusMapViewForScale()
//    let testProducts: [[Double]] = [[5, 8], [10, 12], [12, 12], [12, 10]]
    let testProducts: [[Double]] = [[6.218950437, 6.218950437], [5.990520364, 7.119098669], [6.218950437, 12.09361472]]
    
    var serviceManager = OlympusServiceManager()
    var preIndex: Int = -1
    var isStarted: Bool = false
    var sector_id: Int = 3
    var region: String = "US-East"
    var mode: String = "pdr"
    var userId: String = ""
    let key_header = "SOLUM_0F"
    
    var timer: Timer?
    let TIMER_INTERVAL: TimeInterval = 1 / 10
    
    private var foregroundObserver: Any!
    private var backgroundObserver: Any!
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(false)
        navigationController?.isNavigationBarHidden = true
        self.notificationCenterAddObserver()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        mapView.delegate = self
        mapView.setBuildingLevelIsHidden(flag: true)
        mapView.setIsPpHidden(flag: false)
        OlympusMapManager.shared.loadMapForScale(region: region, sector_id: sector_id, mapView: mapView)
        setupMapView()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        stopOlympus()
        stopTimer()
    }
    
    private func startOlympus() {
        serviceManager.addObserver(self)
//        serviceManager.setDeadReckoningMode(flag: true, buildingName: "S3", levelName: "7F", x: 16, y: 13, heading: 180)
        serviceManager.setDeadReckoningMode(flag: true, buildingName: "Solum", levelName: "0F", x: 5, y: 5, heading: 90)
        let uniqueId = makeUniqueId(uuid: self.userId)
        serviceManager.startService(user_id: uniqueId, region: region, sector_id: sector_id, service: "FLT", mode: mode, completion: { [self] isStart, returnedString in
            if (isStart) {
                self.startTimer()
            } else {
                print(returnedString)
            }
        })
        
//        OlympusMapManager.shared.loadMapForScale(region: "Korea", sector_id: sector_id, mapView: mapView)
    }
    
    private func stopOlympus() {
        self.notificationCenterRemoveObserver()
        serviceManager.stopService()
        serviceManager.removeObserver(self)
    }
    
    func startTimer() {
        if timer == nil {
            timer = Timer.scheduledTimer(timeInterval: TIMER_INTERVAL, target: self, selector: #selector(self.timerUpdate), userInfo: nil, repeats: true)
            RunLoop.current.add(self.timer!, forMode: .common)
        }
    }
    
    func stopTimer() {
        if timer != nil {
            self.timer!.invalidate()
            self.timer = nil
        }
    }
    
    @IBAction func tapStartButton(_ sender: UIButton) {
        if isStarted {
            startButton.titleLabel!.text = "Start"
            stopOlympus()
            isStarted = false
        } else {
            startButton.titleLabel!.text = "Stop"
            startOlympus()
            isStarted = true
        }
    }
    
    
    @objc func timerUpdate() { }
    
    private func makeUniqueId(uuid: String) -> String {
        let currentTime: Int = getCurrentTimeInMilliseconds()
        let unique_id: String = "\(uuid)_\(currentTime)"
        return unique_id
    }
    
    @IBAction func tapBackButton(_ sender: UIButton) {
        serviceManager.removeObserver(self)
        self.navigationController?.popViewController(animated: true)
    }
    
    func notificationCenterAddObserver() {
        self.backgroundObserver = NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { _ in
            self.serviceManager.setBackgroundMode(flag: true)
        }
        
        self.foregroundObserver = NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { _ in
            self.serviceManager.setBackgroundMode(flag: false)
        }
    }
    
    func notificationCenterRemoveObserver() {
        NotificationCenter.default.removeObserver(self.backgroundObserver)
        NotificationCenter.default.removeObserver(self.foregroundObserver)
    }
    
    @IBAction func tapSettingButton(_ sender: UIButton) {
        self.setupMapScaleView()
    }
    
    func setupMapScaleView() {
        let mapSettingView = MapSettingView()
        mapSettingView.delegate = self
        
        view.addSubview(mapSettingView)
        mapSettingView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        let loadScale = loadMapScaleFromCache(key: key_header)
        if loadScale.0, let cachedValues = loadScale.1 {
            print(getLocalTimeString() + " , (MapScaleViewController) cachedValues = \(cachedValues)")
            mapSettingView.configure(with: cachedValues)
            mapView.mapAndPpScaleValues = cachedValues
            mapView.setIsDefaultScale(flag: false)
        } else {
            let defaultScales = mapView.mapAndPpScaleValues
            print(getLocalTimeString() + " , (MapScaleViewController) defaultScales = \(defaultScales)")
            mapSettingView.configure(with: defaultScales)
        }
        
        mapSettingView.onSave = {
            print(getLocalTimeString() + " , (MapScaleViewController) Save Button Tapped")
            let currentScales = mapSettingView.scales
            self.saveMapScaleToCache(key: self.key_header, value: currentScales)
            self.mapView.setIsPpHidden(flag: true)
        }
        
        mapSettingView.onCancel = {
            self.mapView.setIsPpHidden(flag: true)
        }
        
        mapSettingView.onReset = {
            self.mapView.setIsPpHidden(flag: true)
            self.deleteMapScaleFromCache(key: self.key_header)
        }
    }
    
    private func saveMapScaleToCache(key: String, value: [Double]) {
        print(getLocalTimeString() + " , (MapScaleViewController) Save \(key) scale : \(value)")
        do {
            let key: String = "MapScale_\(key)"
            UserDefaults.standard.set(value, forKey: key)
        }
    }
    
    private func loadMapScaleFromCache(key: String) -> (Bool, [Double]?) {
        let keyMapScale: String = "MapScale_\(key)"
        if let loadedMapScale: [Double] = UserDefaults.standard.object(forKey: keyMapScale) as? [Double] {
            print(getLocalTimeString() + " , (MapScaleViewController) Load \(key) scale : \(loadedMapScale)")
            return (true, loadedMapScale)
        } else {
            return (false, nil)
        }
    }
    
    private func deleteMapScaleFromCache(key: String) {
        let cacheKey = "MapScale_\(key)"
        UserDefaults.standard.removeObject(forKey: cacheKey)
        print(getLocalTimeString() + " , (MapScaleViewController) Deleted \(key) scale from cache")
    }
    
    private func plotProducts(products: [[Double]]) {
        mapView.setUnitTags(num: products.count)
        let mapAndPpScaleValues = mapView.mapAndPpScaleValues
        print("(MapScaleViewController) : plotProduct // mapAndPpScaleValues = \(mapAndPpScaleValues)")
        print("(MapScaleViewController) : plotProduct // products = \(products)")
        
        if mapAndPpScaleValues[0] != 0 && mapAndPpScaleValues[1] != 0 && mapAndPpScaleValues[2] != 0 && mapAndPpScaleValues[3] != 0 {
            var productViews = [UIView]()
            for item in products {
                let productView = makeProductUIView(product: item, scales: mapAndPpScaleValues)
                productViews.append(productView)
//                mapView.plotUnitUsingCoord(unitView: productView)
            }
            mapView.plotUnitUsingCoord(unitViews: productViews)
        }
        
//        for item in products {
//            let productView = makeProductUIView(product: item, scales: mapAndPpScaleValues)
//            mapView.plotUnitUsingCoord(unitView: productView)
//        }
    }
    
    private func makeProductUIView(product: [Double], scales: [Double]) -> UIView {
        let x = product[0]
        let y = -product[1]
        
        let transformedX = (x - scales[2])*scales[0]
        let transformedY = (y - scales[3])*scales[1]
        
        let rotatedX = transformedX
        let rotatedY = transformedY
        
        let markerSize: Double = 20
        let productView = UIView(frame: CGRect(x: rotatedX - markerSize/2, y: rotatedY - markerSize/2, width: markerSize, height: markerSize))
        productView.backgroundColor = .systemRed
        productView.layer.cornerRadius = markerSize/4
        
        let categoryLabel = UILabel()
        categoryLabel.text = "1"
        categoryLabel.textAlignment = .center
        categoryLabel.font = UIFont.systemFont(ofSize: 12, weight: .bold)
        categoryLabel.textColor = .white
        categoryLabel.frame = productView.bounds
        categoryLabel.adjustsFontSizeToFitWidth = true
        categoryLabel.minimumScaleFactor = 0.5
        productView.addSubview(categoryLabel)
        
        return productView
    }
}

extension MapScaleViewController {
    func setupMapView() {
        mapView.configureFrame(to: mainView)
        mainView.addSubview(mapView)
    }
}
