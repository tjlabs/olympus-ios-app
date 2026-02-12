import UIKit
import SnapKit
import Charts
import OlympusSDK
import TJLabsCommon
import TJLabsResource

class CardViewController: UIViewController, JupiterManagerDelegate {
    func onJupiterSuccess(_ isSuccess: Bool) {
        print("(CardVC) onJupiterSuccess : \(isSuccess)")
    }
    
    func onJupiterError(_ code: Int, _ msg: String) {
        print("(CardVC) onJupiterError : \(code) , \(msg)")
    }
    
    func onJupiterResult(_ result: OlympusSDK.JupiterResult) {
//        print("(CardVC) onJupiterResult : \(result)")
        let building = result.building_name
        let level = result.level_name
        let x = result.x
        let y = result.y
        
        if (result.ble_only_position) {
            self.isBleOnlyMode = true
        } else {
            self.isBleOnlyMode = false
        }
        
        if (building.count < 2 && level.count < 2) {
            print("(VC) Error : \(result)")
        }
        updateCoord(flag: true)
    }
    
    func onJupiterReport(_ flag: Int) {
        print("(CardVC) onJupiterReport")
    }
    
    private var saveButton: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.black
        view.alpha = 0.8
        view.isUserInteractionEnabled = false
        view.cornerRadius = 15
        return view
    }()
    
    private let saveButtonTitleLabel: UILabel = {
        let label = UILabel()
        label.backgroundColor = .clear
        label.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        label.textColor = .white
        label.textAlignment = .center
        label.text = "Save"
        return label
    }()
    
    @IBOutlet weak var imgViewLevel: UIImageView!
    @IBOutlet weak var scatterChart: ScatterChartView!
    
    @IBOutlet weak var indexLabel: UILabel!
    @IBOutlet weak var peakIdLabel: UILabel!
    @IBOutlet weak var lossLabel: UILabel!
    @IBOutlet weak var ratioLabel: UILabel!
    
    @IBOutlet weak var inOutStatusLabel: UILabel!
    
    var headingImage = UIImage(named: "heading")

    var isSaved: Bool = false
    
    var phoenixIndex: Int = 0
    var phoenixData = PhoenixRecord(user_id: "", company: "", car_number: "", mobile_time: 0, index: 0, latitude: 0, longitude: 0, remaining_time: 0, velocity: 0, sector_id: 0, building_name: "", level_name: "", x: 0, y: 0, absolute_heading: 0, is_indoor: false)
    var phoenixRecords = [PhoenixRecord]()
    
    var progressingView: ProgressingView?
    
    var serviceManager: JupiterManager?
    override func viewDidDisappear(_ animated: Bool) {
//        serviceManager.stopService(completion: { _,_ in
//        })
//        serviceManager.removeObserver(self)
    }
    
    var statusTime: Int = 0
    
    var region: String = ""
    var userId: String = ""
    
//    var sector_id: Int = 3
//    var mode: String = "pdr"
    
//    var sector_id: Int = 14 // DS
//    var mode: String = "pdr"
    
    var sector_id: Int = 6
    var mode: String = "auto"
    
//    var sector_id: Int = 20  // Convensia
//    var mode: String = "auto"
    
//    var sector_id: Int = 2
//    var mode: String = "pdr"
    
    var currentBuilding: String = ""
    var currentLevel: String = ""
    var pastBuilding: String = "Unknwon"
    var pastLevel: String = "Unknwon"
    
    var isBleOnlyMode: Bool = false
    var PathPixel = [String: [[Double]]]()
    
    let OPERATING_SYSTEM: String = "iOS"
    
    var isCollect: Bool = false
    
    var timer: DispatchSourceTimer?
    let TIMER_INTERVAL: TimeInterval = 1/10
    var phoenixTime: TimeInterval = 0
    var preServiceTime: Int = 0
    
    
    var serviceState: Bool = false
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupLayout()
        bindActions()
        
        headingImage = headingImage?.resize(newWidth: 20)
        
//        serviceManager.setSimulationMode(flag: true, bleFileName: "ble_coex_io_0811.csv", sensorFileName: "sensor_coex_io_0811.csv")
//        serviceManager.setSimulationMode(flag: true, bleFileName: "ble_coex_0604_05.csv", sensorFileName: "sensor_coex_0604_05.csv")
//        serviceManager.setSimulationMode(flag: true, bleFileName: "ble_coex_03_0930.csv", sensorFileName: "sensor_coex_03_0930.csv")
//        serviceManager.setSimulationMode(flag: true, bleFileName: "ble_coex_05_04_1007.csv", sensorFileName: "sensor_coex_05_04_1007.csv")
//        serviceManager.setSimulationMode(flag: true, bleFileName: "ble_coex_dr_03_1030.csv", sensorFileName: "sensor_coex_dr_03_1030.csv")
    
//        serviceManager.setDeadReckoningMode(flag: true, buildingName: "S3", levelName: "7F", x: 6, y: 16, heading: 270)
        
//        OlympusNavigationManager.shared.setDummyRoutes(option: false)
//        serviceManager.setSimulationMode(flag: true, bleFileName: "ble_coex_01_2_0811.csv", sensorFileName: "sensor_coex_01_2_0811.csv")
        
