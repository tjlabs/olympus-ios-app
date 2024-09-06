
public class OlympusRouteTracker {
    init() { }
    
    public var EntranceRouteVersion = [String: String]()
    public var EntranceRouteLevel = [String: [String]]()
    public var EntranceRouteCoord = [String: [[Double]]]()
    public var EntranceNetworkStatus = [String: Bool]()
    public var EntranceVelocityScales = [String: Double]()
    public var EntranceIsLoaded = [String: Bool]()
    public var EntranceNumbers: Int = 0
    public var EntranceInnerWardID = [String: String]()
    public var EntranceInnerWardRSSI = [String: Double]()
    public var EntranceInnerWardCoord = [String: [Double]]()
    
    var indexAfterRouteTrack: Int = 0
    public var entranceVelocityScale: Double = 1.0
    public var currentEntrance: String = ""
    var currentEntranceIndex: Int = 0
    var currentEntranceLength: Int = 0
    
    public func initialize() {
        self.indexAfterRouteTrack = 0
        self.entranceVelocityScale = 1.0
        self.currentEntrance = ""
        self.currentEntranceIndex = 0
        self.currentEntranceLength = 0
    }
    
    public func setEntranceInnerWardInfo(key: String, sectorInfoInnermostWard: SectorInfoInnermostWard) {
        self.EntranceInnerWardID[key] = sectorInfoInnermostWard.id
        self.EntranceInnerWardRSSI[key] = Double(sectorInfoInnermostWard.rss)
        self.EntranceInnerWardCoord[key] = sectorInfoInnermostWard.pos + sectorInfoInnermostWard.direction
//        print(getLocalTimeString() + " , (Olympus) setEntranceInnerWardInfo : key = \(key) , ID = \(EntranceInnerWardID[key]) , RSSI = \(EntranceInnerWardRSSI[key]) , XYH = \(EntranceInnerWardCoord[key])")
        
//        self.EntranceInnerWardID["COEX_B0_1"] = "TJ-00CB-00000320-0000"
//        self.EntranceInnerWardRSSI["COEX_B0_1"] = -80
//        self.EntranceInnerWardCoord["COEX_B0_1"] = [252, 70, 90]
//        
//        self.EntranceInnerWardID["COEX_B0_2"] = "TJ-00CB-00000323-0000"
//        self.EntranceInnerWardRSSI["COEX_B0_2"] = -80
//        self.EntranceInnerWardCoord["COEX_B0_2"] = [250, 180, 90]
//        
//        self.EntranceInnerWardID["COEX_B0_3"] = "TJ-00CB-00000344-0000"
//        self.EntranceInnerWardRSSI["COEX_B0_3"] = -72
//        self.EntranceInnerWardCoord["COEX_B0_3"] = [291, 290, 90]
//        
//        self.EntranceInnerWardID["COEX_B0_4"] = "TJ-00CB-000002A4-0000"
//        self.EntranceInnerWardRSSI["COEX_B0_4"] = -80
//        self.EntranceInnerWardCoord["COEX_B0_4"] = [248, 442, 180]
//        
//        self.EntranceInnerWardID["COEX_B0_5"] = "TJ-00CB-000002B1-0000"
//        self.EntranceInnerWardRSSI["COEX_B0_5"] = -80
//        self.EntranceInnerWardCoord["COEX_B0_5"] = [59, 350, 270]
    }

    private func parseRoute(data: String) -> ([String], [[Double]]) {
        var entracneLevelArray = [String]()
        var entranceArray = [[Double]]()

        let entranceString = data.components(separatedBy: .newlines)
        for i in 0..<entranceString.count {
            if (entranceString[i] != "") {
                let lineData = entranceString[i].components(separatedBy: ",")
                
                let entrance: [Double] = [(Double(lineData[1])!), (Double(lineData[2])!), (Double(lineData[3])!)]
                
                entracneLevelArray.append(lineData[0])
                entranceArray.append(entrance)
            }
        }
        return (entracneLevelArray, entranceArray)
    }
    
