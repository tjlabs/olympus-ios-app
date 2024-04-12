
public class OlympusRouteTracker {
    init() { }
    
    public var EntranceRouteVersion = [String: String]()
    public var EntranceRouteLevel = [String: [String]]()
    public var EntranceRouteCoord = [String: [[Double]]]()
    public var EntranceNetworkStatus = [String: Bool]()
    public var EntranceVelocityScales = [String: Double]()
    public var EntranceIsLoaded = [String: Bool]()
    public var EntranceNumbers: Int = 0
    
    var indexAfterRouteTrack: Int = 0
    public var entranceVelocityScale: Double = 1.0
    public var currentEntrance: String = ""
    var currentEntranceIndex: Int = 0
    var currentEntranceLength: Int = 0
    
    private func parseEntrance(data: String) -> ([String], [[Double]]) {
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
                            let parsedData = self.parseEntrance(data: contents)
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
                                    let parsedData = self.parseEntrance(data: contents)
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
                                let parsedData = self.parseEntrance(data: contents)
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
                            let parsedData = parseEntrance(data: contents)
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
        var networkBad: Bool = false
        
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
                    if let entranceNetworkStatus: Bool = self.EntranceNetworkStatus[entranceKey] {
                        networkBad = entranceNetworkStatus
                    }
                    return (true, networkBad)
                }
            }
        }
        return (false, networkBad)
    }
    
    public func getRouteTrackResult(temporalResult: FineLocationTrackingFromServer, currentLevel: String, isVenusMode: Bool, isKF: Bool, isPhaseBreakInRouteTrack: Bool) -> (isRouteTrackFinished: Bool, FineLocationTrackingFromServer) {
        var isRouteTrackFinished: Bool = false
        
        var result = temporalResult
        let localTime = getLocalTimeString()
        result = routeTrackEntrance(temporalResult: temporalResult, currentEntranceIndex: self.currentEntranceIndex)
        if (self.currentEntranceIndex < self.currentEntranceLength) {
            self.currentEntranceIndex += 1
                                    
            if (isVenusMode) {
                print(localTime + " , (Olympus) Entrance Route Tracker : Finish (BLE Only Mode)")
                isRouteTrackFinished = true
                
//                self.isStartSimulate = false
//                unitDRGenerator.setIsStartSimulate(isStartSimulate: self.isStartSimulate)
//                self.isPhaseBreakInSimulate = false
//                self.isInNetworkBadEntrance = false
                
                self.indexAfterRouteTrack = 0
                self.currentEntrance = ""
                self.currentEntranceLength = 0
                self.currentEntranceIndex = 0
            } else {
                if (result.level_name != "B0") {
                    let curLevel = removeLevelDirectionString(levelName: currentLevel)
                    if (isKF && (curLevel == result.level_name)) {
                        print(localTime + " , (Olympus) Entrance Route Tracker : Finish (Enter Phase4)")
//                        self.timeUpdatePosition.x = self.outputResult.x
//                        self.timeUpdatePosition.y = self.outputResult.y
//                        self.timeUpdatePosition.heading = self.outputResult.absolute_heading
//                        self.timeUpdateOutput.x = self.outputResult.x
//                        self.timeUpdateOutput.y = self.outputResult.y
//                        self.timeUpdateOutput.absolute_heading = self.outputResult.absolute_heading
//                        self.measurementPosition.x = self.outputResult.x
//                        self.measurementPosition.y = self.outputResult.y
//                        self.measurementPosition.heading = self.outputResult.absolute_heading
//                        self.measurementOutput.x = self.outputResult.x
//                        self.measurementOutput.y = self.outputResult.y
//                        self.measurementOutput.absolute_heading = self.outputResult.absolute_heading
                        
                        
                        isRouteTrackFinished = true
                        self.indexAfterRouteTrack = 0
                        self.currentEntrance = ""
                        self.currentEntranceLength = 0
                        self.currentEntranceIndex = 0
                    }
                }
            }
        } else {
//            self.currentLevel = self.resultToReturn.level_name
//            if (isKF) {
//                self.timeUpdatePosition.x = self.outputResult.x
//                self.timeUpdatePosition.y = self.outputResult.y
//                self.timeUpdatePosition.heading = self.outputResult.absolute_heading
//                self.timeUpdateOutput.x = self.outputResult.x
//                self.timeUpdateOutput.y = self.outputResult.y
//                self.timeUpdateOutput.absolute_heading = self.outputResult.absolute_heading
//                self.measurementPosition.x = self.outputResult.x
//                self.measurementPosition.y = self.outputResult.y
//                self.measurementPosition.heading = self.outputResult.absolute_heading
//                self.measurementOutput.x = self.outputResult.x
//                self.measurementOutput.y = self.outputResult.y
//                self.measurementOutput.absolute_heading = self.outputResult.absolute_heading
//            }
            print(localTime + " , (Olympus) Entrance Route Tracker : Finish")
            
            isRouteTrackFinished = true
            self.indexAfterRouteTrack = 0
            self.currentEntrance = ""
            self.currentEntranceLength = 0
            self.currentEntranceIndex = 0
        }
        
        return (isRouteTrackFinished, result)
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
    
    public func getEntranceVelocityScale(isGetFirstResponse: Bool, isStartRouteTrack: Bool) -> Double {
        var scale: Double = 1.0
        if (isStartRouteTrack) {
            self.indexAfterRouteTrack += 1
            scale = self.entranceVelocityScale
        }
        
        return scale
    }
    
    public func findEntrance(result: FineLocationTrackingFromServer, entrance: Int) -> (Int, Int) {
        var entranceNumber: Int = 0
        var entranceLength: Int = 0
        
        let buildingName = result.building_name
        let levelName = removeLevelDirectionString(levelName: result.level_name)
        
        let resultPm = OlympusPathMatchingCalculator.shared.pathMatching(building: buildingName, level: levelName, x: result.x, y: result.y, heading: result.absolute_heading, isPast: false, HEADING_RANGE: OlympusConstants.HEADING_RANGE, isUseHeading: false, pathType: 1, COORD_RANGE: OlympusConstants.COORD_RANGE)
        
        let coordX = resultPm.xyhs[0]
        let coordY = resultPm.xyhs[1]
        
        var resultCopy = result
        resultCopy.x = coordX
        resultCopy.y = coordY
        
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

            let xMin = column1Min
            let xMax = column1Max
            let yMin = column2Min
            let yMax = column2Max

            if (coordX >= xMin && coordX <= xMax) {
                if (coordY >= yMin && coordY <= yMax) {
                    entranceNumber = number
                    entranceLength = entranceCoord.count
                }
            }
        }
        
        return (entranceNumber, entranceLength)
    }
}