//        serviceManager.setSimulationMode(flag: true, bleFileName: "ble_songdo_250818_test2.csv", sensorFileName: "sensor_songdo_250818_test2.csv")
//        serviceManager.setSimulationMode(flag: true, bleFileName: "ble_songdo_250818_test8.csv", sensorFileName: "sensor_songdo_250818_test8.csv")
//        serviceManager.setSimulationMode(flag: true, bleFileName: "ble_songdo_250822_km01.csv", sensorFileName: "sensor_songdo_250822_km01.csv")
//        serviceManager.setSimulationMode(flag: true, bleFileName: "ble_250829_test02_ent1.csv", sensorFileName: "sensor_250829_test02_ent1.csv")
//        serviceManager.setSimulationMode(flag: true, bleFileName: "ble_250911_songdo_test3.csv", sensorFileName: "sensor_250911_songdo_test3.csv")
        
        // Analysis
//        serviceManager.setSimulationMode(flag: true, bleFileName: "ble_250829_test02_ent1.csv", sensorFileName: "sensor_250829_test02_ent1.csv")
//        serviceManager.setSimulationMode(flag: true, bleFileName: "ble_250829_test08_ent2.csv", sensorFileName: "sensor_250829_test08_ent2.csv")
//        serviceManager.setSimulationMode(flag: true, bleFileName: "ble_250829_test06_ent3.csv", sensorFileName: "sensor_250829_test06_ent3.csv")
        
        // Ent3
//        serviceManager.setSimulationMode(flag: true, bleFileName: "ble_songdo_250818_test6.csv", sensorFileName: "sensor_songdo_250818_test6.csv")
//        serviceManager.setSimulationMode(flag: true, bleFileName: "ble_songdo_250818_test10.csv", sensorFileName: "sensor_songdo_250818_test10.csv")
//        serviceManager.setSimulationMode(flag: true, bleFileName: "ble_songdo_250822_stop.csv", sensorFileName: "sensor_songdo_250822_stop.csv")
        
//        serviceManager.setSimulationMode(flag: true, bleFileName: "ble_251013_songdo_test01_ent1.csv", sensorFileName: "sensor_251013_songdo_test01_ent1.csv")
        
        // collect
//        isCollect = true
//        serviceManager.initCollect(region: self.region)
//        serviceManager.startCollect()
//        self.startTimer()
        
//        self.setPhoenixData()
        let uniqueId = makeUniqueId(uuid: self.userId)
        
        serviceManager = JupiterManager(id: uniqueId)
        serviceManager?.delegate = self
        serviceManager?.navigationMode(flag: true)
        serviceManager?.setSimulationMode(flag: true, bleFileName: "ble_coex_03_01_0119.csv", sensorFileName: "sensor_coex_03_01_0119.csv")
//        serviceManager?.setSimulationMode(flag: true, bleFileName: "ble_coex_test1_0129.csv", sensorFileName: "sensor_coex_test1_0129.csv")
//        serviceManager?.setSimulationMode(flag: true, bleFileName: "ble_coex_test1_0203.csv", sensorFileName: "sensor_coex_test1_0203.csv")
        
//        serviceManager?.setSimulationMode(flag: true, bleFileName: "ble_coex_01_02_1007.csv", sensorFileName: "sensor_coex_01_02_1007.csv")
//        serviceManager?.setSimulationMode(flag: true, bleFileName: "ble_coex_05_04_1007.csv", sensorFileName: "sensor_coex_05_04_1007.csv")
        serviceManager?.startJupiter(sectorId: sector_id, mode: .MODE_AUTO, debugOption: true)
        
        // service