    public func saveEntranceRouteLocalUrl(key: String, url: String) {
        print(getLocalTimeString() + " , (Olympus) Save \(key) Entrance Route Local URL : \(url)")
        
        do {
            let key: String = "OlympusEntranceRouteLocalUrl_\(key)"
            UserDefaults.standard.set(url, forKey: key)
        }
    }
    
    public func loadEntranceRouteLocalUrl(key: String) -> (Bool, String?) {
        let keyEntranceRouteUrl: String = "OlympusEntranceRouteLocalUrl_\(key)"
        if let loadedEntranceRouteUrl: String = UserDefaults.standard.object(forKey: keyEntranceRouteUrl) as? String {
            return (true, loadedEntranceRouteUrl)
        } else {
            return (false, nil)
        }
    }
    
    public func saveEntranceRouteVersion(key: String, routeVersion: String) {
        print(getLocalTimeString() + " , (Olympus) Save \(key) Entrance Route Version : \(routeVersion)")
        do {
            let key: String = "OlympusEntranceRouteVersion_\(key)"
            UserDefaults.standard.set(routeVersion, forKey: key)
        }
    }
    
    public func loadEntranceRoute(sector_id: Int, RouteVersion: [String: String]) {
        for (key, value) in RouteVersion {
            // Cache를 통해 PP 버전을 확인
            let keyRouteVersion: String = "OlympusEntranceRouteVersion_\(key)"
            if let loadedRouteVersion: String = UserDefaults.standard.object(forKey: keyRouteVersion) as? String {
                if value == loadedRouteVersion {
                    // 만약 버전이 같다면 파일을 가져오기
                    let routeLocalUrl = loadEntranceRouteLocalUrl(key: key)
                    if (routeLocalUrl.0) {
                        do {
                            let contents = routeLocalUrl.1!
                            let parsedData = self.parseRoute(data: contents)
                            self.EntranceRouteLevel[key] = parsedData.0
                            self.EntranceRouteCoord[key] = parsedData.1
                            self.EntranceIsLoaded[key] = true
                        }
                    } else {
                        // 첫 시작과 동일하게 다운로드 받아오기
                        let building_level_entrance = key.split(separator: "_")
                        let routeUrl: String = CSV_URL + "/entrance-route/\(sector_id)/\(building_level_entrance[0])/\(building_level_entrance[1])/\(building_level_entrance[2])/\(value)/\(OlympusConstants.OPERATING_SYSTEM).csv"
                        let urlComponents = URLComponents(string: routeUrl)
                        OlympusFileDownloader.shared.downloadCSVFile(from: (urlComponents?.url)!, fname: key, completion: { [self] url, error in
                            if error == nil {
                                do {
                                    let contents = try String(contentsOf: url!)
                                    let parsedData = self.parseRoute(data: contents)
                                    EntranceRouteLevel[key] = parsedData.0
                                    EntranceRouteCoord[key] = parsedData.1
                                    saveEntranceRouteVersion(key: key, routeVersion: value)
                                    saveEntranceRouteLocalUrl(key: key, url: contents)
                                    EntranceIsLoaded[key] = true
                                } catch {
                                    EntranceIsLoaded[key] = false
                                    print("Error reading file:", error.localizedDescription)
                                }
                            } else {
                                self.EntranceIsLoaded[key] = false
                            }
                        })
                    }
                } else {
                    // 만약 버전이 다르면 다운로드 받아오기
                    // 첫 시작과 동일하게 다운로드 받아오기
                    let building_level_entrance = key.split(separator: "_")
                    let routeUrl: String = CSV_URL + "/entrance-route/\(sector_id)/\(building_level_entrance[0])/\(building_level_entrance[1])/\(building_level_entrance[2])/\(value)/\(OlympusConstants.OPERATING_SYSTEM).csv"
                    let urlComponents = URLComponents(string: routeUrl)
                    OlympusFileDownloader.shared.downloadCSVFile(from: (urlComponents?.url)!, fname: key, completion: { [self] url, error in
                        if error == nil {
                            do {
                                let contents = try String(contentsOf: url!)
                                let parsedData = self.parseRoute(data: contents)
                                EntranceRouteLevel[key] = parsedData.0
                                EntranceRouteCoord[key] = parsedData.1
                                saveEntranceRouteVersion(key: key, routeVersion: value)
                                saveEntranceRouteLocalUrl(key: key, url: contents)
                                EntranceIsLoaded[key] = true
                            } catch {
                                EntranceIsLoaded[key] = false
                                print("Error reading file:", error.localizedDescription)
                            }
                        } else {
                            EntranceIsLoaded[key] = false
                        }
                    })
                }
            } else {
                // 첫 시작이면 다운로드 받아오기
                let building_level_entrance = key.split(separator: "_")
                let routeUrl: String = CSV_URL + "/entrance-route/\(sector_id)/\(building_level_entrance[0])/\(building_level_entrance[1])/\(building_level_entrance[2])/\(value)/\(OlympusConstants.OPERATING_SYSTEM).csv"
                let urlComponents = URLComponents(string: routeUrl)
                OlympusFileDownloader.shared.downloadCSVFile(from: (urlComponents?.url)!, fname: key, completion: { [self] url, error in
                    if error == nil {
                        do {
                            let contents = try String(contentsOf: url!)
                            let parsedData = parseRoute(data: contents)
                            EntranceRouteLevel[key] = parsedData.0
                            EntranceRouteCoord[key] = parsedData.1
                            saveEntranceRouteVersion(key: key, routeVersion: value)
                            saveEntranceRouteLocalUrl(key: key, url: contents)
                            EntranceIsLoaded[key] = true
                        } catch {
                            EntranceIsLoaded[key] = false
                            print("Error reading file:", error.localizedDescription)
                        }
                    } else {
                        EntranceIsLoaded[key] = false
                    }
                })
            }
        }
    }
    
