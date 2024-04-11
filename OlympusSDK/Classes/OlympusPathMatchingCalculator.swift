public class OlympusPathMatchingCalculator {
    static var shared = OlympusPathMatchingCalculator()
    
    public var PpVersion = [String: String]()
    public var PpCoord = [String: [[Double]]]()
    public var PpType = [String: [Int]]()
    public var PpMinMax = [Double]()
    public var PpMagScale = [String: [Double]]()
    public var PpHeading = [String: [String]]()
    
    public var PpIsLoaded = [String: Bool]()
    
    // Path-Matching Areas
    public var EntranceArea = [String: [[Double]]]()
    public var EntranceMatchingArea = [String: [[Double]]]()
    public var LevelChangeArea = [String: [[Double]]]()
    
    init() {
        
    }
    
    public func parseRoad(data: String) -> ([Int], [[Double]], [Double], [String] ) {
        var roadType = [Int]()
        var road = [[Double]]()
        var roadScale = [Double]()
        var roadHeading = [String]()
        
        var roadX = [Double]()
        var roadY = [Double]()
        
        let roadString = data.components(separatedBy: .newlines)
        for i in 0..<roadString.count {
            if (roadString[i] != "") {
                let lineData = roadString[i].components(separatedBy: ",")
                
                roadType.append(Int(Double(lineData[0])!))
                roadX.append(Double(lineData[1])!)
                roadY.append(Double(lineData[2])!)
                roadScale.append(Double(lineData[3])!)
                
                var headingArray: String = ""
                if (lineData.count > 4) {
                    for j in 4..<lineData.count {
                        headingArray.append(lineData[j])
                        if (lineData[j] != "") {
                            headingArray.append(",")
                        }
                    }
                }
                roadHeading.append(headingArray)
            }
        }
        road = [roadX, roadY]
        self.PpMinMax = [roadX.min() ?? 0, roadY.min() ?? 0, roadX.max() ?? 0, roadY.max() ?? 0]
        
        return (roadType, road, roadScale, roadHeading)
    }
    
    public func savePathPixelLocalUrl(key: String, url: String) {
        print(getLocalTimeString() + " , (Olympus) Save \(key) Path-Pixel Local URL : \(url)")
        
        do {
            let key: String = "OlympusPathPixelLocalUrl_\(key)"
            UserDefaults.standard.set(url, forKey: key)
        }
    }
    
    public func loadPathPixelLocalUrl(key: String) -> (Bool, String?) {
        let keyPpLocalUrl: String = "OlympusPathPixelLocalUrl_\(key)"
        if let loadedPpLocalUrl: String = UserDefaults.standard.object(forKey: keyPpLocalUrl) as? String {
            return (true, loadedPpLocalUrl)
        } else {
            return (false, nil)
        }
    }
    
    public func savePathPixelVersion(key: String, ppVersion: String) {
        print(getLocalTimeString() + " , (Olympus) Save \(key) Path-Pixel Version : \(ppVersion)")
        do {
            let key: String = "OlympusPathPixelVersion_\(key)"
            UserDefaults.standard.set(ppVersion, forKey: key)
        }
    }
    
    public func loadPathPixel(sector_id: Int, PathPixelVersion: [String: String]) {
        for (key, value) in PathPixelVersion {
            // Cache를 통해 PP 버전을 확인
            let keyPpVersion: String = "OlympusPathPixelVersion_\(key)"
            if let loadedPpVersion: String = UserDefaults.standard.object(forKey: keyPpVersion) as? String {
                if value == loadedPpVersion {
                    // 만약 버전이 같다면 파일을 가져오기
                    let ppLocalUrl = loadPathPixelLocalUrl(key: key)
                    if (ppLocalUrl.0) {
                        do {
                            let contents = ppLocalUrl.1!
                            ( PpType[key], PpCoord[key], PpMagScale[key], PpHeading[key] ) = parseRoad(data: contents)
                            PpIsLoaded[key] = true
                        }
                    } else {
                        // 첫 시작과 동일하게 다운로드 받아오기
                        let building_n_level = key.split(separator: "_")
                        let ppUrl: String = CSV_URL + "/path-pixel/\(sector_id)/\(building_n_level[0])/\(building_n_level[1])/\(value)/\(OlympusConstants.OPERATING_SYSTEM).csv"
                        let urlComponents = URLComponents(string: ppUrl)
                        OlympusFileDownloader.shared.downloadCSVFile(from: (urlComponents?.url)!, fname: key, completion: { [self] url, error in
                            if error == nil {
                                do {
                                    let contents = try String(contentsOf: url!)
                                    ( PpType[key], PpCoord[key], PpMagScale[key], PpHeading[key] ) = parseRoad(data: contents)
                                    savePathPixelVersion(key: key, ppVersion: value)
                                    savePathPixelLocalUrl(key: key, url: contents)
                                    PpIsLoaded[key] = true
                                } catch {
                                    PpIsLoaded[key] = false
                                    print("Error reading file:", error.localizedDescription)
                                }
                            } else {
                                PpIsLoaded[key] = false
                            }
                        })
                    }
                } else {
                    // 만약 버전이 다르면 다운로드 받아오기
                    // 첫 시작과 동일하게 다운로드 받아오기
                    let building_n_level = key.split(separator: "_")
                    let ppUrl: String = CSV_URL + "/path-pixel/\(sector_id)/\(building_n_level[0])/\(building_n_level[1])/\(value)/\(OlympusConstants.OPERATING_SYSTEM).csv"
                    let urlComponents = URLComponents(string: ppUrl)
                    OlympusFileDownloader.shared.downloadCSVFile(from: (urlComponents?.url)!, fname: key, completion: { [self] url, error in
                        if error == nil {
                            do {
                                let contents = try String(contentsOf: url!)
                                ( PpType[key], PpCoord[key], PpMagScale[key], PpHeading[key] ) = parseRoad(data: contents)
                                savePathPixelVersion(key: key, ppVersion: value)
                                savePathPixelLocalUrl(key: key, url: contents)
                                PpIsLoaded[key] = true
                            } catch {
                                PpIsLoaded[key] = false
                                print("Error reading file:", error.localizedDescription)
                            }
                        } else {
                            PpIsLoaded[key] = false
                        }
                    })
                }
            } else {
                // 첫 시작이면 다운로드 받아오기
                if (!value.isEmpty) {
                    let building_n_level = key.split(separator: "_")
                    let ppUrl: String = CSV_URL + "/path-pixel/\(sector_id)/\(building_n_level[0])/\(building_n_level[1])/\(value)/\(OlympusConstants.OPERATING_SYSTEM).csv"
                    let urlComponents = URLComponents(string: ppUrl)
                    OlympusFileDownloader.shared.downloadCSVFile(from: (urlComponents?.url)!, fname: key, completion: { [self] url, error in
                        if error == nil {
                            do {
                                let contents = try String(contentsOf: url!)
                                print(key)
                                ( PpType[key], PpCoord[key], PpMagScale[key], PpHeading[key] ) = parseRoad(data: contents)
                                savePathPixelVersion(key: key, ppVersion: value)
                                savePathPixelLocalUrl(key: key, url: contents)
                                PpIsLoaded[key] = true
                            } catch {
                                PpIsLoaded[key] = false
                                print("Error reading file:", error.localizedDescription)
                            }
                        } else {
                            PpIsLoaded[key] = false
                        }
                    })
                }
            }
        }
    }
    
    public func pathMatching(building: String, level: String, x: Double, y: Double, heading: Double, isPast: Bool, HEADING_RANGE: Double, isUseHeading: Bool, pathType: Int, COORD_RANGE: Double) -> (isSuccess: Bool, xyhs: [Double]) {
        var isSuccess: Bool = false
        var xyhs: [Double] = [x, y, heading, 1.0]
        let levelCopy: String = removeLevelDirectionString(levelName: level)
        let key: String = "\(building)_\(levelCopy)"
        if (isPast) {
            isSuccess = true
            return (isSuccess, xyhs)
        }
        
        if (!(building.isEmpty) && !(level.isEmpty)) {
            guard let mainType: [Int] = self.PpType[key] else {
                return (isSuccess, xyhs)
            }
            guard let mainRoad: [[Double]] = self.PpCoord[key] else {
                return (isSuccess, xyhs)
            }
            
            guard let mainMagScale: [Double] = self.PpMagScale[key] else {
                return (isSuccess, xyhs)
            }
            
            guard let mainHeading: [String] = self.PpHeading[key] else {
                return (isSuccess, xyhs)
            }
            
            let pathhMatchingArea = self.checkInEntranceMatchingArea(x: x, y: y, building: building, level: levelCopy)
            
            var idshArray = [[Double]]()
            var idshArrayWhenFail = [[Double]]()
            var pathArray = [[Double]]()
            if (!mainRoad.isEmpty) {
                let roadX = mainRoad[0]
                let roadY = mainRoad[1]
                
                var xMin = x - COORD_RANGE
                var xMax = x + COORD_RANGE
                var yMin = y - COORD_RANGE
                var yMax = y + COORD_RANGE
                if (pathhMatchingArea.0) {
                    xMin = pathhMatchingArea.1[0]
                    yMin = pathhMatchingArea.1[1]
                    xMax = pathhMatchingArea.1[2]
                    yMax = pathhMatchingArea.1[3]
                }
                
                for i in 0..<roadX.count {
                    let xPath = roadX[i]
                    let yPath = roadY[i]
                    
                    let pathTypeLoaded = mainType[i]
                    if (pathType == 1) {
                        if (pathType != pathTypeLoaded) {
                            continue
                        }
                    }
                    // XY 범위 안에 있는 값 중에 검사
                    if (xPath >= xMin && xPath <= xMax) {
                        if (yPath >= yMin && yPath <= yMax) {
                            let index = Double(i)
                            let distance = sqrt(pow(x-xPath, 2) + pow(y-yPath, 2))
                            
                            let magScale = mainMagScale[i]
                            var idsh: [Double] = [index, distance, magScale, heading]
                            var path: [Double] = [xPath, yPath, 0, 0]
                            
                            idshArrayWhenFail.append(idsh)
                            
                            // Heading 사용
                            if (isUseHeading) {
                                let headingArray = mainHeading[i]
                                var isValidIdh: Bool = true
                                if (!headingArray.isEmpty) {
                                    let headingData = headingArray.components(separatedBy: ",")
                                    var diffHeading = [Double]()
                                    for j in 0..<headingData.count {
                                        if(!headingData[j].isEmpty) {
                                            let mapHeading = Double(headingData[j])!
                                            if (heading > 270 && (mapHeading >= 0 && mapHeading < 90)) {
                                                diffHeading.append(abs(heading - (mapHeading+360)))
                                            } else if (mapHeading > 270 && (heading >= 0 && heading < 90)) {
                                                diffHeading.append(abs(mapHeading - (heading+360)))
                                            } else {
                                                diffHeading.append(abs(heading - mapHeading))
                                            }
                                        }
                                    }
                                    
                                    if (!diffHeading.isEmpty) {
                                        let idxHeading = diffHeading.firstIndex(of: diffHeading.min()!)
                                        let minHeading = Double(headingData[idxHeading!])!
                                        idsh[3] = minHeading
                                        if (isUseHeading) {
                                            if (heading > 270 && (minHeading >= 0 && minHeading < 90)) {
                                                if (abs(minHeading+360-heading) >= HEADING_RANGE) {
                                                    isValidIdh = false
                                                }
                                            } else if (minHeading > 270 && (heading >= 0 && heading < 90)) {
                                                if (abs(heading+360-minHeading) >= HEADING_RANGE) {
                                                    isValidIdh = false
                                                }
                                            } else {
                                                if (abs(heading-minHeading) >= HEADING_RANGE) {
                                                    isValidIdh = false
                                                }
                                            }
                                        }
                                        path[2] = minHeading
                                        path[3] = 1
                                    }
                                }
                                
                                if (isValidIdh) {
                                    idshArray.append(idsh)
                                    pathArray.append(path)
                                }
                                
                                if (!idshArray.isEmpty) {
                                    let sortedIdsh = idshArray.sorted(by: {$0[1] < $1[1] })
                                    var index: Int = 0
                                    var correctedHeading: Double = heading
                                    var correctedScale = 1.0
                                    
                                    if (!sortedIdsh.isEmpty) {
                                        let minData: [Double] = sortedIdsh[0]
                                        index = Int(minData[0])
                                        if (isUseHeading) {
                                            correctedScale = minData[2]
                                            correctedHeading = minData[3]
                                        } else {
                                            correctedHeading = heading
                                        }
                                    }
                                    
                                    isSuccess = true
                                    
                                    if (correctedScale < 0.7) {
                                        correctedScale = 0.7
                                    }
                                    
                                    xyhs = [roadX[index], roadY[index], correctedHeading, correctedScale]
                                } else {
                                    let sortedIdsh = idshArrayWhenFail.sorted(by: {$0[1] < $1[1] })
                                    var index: Int = 0
                                    var correctedScale = 1.0
                                    
                                    if (!sortedIdsh.isEmpty) {
                                        let minData: [Double] = sortedIdsh[0]
                                        index = Int(minData[0])
                                        correctedScale = minData[2]
                                    }
                                    
                                    isSuccess = false
                                    
                                    if (correctedScale < 0.7) {
                                        correctedScale = 0.7
                                    }
                                    
                                    xyhs = [roadX[index], roadY[index], heading, correctedScale]
                                }
                            } else {
                                // Heading 미사용
                                idshArray.append(idsh)
                                pathArray.append(path)
                                if (!idshArray.isEmpty) {
                                    isSuccess = true
                                    
                                    let sortedIdsh = idshArray.sorted(by: {$0[1] < $1[1] })
                                    var index: Int = 0
                                    var correctedScale = 1.0
                                    
                                    if (!sortedIdsh.isEmpty) {
                                        let minData: [Double] = sortedIdsh[0]
                                        index = Int(minData[0])
                                        correctedScale = minData[2]
                                        
                                        if (correctedScale < 0.7) {
                                            correctedScale = 0.7
                                        }
                                        
                                        xyhs = [roadX[index], roadY[index], heading, correctedScale]
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        return (isSuccess, xyhs)
    }
    
    public func checkInEntranceMatchingArea(x: Double, y: Double, building: String, level: String) -> (Bool, [Double]) {
        var area = [Double]()
        
        let buildingName = building
        let levelName = removeLevelDirectionString(levelName: level)
        
        let key = "\(buildingName)_\(levelName)"
        guard let entranceMatchingArea: [[Double]] = self.EntranceMatchingArea[key] else {
            return (false, area)
        }
        
        for i in 0..<entranceMatchingArea.count {
            if (!entranceMatchingArea[i].isEmpty) {
                let xMin = entranceMatchingArea[i][0]
                let yMin = entranceMatchingArea[i][1]
                let xMax = entranceMatchingArea[i][2]
                let yMax = entranceMatchingArea[i][3]
                
                if (x >= xMin && x <= xMax) {
                    if (y >= yMin && y <= yMax) {
                        area = entranceMatchingArea[i]
                        return (true, area)
                    }
                }
            }
        }
        
        return (false, area)
    }
    
    public func getPathMatchingHeadings(building: String, level: String, x: Double, y: Double, heading: Double, PADDING_VALUE: Double, mode: String) -> [Double] {
        var headings: [Double] = []
        let levelCopy: String = removeLevelDirectionString(levelName: level)
        let key: String = "\(building)_\(levelCopy)"
        
        if (!(building.isEmpty) && !(level.isEmpty)) {
            guard let mainType: [Int] = self.PpType[key] else {
                return headings
            }
            
            guard let mainRoad: [[Double]] = self.PpCoord[key] else {
                return headings
            }
            
            guard let mainHeading: [String] = self.PpHeading[key] else {
                return headings
            }
            
            if (!mainRoad.isEmpty) {
                let roadX = mainRoad[0]
                let roadY = mainRoad[1]
                
                let xMin = x - PADDING_VALUE
                let xMax = x + PADDING_VALUE
                let yMin = y - PADDING_VALUE
                let yMax = y + PADDING_VALUE
                
                for i in 0..<roadX.count {
                    let xPath = roadX[i]
                    let yPath = roadY[i]
                    
                    let pathType = mainType[i]
                    
                    if (mode == "dr") {
                        if (pathType != 1) {
                            continue
                        }
                    }
                    
                    if (xPath >= xMin && xPath <= xMax) {
                        if (yPath >= yMin && yPath <= yMax) {
                            let headingArray = mainHeading[i]
                            if (!headingArray.isEmpty) {
                                let headingData = headingArray.components(separatedBy: ",")
                                for j in 0..<headingData.count {
                                    if (!headingData[j].isEmpty) {
                                        let value = Double(headingData[j])!
                                        if (!headings.contains(value)) {
                                            headings.append(value)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        return headings
    }
}
