import Foundation

public class OlympusRouteTracker {
    init() { }
    
    private var sector_id: Int = -1
    public var EntranceRouteURL = [String: String]()
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
    
    public func setSectorID(sector_id: Int) {
        self.sector_id = sector_id
    }
    
    public func setEntranceInnerWardInfo(key: String, entranceRF: EntranceRF) {
        self.EntranceInnerWardID[key] = entranceRF.id
        self.EntranceInnerWardRSSI[key] = Double(entranceRF.rss)
        self.EntranceInnerWardCoord[key] = entranceRF.pos + entranceRF.direction
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
    
    public func saveEntranceRouteLocalUrl(key: String, url: URL?) {
        if let urlToSave = url {
//            print(getLocalTimeString() + " , (Olympus) Save \(key) Entrance Route Local URL : \(urlToSave)")
            do {
                let key: String = "OlympusEntranceRouteLocalUrl_\(key)"
                UserDefaults.standard.set(url, forKey: key)
            }
        } else {
            print(getLocalTimeString() + " , (Olympus) Error : Save \(key) Entrance Route Local URL")
        }
    }
    
    public func loadEntranceRouteLocalUrl(key: String) -> (Bool, URL?) {
        let keyEntranceRouteUrl: String = "OlympusEntranceRouteLocalUrl_\(key)"
        if let loadedEntranceRouteUrl: URL = UserDefaults.standard.object(forKey: keyEntranceRouteUrl) as? URL {
            return (true, loadedEntranceRouteUrl)
        } else {
            return (false, nil)
        }
    }
    
    public func saveEntranceRouteURL(key: String, routeURL: String) {
        print(getLocalTimeString() + " , (Olympus) Save \(key) Entrance Route URL : \(routeURL)")
        do {
            let key: String = "OlympusEntranceRouteURL_\(key)"
            UserDefaults.standard.set(routeURL, forKey: key)
        }
    }
    
    public func loadEntranceRoute(sector_id: Int, RouteURL: [String: String]) {
        for (key, value) in RouteURL {
            // Cache를 통해 PP 버전을 확인
            let keyRouteVersion: String = "OlympusEntranceRouteURL_\(key)"
            if let loadedRouteVersion: String = UserDefaults.standard.object(forKey: keyRouteVersion) as? String {
                if value == loadedRouteVersion {
                    // 만약 버전이 같다면 파일을 가져오기
                    let routeLocalUrl = loadEntranceRouteLocalUrl(key: key)
                    if (routeLocalUrl.0) {
                        do {
                            if let loadedURL: URL = routeLocalUrl.1 {
                                let contents = try String(contentsOf: loadedURL)
                                let parsedData = self.parseRoute(data: contents)
                                self.EntranceRouteLevel[key] = parsedData.0
                                self.EntranceRouteCoord[key] = parsedData.1
                                self.EntranceIsLoaded[key] = true
                            }
                        } catch {
                            print(getLocalTimeString() + " , (Olympus) Error : Reading Entrance Route File \(key)")
                        }
                    } else {
                        // 첫 시작과 동일하게 다운로드 받아오기
                        let routeUrl: String = value
                        let urlComponents = URLComponents(string: routeUrl)
                        OlympusFileDownloader.shared.downloadCSVFile(from: (urlComponents?.url)!, fname: key, completion: { [self] url, error in
                            if error == nil {
                                do {
                                    let contents = try String(contentsOf: url!)
                                    let parsedData = self.parseRoute(data: contents)
                                    EntranceRouteLevel[key] = parsedData.0
                                    EntranceRouteCoord[key] = parsedData.1
                                    saveEntranceRouteURL(key: key, routeURL: value)
                                    saveEntranceRouteLocalUrl(key: key, url: url)
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
                    let routeUrl: String = value
                    let urlComponents = URLComponents(string: routeUrl)
                    OlympusFileDownloader.shared.downloadCSVFile(from: (urlComponents?.url)!, fname: key, completion: { [self] url, error in
                        if error == nil {
                            do {
                                let contents = try String(contentsOf: url!)
                                let parsedData = self.parseRoute(data: contents)
                                EntranceRouteLevel[key] = parsedData.0
                                EntranceRouteCoord[key] = parsedData.1
                                saveEntranceRouteURL(key: key, routeURL: value)
                                saveEntranceRouteLocalUrl(key: key, url: url)
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
                let routeUrl: String = value
                let urlComponents = URLComponents(string: routeUrl)
                OlympusFileDownloader.shared.downloadCSVFile(from: (urlComponents?.url)!, fname: key, completion: { [self] url, error in
                    if error == nil {
                        do {
                            let contents = try String(contentsOf: url!)
                            let parsedData = parseRoute(data: contents)
                            EntranceRouteLevel[key] = parsedData.0
                            EntranceRouteCoord[key] = parsedData.1
                            saveEntranceRouteURL(key: key, routeURL: value)
                            saveEntranceRouteLocalUrl(key: key, url: url)
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
                    
                    let entranceKey: String = "\(self.sector_id)_\(buildingName)_\(levelName)_\(entranceResult.0)"
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
        if (currentEntranceIndex < (currentEntranceLength-1)) {
            self.currentEntranceIndex += 1
//            print(getLocalTimeString() + " , (Olympus) Route Tracker : \(result.level_name), \(result.x), \(result.y), \(result.absolute_heading)")
            
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
                        print(localTime + " , (Olympus) Entrance Route Tracker : Finish (Enter Phase6)")
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
//                        print(getLocalTimeString() + " , (Olympus) Route Tracker : checkIsEntranceFinished // scannedRSSI [\(bleID) : Raw = \(scannedRSSI) : normalizedRSSI = \(normalizedRSSI) // thresholdRSSI = \(thresholdRSSI)]")
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
            
            let key = "\(self.sector_id)_\(buildingName)_\(levelName)_\(number)"
            
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

            let xMin = column1Min - 20
            let xMax = column1Max + 20
            let yMin = column2Min - 20
            let yMax = column2Max + 20

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