    public func startRouteTracking(result: FineLocationTrackingFromServer, isStartRouteTrack: Bool) -> (Bool, Bool) {
        var networkStatus: Bool = false
        
        for i in 0..<self.EntranceNumbers {
            if (!isStartRouteTrack) {
                let entranceResult = self.findEntrance(result: result, entrance: i)
                if (entranceResult.0 != 0) {
                    let buildingName = result.building_name
                    let levelName = removeLevelDirectionString(levelName: result.level_name)
                    
                    let entranceKey: String = "\(buildingName)_\(levelName)_\(entranceResult.0)"
                    if let velocityScale: Double = self.EntranceVelocityScales[entranceKey] {
                        self.entranceVelocityScale = velocityScale
                    } else {
                        self.entranceVelocityScale = 1.0
                    }

                    self.currentEntrance = entranceKey
                    self.currentEntranceLength = entranceResult.1
                    print(getLocalTimeString() + " , (Olympus) Route Tracker : EntranceNetworkStatus = \(EntranceNetworkStatus)")
                    if let entranceNetworkStatus: Bool = self.EntranceNetworkStatus[entranceKey] {
                        networkStatus = entranceNetworkStatus
                    }
                    print(getLocalTimeString() + " , (Olympus) Start Route Tracker : entrance = \(currentEntrance) // networkStatus = \(networkStatus) // length = \(currentEntranceLength)")
                    return (true, networkStatus)
                }
            }
        }
        return (false, networkStatus)
    }
    
