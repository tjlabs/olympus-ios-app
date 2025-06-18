import UIKit
import Charts
import OlympusSDK

class CardViewController: UIViewController, Observer {
    
    @IBOutlet weak var imgViewLevel: UIImageView!
    @IBOutlet weak var scatterChart: ScatterChartView!
    
    @IBOutlet weak var indexTx: UILabel!
    @IBOutlet weak var indexRx: UILabel!
    @IBOutlet weak var scc: UILabel!
    @IBOutlet weak var searchDirections: UILabel!
    @IBOutlet weak var resultDirection: UILabel!
    
    @IBOutlet weak var saveButton: UIButton!
    @IBOutlet weak var stopButton: UIButton!
    
    var headingImage = UIImage(named: "heading")
    var coordToDisplay = CoordToDisplay()
    var isSaved: Bool = false
    
    var phoenixIndex: Int = 0
    var phoenixData = PhoenixRecord(user_id: "", company: "", car_number: "", mobile_time: 0, index: 0, latitude: 0, longitude: 0, remaining_time: 0, velocity: 0, sector_id: 0, building_name: "", level_name: "", x: 0, y: 0, absolute_heading: 0, is_indoor: false)
    var phoenixRecords = [PhoenixRecord]()
    
    override func viewDidDisappear(_ animated: Bool) {
        serviceManager.stopService()
        serviceManager.removeObserver(self)
    }
    
    func update(result: OlympusSDK.FineLocationTrackingResult) {
        DispatchQueue.main.async {
            if (result.x != 0 && result.y != 0) {
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
                
                self.coordToDisplay.building = building
                self.coordToDisplay.level = level
                self.coordToDisplay.x = x
                self.coordToDisplay.y = y
                self.coordToDisplay.heading = result.absolute_heading
                self.coordToDisplay.isIndoor = result.isIndoor
                
                self.phoenixData.building_name = building
                self.phoenixData.level_name = level
                self.phoenixData.x = Int(result.x)
                self.phoenixData.y = Int(result.y)
                self.phoenixData.absolute_heading = result.absolute_heading
                self.phoenixData.velocity = result.velocity
                self.phoenixData.is_indoor = result.isIndoor
                
//                let diffTime = result.mobile_time - self.preServiceTime
//                print(getLocalTimeString() + " , (VC) : index = \(result.index) // isIndoor = \(result.isIndoor)")
                self.preServiceTime = result.mobile_time
            }
        }
    }
    
    func report(flag: Int) {
        print("InnerLabs : Flag = \(flag)")
    }
    
    var region: String = ""
    var userId: String = ""
    
//    var sector_id: Int = 3
//    var mode: String = "pdr"
    
//    var sector_id: Int = 14 // DS
//    var mode: String = "pdr"
    
    var sector_id: Int = 6
    var mode: String = "auto"
    
//    var sector_id: Int = 15 // LG G2
//    var mode: String = "pdr"
    
//    var sector_id: Int = 4
//    var mode: String = "pdr"
    
    var currentBuilding: String = ""
    var currentLevel: String = ""
    var pastBuilding: String = "Unknwon"
    var pastLevel: String = "Unknwon"
    
    var isBleOnlyMode: Bool = false
    var PathPixel = [String: [[Double]]]()
    
    let OPERATING_SYSTEM: String = "iOS"
    
    var serviceManager = OlympusServiceManager()
    var isCollect: Bool = false
    
    var timer: Timer?
    let TIMER_INTERVAL: TimeInterval = 1/10
    var phoenixTime: TimeInterval = 0
    var preServiceTime: Int = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        headingImage = headingImage?.resize(newWidth: 20)

//        serviceManager.setSimulationMode(flag: true, bleFileName: "ble_dr3.csv", sensorFileName: "sensor_dr3.csv")
//        serviceManager.setSimulationMode(flag: true, bleFileName: "ble_coex_0604_02.csv", sensorFileName: "sensor_coex_0604_02.csv")
//        serviceManager.setSim1ulationMode(flag: true, bleFileName: "ble_coex_02_0930.csv", sensorFileName: "sensor_coex_02_0930.csv")
        serviceManager.setSimulationMode(flag: true, bleFileName: "ble_coex_05_04_1007.csv", sensorFileName: "sensor_coex_05_04_1007.csv")
//        serviceManager.setSimulationMode(flag: true, bleFileName: "ble_coex_dr_03_1030.csv", sensorFileName: "sensor_coex_dr_03_1030.csv")
    
//        serviceManager.setDeadReckoningMode(flag: true, buildingName: "Solum", levelName: "0F", x: 5, y: 5, heading: 90)
//        serviceManager.setDeadReckoningMode(flag: true, buildingName: "S3", levelName: "7F", x: 6, y: 16, heading: 270)
        
//        serviceManager.setSimulationMode(flag: true, bleFileName: "ble_songdo_0519_02.csv", sensorFileName: "sensor_songdo_0519_02.csv")
        