//        serviceManager.addObserver(self)
//        serviceManager.setDebugOption(flag: true)
//        serviceManager.startService(user_id: uniqueId, region: self.region, sector_id: sector_id, service: "FLT", mode: mode, completion: { [self] isStart, returnedString in
//        serviceManager.startService(user_id: uniqueId, region: "Korea", sector_id: 16, service: "FLT", mode: "pdr", completion: { [self] isStart, returnedString in
//            if (isStart) {
//                serviceState = true
//                self.startTimer()
//            } else {
//                print(returnedString)
//            }
//        })
    }
    
    override func viewWillDisappear(_ animated: Bool) {
    }

    private func setupLayout() {
        // // MARK: - Start
        view.addSubview(saveButton)
        saveButton.snp.makeConstraints { make in
            make.bottom.equalToSuperview().inset(40)
            make.leading.trailing.equalToSuperview().inset(40)
            make.height.equalTo(40)
        }
        
        saveButton.addSubview(saveButtonTitleLabel)
        saveButtonTitleLabel.snp.makeConstraints { make in
            make.leading.trailing.top.bottom.equalToSuperview().inset(5)
        }
    }
    
    private func bindActions() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleSaveButton))
        saveButton.isUserInteractionEnabled = true
        saveButton.addGestureRecognizer(tapGesture)
    }
    
    @objc func handleSaveButton() {
        DispatchQueue.main.async { [self] in
            saveButton.isUserInteractionEnabled = false
            saveButtonTitleLabel.text = "ing..."
//            saveButtonTitleLabel.textColor = .red1
            
            self.progressingView = ProgressingView()
            UIView.animate(withDuration: 0.2, animations: {
                view.addSubview(progressingView!)
                progressingView!.snp.makeConstraints { make in
                    make.top.bottom.leading.trailing.equalToSuperview()
                }
            })
        }
        
//        serviceManager?.saveFilesForSimulation(completion: { [self] isSuccess in
        serviceManager?.saveDebugFile(completion: { [self] isSuccess in
            DispatchQueue.main.async { [self] in
                saveButton.isHidden = true
                saveButton.isUserInteractionEnabled = true
                saveButtonTitleLabel.text = "Save"
            }
            DispatchQueue.main.async {
                self.progressingView?.removeFromSuperview()
            }
        })
        self.stopTimer()
    }
    
    private func loadPp(fileName: String) -> [[Double]] {
        guard let path = Bundle.main.path(forResource: fileName, ofType: "csv") else {
            return [[Double]]()
        }
        let ppXY:[[Double]] = parsePp(url: URL(fileURLWithPath: path))
//        print(getLocalTimeString() + " , (VC) Load PP : path = \(path)")
        return ppXY
    }
    
    private func parsePp(url:URL) -> [[Double]] {
        var rpXY = [[Double]]()
        
        var rpX = [Double]()
        var rpY = [Double]()
        
        do {
            let data = try Data(contentsOf: url)
            let dataEncoded = String(data: data, encoding: .utf8)
            if let dataArr = dataEncoded?.components(separatedBy: "\n").map({$0.components(separatedBy: ",")}) {
                for item in dataArr {
                    let rp: [String] = item
                    if (rp.count >= 4) {
                        if (mode == "pdr") {
                            guard let x: Double = Double(rp[2]) else { return [[Double]]() }
                            guard let y: Double = Double(rp[3].components(separatedBy: "\r")[0]) else { return [[Double]]() }
                            
                            rpX.append(x)
                            rpY.append(y)
                        } else {
                            let pathType = Int(rp[0])
                            if (pathType == 1) {
                                guard let x: Double = Double(rp[2]) else { return [[Double]]() }
                                guard let y: Double = Double(rp[3].components(separatedBy: "\r")[0]) else { return [[Double]]() }
                                
                                rpX.append(x)
                                rpY.append(y)
                            }
                        }
                    }
                }
            }
            rpXY = [rpX, rpY]
        } catch {
//            print(getLocalTimeString() + " , (VC) Error reading .csv file")
        }
        return rpXY
    }
    
    private func loadLevel(building: String, level: String, flag: Bool, completion: @escaping (UIImage?, Error?) -> Void) {
        let urlString: String = "\(IMAGE_URL)/map/\(self.sector_id)/\(building)/\(level).png"
        if let urlLevel = URL(string: urlString) {
            let cacheKey = NSString(string: urlString)
            
            if let cachedImage = ImageCacheManager.shared.object(forKey: cacheKey) {
                completion(cachedImage, nil)
            } else {
                let task = URLSession.shared.dataTask(with: urlLevel) { (data, response, error) in
                    if let error = error {
                        completion(nil, error)
                    }
                    
                    if let data = data, let httpResponse = response as? HTTPURLResponse,
                       httpResponse.statusCode == 200 {
                        DispatchQueue.main.async {
                            ImageCacheManager.shared.setObject(UIImage(data: data)!, forKey: cacheKey)
                            completion(UIImage(data: data), nil)
                        }
                    } else {
                        completion(nil, error)
                    }
                }
                task.resume()
            }
        } else {
            completion(nil, nil)
        }
    }
    
    private func displayLevelImage(building: String, level: String, flag: Bool) {
        self.loadLevel(building: building, level: level, flag: flag, completion: { [self] data, error in
            DispatchQueue.main.async {
                if (data != nil) {
                    // 빌딩 -> 층 이미지가 있는 경우
//                    self.imgViewLevel.isHidden = false
//                    self.scatterChart.isHidden = false
//                    self.imgViewLevel.image = data
                } else {
                    // 빌딩 -> 층 이미지가 없는 경우
//                    self.imgViewLevel.isHidden = true
//                    self.scatterChart.isHidden = true
                }
            }
        })
    }
    
    private func drawDebug(XYH: [Double], RP_X: [Double], RP_Y: [Double],
                           calcXYH: [Double], tuXYH: [Double],
                           landmark: LandmarkData?,
                           best_landmark: PeakData?,
                           recon_raw_traj: [[Double]]?,
                           recon_corr_traj: [FineLocationTrackingOutput]?,
                           recovery_result: RecoveryResult?,
                           recovery_result3Peaks: RecoveryResult3Peaks?,
                           navi_route: [[Float]],
                           naviXYH: [Double],
                           limits: [Double], isBleOnlyMode: Bool, isPmSuccess: Bool, isIndoor: Bool) {
        let xAxisValue: [Double] = RP_X
        let yAxisValue: [Double] = RP_Y
        
        var valueColor = UIColor.systemRed
        
        if (!isIndoor) {
            valueColor = UIColor.systemGray
        } else if (isBleOnlyMode) {
            valueColor = UIColor.systemBlue
        } else {
            valueColor = UIColor.systemRed
        }

        let values0 = (0..<xAxisValue.count).map { (i) -> ChartDataEntry in
            return ChartDataEntry(x: xAxisValue[i], y: yAxisValue[i])
        }
        
        let set0 = ScatterChartDataSet(entries: values0, label: "RP")
        set0.drawValuesEnabled = false
        set0.setScatterShape(.square)
        set0.setColor(UIColor.yellow)
        set0.scatterShapeSize = 4
        
        let values1 = (0..<1).map { (i) -> ChartDataEntry in
            return ChartDataEntry(x: XYH[0], y: XYH[1])
        }
        let set1 = ScatterChartDataSet(entries: values1, label: "USER")
        set1.drawValuesEnabled = false
        set1.setScatterShape(.circle)
        set1.setColor(valueColor)
        set1.scatterShapeSize = 21
        
        let valuesCalc = (0..<1).map { (i) -> ChartDataEntry in
            return ChartDataEntry(x: tuXYH[0], y: tuXYH[1])
        }
        
        let setCalc = ScatterChartDataSet(entries: valuesCalc, label: "CALC")
        setCalc.drawValuesEnabled = false
        setCalc.setScatterShape(.circle)
        setCalc.setColor(.systemPink)
        setCalc.scatterShapeSize = 18
        
        let valuesTu = (0..<1).map { (i) -> ChartDataEntry in
            return ChartDataEntry(x: tuXYH[0], y: tuXYH[1])
        }
        
        let setTu = ScatterChartDataSet(entries: valuesTu, label: "TU")
        setTu.drawValuesEnabled = false
        setTu.setScatterShape(.circle)
        setTu.setColor(.systemGreen)
        setTu.scatterShapeSize = 15
        
        let valuesNaviXyh = (0..<1).map { (i) -> ChartDataEntry in
            return ChartDataEntry(x: naviXYH[0], y: naviXYH[1])
        }
        
        let setNaviXyh = ScatterChartDataSet(entries: valuesNaviXyh, label: "NaviXyh")
        setNaviXyh.drawValuesEnabled = false
        setNaviXyh.setScatterShape(.circle)
        setNaviXyh.setColor(.systemBlue)
        setNaviXyh.scatterShapeSize = 12
        
        let chartData = ScatterChartData(dataSet: set0)
        chartData.append(set1)
        chartData.append(setCalc)
        chartData.append(setTu)
        chartData.append(setNaviXyh)
        chartData.setDrawValues(false)
        
        if !navi_route.isEmpty {
            var xAxisValue = [Double]()
            var yAxisValue = [Double]()
            
            for route in navi_route {
                xAxisValue.append(Double(route[0]))
                yAxisValue.append(Double(route[1]))
            }
            
            let valuesNaviRoute = (0..<xAxisValue.count).map { (i) -> ChartDataEntry in
                return ChartDataEntry(x: xAxisValue[i], y: yAxisValue[i])
            }
            
            let setNaviRoute = ScatterChartDataSet(entries: valuesNaviRoute, label: "NaviRoute")
            setNaviRoute.drawValuesEnabled = false
            setNaviRoute.setScatterShape(.circle)
            setNaviRoute.setColor(UIColor.orange)
            setNaviRoute.scatterShapeSize = 2.5
            chartData.append(setNaviRoute)
        }
        
        if let landmark = landmark {
            let xAxisValue: [Double] = landmark.peaks.map({Double($0.x)})
            let yAxisValue: [Double] = landmark.peaks.map({Double($0.y)})
            
            let valuesPeaks = (0..<xAxisValue.count).map { (i) -> ChartDataEntry in
                return ChartDataEntry(x: xAxisValue[i], y: yAxisValue[i])
            }
            
            let setLandmarkPeak = ScatterChartDataSet(entries: valuesPeaks, label: "Landmark")
            setLandmarkPeak.drawValuesEnabled = false
            setLandmarkPeak.setScatterShape(.triangle)
            setLandmarkPeak.setColor(UIColor.black)
            setLandmarkPeak.scatterShapeSize = 8
            chartData.append(setLandmarkPeak)
        }
        
        if let best_landmark = best_landmark {
            let xAxisValue: [Double] = [Double(best_landmark.x)]
            let yAxisValue: [Double] = [Double(best_landmark.y)]
            
            let valuesPeaks = (0..<xAxisValue.count).map { (i) -> ChartDataEntry in
                return ChartDataEntry(x: xAxisValue[i], y: yAxisValue[i])
            }
            
            let setLandmarkPeak = ScatterChartDataSet(entries: valuesPeaks, label: "Best")
            setLandmarkPeak.drawValuesEnabled = false
            setLandmarkPeak.setScatterShape(.circle)
            setLandmarkPeak.setColor(.darkgrey4)
            setLandmarkPeak.scatterShapeSize = 10
            chartData.append(setLandmarkPeak)
        }
        
        if let recon_raw_traj = recon_raw_traj {
            var xAxisValue = [Double]()
            var yAxisValue = [Double]()
            for traj in recon_raw_traj {
                xAxisValue.append(traj[0])
                yAxisValue.append(traj[1])
            }
            
            let valuesRawTraj = (0..<xAxisValue.count).map { (i) -> ChartDataEntry in
                return ChartDataEntry(x: xAxisValue[i], y: yAxisValue[i])
            }
            
            let setRawTraj = ScatterChartDataSet(entries: valuesRawTraj, label: "RawTraj")
            setRawTraj.drawValuesEnabled = false
            setRawTraj.setScatterShape(.circle)
            setRawTraj.setColor(.red1)
            setRawTraj.scatterShapeSize = 5
            chartData.append(setRawTraj)
        }
        
        if let recon_corr_traj = recon_corr_traj {
            var xAxisValue = [Double]()
            var yAxisValue = [Double]()
            for traj in recon_corr_traj {
                xAxisValue.append(Double(traj.x))
                yAxisValue.append(Double(traj.y))
            }
            
            let valuesCorrTraj = (0..<xAxisValue.count).map { (i) -> ChartDataEntry in
                return ChartDataEntry(x: xAxisValue[i], y: yAxisValue[i])
            }
            
            let setCorrTraj = ScatterChartDataSet(entries: valuesCorrTraj, label: "CorrTraj")
            setCorrTraj.drawValuesEnabled = false
            setCorrTraj.setScatterShape(.circle)
            setCorrTraj.setColor(.blue2)
            setCorrTraj.scatterShapeSize = 3
            chartData.append(setCorrTraj)
        }
        
        if let recovery_result = recovery_result {
            let recovery_traj = recovery_result.traj
            lossLabel.text = String(recovery_result.loss)
            var xAxisValue = [Double]()
            var yAxisValue = [Double]()
            for traj in recovery_traj {
                xAxisValue.append(traj[0])
                yAxisValue.append(traj[1])
            }
            
            let valuesRecoveryTraj = (0..<xAxisValue.count).map { (i) -> ChartDataEntry in
                return ChartDataEntry(x: xAxisValue[i], y: yAxisValue[i])
            }
            
            let setRecoveryTraj = ScatterChartDataSet(entries: valuesRecoveryTraj, label: "RecoveryTraj")
            setRecoveryTraj.drawValuesEnabled = false
            setRecoveryTraj.setScatterShape(.circle)
            setRecoveryTraj.setColor(.systemBrown)
            setRecoveryTraj.scatterShapeSize = 5
            chartData.append(setRecoveryTraj)
            
            let bestOlder = recovery_result.bestOlder
            let oldX: [Double] = [Double(bestOlder[0])]
            let oldY: [Double] = [Double(bestOlder[1])]
            let valuesOld = (0..<oldX.count).map { (i) -> ChartDataEntry in
                return ChartDataEntry(x: oldX[i], y: oldY[i])
            }
            
            let setOld = ScatterChartDataSet(entries: valuesOld, label: "BestOld")
            setOld.drawValuesEnabled = false
            setOld.setScatterShape(.square)
            setOld.setColor(.systemRed)
            setOld.scatterShapeSize = 8
            chartData.append(setOld)
            
            let bestRecent = [recovery_result.bestRecentCand.x, recovery_result.bestRecentCand.y]
            let recentX: [Double] = [Double(bestRecent[0])]
            let recentY: [Double] = [Double(bestRecent[1])]
            let valuesRecent = (0..<oldX.count).map { (i) -> ChartDataEntry in
                return ChartDataEntry(x: recentX[i], y: recentY[i])
            }
            
            let setRecent = ScatterChartDataSet(entries: valuesRecent, label: "BestRecent")
            setRecent.drawValuesEnabled = false
            setRecent.setScatterShape(.square)
            setRecent.setColor(.systemBlue)
            setRecent.scatterShapeSize = 6
            chartData.append(setRecent)
        }
        
        if let recovery_result3Peaks = recovery_result3Peaks {
            lossLabel.text = String(recovery_result3Peaks.loss) + " // Recovery"
            let recovery_traj = recovery_result3Peaks.traj
            var xAxisValue = [Double]()
            var yAxisValue = [Double]()
            for traj in recovery_traj {
                xAxisValue.append(traj[0])
                yAxisValue.append(traj[1])
            }
            
            let valuesRecoveryTraj = (0..<xAxisValue.count).map { (i) -> ChartDataEntry in
                return ChartDataEntry(x: xAxisValue[i], y: yAxisValue[i])
            }
            
            let setRecoveryTraj = ScatterChartDataSet(entries: valuesRecoveryTraj, label: "RecoveryTraj")
            setRecoveryTraj.drawValuesEnabled = false
            setRecoveryTraj.setScatterShape(.circle)
            setRecoveryTraj.setColor(.systemGreen)
            setRecoveryTraj.scatterShapeSize = 5
            chartData.append(setRecoveryTraj)
            
            let bestFirst = recovery_result3Peaks.bestFirst
            let firstX: [Double] = [Double(bestFirst[0])]
            let firstY: [Double] = [Double(bestFirst[1])]
            let valuesFirst = (0..<firstX.count).map { (i) -> ChartDataEntry in
                return ChartDataEntry(x: firstX[i], y: firstY[i])
            }
            
            let setFirst = ScatterChartDataSet(entries: valuesFirst, label: "BestFirst")
            setFirst.drawValuesEnabled = false
            setFirst.setScatterShape(.square)
            setFirst.setColor(.systemBlue)
            setFirst.scatterShapeSize = 8
            chartData.append(setFirst)
            
            let bestSecond = recovery_result3Peaks.bestSecond
            let secondX: [Double] = [Double(bestSecond[0])]
            let secondY: [Double] = [Double(bestSecond[1])]
            let valuesSecond = (0..<secondX.count).map { (i) -> ChartDataEntry in
                return ChartDataEntry(x: secondX[i], y: secondY[i])
            }
            
            let setSecond = ScatterChartDataSet(entries: valuesSecond, label: "BestSecond")
            setSecond.drawValuesEnabled = false
            setSecond.setScatterShape(.square)
            setSecond.setColor(.systemOrange)
            setSecond.scatterShapeSize = 8
            chartData.append(setSecond)
            
            let bestThird = recovery_result3Peaks.bestThird
            let thirdX: [Double] = [Double(bestThird[0])]
            let thirdY: [Double] = [Double(bestThird[1])]
            let valuesThird = (0..<thirdX.count).map { (i) -> ChartDataEntry in
                return ChartDataEntry(x: thirdX[i], y: thirdY[i])
            }
            
            let setThird = ScatterChartDataSet(entries: valuesThird, label: "BestThird")
            setThird.drawValuesEnabled = false
            setThird.setScatterShape(.square)
            setThird.setColor(.systemRed)
            setThird.scatterShapeSize = 8
            chartData.append(setThird)
        }
        
        // Heading
        let point = scatterChart.getPosition(entry: ChartDataEntry(x: XYH[0], y: XYH[1]), axis: .left)
        let imageView = UIImageView(image: headingImage!.rotate(degrees: -XYH[2]+90))
        let xyhSize: CGFloat = 44
        imageView.frame = CGRect(x: point.x - xyhSize/2, y: point.y - xyhSize/2, width: xyhSize, height: xyhSize)
        imageView.contentMode = .center
        imageView.tag = 100
        if let viewWithTag = scatterChart.viewWithTag(100) {
            viewWithTag.removeFromSuperview()
        }
        scatterChart.addSubview(imageView)
        
        let pointCalc = scatterChart.getPosition(entry: ChartDataEntry(x: calcXYH[0], y: calcXYH[1]), axis: .left)
        let imageViewCalc = UIImageView(image: headingImage!.rotate(degrees: -calcXYH[2]+90))
        let calcSize: CGFloat = 40
        imageViewCalc.frame = CGRect(x: pointCalc.x - calcSize/2, y: pointCalc.y - calcSize/2, width: calcSize, height: calcSize)
        imageViewCalc.contentMode = .center
        imageViewCalc.tag = 200
        if let viewWithTagCalc = scatterChart.viewWithTag(200) {
            viewWithTagCalc.removeFromSuperview()
        }
        scatterChart.addSubview(imageViewCalc)
        
        let pointTu = scatterChart.getPosition(entry: ChartDataEntry(x: tuXYH[0], y: tuXYH[1]), axis: .left)
        let imageViewTu = UIImageView(image: headingImage!.rotate(degrees: -tuXYH[2]+90))
        let tuSize: CGFloat = 36
        imageViewTu.frame = CGRect(x: pointTu.x - tuSize/2, y: pointTu.y - tuSize/2, width: tuSize, height: tuSize)
        imageViewTu.contentMode = .center
        imageViewTu.tag = 300
        if let viewWithTagTu = scatterChart.viewWithTag(300) {
            viewWithTagTu.removeFromSuperview()
        }
        scatterChart.addSubview(imageViewTu)
        
        let pointNavi = scatterChart.getPosition(entry: ChartDataEntry(x: naviXYH[0], y: naviXYH[1]), axis: .left)
        let imageViewNavi = UIImageView(image: headingImage!.rotate(degrees: -naviXYH[2]+90))
        let naviSize: CGFloat = 32
        imageViewNavi.frame = CGRect(x: pointNavi.x - naviSize/2, y: pointNavi.y - naviSize/2, width: naviSize, height: naviSize)
        imageViewNavi.contentMode = .center
        imageViewNavi.tag = 400
        if let viewWithTagNavi = scatterChart.viewWithTag(400) {
            viewWithTagNavi.removeFromSuperview()
        }
        scatterChart.addSubview(imageViewNavi)
        
        let chartFlag: Bool = false
        scatterChart.isHidden = false
        
        let xMin = xAxisValue.min()!
        let xMax = xAxisValue.max()!
        let yMin = yAxisValue.min()!
        let yMax = yAxisValue.max()!
        
//        print("\(currentBuilding) \(currentLevel) MinMax : \(xMin) , \(xMax), \(yMin), \(yMax)")
//        print("\(currentBuilding) \(currentLevel) Limits : \(limits[0]) , \(limits[1]), \(limits[2]), \(limits[3])")
        
//        scatterChart.xAxis.axisMinimum = -5.8
//        scatterChart.xAxis.axisMaximum = 56.8
//        scatterChart.leftAxis.axisMinimum = -2.8
//        scatterChart.leftAxis.axisMaximum = 66.6
        
//        scatterChart.xAxis.axisMinimum = -4
//        scatterChart.xAxis.axisMaximum = 36
//        scatterChart.leftAxis.axisMinimum = -4
//        scatterChart.leftAxis.axisMaximum = 78
        
//        scatterChart.xAxis.axisMinimum = -4
//        scatterChart.xAxis.axisMaximum = 36
//        scatterChart.leftAxis.axisMinimum = -4.65
//        scatterChart.leftAxis.axisMaximum = 79
        
        // Configure Chart
        if ( limits[0] == 0 && limits[1] == 0 && limits[2] == 0 && limits[3] == 0 ) {
            scatterChart.xAxis.axisMinimum = xMin - 10
            scatterChart.xAxis.axisMaximum = xMax + 10
            scatterChart.leftAxis.axisMinimum = yMin - 10
            scatterChart.leftAxis.axisMaximum = yMax + 10
        } else {
            scatterChart.xAxis.axisMinimum = limits[0]
            scatterChart.xAxis.axisMaximum = limits[1]
            scatterChart.leftAxis.axisMinimum = limits[2]
            scatterChart.leftAxis.axisMaximum = limits[3]
        }
        
        scatterChart.xAxis.drawGridLinesEnabled = chartFlag
        scatterChart.leftAxis.drawGridLinesEnabled = chartFlag
        scatterChart.rightAxis.drawGridLinesEnabled = chartFlag
        
        scatterChart.xAxis.drawAxisLineEnabled = chartFlag
        scatterChart.leftAxis.drawAxisLineEnabled = chartFlag
        scatterChart.rightAxis.drawAxisLineEnabled = chartFlag
        
        scatterChart.xAxis.centerAxisLabelsEnabled = chartFlag
        scatterChart.leftAxis.centerAxisLabelsEnabled = chartFlag
        scatterChart.rightAxis.centerAxisLabelsEnabled = chartFlag
        
        scatterChart.xAxis.drawLabelsEnabled = chartFlag
        scatterChart.leftAxis.drawLabelsEnabled = chartFlag
        scatterChart.rightAxis.drawLabelsEnabled = chartFlag
        
        scatterChart.legend.enabled = chartFlag
        
        scatterChart.backgroundColor = .clear
        
        scatterChart.data = chartData
    }
    
    func updateCoord(flag: Bool) {
        guard let debugResult = serviceManager?.getJupiterDebugResult() else { return }
        DispatchQueue.main.async { [self] in
//            let ioStatus = serviceManager.getInOutState()
            let ioStatus = "DEBUGING"
            self.inOutStatusLabel.text = "\(ioStatus)"
            
            indexLabel.text = String(debugResult.index)
            
            let XYH: [Double] = [Double(debugResult.x), Double(debugResult.y), Double(debugResult.absolute_heading)]
            let isIndoor = debugResult.isIndoor
            
            if (debugResult.building_name != "") {
                currentBuilding = debugResult.building_name
                if (debugResult.level_name != "") {
                    currentLevel = debugResult.level_name
                }
            }
            if let landmark = debugResult.landmark {
                peakIdLabel.text = String(landmark.ward_id)

            }
            if let ratio = debugResult.ratio {
                ratioLabel.text = String(format: "%.4f", ratio)
            } else {
                ratioLabel.text = "N/A"
            }
            
            pastBuilding = currentBuilding
            pastLevel = currentLevel
            
            let key = "\(currentBuilding)_\(currentLevel)"
            let condition: ((String, [[Double]])) -> Bool = { $0.0.contains(key) }
            let pathPixel: [[Double]] = PathPixel[key] ?? [[Double]]()
            
            var naviRoute = [[Float]]()
            if let navi_route = debugResult.navi_route {
                for route in navi_route {
                    if route.building  == currentBuilding && route.level == currentLevel {
                        naviRoute.append([route.x, route.y])
                    }
                }
            }
            
            if (PathPixel.contains(where: condition)) {
                if (pathPixel.isEmpty) {
                    PathPixel[key] = loadPp(fileName: key)
    //                scatterChart.isHidden = true
                } else {
                    var calc_xyh = [Double]()
                    for value in debugResult.calc_xyh {
                        calc_xyh.append(Double(value))
                    }
                    
                    var tu_xyh = [Double]()
                    for value in debugResult.tu_xyh {
                        tu_xyh.append(Double(value))
                    }
                    
                    var navi_xyh = [Double]()
                    for value in debugResult.navi_xyh {
                        navi_xyh.append(Double(value))
                    }
                    
                    drawDebug(XYH: XYH, RP_X: pathPixel[0], RP_Y: pathPixel[1],
                              calcXYH: calc_xyh,
                              tuXYH: tu_xyh,
                              landmark: debugResult.landmark,
                              best_landmark: debugResult.best_landmark,
                              recon_raw_traj: debugResult.recon_raw_traj,
                              recon_corr_traj: debugResult.recon_corr_traj,
                              recovery_result: debugResult.recovery_result,
                              recovery_result3Peaks: debugResult.recovery_result3Peaks,
                              navi_route: naviRoute,
                              naviXYH: navi_xyh,
                              limits: [0, 0, 0, 0], isBleOnlyMode: self.isBleOnlyMode, isPmSuccess: true, isIndoor: isIndoor)
                }
            } else {
                PathPixel[key] = loadPp(fileName: key)
            }
        }
    }
    
    // Display Outputs
    func startTimer() {
        if (self.timer == nil) {
            let queue = DispatchQueue(label: Bundle.main.bundleIdentifier! + ".timer")
            self.timer = DispatchSource.makeTimerSource(queue: queue)
            self.timer!.schedule(deadline: .now(), repeating: TIMER_INTERVAL)
            self.timer!.setEventHandler { [weak self] in
                guard let self = self else { return }
                self.timerUpdate()
            }
            self.timer!.resume()
        }
    }
    
    func stopTimer() {
        self.timer?.cancel()
        self.timer = nil
    }
    
    @objc func timerUpdate() {
        if (isCollect) {
//            print(getLocalTimeString() + " , (Collect) : gyroX = \(serviceManager.collectData.gyro[0])")
//            print(getLocalTimeString() + " , (Collect) : trueHeading = \(serviceManager.collectData.trueHeading)")
//            print(getLocalTimeString() + " , (Collect) : bleRaw = \(serviceManager.collectData.bleRaw)")
        } else {
            DispatchQueue.main.async {
//                if getCurrentTimeInMilliseconds() - self.statusTime > 10000 && self.inOutStatusLabel.text != "..." {
//                    self.inOutStatusLabel.text = "..."
//                }
                self.updateCoord(flag: true)
            }
            if (self.isSaved) {
                saveButton.isHidden = true
            }
        }
        
        self.phoenixTime += TIMER_INTERVAL
        if self.phoenixTime >= 1 {
            self.phoenixTime = 0
//            postPhoenixRecords()
        }
    }
    
    private func makeUniqueId(uuid: String) -> String {
        let currentTime = TJLabsUtilFunctions.shared.getCurrentTimeInMilliseconds(as: .int) as! Int
        let unique_id: String = "\(uuid)_\(currentTime)"
        
        return unique_id
    }
    
    private func setPhoenixData() {
        self.phoenixData.user_id = "user1163"
        self.phoenixData.company = "TJLABS"
        self.phoenixData.car_number = "07도3687"
        self.phoenixData.latitude = 37.513109
        self.phoenixData.longitude = 127.058375
    }
    
    private func postPhoenixRecords() {
        if phoenixData.longitude != 0 && phoenixData.latitude != 0 {
//            self.phoenixData.mobile_time = getCurrentTimeInMillisecondsDouble()
            self.phoenixIndex += 1
            self.phoenixData.index = self.phoenixIndex
            
            self.phoenixData.remaining_time = 0
//            self.phoenixData.mobile_time = getCurrentTimeInMillisecondsDouble()
            self.phoenixData.sector_id = self.sector_id

            postPhoenixRecord(url: PHOENIX_RECORD_URL, input: [phoenixData], completion: { [self] statusCode, returnedString in
                if statusCode == 200 {
//                    print(getLocalTimeString() + " , (Phoenix) Record Success : \(statusCode) , \(returnedString)")
                } else {
//                    print(getLocalTimeString() + " , (Phoenix) Record Error : \(statusCode) , \(returnedString)")
                }
            })
        }
    }
    
    func postPhoenixRecord(url: String, input: [PhoenixRecord], completion: @escaping (Int, String) -> Void) {
        // [http 비동기 방식을 사용해서 http 요청 수행 실시]
        let urlComponents = URLComponents(string: url)
        var requestURL = URLRequest(url: (urlComponents?.url)!)
        
        requestURL.httpMethod = "POST"
        let encodingData = JSONConverter.encodeJson(param: input)
        if (encodingData != nil) {
            requestURL.httpBody = encodingData
            requestURL.addValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
            
            let sessionConfig = URLSessionConfiguration.default
            sessionConfig.timeoutIntervalForResource = 5.0
            sessionConfig.timeoutIntervalForRequest = 5.0
            let session = URLSession(configuration: sessionConfig)
            
            let dataTask = session.dataTask(with: requestURL, completionHandler: { (data, response, error) in
                // [error가 존재하면 종료]
                guard error == nil else {
                    if let timeoutError = error as? URLError, timeoutError.code == .timedOut {
                        DispatchQueue.main.async {
                            completion(timeoutError.code.rawValue, error?.localizedDescription ?? "timed out")
                        }
                    } else {
                        DispatchQueue.main.async {
                            completion(500, error?.localizedDescription ?? "Fail")
                        }
                    }
                    return
                }
                
                // [status 코드 체크 실시]
                let successsRange = 200..<300
                guard let statusCode = (response as? HTTPURLResponse)?.statusCode, successsRange.contains(statusCode)
                else {
                    DispatchQueue.main.async {
                        completion(500, (response as? HTTPURLResponse)?.description ?? "Fail")
                    }
                    return
                }
                
                // [response 데이터 획득]
                let resultCode = (response as? HTTPURLResponse)?.statusCode ?? 500 // [상태 코드]
                guard let resultLen = data else {
                    DispatchQueue.main.async {
                        completion(500, (response as? HTTPURLResponse)?.description ?? "Fail")
                    }
                    return
                }
                let resultData = String(data: resultLen, encoding: .utf8) ?? "" // [데이터 확인]
                
                // [콜백 반환]
                DispatchQueue.main.async {
                    completion(resultCode, resultData)
                }
            })
            
            // [network 통신 실행]
            dataTask.resume()
        } else {
            DispatchQueue.main.async {
                completion(500, "Fail to encode")
            }
        }
    }
}

let PHOENIX_RECORD_URL: String = "https://ap-northeast-2.rec.phoenix.tjlabs.dev/2024-08-05/mr"

struct PhoenixRecord: Codable {
    var user_id: String
    var company: String
    var car_number: String
    var mobile_time: Double
    var index: Int
    var latitude: Double
    var longitude: Double
    var remaining_time: Int
    var velocity: Double
    var sector_id: Int
    var building_name: String
    var level_name: String
    var x: Int
    var y: Int
    var absolute_heading: Double
    var is_indoor: Bool
}