    public func getRouteTrackResult(temporalResult: FineLocationTrackingFromServer, currentLevel: String, isVenusMode: Bool, isKF: Bool, isPhaseBreakInRouteTrack: Bool) -> (isRouteTrackFinished: Bool, RouteTrackFinishType, FineLocationTrackingFromServer) {
        var isRouteTrackFinished: Bool = false
        var finishType = RouteTrackFinishType.NOT_STABLE
        
        var result = temporalResult
        let localTime = getLocalTimeString()
        result = routeTrackEntrance(temporalResult: temporalResult, currentEntranceIndex: currentEntranceIndex)
//        print(getLocalTimeString() + " , (Olympus) Route Track : currentEntranceIndex = \(currentEntranceIndex) // currentEntranceLength = \(currentEntranceLength)")
        if (currentEntranceIndex < (currentEntranceLength-1)) {
            self.currentEntranceIndex += 1
//            print(getLocalTimeString() + " , (Olympus) Route Track : temporalResult = \(temporalResult)")
            
            if (isVenusMode) {
                print(localTime + " , (Olympus) Entrance Route Tracker : Finish (BLE Only Mode)")
                isRouteTrackFinished = true
                finishType = .VENUS
                self.indexAfterRouteTrack = 0
                self.currentEntrance = ""
                self.currentEntranceLength = 0
                self.currentEntranceIndex = 0
            } else {
                if (result.level_name != "B0") {
                    let curLevel = removeLevelDirectionString(levelName: currentLevel)
                    if (isKF && (curLevel == result.level_name)) {
                        print(localTime + " , (Olympus) Entrance Route Tracker : Finish (Enter Phase5)")
                        isRouteTrackFinished = true
                        finishType = .STABLE
                        self.indexAfterRouteTrack = 0
                        self.currentEntrance = ""
                        self.currentEntranceLength = 0
                        self.currentEntranceIndex = 0
                    }
                }
            }
        } else {
            print(localTime + " , (Olympus) Entrance Route Tracker : Finish")
            isRouteTrackFinished = true
            finishType = .NOT_STABLE
            self.indexAfterRouteTrack = 0
            self.currentEntrance = ""
            self.currentEntranceLength = 0
            self.currentEntranceIndex = 0
        }
        
        return (isRouteTrackFinished, finishType, result)
    }
    
    private func routeTrackEntrance(temporalResult: FineLocationTrackingFromServer, currentEntranceIndex: Int) -> FineLocationTrackingFromServer {
        var result = temporalResult
        guard let entranceRouteLevel: [String] = self.EntranceRouteLevel[self.currentEntrance] else {
            return result
        }
        
        guard let entranceRouteCoord: [[Double]] = self.EntranceRouteCoord[self.currentEntrance] else {
            return result
        }
        
        result.level_name = entranceRouteLevel[currentEntranceIndex]
        result.x = entranceRouteCoord[currentEntranceIndex][0]
        result.y = entranceRouteCoord[currentEntranceIndex][1]
        result.absolute_heading = entranceRouteCoord[currentEntranceIndex][2]
        
        return result
    }
    
    public func getRouteTrackEndLevel() -> String {
        if let entranceRouteLevel: [String] = self.EntranceRouteLevel[self.currentEntrance] {
            let levelName = entranceRouteLevel[currentEntranceLength-1]
            return levelName
        } else {
            return ""
        }
    }
    
    public func getEntranceVelocityScale(isGetFirstResponse: Bool, isStartRouteTrack: Bool) -> Double {
        var scale: Double = 1.0
        if (isStartRouteTrack) {
            self.indexAfterRouteTrack += 1
            scale = self.entranceVelocityScale
        }
        
        return scale
    }
    