        // collect
//        isCollect = true
//        serviceManager.initCollect(region: self.region)
//        serviceManager.startCollect()
//        self.startTimer()
        
//        self.setPhoenixData()
        let uniqueId = makeUniqueId(uuid: self.userId)
//        let uniqueId = "coex01_olympus"
        // service
        serviceManager.addObserver(self)
        serviceManager.startService(user_id: uniqueId, region: self.region, sector_id: sector_id, service: "FLT", mode: mode, completion: { [self] isStart, returnedString in
//        serviceManager.startService(user_id: uniqueId, region: "Korea", sector_id: 16, service: "FLT", mode: "pdr", completion: { [self] isStart, returnedString in
            if (isStart) {
                self.startTimer()
            } else {
                print(returnedString)
            }
        })
    }
    
    override func viewWillDisappear(_ animated: Bool) {
    }
    

    @IBAction func tapSaveButton(_ sender: UIButton) {
        self.isSaved = serviceManager.saveSimulationFile()
        if (self.isSaved) {
            saveButton.isHidden = true
        }
//        serviceManager.stopCollect()
        serviceManager.stopService()
        self.stopTimer()
    }
    
    
    @IBAction func tapStopButton(_ sender: UIButton) {
        let isStop = serviceManager.stopService()
    }
    
    
    private func loadPp(fileName: String) -> [[Double]] {
        guard let path = Bundle.main.path(forResource: fileName, ofType: "csv") else {
            return [[Double]]()
        }
        let ppXY:[[Double]] = parsePp(url: URL(fileURLWithPath: path))
        print(getLocalTimeString() + " , (VC) Load PP : path = \(path)")
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
            print(getLocalTimeString() + " , (VC) Error reading .csv file")
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
    
    private func drawResult(XY: [Double], RP_X: [Double], RP_Y: [Double], heading: Double, limits: [Double], isBleOnlyMode: Bool, isPmSuccess: Bool, isIndoor: Bool) {
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
            return ChartDataEntry(x: XY[0], y: XY[1])
        }
        let set1 = ScatterChartDataSet(entries: values1, label: "USER")
        set1.drawValuesEnabled = false
        set1.setScatterShape(.circle)
        set1.setColor(valueColor)
        set1.scatterShapeSize = 16
        
        let chartData = ScatterChartData(dataSet: set0)
        chartData.append(set1)
        chartData.setDrawValues(false)
        
        // Heading
        let point = scatterChart.getPosition(entry: ChartDataEntry(x: XY[0], y: XY[1]), axis: .left)
        let imageView = UIImageView(image: headingImage!.rotate(degrees: -heading+90))
        imageView.frame = CGRect(x: point.x - 15, y: point.y - 15, width: 30, height: 30)
        imageView.contentMode = .center
        imageView.tag = 100
        if let viewWithTag = scatterChart.viewWithTag(100) {
            viewWithTag.removeFromSuperview()
        }
        scatterChart.addSubview(imageView)
        
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
    
    private func drawDebug(XY: [Double], RP_X: [Double], RP_Y: [Double],  serverXY: [Double], tuXY: [Double], heading: Double, limits: [Double], isBleOnlyMode: Bool, isPmSuccess: Bool, trajectoryStartCoord: [Double], userTrajectory: [[Double]], searchArea: [[Double]], searchType: Int, isIndoor: Bool, trajPm: [[Double]], trajOg: [[Double]]) {
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
            return ChartDataEntry(x: XY[0], y: XY[1])
        }
        let set1 = ScatterChartDataSet(entries: values1, label: "USER")
        set1.drawValuesEnabled = false
        set1.setScatterShape(.circle)
        set1.setColor(valueColor)
        set1.scatterShapeSize = 16
        
        let values2 = (0..<1).map { (i) -> ChartDataEntry in
            return ChartDataEntry(x: serverXY[0], y: serverXY[1])
        }
        
        let set2 = ScatterChartDataSet(entries: values2, label: "SERVER")
        set2.drawValuesEnabled = false
        set2.setScatterShape(.circle)
        set2.setColor(.yellow)
        set2.scatterShapeSize = 12
        
        let values3 = (0..<1).map { (i) -> ChartDataEntry in
            return ChartDataEntry(x: tuXY[0], y: tuXY[1])
        }
        
        let set3 = ScatterChartDataSet(entries: values3, label: "TU")
        set3.drawValuesEnabled = false
        set3.setScatterShape(.circle)
        set3.setColor(.systemGreen)
        set3.scatterShapeSize = 12
        
        let values4 = (0..<1).map { (i) -> ChartDataEntry in
            return ChartDataEntry(x: trajectoryStartCoord[0], y: trajectoryStartCoord[1])
        }
        
        let set4 = ScatterChartDataSet(entries: values4, label: "startCoord")
        set4.drawValuesEnabled = false
        set4.setScatterShape(.circle)
        set4.setColor(.blue)
        set4.scatterShapeSize = 8
        
        let values5 = (0..<userTrajectory.count).map { (i) -> ChartDataEntry in
            return ChartDataEntry(x: userTrajectory[i][0], y: userTrajectory[i][1])
        }
        let set5 = ScatterChartDataSet(entries: values5, label: "Trajectory")
        set5.drawValuesEnabled = false
        set5.setScatterShape(.circle)
        set5.setColor(.black)
        set5.scatterShapeSize = 6
        
        let values6 = (0..<searchArea.count).map { (i) -> ChartDataEntry in
            return ChartDataEntry(x: searchArea[i][0], y: searchArea[i][1])
        }
        let set6 = ScatterChartDataSet(entries: values6, label: "SearchArea")
        set6.drawValuesEnabled = false
        set6.setScatterShape(.circle)
        
        let values7 = (0..<trajPm.count).map { (i) -> ChartDataEntry in
            return ChartDataEntry(x: trajPm[i][0], y: trajPm[i][1])
        }
        let set7 = ScatterChartDataSet(entries: values7, label: "TrajectoryPm")
        set7.drawValuesEnabled = false
        set7.setScatterShape(.circle)
        set7.setColor(.systemRed)
        set7.scatterShapeSize = 6
        
        let values8 = (0..<trajOg.count).map { (i) -> ChartDataEntry in
            return ChartDataEntry(x: trajOg[i][0], y: trajOg[i][1])
        }
        let set8 = ScatterChartDataSet(entries: values8, label: "TrajectoryOg")
        set8.drawValuesEnabled = false
        set8.setScatterShape(.circle)
        set8.setColor(.systemBlue)
        set8.scatterShapeSize = 6
        
        switch (searchType) {
        case 0:
            // 곡선
            set6.setColor(.systemYellow)
        case 1:
            // All 직선
            set6.setColor(.systemGreen)
        case 2:
            // Head 직선
            set6.setColor(.systemBlue)
        case 3:
            // Tail 직선
            set6.setColor(.blue3)
        case 4:
            // PDR_IN_PHASE4_HAS_MAJOR_DIR & Phase == 2 Request 
            set6.setColor(.systemOrange)
        case 5:
            // PDR Phase < 4
            set6.setColor(.systemGreen)
        case 6:
            // PDR_IN_PHASE4_NO_MAJOR_DIR
            set6.setColor(.systemBlue)
        case 7:
            // PDR Phase = 4 & Empty Closest Index
            set6.setColor(.blue3)
        case -1:
            // Phase 2 & No Request
            set6.setColor(.red)
        case -2:
            // KF 진입 전
            set6.setColor(.systemBrown)
        default:
            set6.setColor(.systemTeal)
        }
        set6.scatterShapeSize = 6
        
        let chartData = ScatterChartData(dataSet: set0)
        chartData.append(set1)
        chartData.append(set2)
        chartData.append(set3)
        chartData.append(set4)
        chartData.append(set5)
        chartData.append(set6)
        chartData.append(set7)
        chartData.append(set8)
        chartData.setDrawValues(false)
        
        // Heading
        let point = scatterChart.getPosition(entry: ChartDataEntry(x: XY[0], y: XY[1]), axis: .left)
        let imageView = UIImageView(image: headingImage!.rotate(degrees: -heading+90))
        imageView.frame = CGRect(x: point.x - 15, y: point.y - 15, width: 30, height: 30)
        imageView.contentMode = .center
        imageView.tag = 100
        if let viewWithTag = scatterChart.viewWithTag(100) {
            viewWithTag.removeFromSuperview()
        }
        scatterChart.addSubview(imageView)
        
        let point2 = scatterChart.getPosition(entry: ChartDataEntry(x: serverXY[0], y: serverXY[1]), axis: .left)
        let imageView2 = UIImageView(image: headingImage!.rotate(degrees: -serverXY[2]+90))
        imageView2.frame = CGRect(x: point2.x - 15, y: point2.y - 15, width: 30, height: 30)
        imageView2.contentMode = .center
        imageView2.tag = 200
        if let viewWithTag2 = scatterChart.viewWithTag(200) {
            viewWithTag2.removeFromSuperview()
        }
        scatterChart.addSubview(imageView2)
        
        let point3 = scatterChart.getPosition(entry: ChartDataEntry(x: tuXY[0], y: tuXY[1]), axis: .left)
        let imageView3 = UIImageView(image: headingImage!.rotate(degrees: -tuXY[2]+90))
        imageView3.frame = CGRect(x: point3.x - 15, y: point3.y - 15, width: 30, height: 30)
        imageView3.contentMode = .center
        imageView3.tag = 300
        if let viewWithTag3 = scatterChart.viewWithTag(300) {
            viewWithTag3.removeFromSuperview()
        }
        scatterChart.addSubview(imageView3)
        
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
    
    func updateCoord(data: CoordToDisplay, flag: Bool) {
        DispatchQueue.main.async { [self] in
            indexTx.text = String(serviceManager.displayOutput.indexTx)
            indexRx.text = String(serviceManager.displayOutput.indexRx) + " // " + String(serviceManager.displayOutput.phase)
            scc.text = String(serviceManager.displayOutput.scc)
            
            let directionArray = serviceManager.displayOutput.searchDirection
            let stringArray = directionArray.map { String($0) }
            searchDirections.text = stringArray.joined(separator: ", ")
            resultDirection.text = String(serviceManager.displayOutput.resultDirection)
            
            let XY: [Double] = [data.x, data.y]
            let heading: Double = data.heading
            let isIndoor = data.isIndoor
            var limits: [Double] = [0, 0, 0, 0]
            
            if (data.building != "") {
                currentBuilding = data.building
                if (data.level != "") {
                    currentLevel = data.level
                }
            }
            
            
            pastBuilding = currentBuilding
            pastLevel = currentLevel
            
            
            let key = "\(data.building)_\(data.level)"
            let condition: ((String, [[Double]])) -> Bool = {
                $0.0.contains(key)
            }
            let pathPixel: [[Double]] = PathPixel[key] ?? [[Double]]()
            if (PathPixel.contains(where: condition)) {
                if (pathPixel.isEmpty) {
                    PathPixel[key] = loadPp(fileName: key)
    //                scatterChart.isHidden = true
                } else {
    //                scatterChart.isHidden = false
                    let serverXY: [Double] = serviceManager.displayOutput.serverResult
                    let tuXY: [Double] = serviceManager.timeUpdateResult
                    drawDebug(XY: XY, RP_X: pathPixel[0], RP_Y: pathPixel[1], serverXY: serverXY, tuXY: tuXY, heading: heading, limits: limits, isBleOnlyMode: self.isBleOnlyMode, isPmSuccess: true, trajectoryStartCoord: serviceManager.displayOutput.trajectoryStartCoord, userTrajectory: serviceManager.displayOutput.userTrajectory, searchArea: serviceManager.displayOutput.searchArea, searchType: serviceManager.displayOutput.searchType, isIndoor: isIndoor, trajPm: serviceManager.displayOutput.trajectoryPm, trajOg: serviceManager.displayOutput.trajectoryOg)
    //                drawResult(XY: XY, RP_X: pathPixel[0], RP_Y: pathPixel[1], heading: heading, limits: limits, isBleOnlyMode: self.isBleOnlyMode, isPmSuccess: true, isIndoor: isIndoor)
                }
            } else {
                PathPixel[key] = loadPp(fileName: key)
            }
        }
    }
    
    // Display Outputs
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
        if (isCollect) {
            print(getLocalTimeString() + " , (Collect) : gyroX = \(serviceManager.collectData.gyro[0])")
            print(getLocalTimeString() + " , (Collect) : trueHeading = \(serviceManager.collectData.trueHeading)")
            print(getLocalTimeString() + " , (Collect) : bleRaw = \(serviceManager.collectData.bleRaw)")
        } else {
            DispatchQueue.main.async {
                self.updateCoord(data: self.coordToDisplay, flag: true)
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
        let currentTime: Int = getCurrentTimeInMilliseconds()
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
            self.phoenixData.mobile_time = getCurrentTimeInMillisecondsDouble()
            self.phoenixIndex += 1
            self.phoenixData.index = self.phoenixIndex
            
            self.phoenixData.remaining_time = 0
            self.phoenixData.mobile_time = getCurrentTimeInMillisecondsDouble()
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
