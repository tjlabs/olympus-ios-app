public class OlympusPathMatchingCalculator {
    static var shared = OlympusPathMatchingCalculator()
    
    public var PpVersion = [String: String]()
    public var PpType = [String: [Int]]()
    public var PpNode = [String: [Int]]()
    public var PpCoord = [String: [[Double]]]()
    public var PpMinMax = [Double]()
    public var PpMagScale = [String: [Double]]()
    public var PpHeading = [String: [String]]()
    
    public var PpIsLoaded = [String: Bool]()
    
    // Path-Matching Areas
    public var EntranceArea = [String: [[Double]]]()
    public var EntranceMatchingArea = [String: [[Double]]]()
    public var LevelChangeArea = [String: [[Double]]]()
    
    var passedNode: Int = -1
    var passedNodeCoord: [Double] = [0, 0]
    var passedNodeHeadings = [Double]()
    var distFromNode: Double = -1
    var linkCoord: [Double] = [0, 0]
    var linkDirections = [Double]()
    
    init() {
        
    }
    
    public func initialize() {
        self.passedNode = -1
        self.passedNodeCoord = [0, 0]
        self.passedNodeHeadings = [Double]()
        self.distFromNode = -1
        self.linkCoord = [0, 0]
        self.linkDirections = [Double]()
    }
    
    public func parseRoad(data: String) -> ([Int], [Int], [[Double]], [Double], [String] ) {
        var roadType = [Int]()
        var roadNode = [Int]()
        var road = [[Double]]()
        var roadScale = [Double]()
        var roadHeading = [String]()
        
        var roadX = [Double]()
        var roadY = [Double]()
        
        let roadString = data.components(separatedBy: .newlines)
        for i in 0..<roadString.count {
            if (roadString[i] != "") {
                let lineString = roadString[i]
                let lineData = roadString[i].components(separatedBy: ",")
                
                roadType.append(Int(Double(lineData[0])!))
                roadNode.append(Int(Double(lineData[1])!))
                roadX.append(Double(lineData[2])!)
                roadY.append(Double(lineData[3])!)
                roadScale.append(Double(lineData[4])!)
                
                let pattern = "\\[[^\\]]+\\]"
                guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
                    print("Invalid regular expression pattern")
                    exit(1)
                }
                let matches = regex.matches(in: lineString, options: [], range: NSRange(location: 0, length: lineString.utf16.count))
                let matchedStrings = matches.map { match -> String in
                    let range = Range(match.range, in: lineString)!
                    return String(lineString[range])
                }
                
                var headingValues = ""
                if (!matchedStrings.isEmpty) {
                    let headingListString = matchedStrings[0]
                    let headingArray = headingListString
                        .replacingOccurrences(of: "[", with: "")
                        .replacingOccurrences(of: "]", with: "")
                        .components(separatedBy: ",")
                        .compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
                    
                    for j in 0..<headingArray.count {
                        headingValues.append(String(headingArray[j]))
                        if (j < (headingArray.count-1)) {
                            headingValues.append(",")
                        }
                    }
                }
                roadHeading.append(headingValues)
            }
        }
        road = [roadX, roadY]
        self.PpMinMax = [roadX.min() ?? 0, roadY.min() ?? 0, roadX.max() ?? 0, roadY.max() ?? 0]
        
        return (roadType, roadNode, road, roadScale, roadHeading)
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
                            ( PpType[key], PpNode[key], PpCoord[key], PpMagScale[key], PpHeading[key] ) = parseRoad(data: contents)
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
                                    ( PpType[key], PpNode[key],PpCoord[key], PpMagScale[key], PpHeading[key] ) = parseRoad(data: contents)
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
                                ( PpType[key], PpNode[key], PpCoord[key], PpMagScale[key], PpHeading[key] ) = parseRoad(data: contents)
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
                                ( PpType[key], PpNode[key], PpCoord[key], PpMagScale[key], PpHeading[key] ) = parseRoad(data: contents)
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
        
        xyhs[2] = compensateHeading(heading: xyhs[2])
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
    
    public func pathTrajectoryMatching(building: String, level: String, x: Double, y: Double, heading: Double, pastResult: FineLocationTrackingResult, unitDRInfoBuffer: [UnitDRInfo], HEADING_RANGE: Double, pathType: Int, mode: String, PADDING_VALUE: Double) -> (isSuccess: Bool, xyd: [Double], matchedTraj: [[Double]], inputTraj: [[Double]]) {
        let pastX = pastResult.x
        let pastY = pastResult.y
        
        var isSuccess: Bool = false
        var xyd: [Double] = [x, y, 50]
        var matchedTraj = [[Double]]()
        var inputTraj = [[Double]]()
        
        let levelCopy: String = removeLevelDirectionString(levelName: level)
        let key: String = "\(building)_\(levelCopy)"
        
        if (!(building.isEmpty) && !(level.isEmpty)) {
            guard let mainType: [Int] = self.PpType[key] else {
                return (isSuccess, xyd, matchedTraj, inputTraj)
            }
            guard let mainRoad: [[Double]] = self.PpCoord[key] else {
                return (isSuccess, xyd, matchedTraj, inputTraj)
            }
            
            if (!mainRoad.isEmpty) {
                let roadX = mainRoad[0]
                let roadY = mainRoad[1]
                
                let xMin = x - PADDING_VALUE
                let xMax = x + PADDING_VALUE
                let yMin = y - PADDING_VALUE
                let yMax = y + PADDING_VALUE
                
                var ppXydArray = [[Double]]()
                var minDistanceCoord = [Double]()
                
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
                            var passedPp = [[Double]]()
                            var distanceSum: Double = 0
                            
                            let headingCompensation: Double = heading - unitDRInfoBuffer[unitDRInfoBuffer.count-1].heading
                            var headingBuffer: [Double] = []
                            for i in 0..<unitDRInfoBuffer.count {
                                let compensatedHeading = compensateHeading(heading: unitDRInfoBuffer[i].heading + headingCompensation - 180)
                                headingBuffer.append(compensatedHeading)
                            }
                            
                            var xyFromHead: [Double] = [xPath, yPath]
                            var xyOriginal: [Double] = [xPath, yPath]
                            let firstXyd = calDistacneFromNearestPp(coord: xyFromHead, passedPp: passedPp, mainRoad: mainRoad, mainType: mainType, pathType: pathType, PADDING_VALUE: PADDING_VALUE)
                            passedPp.append(xyFromHead)
                            
                            var xydArray: [[Double]] = [firstXyd]
                            distanceSum += firstXyd[2]
                            
                            var trajectoryFromHead = [[Double]]()
                            var trajectoryOriginal = [[Double]]()
                            trajectoryFromHead.append(xyFromHead)
                            trajectoryOriginal.append(xyOriginal)
                            for i in (1..<unitDRInfoBuffer.count).reversed() {
                                let headAngle = headingBuffer[i]
                                xyOriginal[0] = xyOriginal[0] + unitDRInfoBuffer[i].length*cos(headAngle*OlympusConstants.D2R)
                                xyOriginal[1] = xyOriginal[1] + unitDRInfoBuffer[i].length*sin(headAngle*OlympusConstants.D2R)
                                trajectoryOriginal.append(xyOriginal)
                                if (mode == OlympusConstants.MODE_PDR) {
                                    if (i%2 == 0) {
                                        let propagatedX = xyFromHead[0] + unitDRInfoBuffer[i].length*cos(headAngle*OlympusConstants.D2R)
                                        let propagatedY = xyFromHead[1] + unitDRInfoBuffer[i].length*sin(headAngle*OlympusConstants.D2R)
                                        let calculatedXyd = calDistacneFromNearestPp(coord: [propagatedX, propagatedY], passedPp: passedPp, mainRoad: mainRoad, mainType: mainType, pathType: pathType, PADDING_VALUE: PADDING_VALUE)
                                        
                                        xyFromHead[0] = calculatedXyd[0]
                                        xyFromHead[1] = calculatedXyd[1]
                                        xydArray.append(calculatedXyd)
                                        distanceSum += calculatedXyd[2]
                                        trajectoryFromHead.append(xyFromHead)
                                        passedPp.append(xyFromHead)
                                    } else {
                                        let propagatedX = xyFromHead[0] + unitDRInfoBuffer[i].length*cos(headAngle*OlympusConstants.D2R)
                                        let propagatedY = xyFromHead[1] + unitDRInfoBuffer[i].length*sin(headAngle*OlympusConstants.D2R)
                                        let calculatedXyd = calDistacneFromNearestPp(coord: [propagatedX, propagatedY], passedPp: passedPp, mainRoad: mainRoad, mainType: mainType, pathType: pathType, PADDING_VALUE: PADDING_VALUE)
                                        
                                        xyFromHead[0] = propagatedX
                                        xyFromHead[1] = propagatedY
                                        xydArray.append(calculatedXyd)
                                        distanceSum += calculatedXyd[2]
                                        trajectoryFromHead.append(xyFromHead)
                                        passedPp.append(xyFromHead)
                                    }
                                } else {
                                    let propagatedX = xyFromHead[0] + unitDRInfoBuffer[i].length*cos(headAngle*OlympusConstants.D2R)
                                    let propagatedY = xyFromHead[1] + unitDRInfoBuffer[i].length*sin(headAngle*OlympusConstants.D2R)
                                    let calculatedXyd = calDistacneFromNearestPp(coord: [propagatedX, propagatedY], passedPp: passedPp, mainRoad: mainRoad, mainType: mainType, pathType: pathType, PADDING_VALUE: PADDING_VALUE)
                                    
                                    xyFromHead[0] = calculatedXyd[0]
                                    xyFromHead[1] = calculatedXyd[1]
                                    xydArray.append(calculatedXyd)
                                    distanceSum += calculatedXyd[2]
                                    trajectoryFromHead.append(xyFromHead)
                                    passedPp.append(xyFromHead)
                                }
                            }
                            
                            let distWithPast = sqrt((pastX - xPath)*(pastX - xPath) + (pastY - yPath)*(pastY - yPath))
                            ppXydArray.append([xPath, yPath, distanceSum, distWithPast])
                            
                            if (minDistanceCoord.isEmpty) {
                                minDistanceCoord = [xPath, yPath, distanceSum, distWithPast]
                                matchedTraj = trajectoryFromHead
                                inputTraj = trajectoryOriginal
                            } else {
                                let distanceCurrent = distanceSum
                                let distancePast = minDistanceCoord[2]
                                if (distanceCurrent < distancePast && distWithPast <= 3) {
                                    minDistanceCoord = [xPath, yPath, distanceSum, distWithPast]
                                    matchedTraj = trajectoryFromHead
                                    inputTraj = trajectoryOriginal
                                }
                            }
                        }
                    }
                }
                
                if (!minDistanceCoord.isEmpty) {
                    if (minDistanceCoord[2] <= 15 && minDistanceCoord[3] <= 5) {
                        isSuccess = true
                    } else {
                        isSuccess = false
                    }
                    xyd = minDistanceCoord
                }
            }
        }
        
        return (isSuccess, xyd, matchedTraj, inputTraj)
    }
    
    public func updateNodeAndLinkInfo(currentResult: FineLocationTrackingFromServer, pastResult: FineLocationTrackingFromServer, pathType: Int) {
        let diffX = abs(currentResult.x - pastResult.x)
        let diffY = abs(currentResult.y - pastResult.y)
        
        let x = currentResult.x
        let y = currentResult.y
        
        let building = currentResult.building_name
        let level = removeLevelDirectionString(levelName: currentResult.level_name)
        
        let PADDING_VALUE = OlympusConstants.COORD_RANGE_LARGE
        
        let key: String = "\(building)_\(level)"
        if (diffX != 0 || diffY != 0) {
            if (!(building.isEmpty) && !(level.isEmpty)) {
                guard let mainType: [Int] = self.PpType[key] else { return }
                guard let mainRoad: [[Double]] = self.PpCoord[key] else { return }
                guard let mainHeading: [String] = self.PpHeading[key] else { return }
                guard let mainNode: [Int] = self.PpNode[key] else { return }
                
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
                        let node = mainNode[i]
                        let headingArray = mainHeading[i]
                        
                        let candidates = [[pastResult.x, currentResult.y], [currentResult.x, pastResult.y]]
                        
                        let pathTypeLoaded = mainType[i]
                        if (pathType == 1) {
                            if (pathType != pathTypeLoaded) {
                                continue
                            }
                        }
                        
                        // XY 범위 안에 있는 값 중에 검사
                        if (xPath >= xMin && xPath <= xMax) {
                            if (yPath >= yMin && yPath <= yMax) {
                                if (xPath == x && yPath == y) {
                                    var ppHeadingValues = [Double]()
                                    let headingData = headingArray.components(separatedBy: ",")
                                    for j in 0..<headingData.count {
                                        if(!headingData[j].isEmpty) {
                                            let mapHeading = Double(headingData[j])!
                                            ppHeadingValues.append(mapHeading)
                                        }
                                    }
                                    self.linkCoord = [xPath, yPath]
                                    self.linkDirections = ppHeadingValues
                                    if (node != 0) {
                                        self.passedNode = node
                                        self.passedNodeCoord = [xPath, yPath]
                                        self.passedNodeHeadings = ppHeadingValues
                                        self.distFromNode = sqrt((xPath-x)*(xPath-x) + (yPath-y)*(yPath-y))
        //                                print("Node Find (Normal) : passedNode = \(self.passedNode) // dist = \(self.distFromNode)")
                                    }
                                } else {
                                    for j in 0..<candidates.count {
                                        let coordXy = candidates[j]
                                        if (xPath == coordXy[0] && yPath == coordXy[1] && node != 0) {
                                            self.passedNode = node
                                            self.passedNodeCoord = [xPath, yPath]
                                            var ppHeadingValues = [Double]()
                                            let headingData = headingArray.components(separatedBy: ",")
                                            for j in 0..<headingData.count {
                                                if(!headingData[j].isEmpty) {
                                                    let mapHeading = Double(headingData[j])!
                                                    ppHeadingValues.append(mapHeading)
                                                }
                                            }
                                            self.passedNodeHeadings = ppHeadingValues
                                            self.distFromNode = sqrt((xPath-x)*(xPath-x) + (yPath-y)*(yPath-y))
        //                                    print("Node Find : passedNode (Jump) = \(self.passedNode) // dist = \(self.distFromNode)")
                                        }
                                    }
                                }
                            }
                        }

                    }
                }
                
            }
        }
    }
    
    public func getNodeCandidates(fltResult: FineLocationTrackingFromServer, pathType: Int, isBadCaseInStableMode: Bool) -> [Int] {
        var nodeCandidates = [Int]()
        nodeCandidates.append(passedNode)
        if (!isBadCaseInStableMode) {
            return nodeCandidates
        }
        let heading = fltResult.absolute_heading
        let nodeCoord = passedNodeCoord
        let nodeHeadings = passedNodeHeadings
        print("(Node Check) User Heading = \(fltResult.x) , \(fltResult.y) , \(heading)")
        print("(Node Check) Passed Node (Num) = \(self.passedNode)")
        print("(Node Check) Passed Node (Heading) = \(nodeHeadings)")
        
        var diffHeading = [Double]()
        var candidateDirections = [Double]()
        for mapHeading in nodeHeadings {
            var diffValue: Double = 0
            if (heading > 270 && (mapHeading >= 0 && mapHeading < 90)) {
                diffValue = abs(heading - (mapHeading+360))
            } else if (mapHeading > 270 && (heading >= 0 && heading < 90)) {
                diffValue = abs(mapHeading - (heading+360))
            } else {
                diffValue = abs(heading - mapHeading)
            }
            diffHeading.append(diffValue)
            
            let MARGIN: Double = 30
            
            if !(diffValue <= MARGIN || (diffValue >= 180-MARGIN && diffValue <= 180+MARGIN)) {
                candidateDirections.append(mapHeading)
            }
        }
        print("(Node Check) Passed Node candidateDirections = \(candidateDirections)")
        
        let PIXEL_LENGTH: Double = 1.0
        let PIXELS_TO_CHECK: Int = 10
        
        if (!candidateDirections.isEmpty) {
            for direction in candidateDirections {
                var x: Double = nodeCoord[0]
                var y: Double = nodeCoord[1]
                for _ in 0..<PIXELS_TO_CHECK {
                    x += PIXEL_LENGTH*cos(direction*OlympusConstants.D2R)
                    y += PIXEL_LENGTH*sin(direction*OlympusConstants.D2R)
                    let matchedNodeResult = getMatchedNodeWithCoord(fltResult: fltResult, originCoord: nodeCoord, coordToCheck: [x, y], pathType: pathType, PIXELS_TO_CHECK: PIXELS_TO_CHECK)
                    if (matchedNodeResult.0) {
                        break
                    } else {
                        if (matchedNodeResult.1 != -1) {
                            nodeCandidates.append(matchedNodeResult.1)
                        }
                    }
                }
            }
        }
        
        print("(Node Check) Passed Node (Node Candidates) = \(nodeCandidates)")
        print("(Node Check) -----------------------------------------------")
        return nodeCandidates
    }
    
    private func getMatchedNodeWithCoord(fltResult: FineLocationTrackingFromServer, originCoord: [Double], coordToCheck: [Double], pathType: Int, PIXELS_TO_CHECK: Int) -> (Bool, Int) {
        let building = fltResult.building_name
        let level = fltResult.level_name
        let levelCopy: String = removeLevelDirectionString(levelName: level)
        let x = coordToCheck[0]
        let y = coordToCheck[1]
        let PADDING_VALUE = Double(PIXELS_TO_CHECK)
        let key: String = "\(building)_\(levelCopy)"
        
        let isPpEndPoint: Bool = true
        let matchedNode: Int = -1
        if (!(building.isEmpty) && !(level.isEmpty)) {
            guard let mainType: [Int] = self.PpType[key] else { return (isPpEndPoint, matchedNode) }
            guard let mainRoad: [[Double]] = self.PpCoord[key] else { return (isPpEndPoint, matchedNode) }
            guard let mainNode: [Int] = self.PpNode[key] else { return (isPpEndPoint, matchedNode) }
            
            if (!mainRoad.isEmpty) {
                let roadX = mainRoad[0]
                let roadY = mainRoad[1]
                
                let xMin = originCoord[0] - PADDING_VALUE
                let xMax = originCoord[0] + PADDING_VALUE
                let yMin = originCoord[1] - PADDING_VALUE
                let yMax = originCoord[1] + PADDING_VALUE
                
                print("(Node Check) xy range = \(xMin) , \(xMax) , \(yMin) , \(yMax)")
                
                for i in 0..<roadX.count {
                    let xPath = roadX[i]
                    let yPath = roadY[i]
                    let node = mainNode[i]
                    
                    let pathTypeLoaded = mainType[i]
                    if (pathType == 1) {
                        if (pathType != pathTypeLoaded) {
                            continue
                        }
                    }
                    
                    // XY 범위 안에 있는 값 중에 검사
                    if (xPath >= xMin && xPath <= xMax) {
                        if (yPath >= yMin && yPath <= yMax) {
                            if (x == xPath && y == yPath) {
                                if (node == 0) {
                                    return (false, matchedNode)
                                } else {
                                    return (false, node)
                                }
                            }
                        }
                    }
                }
            }
        }
        return (isPpEndPoint, matchedNode)
    }
    
    public func getTimeUpdateLimitation() -> (limitType: LimitationType, limitValues: [Double]) {
        var limitType: LimitationType = .NO_LIMIT
        var limitValues: [Double] = [0, 0]
        
        let coordX = linkCoord[0]
        let coordY = linkCoord[1]
        
        let directions = linkDirections
        
        print("(Link Info) : coord = \(coordX) , \(coordY) // directions = \(directions)")
        
        if directions.count == 2 {
            if (directions[0] == 0 && directions[1] == 180) {
                limitType = .Y_LIMIT
                limitValues = [coordY - 0.45, coordY + 0.45]
                print("(Link Info) : Y Limit // values = \(limitValues)")
            } else if (directions[0] == 90 && directions[1] == 270) {
                limitType = .X_LIMIT
                limitValues = [coordX - 0.45, coordX + 0.45]
                print("(Link Info) : X Limit // values = \(limitValues)")
            }
        }
        
        return (limitType, limitValues)
    }
    
    private func calDistacneFromNearestPp(coord: [Double], passedPp: [[Double]], mainRoad: [[Double]], mainType: [Int], pathType: Int, PADDING_VALUE: Double) -> [Double] {
        let x = coord[0]
        let y = coord[1]
        
        var xyd: [Double] = [x, y, 50]
        
        var xydArray = [[Double]]()
        
        let roadX = mainRoad[0]
        let roadY = mainRoad[1]
        
        let xMin = x - PADDING_VALUE
        let xMax = x + PADDING_VALUE
        let yMin = y - PADDING_VALUE
        let yMax = y + PADDING_VALUE
        
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
            if (!passedPp.isEmpty) {
                let isContain: Bool = containsArray(passedPp, [xPath, yPath])
                if (isContain) {
                    continue
                }
            }
            
            if (xPath >= xMin && xPath <= xMax) {
                if (yPath >= yMin && yPath <= yMax) {
                    let distance = sqrt(pow(x-xPath, 2) + pow(y-yPath, 2))
                    let xyd: [Double] = [xPath, yPath, distance]
                    
                    xydArray.append(xyd)
                }
            }
        }
        
        if (!xydArray.isEmpty) {
            let sortedXyd = xydArray.sorted(by: {$0[2] < $1[2] })
            if (!sortedXyd.isEmpty) {
                let minData: [Double] = sortedXyd[0]
                xyd = minData
            }
        }
        return xyd
    }
}