    public func checkIsEntranceFinished(bleData: [String: Double], normalization_scale: Double, device_min_rss: Double, standard_min_rss: Double) -> (Bool, [Double]) {
        let xyh: [Double] = [0, 0, 0]
        if let bleID = EntranceInnerWardID[currentEntrance] {
            if let scannedRSSI = bleData[bleID] {
                if let thresholdRSSI = EntranceInnerWardRSSI[currentEntrance] {
                    if let wardCoord = EntranceInnerWardCoord[currentEntrance] {
                        let normalizedRSSI = (scannedRSSI - device_min_rss)*normalization_scale + standard_min_rss
                        return normalizedRSSI >= thresholdRSSI ? (true, wardCoord) : (false, xyh)
                    } else {
                        return (false, xyh)
                    }
                } else {
                    return (false, xyh)
                }
            } else {
                return (false, xyh)
            }
        } else {
            return (false, xyh)
        }
    }
    
//    public func checkIsEntranceAnchor(bleData: [String: Double]) -> (Bool, [Double]) {
//        let xyh: [Double] = [0, 0, 0]
//        if (currentEntrance == "COEX_B0_1") {
//            let bleID = "TJ-00CB-00000320-0000"
//            if let bleRSSI = bleData[bleID] {
//                print(getLocalTimeString() + " , (Olympus) Route Track : checkIsEntranceAnchor // \(currentEntrance) // RSSI = \(bleRSSI)")
//                return bleRSSI >= -80 ? (true, [252, 70, 90]) : (false, xyh)
//            } else {
//                return (false, xyh)
//            }
//        } else if (currentEntrance == "COEX_B0_2") {
//            let bleID = "TJ-00CB-00000323-0000"
//            if let bleRSSI = bleData[bleID] {
//                print(getLocalTimeString() + " , (Olympus) Route Track : checkIsEntranceAnchor // \(currentEntrance) // RSSI = \(bleRSSI)")
//                return bleRSSI >= -80 ? (true, [250, 180, 90]) : (false, xyh)
//            } else {
//                return (false, xyh)
//            }
//        } else if (currentEntrance == "COEX_B0_3") {
//            let bleID = "TJ-00CB-00000344-0000"
//            if let bleRSSI = bleData[bleID] {
//                print(getLocalTimeString() + " , (Olympus) Route Track : checkIsEntranceAnchor // \(currentEntrance) // RSSI = \(bleRSSI)")
//                return bleRSSI >= -72 ? (true, [291, 290, 90]) : (false, xyh)
//            } else {
//                return (false, xyh)
//            }
//        } else if (currentEntrance == "COEX_B0_4") {
//            let bleID = "TJ-00CB-000002A4-0000"
//            if let bleRSSI = bleData[bleID] {
//                print(getLocalTimeString() + " , (Olympus) Route Track : checkIsEntranceAnchor // \(currentEntrance) // RSSI = \(bleRSSI)")
//                return bleRSSI >= -80 ? (true, [248, 442, 180]) : (false, xyh)
//            } else {
//                return (false, xyh)
//            }
//        } else if (currentEntrance == "COEX_B0_5") {
//            let bleID = "TJ-00CB-000002B1-0000"
//            if let bleRSSI = bleData[bleID] {
//                print(getLocalTimeString() + " , (Olympus) Route Track : checkIsEntranceAnchor // \(currentEntrance) // RSSI = \(bleRSSI)")
//                return bleRSSI >= -80 ? (true, [59, 350, 270]) : (false, xyh)
//            } else {
//                return (false, xyh)
//            }
//        }
//        return (false, xyh)
//    }
    
    public func findEntrance(result: FineLocationTrackingFromServer, entrance: Int) -> (Int, Int) {
        var entranceNumber: Int = 0
        var entranceLength: Int = 0
        
        let buildingName = result.building_name
        let levelName = removeLevelDirectionString(levelName: result.level_name)
        
        let resultPm = OlympusPathMatchingCalculator.shared.pathMatching(building: buildingName, level: levelName, x: result.x, y: result.y, heading: result.absolute_heading, HEADING_RANGE: OlympusConstants.HEADING_RANGE, isUseHeading: false, pathType: 1, PADDING_VALUES: OlympusConstants.PADDING_VALUES)
        
        let coordX = resultPm.xyhs[0]
        let coordY = resultPm.xyhs[1]
        
        if (levelName == "B0") {
            let number = entrance+1
            
            let key = "\(buildingName)_\(levelName)_\(number)"
            
            guard let entranceCoord: [[Double]] = EntranceRouteCoord[key] else {
                return (entranceNumber, entranceLength)
            }
            
            var column1Min = Double.infinity
            var column1Max = -Double.infinity

            for row in entranceCoord {
                let value = row[0]
                column1Min = min(column1Min, value)
                column1Max = max(column1Max, value)
            }

            var column2Min = Double.infinity
            var column2Max = -Double.infinity

            for row in entranceCoord {
                let value = row[1]
                column2Min = min(column2Min, value)
                column2Max = max(column2Max, value)
            }

            let xMin = column1Min - 5
            let xMax = column1Max + 5
            let yMin = column2Min - 5
            let yMax = column2Max + 5

            if (coordX >= xMin && coordX <= xMax) {
                if (coordY >= yMin && coordY <= yMax) {
                    entranceNumber = number
                    entranceLength = entranceCoord.count
                }
            }
        }
        
        return (entranceNumber, entranceLength)
    }
    
    public func getCurrentEntranceNumber() -> Int {
        let entranceString = self.currentEntrance.split(separator: "_")
        if entranceString.count == 3 {
            let entranceNumber = Int(entranceString[entranceString.count-1])
            
            return entranceNumber ?? 0
        }
        return 0
    }
}
