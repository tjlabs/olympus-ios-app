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
    var passedNodeMatchedIndex: Int = -1
    var passedNodeCoord: [Double] = [0, 0]
    var passedNodeHeadings = [Double]()
    var passedNodeInfoBuffer = [PassedNodeInfo]()
    var isNeedClearBuffer: Bool = false
    var anchorNode = PassedNodeInfo(nodeNumber: -1, nodeCoord: [], nodeHeadings: [], matchedIndex: -1, userHeading: 0)
    var anchorSection: Int = -1
    var distFromNode: Double = -1
    
    var linkCoord: [Double] = [0, 0]
    var linkDirections = [Double]()
    var isInNode: Bool = false
    
    var pathTrajMatchingArea: [[Double]] = [[0, 0]]
    
    init() {
        
    }
    
    private struct Point {
        var x: Double
        var y: Double
        var direction: Double
    }
    
    public func initialize() {
        self.passedNode = -1
        self.passedNodeMatchedIndex = -1
        self.passedNodeCoord = [0, 0]
        self.passedNodeHeadings = [Double]()
        self.passedNodeInfoBuffer = [PassedNodeInfo]()
        self.isNeedClearBuffer = false
        self.anchorNode = PassedNodeInfo(nodeNumber: -1, nodeCoord: [], nodeHeadings: [], matchedIndex: -1, userHeading: 0)
        self.anchorSection = -1
        self.distFromNode = -1
        
        self.linkCoord = [0, 0]
        self.linkDirections = [Double]()
        self.isInNode = false
    }
    
    public func initPassedNodeInfo() {
        self.passedNode = -1
        self.passedNodeMatchedIndex = -1
        self.passedNodeCoord = [0, 0]
        self.passedNodeHeadings = [Double]()
        self.passedNodeInfoBuffer = [PassedNodeInfo]()
        self.isNeedClearBuffer = false
        self.anchorNode = PassedNodeInfo(nodeNumber: -1, nodeCoord: [], nodeHeadings: [], matchedIndex: -1, userHeading: 0)
        self.anchorSection = -1
        self.distFromNode = -1
        
        self.linkCoord = [0, 0]
        self.linkDirections = [Double]()
        self.isInNode = false
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
    
    public func pathMatching(building: String, level: String, x: Double, y: Double, heading: Double, HEADING_RANGE: Double, isUseHeading: Bool, pathType: Int, PADDING_VALUES: [Double]) -> (isSuccess: Bool, xyhs: [Double], bestHeading: Double) {
        var isSuccess: Bool = false
        var xyhs: [Double] = [x, y, heading, 1.0]
        var bestHeading: Double = heading
        
        let levelCopy: String = removeLevelDirectionString(levelName: level)
        let key: String = "\(building)_\(levelCopy)"
        
        if (!(building.isEmpty) && !(level.isEmpty)) {
            guard let mainType: [Int] = self.PpType[key] else {
                return (isSuccess, xyhs, bestHeading)
            }
            guard let mainRoad: [[Double]] = self.PpCoord[key] else {
                return (isSuccess, xyhs, bestHeading)
            }
            
            guard let mainMagScale: [Double] = self.PpMagScale[key] else {
                return (isSuccess, xyhs, bestHeading)
            }
            
            guard let mainHeading: [String] = self.PpHeading[key] else {
                return (isSuccess, xyhs, bestHeading)
            }
            
            let pathhMatchingArea = self.checkInEntranceMatchingArea(x: x, y: y, building: building, level: levelCopy)
            
            var idshArray = [[Double]]()
            var idshArrayWhenFail = [[Double]]()
            var pathArray = [[Double]]()
            
            var linkDirections = [Double]()
            if (!mainRoad.isEmpty) {
                let roadX = mainRoad[0]
                let roadY = mainRoad[1]
                
                var xMin = x - PADDING_VALUES[0]
                var xMax = x + PADDING_VALUES[2]
                var yMin = y - PADDING_VALUES[1]
                var yMax = y + PADDING_VALUES[3]
//                print(getLocalTimeString() + " , (Olympus) pathMatching : x = \(x) // y = \(y) // heading = \(heading) // ranage = [\(xMin) , \(xMax) , \(yMin) , \(yMax)]")
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
                                            if (xPath == x && yPath == y) {
                                                linkDirections.append(mapHeading)
                                            }
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
                                    bestHeading = correctedHeading
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
                                    
                                    let headingArray = mainHeading[index]
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
                                            bestHeading = minHeading
                                        }
                                    }
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
                                        
                                        let headingArray = mainHeading[index]
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
                                                bestHeading = minHeading
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
        
        xyhs[2] = compensateHeading(heading: xyhs[2])
        return (isSuccess, xyhs, bestHeading)
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
    
    public func getPathMatchingHeadings(building: String, level: String, x: Double, y: Double, PADDING_VALUE: Double, mode: String) -> [Double] {
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
    
    
    public func updateNodeAndLinkInfo(uvdIndex: Int, currentResult: FineLocationTrackingFromServer, currentResultHeading: Double, pastResult: FineLocationTrackingFromServer, pastResultHeading: Double, pathType: Int, updateType: UpdateNodeLinkType) {
        let diffX = abs(currentResult.x - pastResult.x)
        let diffY = abs(currentResult.y - pastResult.y)
        
        let x = currentResult.x
        let y = currentResult.y
        
        let building = currentResult.building_name
        let level = removeLevelDirectionString(levelName: currentResult.level_name)
        
        let PADDING_VALUE = OlympusConstants.PADDING_VALUE_LARGE
        var isNodePassed: Bool = false
        var nodeCandidates = [Int]()
        var xCandidates = [Double]()
        var yCandidates = [Double]()
        var headingCandidates = [String]()
        
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
                    
                    let linkDir = linkDirections
                    
                    if (updateType == .PHASE_5) {
                        // 현재 위치에서부터 반대 방향으로 N m 까지 확인해서 가장 가까운 Node 찾기
                        for i in 0..<roadX.count {
                            let xPath = roadX[i]
                            let yPath = roadY[i]
                            let node = mainNode[i]
                            let headingArray = mainHeading[i]

                            let pathTypeLoaded = mainType[i]
                            if (pathType == 1) {
                                if (pathType != pathTypeLoaded) {
                                    continue
                                }
                            }
                            
                            if (xPath == x && yPath == y) {
                                var ppHeadingValues = [Double]()
                                let headingData = headingArray.components(separatedBy: ",")
                                for j in 0..<headingData.count {
                                    if(!headingData[j].isEmpty) {
                                        let mapHeading = Double(headingData[j])!
                                        ppHeadingValues.append(mapHeading)
                                    }
                                }
                                
                                var oppositeHeading: Double = compensateHeading(heading: currentResultHeading-180)
                                var minDiffValue: Double = 360
                                if (!linkDir.isEmpty) {
                                    for mapHeading in linkDir {
                                        var diffValue: Double = 0
                                        
                                        if (currentResultHeading > 270 && (mapHeading >= 0 && mapHeading < 90)) {
                                            diffValue = abs(currentResultHeading - (mapHeading+360))
                                        } else if (mapHeading > 270 && (currentResultHeading >= 0 && currentResultHeading < 90)) {
                                            diffValue = abs(mapHeading - (currentResultHeading+360))
                                        } else {
                                            diffValue = abs(currentResultHeading - mapHeading)
                                        }
                                        
                                        if diffValue < minDiffValue {
                                            minDiffValue = diffValue
                                            oppositeHeading = compensateHeading(heading: mapHeading-180)
                                        }
                                    }
                                }
                                
                                let checkLength: Double = 10
                                let PIXELS_TO_CHECK = Int(checkLength)
                                
                                var paddingValues = [Double] (repeating: Double(PIXELS_TO_CHECK), count: 4)
                                if (oppositeHeading == 0) {
                                    paddingValues = [0, checkLength, 1, 1]
                                } else if (oppositeHeading == 90) {
                                    paddingValues = [1, 1, 0, checkLength]
                                } else if (oppositeHeading == 180) {
                                    paddingValues = [checkLength, 0, 1, 1]
                                } else if (oppositeHeading == 270) {
                                    paddingValues = [1, 1, checkLength, 0]
                                }
                                
                                var xToCheck: Double = x
                                var yToCheck: Double = y
                                for p in 0..<PIXELS_TO_CHECK {
                                    xToCheck += cos(oppositeHeading*OlympusConstants.D2R)
                                    yToCheck += sin(oppositeHeading*OlympusConstants.D2R)
                                    let matchedNodeResult = getMatchedNodeWithCoord(fltResult: currentResult, originCoord: [x, y], coordToCheck: [xToCheck, yToCheck], pathType: pathType, PADDING_VALUES: paddingValues)
                                    if (matchedNodeResult.0) {
                                        break
                                    } else {
                                        if (matchedNodeResult.1 != -1) {
                                            // Opposite 방향으로 Node 찾음
                                            var indexScale = 2
                                            if (pathType == 1) { indexScale = 1 }
                                            self.passedNode = matchedNodeResult.1
                                            self.passedNodeMatchedIndex = uvdIndex - ((p+1)*indexScale)
                                            self.passedNodeCoord = [xPath, yPath]
                                            self.passedNodeHeadings = ppHeadingValues
                                            
                                            print(getLocalTimeString() + " , (Olympus) Node Find : passedNode (Phase5 (1)) = \(matchedNodeResult.1) // dist = none // index = \(passedNodeMatchedIndex) // heading = \(currentResultHeading)")
                                            controlPassedNodeInfo(passedNodeInfo: PassedNodeInfo(nodeNumber: self.passedNode, nodeCoord: self.passedNodeCoord, nodeHeadings: self.passedNodeHeadings, matchedIndex: self.passedNodeMatchedIndex, userHeading: currentResultHeading))
                                            break
                                        }
                                    }
                                }
                                
                                if (node != 0) {
                                    self.isInNode = true
                                    self.passedNode = node
                                    self.passedNodeMatchedIndex = uvdIndex
                                    self.passedNodeCoord = [xPath, yPath]
                                    self.passedNodeHeadings = ppHeadingValues
                                    self.distFromNode = sqrt((xPath-x)*(xPath-x) + (yPath-y)*(yPath-y))
                                    print(getLocalTimeString() + " , (Olympus) Node Find : passedNode (Phase5 (2)) = \(self.passedNode) // dist = \(self.distFromNode) // index = \(passedNodeMatchedIndex) // heading = \(currentResultHeading)")
                                    controlPassedNodeInfo(passedNodeInfo: PassedNodeInfo(nodeNumber: self.passedNode, nodeCoord: self.passedNodeCoord, nodeHeadings: self.passedNodeHeadings, matchedIndex: self.passedNodeMatchedIndex, userHeading: currentResultHeading))
                                } else {
                                    self.isInNode = false
                                    self.linkCoord = [xPath, yPath]
                                    self.linkDirections = ppHeadingValues
                                }
                            }
                        }
                    } else if (updateType == .PATH_TRAJ_MATCHING) {
                        var passedNodeInfoBuffer = [PassedNodeInfo]()
                        for i in 0..<roadX.count {
                            let xPath = roadX[i]
                            let yPath = roadY[i]
                            let node = mainNode[i]
                            let headingArray = mainHeading[i]
                            
                            let pathTypeLoaded = mainType[i]
                            if (pathType == 1) {
                                if (pathType != pathTypeLoaded) {
                                    continue
                                }
                            }
                            
                            if (xPath >= xMin && xPath <= xMax) {
                                if (yPath >= yMin && yPath <= yMax) {
                                    if (node != 0) {
                                        nodeCandidates.append(node)
                                        xCandidates.append(xPath)
                                        yCandidates.append(yPath)
                                        headingCandidates.append(headingArray)
                                    }
                                    
                                    if (xPath == x && yPath == y) {
                                        var ppHeadingValues = [Double]()
                                        let headingData = headingArray.components(separatedBy: ",")
                                        for j in 0..<headingData.count {
                                            if(!headingData[j].isEmpty) {
                                                let mapHeading = Double(headingData[j])!
                                                ppHeadingValues.append(mapHeading)
                                            }
                                        }
                                        if (node != 0) {
                                            self.linkCoord = [xPath, yPath]
                                            
                                            var newLinkDir = [Double]()
                                            for ppHeading in ppHeadingValues {
                                                if !linkDirections.contains(ppHeading) {
                                                    newLinkDir.append(ppHeading)
                                                }
                                            }
                                            if (!newLinkDir.isEmpty) {
                                                self.linkDirections = newLinkDir
                                            } else {
                                                self.linkDirections = ppHeadingValues
                                            }

                                            self.isInNode = true
                                            self.passedNode = node
                                            self.passedNodeMatchedIndex = uvdIndex
                                            self.passedNodeCoord = [xPath, yPath]
                                            self.passedNodeHeadings = ppHeadingValues
                                            self.distFromNode = sqrt((xPath-x)*(xPath-x) + (yPath-y)*(yPath-y))
//                                            print(getLocalTimeString() + " , (Olympus) Node Find : passedNode (PATH_TRAJ_MATCHING (2)) = \(self.passedNode) // dist = \(self.distFromNode) // index = \(passedNodeMatchedIndex) // heading = \(currentResultHeading)")
                                            
                                            let passedNodeInfo = PassedNodeInfo(nodeNumber: node, nodeCoord: [xPath, yPath], nodeHeadings: ppHeadingValues, matchedIndex: uvdIndex, userHeading: currentResultHeading)
                                            passedNodeInfoBuffer.append(passedNodeInfo)
                                            
//                                            controlPassedNodeInfo(passedNodeInfo: PassedNodeInfo(nodeNumber: self.passedNode, nodeCoord: self.passedNodeCoord, nodeHeadings: self.passedNodeHeadings, matchedIndex: self.passedNodeMatchedIndex, userHeading: currentResultHeading))
                                        } else {
                                            self.isInNode = false
                                            self.linkCoord = [xPath, yPath]
                                            self.linkDirections = ppHeadingValues
                                        }
                                    }
                                }
                            }
                        }
                        
                        if pastResult.x != currentResult.x && pastResult.y != currentResult.y {
                            let point1 = Point(x: pastResult.x, y: pastResult.y, direction: pastResultHeading)
                            let point2 = Point(x: currentResult.x, y: currentResult.y, direction: currentResultHeading)
                            if let intersectionPoint = findIntersection(point1: point1, point2: point2) {
                                var distanceArray = [Double]()
                                for i in 0..<xCandidates.count {
                                    let xValue = xCandidates[i]
                                    let yValue = yCandidates[i]
                                    
                                    let diffValue = sqrt((intersectionPoint.x - xValue)*(intersectionPoint.x - xValue) + (intersectionPoint.y - yValue)*(intersectionPoint.y - yValue))
                                    distanceArray.append(diffValue)
                                }
                                
                                if (!distanceArray.isEmpty) {
                                    let minValue = distanceArray.min()!
                                    let idxMin = distanceArray.firstIndex(of: minValue)!
                                    if minValue <= 20 {
                                        self.passedNode = nodeCandidates[idxMin]
                                        self.passedNodeMatchedIndex = uvdIndex
                                        self.passedNodeCoord = [xCandidates[idxMin], yCandidates[idxMin]]
                                        var ppHeadingValues = [Double]()
                                        let headingData = headingCandidates[idxMin].components(separatedBy: ",")
                                        for j in 0..<headingData.count {
                                            if(!headingData[j].isEmpty) {
                                                let mapHeading = Double(headingData[j])!
                                                ppHeadingValues.append(mapHeading)
                                            }
                                        }
                                        self.passedNodeHeadings = ppHeadingValues
                                        self.distFromNode = sqrt((xCandidates[idxMin]-x)*(xCandidates[idxMin]-x) + (yCandidates[idxMin]-y)*(yCandidates[idxMin]-y))
//                                        print(getLocalTimeString() + " , (Olympus) Node Find : passedNode (PATH_TRAJ_MATCHING (1)) = \(self.passedNode) // dist = \(self.distFromNode) // index = \(passedNodeMatchedIndex) // heading = \(currentResultHeading)")
                                        
                                        let passedNodeInfo = PassedNodeInfo(nodeNumber: nodeCandidates[idxMin], nodeCoord: [xCandidates[idxMin], yCandidates[idxMin]], nodeHeadings: ppHeadingValues, matchedIndex: uvdIndex, userHeading: currentResultHeading)
                                        passedNodeInfoBuffer.append(passedNodeInfo)
                                    }
                                }
                            }
                        }
                        
                        for passedNodeInfo in passedNodeInfoBuffer.reversed() {
                            controlPassedNodeInfo(passedNodeInfo: passedNodeInfo)
                            
                            self.passedNode = passedNodeInfo.nodeNumber
                            self.passedNodeMatchedIndex = passedNodeInfo.matchedIndex
                            self.passedNodeCoord = passedNodeInfo.nodeCoord
                            self.passedNodeHeadings = passedNodeInfo.nodeHeadings
                        }
                        print(getLocalTimeString() + " , (Olympus) Node Find : passedNode (PATH_TRAJ_MATCHING) = \(self.passedNode) // index = \(self.passedNodeMatchedIndex) // heading = \(self.passedNodeHeadings)")
                    } else {
                        for i in 0..<roadX.count {
                            let xPath = roadX[i]
                            let yPath = roadY[i]
                            let node = mainNode[i]
                            let headingArray = mainHeading[i]
                            
                            let pathTypeLoaded = mainType[i]
                            if (pathType == 1) {
                                if (pathType != pathTypeLoaded) {
                                    continue
                                }
                            }
                            
                            // XY 범위 안에 있는 값 중에 검사
                            if (xPath >= xMin && xPath <= xMax) {
                                if (yPath >= yMin && yPath <= yMax) {
                                    if (node != 0) {
                                        nodeCandidates.append(node)
                                        xCandidates.append(xPath)
                                        yCandidates.append(yPath)
                                        headingCandidates.append(headingArray)
                                    }
                                    
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
                                        if (node != 0) {
                                            self.isInNode = true
                                            isNodePassed = true
                                            self.passedNode = node
                                            self.passedNodeMatchedIndex = uvdIndex
                                            self.passedNodeCoord = [xPath, yPath]
                                            self.passedNodeHeadings = ppHeadingValues
                                            self.distFromNode = sqrt((xPath-x)*(xPath-x) + (yPath-y)*(yPath-y))
                                            print(getLocalTimeString() + " , (Olympus) Node Find : passedNode (Normal) = \(self.passedNode) // dist = \(self.distFromNode) // index = \(passedNodeMatchedIndex) // heading = \(currentResultHeading)")
                                            controlPassedNodeInfo(passedNodeInfo: PassedNodeInfo(nodeNumber: self.passedNode, nodeCoord: self.passedNodeCoord, nodeHeadings: self.passedNodeHeadings, matchedIndex: self.passedNodeMatchedIndex, userHeading: currentResultHeading))
                                        } else {
                                            self.isInNode = false
                                            self.linkDirections = ppHeadingValues
                                        }
                                    }
                                }
                            }
                        }
                        
                        if (!isNodePassed) {
                            if pastResult.x != currentResult.x && pastResult.y != currentResult.y {
                                let point1 = Point(x: pastResult.x, y: pastResult.y, direction: pastResultHeading)
                                let point2 = Point(x: currentResult.x, y: currentResult.y, direction: currentResultHeading)
                                if let intersectionPoint = findIntersection(point1: point1, point2: point2) {
                                    var distanceArray = [Double]()
                                    for i in 0..<xCandidates.count {
                                        let xValue = xCandidates[i]
                                        let yValue = yCandidates[i]
                                        
                                        let diffValue = sqrt((intersectionPoint.x - xValue)*(intersectionPoint.x - xValue) + (intersectionPoint.y - yValue)*(intersectionPoint.y - yValue))
                                        distanceArray.append(diffValue)
                                    }
                                    
                                    if (!distanceArray.isEmpty) {
                                        let minValue = distanceArray.min()!
                                        let idxMin = distanceArray.firstIndex(of: minValue)!
                                        if minValue <= 20 {
                                            self.passedNode = nodeCandidates[idxMin]
                                            self.passedNodeMatchedIndex = uvdIndex
                                            self.passedNodeCoord = [xCandidates[idxMin], yCandidates[idxMin]]
                                            var ppHeadingValues = [Double]()
                                            let headingData = headingCandidates[idxMin].components(separatedBy: ",")
                                            for j in 0..<headingData.count {
                                                if(!headingData[j].isEmpty) {
                                                    let mapHeading = Double(headingData[j])!
                                                    ppHeadingValues.append(mapHeading)
                                                }
                                            }
                                            self.passedNodeHeadings = ppHeadingValues
                                            self.distFromNode = sqrt((xCandidates[idxMin]-x)*(xCandidates[idxMin]-x) + (yCandidates[idxMin]-y)*(yCandidates[idxMin]-y))
                                            print(getLocalTimeString() + " , (Olympus) Node Find : passedNode (Jump) = \(self.passedNode) // dist = \(self.distFromNode) // index = \(passedNodeMatchedIndex) // heading = \(currentResultHeading)")
                                            controlPassedNodeInfo(passedNodeInfo: PassedNodeInfo(nodeNumber: self.passedNode, nodeCoord: self.passedNodeCoord, nodeHeadings: self.passedNodeHeadings, matchedIndex: self.passedNodeMatchedIndex, userHeading: currentResultHeading))
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
    
    
    private func controlPassedNodeInfo(passedNodeInfo: PassedNodeInfo) {
        if (self.passedNodeInfoBuffer.count > 1) {
            let currentNode = passedNodeInfo.nodeNumber
            let pastNode = passedNodeInfoBuffer[passedNodeInfoBuffer.count-1].nodeNumber
            
            if (currentNode == pastNode) {
                self.passedNodeInfoBuffer.remove(at: passedNodeInfoBuffer.count-1)
            }
        }
        self.passedNodeInfoBuffer.append(passedNodeInfo)
        if (self.passedNodeInfoBuffer.count > 30) {
            self.passedNodeInfoBuffer.remove(at: 0)
        }
        
        if (isNeedClearBuffer) {
            print(getLocalTimeString() + " , (Olympus) Node Find : before -> passedNodeInfoBuffer = \(passedNodeInfoBuffer)")
            let pastBuffer = self.passedNodeInfoBuffer
            var newBuffer = [PassedNodeInfo]()
            var startIndex: Int = 0
            for i in 0..<pastBuffer.count {
                if pastBuffer[i].nodeNumber == self.anchorNode.nodeNumber {
                    startIndex = i
                    break
                }
            }
            
            for i in startIndex..<pastBuffer.count {
                newBuffer.append(pastBuffer[i])
            }
            self.passedNodeInfoBuffer = newBuffer
            isNeedClearBuffer = false
            print(getLocalTimeString() + " , (Olympus) Node Find : after -> passedNodeInfoBuffer = \(passedNodeInfoBuffer)")
        }
    }
    
    public func getPaddingValues(mode: String, isPhaseBreak: Bool, PADDING_VALUE: Double) -> [Double] {
        var paddingValues: [Double] = [0, 0, 0, 0]
        
        if (isPhaseBreak) {
            paddingValues = [Double] (repeating: PADDING_VALUE, count: 4)
//            print(getLocalTimeString() + " , (Olympus) isPhaseBreak // paddingValues = \(paddingValues)")
            return paddingValues
        }
        
        let directions = linkDirections
        
//        print(getLocalTimeString() + " , (Olympus) linkDirections = \(linkDirections)")
        var isDefault: Bool = true
        if directions.count == 2 {
            var xyLimitValue: Double = 30
            if (mode == OlympusConstants.MODE_PDR) {
                xyLimitValue = xyLimitValue/2
            }
            if (directions.contains(0) && directions.contains(180)) {
                paddingValues = [xyLimitValue, 2, xyLimitValue, 2]
                isDefault = false
            } else if (directions.contains(90) && directions.contains(270)) {
                paddingValues = [2, xyLimitValue, 2, xyLimitValue]
                isDefault = false
            }
        }
        
        var defaultPaddingValue = PADDING_VALUE
        if (mode == OlympusConstants.MODE_PDR) {
            defaultPaddingValue = defaultPaddingValue/2
        }
        
        if (isDefault) {
            paddingValues = [Double] (repeating: defaultPaddingValue, count: 4)
//            print(getLocalTimeString() + " , (Olympus) Default // paddingValues = \(paddingValues)")
        } else {
//            print(getLocalTimeString() + " , (Olympus) XYLimit // paddingValues = \(paddingValues)")
        }
        
        return paddingValues
    }
    
    private func getPathTrajMatcingArea(areaMinMax: [Double], interval: Double) -> [[Double]] {
        var coordinates: [[Double]] = []
        
        let xMin = areaMinMax[0]
        let yMin = areaMinMax[1]
        let xMax = areaMinMax[2]
        let yMax = areaMinMax[3]
        
        var x = xMin
            while x <= xMax {
                coordinates.append([x, yMin])
                coordinates.append([x, yMax])
                x += interval
            }
            
            var y = yMin
            while y <= yMax {
                coordinates.append([xMin, y])
                coordinates.append([xMax, y])
                y += interval
            }
        
        return coordinates
    }
    
    private func getPaddingValuesForPhase4(directions: [Double], PIXELS_TO_CHECK: Int) -> [Double] {
        var paddingValues: [Double] = [0, 0, 0, 0]
        let pixelValue: Double = Double(PIXELS_TO_CHECK)
        
        var isDefault: Bool = true
        if directions.count == 2 {
            if (directions.contains(0) && directions.contains(180)) {
                paddingValues = [pixelValue, 2, pixelValue, 2]
                isDefault = false
            } else if (directions.contains(90) && directions.contains(270)) {
                paddingValues = [2, pixelValue, 2, pixelValue]
                isDefault = false
            }
        }
        
        if (isDefault) {
            paddingValues = [Double] (repeating: pixelValue, count: 4)
            print(getLocalTimeString() + " , (Olympus) Request Phase 4 : Default // paddingValues = \(paddingValues)")
        } else {
            print(getLocalTimeString() + " , (Olympus) Request Phase 4 : XYLimit // paddingValues = \(paddingValues)")
        }
        
        return paddingValues
    }
    
    
    private func findIntersection(point1: Point, point2: Point) -> Point? {
        let radian1 = point1.direction*OlympusConstants.D2R
        let radian2 = point2.direction*OlympusConstants.D2R

        if radian1 == radian2 {
            return nil
        } else {
            if point1.direction == 90 || point1.direction == 270 {
                return Point(x: point1.x, y: point2.y, direction: -1)
            } else if (point2.direction == 90 || point2.direction == 270) {
                return Point(x: point2.x, y: point1.y, direction: -1)
            } else {
                let slope1 = tan(radian1)
                let slope2 = tan(radian2)
                
                let x = (slope1 * point1.x - slope2 * point2.x + point2.y - point1.y) / (slope1 - slope2)
                let y = slope1 * (x - point1.x) + point1.y
                return Point(x: x, y: y, direction: -1)
            }
        }
    }
    
    public func getUserDirection(from A: [Double], to B: [Double]) -> Double {
        let deltaX = B[0] - A[0]
        let deltaY = B[1] - A[1]
        
        let radians = atan2(deltaY, deltaX)
        let degrees = radians * 180 / .pi
        
        let normalizedDegrees = degrees >= 0 ? degrees : (degrees + 360)
        
        return normalizedDegrees
    }
    
    public func updateAnchorNodeAfterPathTrajMatching(nodeInfo: PassedNodeInfo, sectionNumber: Int) {
        self.anchorNode = nodeInfo
        self.anchorSection = sectionNumber
        self.isNeedClearBuffer = true
        
        print(getLocalTimeString() + " , (Olympus) Node Find : Anchor Node After PathTrajMatching = \(self.anchorNode)")
    }
    
    
    public func updateAnchorNode(fltResult: FineLocationTrackingFromServer, pathType: Int, sectionNumber: Int) {
        let anchorNode = findAnchorNode(fltResult: fltResult, pathType: pathType)
        if anchorNode.nodeNumber != -1 {
            if anchorNode.nodeNumber == self.anchorNode.nodeNumber {
                self.anchorSection = sectionNumber
            } else {
                self.anchorNode = anchorNode
                self.anchorSection = sectionNumber
                self.isNeedClearBuffer = true
            }
        }
        print(getLocalTimeString() + " , (Olympus) Node Find : Anchor Node = \(self.anchorNode)")
    }
    
    public func updateAnchorNodeAfterRecovery(badCaseNodeInfo: NodeCandidateInfo, nodeNumber: Int) {
        let nodeCandidatesInfo = badCaseNodeInfo.nodeCandidatesInfo
        for item in nodeCandidatesInfo {
            if item.nodeNumber == nodeNumber {
                self.anchorNode = item
            }
        }
        print(getLocalTimeString() + " , (Olympus) Node Find : Anchor Node Recover = \(self.anchorNode)")
    }
    
    public func getAnchorNodeCandidatesForGoodCase(fltResult: FineLocationTrackingFromServer, pathType: Int) -> NodeCandidateInfo {
        var goodCaseNodeInfo = NodeCandidateInfo(isPhaseBreak: false, nodeCandidatesInfo: [])
        var nodeCandidatesInfo = [PassedNodeInfo]()
        
        if (self.anchorNode.nodeNumber == -1) {
            return goodCaseNodeInfo
        } else {
            let nodeInfo = self.anchorNode
            nodeCandidatesInfo.append(nodeInfo)
            goodCaseNodeInfo = NodeCandidateInfo(isPhaseBreak: false, nodeCandidatesInfo: nodeCandidatesInfo)
            return goodCaseNodeInfo
        }
    }
    
    public func getAnchorNodeCandidatesForBadCase(fltResult: FineLocationTrackingFromServer, pathType: Int) -> NodeCandidateInfo {
        var badCaseNodeInfo = NodeCandidateInfo(isPhaseBreak: false, nodeCandidatesInfo: [])
        if self.anchorNode.nodeNumber == -1 {
            return NodeCandidateInfo(isPhaseBreak: true, nodeCandidatesInfo: [])
        } else {
            let anchorNodeInfo = self.anchorNode
//            let heading = anchorNodeInfo.userHeading
            
            let nodeCoord = anchorNodeInfo.nodeCoord
            let nodeHeadings = anchorNodeInfo.nodeHeadings
            let nodeMatchedIndex = anchorNodeInfo.matchedIndex
            
            var heading = fltResult.absolute_heading
            if (nodeCoord != linkCoord) {
                heading = getUserDirection(from: nodeCoord, to: linkCoord)
            }
//            let heading = getUserDirection(from: nodeCoord, to: linkCoord)
            print(getLocalTimeString() + " , (Olympus) Node Find : getAnchorNodeCandidatesForBadCase // heading = \(heading) , anchorNodeInfo = \(anchorNodeInfo)")
            
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
                
                if (diffValue >= 90-MARGIN && diffValue <= 90+MARGIN) || (diffValue >= 270-MARGIN && diffValue <= 270+MARGIN) {
                    candidateDirections.append(mapHeading)
                }
            }
            print(getLocalTimeString() + " , (Olympus) Node Find : getAnchorNodeCandidatesForBadCase // candidateDirections = \(candidateDirections)")
            
//            var sectionLength = OlympusConstants.REQUIRED_SECTION_STRAIGHT_LENGTH
//            if (pathType == 1) { sectionLength = sectionLength*2 }
//            let PIXELS_TO_CHECK = Int(sectionLength)
            let PIXEL_LENGTH = OlympusConstants.PIXEL_LENGTH_TO_FIND_NODE
            let PIXELS_TO_CHECK = Int(OlympusConstants.PIXEL_LENGTH_TO_FIND_NODE)
            
            var nodeCandidatesInfo = [PassedNodeInfo]()
            
            for direction in candidateDirections {
                var paddingValues = [Double] (repeating: Double(PIXELS_TO_CHECK), count: 4)
                if (direction == 0) {
                    paddingValues = [0, PIXEL_LENGTH, 1, 1]
                } else if (direction == 90) {
                    paddingValues = [1, 1, 0, PIXEL_LENGTH]
                } else if (direction == 180) {
                    paddingValues = [PIXEL_LENGTH, 0, 1, 1]
                } else if (direction == 270) {
                    paddingValues = [1, 1, PIXEL_LENGTH, 0]
                }
                
                var x: Double = nodeCoord[0]
                var y: Double = nodeCoord[1]
                for _ in 0..<PIXELS_TO_CHECK {
                    x += cos(direction*OlympusConstants.D2R)
                    y += sin(direction*OlympusConstants.D2R)
                    let matchedNodeResult = getMatchedNodeWithCoord(fltResult: fltResult, originCoord: nodeCoord, coordToCheck: [x, y], pathType: pathType, PADDING_VALUES: paddingValues)
                    if (matchedNodeResult.0) {
                        break
                    } else {
                        if (matchedNodeResult.1 != -1) {
                            let coordToCheck: [Double] = [x+cos(heading*OlympusConstants.D2R), y+sin(heading*OlympusConstants.D2R)]
                            let isPossibleNode = checkPathPixelHasCoords(fltResult: fltResult, coordToCheck: coordToCheck)
                            if (isPossibleNode) {
                                let nodeInfo = PassedNodeInfo(nodeNumber: matchedNodeResult.1, nodeCoord: [x, y], nodeHeadings: matchedNodeResult.2, matchedIndex: nodeMatchedIndex, userHeading: heading)
                                nodeCandidatesInfo.append(nodeInfo)
                                break
                            }
                        }
                    }
                }
            }
            
            badCaseNodeInfo = NodeCandidateInfo(isPhaseBreak: false, nodeCandidatesInfo: nodeCandidatesInfo)
            print(getLocalTimeString() + " , (Olympus) Node Find : getAnchorNodeCandidatesForBadCase // candidateNodeNumbers = \(nodeCandidatesInfo)")
        }
        
        return badCaseNodeInfo
    }
    
    public func getAnchorNodeCandidatesForRecovery(fltResult: FineLocationTrackingFromServer, inputNodeCandidateInfo: NodeCandidateInfo, pathType: Int) -> NodeCandidateInfo {
        var recoveryCaseNodeInfo = NodeCandidateInfo(isPhaseBreak: false, nodeCandidatesInfo: [])
        let nodeCandidatesInfo = inputNodeCandidateInfo.nodeCandidatesInfo
        
        print(getLocalTimeString() + " , (Olympus) Node Find : fltResult node_number = \(fltResult.node_number)")
        print(getLocalTimeString() + " , (Olympus) Node Find : inputNodeCandidateInfo = \(inputNodeCandidateInfo)")
        var anchorNodeInfo = PassedNodeInfo(nodeNumber: -1, nodeCoord: [], nodeHeadings: [], matchedIndex: -1, userHeading: 0)
        for item in nodeCandidatesInfo {
            if item.nodeNumber == fltResult.node_number {
                anchorNodeInfo = item
            }
        }
        
        print(getLocalTimeString() + " , (Olympus) Node Find : getAnchorNodeCandidatesForRecovery (1) // anchorNodeInfo = \(anchorNodeInfo)")
        
        if anchorNodeInfo.matchedIndex == -1 {
            return recoveryCaseNodeInfo
        } else {
//            let heading = anchorNodeInfo.userHeading
            
            let nodeCoord = anchorNodeInfo.nodeCoord
            let nodeHeadings = anchorNodeInfo.nodeHeadings
            let nodeMatchedIndex = anchorNodeInfo.matchedIndex
            
            let heading = getUserDirection(from: nodeCoord, to: linkCoord)
            print(getLocalTimeString() + " , (Olympus) Node Find : getAnchorNodeCandidatesForRecovery (2) // anchorNodeInfo = \(anchorNodeInfo)")
            
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
                
                if (diffValue >= 90-MARGIN && diffValue <= 90+MARGIN) || (diffValue >= 270-MARGIN && diffValue <= 270+MARGIN) {
                    candidateDirections.append(mapHeading)
                }
            }
            print(getLocalTimeString() + " , (Olympus) Node Find : getAnchorNodeCandidatesForRecovery // candidateDirections = \(candidateDirections)")
            
//            var sectionLength = OlympusConstants.REQUIRED_SECTION_STRAIGHT_LENGTH
//            if (pathType == 1) { sectionLength = sectionLength*2 }
//            let PIXELS_TO_CHECK = Int(sectionLength)
            
            let PIXEL_LENGTH = OlympusConstants.PIXEL_LENGTH_TO_FIND_NODE
            let PIXELS_TO_CHECK = Int(OlympusConstants.PIXEL_LENGTH_TO_FIND_NODE)
            
            var nodeCandidatesInfo = [PassedNodeInfo]()
            
            for direction in candidateDirections {
                var paddingValues = [Double] (repeating: Double(PIXELS_TO_CHECK), count: 4)
                if (direction == 0) {
                    paddingValues = [0, PIXEL_LENGTH, 1, 1]
                } else if (direction == 90) {
                    paddingValues = [1, 1, 0, PIXEL_LENGTH]
                } else if (direction == 180) {
                    paddingValues = [PIXEL_LENGTH, 0, 1, 1]
                } else if (direction == 270) {
                    paddingValues = [1, 1, PIXEL_LENGTH, 0]
                }
                
                var x: Double = nodeCoord[0]
                var y: Double = nodeCoord[1]
                for _ in 0..<PIXELS_TO_CHECK {
                    x += cos(direction*OlympusConstants.D2R)
                    y += sin(direction*OlympusConstants.D2R)
                    let matchedNodeResult = getMatchedNodeWithCoord(fltResult: fltResult, originCoord: nodeCoord, coordToCheck: [x, y], pathType: pathType, PADDING_VALUES: paddingValues)
                    if (matchedNodeResult.0) {
                        break
                    } else {
                        if (matchedNodeResult.1 != -1) {
                            let coordToCheck: [Double] = [x+cos(heading*OlympusConstants.D2R), y+sin(heading*OlympusConstants.D2R)]
                            let isPossibleNode = checkPathPixelHasCoords(fltResult: fltResult, coordToCheck: coordToCheck)
                            if (isPossibleNode) {
                                let nodeInfo = PassedNodeInfo(nodeNumber: matchedNodeResult.1, nodeCoord: [x, y], nodeHeadings: matchedNodeResult.2, matchedIndex: nodeMatchedIndex, userHeading: heading)
                                nodeCandidatesInfo.append(nodeInfo)
                                break
                            }
//                            let nodeInfo = PassedNodeInfo(nodeNumber: matchedNodeResult.1, nodeCoord: [x, y], nodeHeadings: matchedNodeResult.2, matchedIndex: nodeMatchedIndex, userHeading: heading)
//                            nodeCandidatesInfo.append(nodeInfo)
//                            break
                        }
                    }
                }
            }
            recoveryCaseNodeInfo = NodeCandidateInfo(isPhaseBreak: false, nodeCandidatesInfo: nodeCandidatesInfo)
            print(getLocalTimeString() + " , (Olympus) Node Find : getAnchorNodeCandidatesForRecovery // candidateNodeNumbers = \(nodeCandidatesInfo)")
        }
        
        return recoveryCaseNodeInfo
    }
    
    private func findAnchorNode(fltResult: FineLocationTrackingFromServer, pathType: Int) -> PassedNodeInfo {
        let startNodeHeading = passedNodeHeadings
        let nodeInfoBuffer = passedNodeInfoBuffer
        print(getLocalTimeString() + " , (Olympus) Node Find : nodeInfoBuffer = \(nodeInfoBuffer)")
        
        var resultPassedNodeInfo = PassedNodeInfo(nodeNumber: -1, nodeCoord: [], nodeHeadings: [], matchedIndex: -1, userHeading: 0)
        
        let startCoord = linkCoord
        print(getLocalTimeString() + " , (Olympus) Node Find : linkCoord = \(self.linkCoord) // linkDirections = \(self.linkDirections)")
        let heading = compensateHeading(heading: fltResult.absolute_heading)
        
        var diffHeading = [Double]()
        var candidateDirections = [Double]()
        for mapHeading in startNodeHeading {
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
            
            if (diffValue >= 180-MARGIN && diffValue <= 180+MARGIN) {
                candidateDirections.append(mapHeading)
            }
        }
        print(getLocalTimeString() + " , (Olympus) Node Find : heading = \(heading) // candidateDirections = \(candidateDirections)")

//        let sectionLength = OlympusConstants.REQUIRED_SECTION_STRAIGHT_LENGTH*2
        let sectionLength: Double = 100
        let PIXELS_TO_CHECK = Int(sectionLength)
        
        if (candidateDirections.count == 1) {
            var candidateNodeNumbers = [Int]()
            
            let direction = candidateDirections[0]
            var paddingValues = [Double] (repeating: Double(PIXELS_TO_CHECK), count: 4)
            if (direction == 0) {
                paddingValues = [0, sectionLength, 1, 1]
            } else if (direction == 90) {
                paddingValues = [1, 1, 0, sectionLength]
            } else if (direction == 180) {
                paddingValues = [sectionLength, 0, 1, 1]
            } else if (direction == 270) {
                paddingValues = [1, 1, sectionLength, 0]
            } else {
                paddingValues = [20, 20, 20, 20]
            }
            
//            print(getLocalTimeString() + " , (Olympus) Node Find : paddingValues = \(paddingValues)")
            var x: Double = startCoord[0]
            var y: Double = startCoord[1]
            for _ in 0..<PIXELS_TO_CHECK {
                x += cos(direction*OlympusConstants.D2R)
                y += sin(direction*OlympusConstants.D2R)
                let matchedNodeResult = getMatchedNodeWithCoord(fltResult: fltResult, originCoord: startCoord, coordToCheck: [x, y], pathType: pathType, PADDING_VALUES: paddingValues)
                if (matchedNodeResult.0) {
                    break
                } else {
                    if (matchedNodeResult.1 != -1) {
                        candidateNodeNumbers.append(matchedNodeResult.1)
                    }
                }
            }
            
            print(getLocalTimeString() + " , (Olympus) Node Find : candidateNodeNumbers = \(candidateNodeNumbers)")
            for nodeNumber in candidateNodeNumbers.reversed() {
                for item in nodeInfoBuffer {
                    if item.nodeNumber == nodeNumber {
                        resultPassedNodeInfo = item
                        return resultPassedNodeInfo
                    }
                }
            }
        }
        
        return resultPassedNodeInfo
    }
    
    private func checkPathPixelHasCoords(fltResult: FineLocationTrackingFromServer, coordToCheck: [Double]) -> Bool {
        let building = fltResult.building_name
        let level = fltResult.level_name
        let levelCopy: String = removeLevelDirectionString(levelName: level)
        let x = coordToCheck[0]
        let y = coordToCheck[1]
        let key: String = "\(building)_\(levelCopy)"
        
        if (!(building.isEmpty) && !(level.isEmpty)) {
            guard let mainType: [Int] = self.PpType[key] else { return false }
            guard let mainRoad: [[Double]] = self.PpCoord[key] else { return false }
            guard let mainNode: [Int] = self.PpNode[key] else { return false }
            guard let mainHeading: [String] = self.PpHeading[key] else { return false }
            
            if (!mainRoad.isEmpty) {
                let roadX = mainRoad[0]
                let roadY = mainRoad[1]
                for i in 0..<roadX.count {
                    let xPath = roadX[i]
                    let yPath = roadY[i]
                    if (x == xPath && y == yPath) {
                        return true
                    }
                }
            }
        }
        return false
    }
    
    private func getMatchedNodeWithCoord(fltResult: FineLocationTrackingFromServer, originCoord: [Double], coordToCheck: [Double], pathType: Int, PADDING_VALUES: [Double]) -> (Bool, Int, [Double]) {
        let building = fltResult.building_name
        let level = fltResult.level_name
        let levelCopy: String = removeLevelDirectionString(levelName: level)
        let x = coordToCheck[0]
        let y = coordToCheck[1]
        let key: String = "\(building)_\(levelCopy)"
        
        let isPpEndPoint: Bool = true
        let matchedNode: Int = -1
        var matchedNodeHeadings = [Double]()
        if (!(building.isEmpty) && !(level.isEmpty)) {
            guard let mainType: [Int] = self.PpType[key] else { return (isPpEndPoint, matchedNode, matchedNodeHeadings) }
            guard let mainRoad: [[Double]] = self.PpCoord[key] else { return (isPpEndPoint, matchedNode, matchedNodeHeadings) }
            guard let mainNode: [Int] = self.PpNode[key] else { return (isPpEndPoint, matchedNode, matchedNodeHeadings) }
            guard let mainHeading: [String] = self.PpHeading[key] else { return (isPpEndPoint, matchedNode, matchedNodeHeadings) }
            
            if (!mainRoad.isEmpty) {
                let roadX = mainRoad[0]
                let roadY = mainRoad[1]
                
                let xMin = originCoord[0] - PADDING_VALUES[0]
                let xMax = originCoord[0] + PADDING_VALUES[1]
                let yMin = originCoord[1] - PADDING_VALUES[2]
                let yMax = originCoord[1] + PADDING_VALUES[3]
                
                for i in 0..<roadX.count {
                    let xPath = roadX[i]
                    let yPath = roadY[i]
                    let node = mainNode[i]
                    let headingArray = mainHeading[i]
                    
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
                                var ppHeadingValues = [Double]()
                                let headingData = headingArray.components(separatedBy: ",")
                                for j in 0..<headingData.count {
                                    if(!headingData[j].isEmpty) {
                                        let mapHeading = Double(headingData[j])!
                                        ppHeadingValues.append(mapHeading)
                                    }
                                }
                                if (node == 0) {
                                    return (false, matchedNode, matchedNodeHeadings)
                                } else {
                                    matchedNodeHeadings = ppHeadingValues
//                                    print(getLocalTimeString() + " , (Olympus) Node Find : findStartNode (Process) headingArray = \(headingArray) // headingData = \(headingData) // ppHeadingValues = \(ppHeadingValues)")
                                    return (false, node, matchedNodeHeadings)
                                }
                            }
                        }
                    }
                }
            }
        }
        return (isPpEndPoint, matchedNode, matchedNodeHeadings)
    }
    
    public func findPathTrajMatchingNode(fltResult: FineLocationTrackingFromServer, x: Double, y: Double, heading: Double, uvdBuffer: [UnitDRInfo], pathType: Int, linkDirections: [Double]) -> [PathMatchingNodeCandidateInfo] {
        var pathMatchingNodeCandidates = [PathMatchingNodeCandidateInfo]()
        
        let MARGIN: Double = 30
        let startHeading = compensateHeading(heading: heading)
        var diffHeadings = [Double]()
        var candidateDirections = [Double]()
        for mapHeading in linkDirections {
            var diffValue: Double = 0
            if (startHeading > 270 && (mapHeading >= 0 && mapHeading < 90)) {
                diffValue = abs(startHeading - (mapHeading+360))
            } else if (mapHeading > 270 && (startHeading >= 0 && startHeading < 90)) {
                diffValue = abs(mapHeading - (startHeading+360))
            } else {
                diffValue = abs(startHeading - mapHeading)
            }
            diffHeadings.append(diffValue)
            
            
            
            if diffValue <= MARGIN || (diffValue >= 180-MARGIN && diffValue < 180+MARGIN) {
                candidateDirections.append(mapHeading)
            }
        }
        
        print(getLocalTimeString() + " , (Olympus) Path-Matching : userXY = \(x) , \(y)")
        print(getLocalTimeString() + " , (Olympus) Path-Matching : startHeading = \(startHeading)")
        print(getLocalTimeString() + " , (Olympus) Path-Matching : diffHeadings = \(diffHeadings)")
        print(getLocalTimeString() + " , (Olympus) Path-Matching : candidateDirections = \(candidateDirections)")
        var uvdLength: Double = 0
        for uvd in uvdBuffer {
            uvdLength += uvd.length
        }
        
        let PIXELS_TO_CHECK = Int(round(uvdLength + uvdLength*0.2))
        print(getLocalTimeString() + " , (Olympus) Path-Matching : PIXELS_TO_CHECK = \(PIXELS_TO_CHECK)")
        if (!candidateDirections.isEmpty) {
            let matchedNodeResult = getMatchedNodeWithCoord(fltResult: fltResult, originCoord: [x, y], coordToCheck: [x, y], pathType: pathType, PADDING_VALUES: [1, 1, 1, 1])
            if (matchedNodeResult.1 != -1) {
                let nodeInfo = PathMatchingNodeCandidateInfo(nodeNumber: matchedNodeResult.1, nodeCoord: [x, y], nodeHeadings: matchedNodeResult.2)
                pathMatchingNodeCandidates.append(nodeInfo)
            }
            
            for direction in candidateDirections {
                var matchedNodeNumber: Int = -1
                var matchedNodeCoord: [Double] = [0, 0]
                var matchedNodeHeadings = [Double]()
                let paddingValues = [Double] (repeating: Double(PIXELS_TO_CHECK), count: 4)
                
                var xToCheck: Double = x
                var yToCheck: Double = y
                for _ in 0..<PIXELS_TO_CHECK {
                    xToCheck += cos(direction*OlympusConstants.D2R)
                    yToCheck += sin(direction*OlympusConstants.D2R)
                    let matchedNodeResult = getMatchedNodeWithCoord(fltResult: fltResult, originCoord: [x, y], coordToCheck: [xToCheck, yToCheck], pathType: pathType, PADDING_VALUES: paddingValues)
                    if (matchedNodeResult.0) {
                        break
                    } else {
                        if (matchedNodeResult.1 != -1) {
                            matchedNodeNumber = matchedNodeResult.1
                            matchedNodeCoord = [xToCheck, yToCheck]
                            matchedNodeHeadings = matchedNodeResult.2
                            break
                        }
                    }
                }
                
                if (matchedNodeNumber != -1) {
                    print(getLocalTimeString() + " , (Olympus) Path-Matching : matchedNodeNumber = \(matchedNodeNumber) // matchedNodeCoord = \(matchedNodeCoord)")
                    let nodeInfo = PathMatchingNodeCandidateInfo(nodeNumber: matchedNodeNumber, nodeCoord: matchedNodeCoord, nodeHeadings: matchedNodeHeadings)
                    pathMatchingNodeCandidates.append(nodeInfo)
                }
            }
        }
        
        return pathMatchingNodeCandidates
    }
    
    public func getTimeUpdateLimitation(mode: String) -> (limitType: LimitationType, limitValues: [Double]) {
        var limitType: LimitationType = .NO_LIMIT
        var limitValues: [Double] = [0, 0]
        var LIMIT: Double = 0.8
        if (mode == OlympusConstants.MODE_PDR) {
            LIMIT = 0.4
        }
        
        let isInNode = self.isInNode
        
        let coordX = linkCoord[0]
        let coordY = linkCoord[1]
        
        let directions = linkDirections
        
//        print("(Link Info) : coord = \(coordX) , \(coordY) // directions = \(directions)")
        
        if (!isInNode) {
            if (directions.contains(0) && directions.contains(180)) {
                limitType = .Y_LIMIT
                limitValues = [coordY - LIMIT, coordY + LIMIT]
            } else if (directions.contains(90) && directions.contains(270)) {
                limitType = .X_LIMIT
                limitValues = [coordX - LIMIT, coordX + LIMIT]
            }
        }
        
        return (limitType, limitValues)
    }
    
    private func calDistacneFromNearestPp(coord: [Double], passedPp: [[Double]], mainRoad: [[Double]], mainType: [Int], pathType: Int, PADDING_VALUES: [Double]) -> [Double] {
        let x = coord[0]
        let y = coord[1]
        
        var xyd: [Double] = [x, y, 50]
        
        var xydArray = [[Double]]()
        
        let roadX = mainRoad[0]
        let roadY = mainRoad[1]
        
        let xMin = x - PADDING_VALUES[0]
        let xMax = x + PADDING_VALUES[1]
        let yMin = y - PADDING_VALUES[2]
        let yMax = y + PADDING_VALUES[3]
        
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
