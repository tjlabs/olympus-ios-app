import Foundation

public class OlympusPathMatchingCalculator {
    static var shared = OlympusPathMatchingCalculator()
    
    private var sector_id: Int = -1
    public var PpURL = [String: String]()
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
    var currentPassedNodeInfo = PassedNodeInfo(nodeNumber: -1, nodeCoord: [], nodeHeadings: [], matchedIndex: -1, userHeading: 0)
    var passedNodeInfoBuffer = [PassedNodeInfo]()
    var passedNodeInfoBufferForMulti = [PassedNodeInfo]()
    var isNeedClearBuffer: Bool = false
    var anchorNode = PassedNodeInfo(nodeNumber: -1, nodeCoord: [], nodeHeadings: [], matchedIndex: -1, userHeading: 0)
    var anchorSection: Int = -1
    var unitDRInfoBuffer = [UnitDRInfo]()
    var isNeedClearUVDBuffer: Bool = false
    var distFromNode: Double = -1
    var buildingLevelChangedCoord = [Double]()
    
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
        self.currentPassedNodeInfo = PassedNodeInfo(nodeNumber: -1, nodeCoord: [], nodeHeadings: [], matchedIndex: -1, userHeading: 0)
        self.passedNodeInfoBuffer = [PassedNodeInfo]()
        self.passedNodeInfoBufferForMulti = [PassedNodeInfo]()
        self.isNeedClearBuffer = false
        self.anchorNode = PassedNodeInfo(nodeNumber: -1, nodeCoord: [], nodeHeadings: [], matchedIndex: -1, userHeading: 0)
        self.anchorSection = -1
        self.unitDRInfoBuffer = [UnitDRInfo]()
        self.isNeedClearUVDBuffer = false
        self.distFromNode = -1
        self.buildingLevelChangedCoord = [Double]()
        
        self.linkCoord = [0, 0]
        self.linkDirections = [Double]()
        self.isInNode = false
    }
    
    public func initPassedNodeInfo() {
        self.passedNode = -1
        self.passedNodeMatchedIndex = -1
        self.passedNodeCoord = [0, 0]
        self.passedNodeHeadings = [Double]()
        self.currentPassedNodeInfo = PassedNodeInfo(nodeNumber: -1, nodeCoord: [], nodeHeadings: [], matchedIndex: -1, userHeading: 0)
        self.passedNodeInfoBuffer = [PassedNodeInfo]()
        self.passedNodeInfoBufferForMulti = [PassedNodeInfo]()
        self.isNeedClearBuffer = false
        self.anchorNode = PassedNodeInfo(nodeNumber: -1, nodeCoord: [], nodeHeadings: [], matchedIndex: -1, userHeading: 0)
        self.anchorSection = -1
        self.unitDRInfoBuffer = [UnitDRInfo]()
        self.isNeedClearUVDBuffer = false
        self.distFromNode = -1
        
        self.linkCoord = [0, 0]
        self.linkDirections = [Double]()
        self.isInNode = false
    }
    
    public func setSectorID(sector_id: Int) {
        self.sector_id = sector_id
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
                
                let typeString = lineData[0]
                let nodeString = lineData[1]
                let xString = lineData[2]
                let yString = lineData[3]
                let scaleString = lineData[4]
                
                if !xString.isEmpty && !yString.isEmpty {
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
        }
        road = [roadX, roadY]
        self.PpMinMax = [roadX.min() ?? 0, roadY.min() ?? 0, roadX.max() ?? 0, roadY.max() ?? 0]
        
        return (roadType, roadNode, road, roadScale, roadHeading)
    }
    
    public func savePathPixelLocalUrl(key: String, url: URL?) {
        if let urlToSave = url {
//            print(getLocalTimeString() + " , (Olympus) Save \(key) Path-Pixel Local URL : \(urlToSave)")
            do {
                let key: String = "OlympusPathPixelLocalUrl_\(key)"
                UserDefaults.standard.set(url, forKey: key)
            }
        } else {
            print(getLocalTimeString() + " , (Olympus) Error : Save \(key) Path-Pixel Local URL")
        }
    }
    
    public func loadPathPixelLocalUrl(key: String) -> (Bool, URL?) {
        let keyPpLocalUrl: String = "OlympusPathPixelLocalUrl_\(key)"
        if let loadedPpLocalUrl: URL = UserDefaults.standard.object(forKey: keyPpLocalUrl) as? URL {
            return (true, loadedPpLocalUrl)
        } else {
            return (false, nil)
        }
    }
    
    public func savePathPixelURL(key: String, ppURL: String) {
        print(getLocalTimeString() + " , (Olympus) Save \(key) Path-Pixel URL : \(ppURL)")
        do {
            let key: String = "OlympusPathPixelURL_\(key)"
            UserDefaults.standard.set(ppURL, forKey: key)
        }
    }
    
    public func loadPathPixel(sector_id: Int, PathPixelURL: [String: String]) {
        for (key, value) in PathPixelURL {
            // Cache를 통해 PP 버전을 확인
            let keyPpURL: String = "OlympusPathPixelURL_\(key)"
            if let loadedPpURL: String = UserDefaults.standard.object(forKey: keyPpURL) as? String {
                if value == loadedPpURL {
                    // 만약 버전이 같다면 파일을 가져오기
                    let ppLocalUrl = loadPathPixelLocalUrl(key: key)
                    if (ppLocalUrl.0) {
                        do {
                            if let loadedURL: URL = ppLocalUrl.1 {
                                let contents = try String(contentsOf: loadedURL)
                                ( PpType[key], PpNode[key], PpCoord[key], PpMagScale[key], PpHeading[key] ) = parseRoad(data: contents)
                                NotificationCenter.default.post(name: .sectorPathPixelUpdated, object: nil, userInfo: ["pathPixelKey": key])
                                PpIsLoaded[key] = true
                            }
                        } catch {
                            print(getLocalTimeString() + " , (Olympus) Error : Reading Path-Pixel File \(key)")
                        }
                        
                    } else {
                        // 첫 시작과 동일하게 다운로드 받아오기
                        let ppUrl: String = value
                        let urlComponents = URLComponents(string: ppUrl)
                        OlympusFileDownloader.shared.downloadCSVFile(from: (urlComponents?.url)!, fname: key, completion: { [self] url, error in
                            if error == nil {
                                do {
                                    let contents = try String(contentsOf: url!)
                                    ( PpType[key], PpNode[key],PpCoord[key], PpMagScale[key], PpHeading[key] ) = parseRoad(data: contents)
                                    NotificationCenter.default.post(name: .sectorPathPixelUpdated, object: nil, userInfo: ["pathPixelKey": key])
                                    savePathPixelURL(key: key, ppURL: value)
                                    savePathPixelLocalUrl(key: key, url: url)
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
                    let ppUrl: String = value
                    let urlComponents = URLComponents(string: ppUrl)
                    OlympusFileDownloader.shared.downloadCSVFile(from: (urlComponents?.url)!, fname: key, completion: { [self] url, error in
                        if error == nil {
                            do {
                                let contents = try String(contentsOf: url!)
                                ( PpType[key], PpNode[key], PpCoord[key], PpMagScale[key], PpHeading[key] ) = parseRoad(data: contents)
                                NotificationCenter.default.post(name: .sectorPathPixelUpdated, object: nil, userInfo: ["pathPixelKey": key])
                                savePathPixelURL(key: key, ppURL: value)
                                savePathPixelLocalUrl(key: key, url: url)
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
                    let ppUrl: String = value
                    let urlComponents = URLComponents(string: ppUrl)
                    OlympusFileDownloader.shared.downloadCSVFile(from: (urlComponents?.url)!, fname: key, completion: { [self] url, error in
                        if error == nil {
                            do {
                                let contents = try String(contentsOf: url!)
                                print(key)
                                ( PpType[key], PpNode[key], PpCoord[key], PpMagScale[key], PpHeading[key] ) = parseRoad(data: contents)
                                NotificationCenter.default.post(name: .sectorPathPixelUpdated, object: nil, userInfo: ["pathPixelKey": key])
                                savePathPixelURL(key: key, ppURL: value)
                                savePathPixelLocalUrl(key: key, url: url)
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
        var isSuccess = false
        var xyhs: [Double] = [x, y, heading, 1.0]
        var bestHeading = heading

        let levelCopy = removeLevelDirectionString(levelName: level)
        let key = "\(self.sector_id)_\(building)_\(levelCopy)"

        guard !building.isEmpty, !level.isEmpty,
              let mainType = self.PpType[key],
              let mainRoad = self.PpCoord[key],
              let mainMagScale = self.PpMagScale[key],
              let mainHeading = self.PpHeading[key] else {
            return (isSuccess, xyhs, bestHeading)
        }

        let pathMatchingArea = self.checkInEntranceMatchingArea(x: x, y: y, building: building, level: levelCopy)

        var idshArray = [[Double]]()
        var idshArrayWhenFail = [[Double]]()

        if !mainRoad.isEmpty {
            let roadX = mainRoad[0]
            let roadY = mainRoad[1]

            var xMin = x - PADDING_VALUES[0]
            var xMax = x + PADDING_VALUES[2]
            var yMin = y - PADDING_VALUES[1]
            var yMax = y + PADDING_VALUES[3]
            
            if PADDING_VALUES[0] != 0 || PADDING_VALUES[1] != 0 || PADDING_VALUES[2] != 0 || PADDING_VALUES[3] != 0 {
                if pathMatchingArea.0 {
                    xMin = pathMatchingArea.1[0]
                    yMin = pathMatchingArea.1[1]
                    xMax = pathMatchingArea.1[2]
                    yMax = pathMatchingArea.1[3]
                }
            }

            for i in 0..<roadX.count {
                let xPath = roadX[i]
                let yPath = roadY[i]
                let pathTypeLoaded = mainType[i]

                // Skip this path type if conditions aren't met
                if pathType == 1 && pathTypeLoaded == 0 { continue }

                // Check if the path is within the bounding box
                if xPath >= xMin && xPath <= xMax, yPath >= yMin && yPath <= yMax {
                    let distance = sqrt(pow(x - xPath, 2) + pow(y - yPath, 2))
                    let magScale = mainMagScale[i]
                    var idsh: [Double] = [Double(i), distance, magScale, heading]
                    idshArrayWhenFail.append(idsh)

                    if isUseHeading {
                        if let headingData = getHeadingDataArray(mainHeading[i]) {
                            let (isValid, correctedHeading) = validateHeading(heading: heading, HEADING_RANGE: HEADING_RANGE, headingData: headingData, x: xPath, y: yPath)
                            if isValid {
                                idsh[3] = correctedHeading
                                idshArray.append(idsh)
                            }
                        }
                    } else {
                        idshArray.append(idsh)
                    }
                }
            }

            if !idshArray.isEmpty {
                processIdshArray(&idshArray, roadX, roadY, &xyhs, &bestHeading, isUseHeading)
                isSuccess = true
            } else {
                processFailedIdshArray(&idshArrayWhenFail, mainHeading, roadX, roadY, &xyhs, &bestHeading)
            }
        }

        xyhs[2] = compensateHeading(heading: xyhs[2])
        return (isSuccess, xyhs, bestHeading)
    }

    private func getHeadingDataArray(_ headingString: String) -> [Double]? {
        let headingData = headingString.components(separatedBy: ",").compactMap { Double($0) }
        return headingData.isEmpty ? nil : headingData
    }

    private func validateHeading(heading: Double, HEADING_RANGE: Double, headingData: [Double], x: Double, y: Double) -> (Bool, Double) {
        var diffHeading = [Double]()
        for mapHeading in headingData {
            let adjustedHeading = adjustHeading(heading, mapHeading)
            diffHeading.append(abs(adjustedHeading))
        }
        if let minHeading = diffHeading.min() {
            let valid = minHeading < HEADING_RANGE
            return (valid, headingData[diffHeading.firstIndex(of: minHeading)!])
        }
        return (false, heading)
    }

    private func adjustHeading(_ heading: Double, _ mapHeading: Double) -> Double {
        if heading > 270 && mapHeading < 90 {
            return abs(heading - (mapHeading + 360))
        } else if mapHeading > 270 && heading < 90 {
            return abs(mapHeading - (heading + 360))
        } else {
            return abs(heading - mapHeading)
        }
    }

    private func processIdshArray(_ idshArray: inout [[Double]], _ roadX: [Double], _ roadY: [Double], _ xyhs: inout [Double], _ bestHeading: inout Double, _ isUseHeading: Bool) {
        let sortedIdsh = idshArray.sorted(by: { $0[1] < $1[1] })
        if let minData = sortedIdsh.first {
            let index = Int(minData[0])
            let correctedScale = max(minData[2], 0.7)
            let correctedHeading = isUseHeading ? minData[3] : xyhs[2]
            xyhs = [roadX[index], roadY[index], correctedHeading, correctedScale]
            bestHeading = correctedHeading
        }
    }

    private func processFailedIdshArray(_ idshArrayWhenFail: inout [[Double]], _ mainHeading: [String], _ roadX: [Double], _ roadY: [Double], _ xyhs: inout [Double], _ bestHeading: inout Double) {
        let sortedIdsh = idshArrayWhenFail.sorted(by: { $0[1] < $1[1] })
        if let minData = sortedIdsh.first {
            let index = Int(minData[0])
            xyhs = [roadX[index], roadY[index], xyhs[2], max(minData[2], 0.7)]
            if let headingData = getHeadingDataArray(mainHeading[index]) {
                bestHeading = headingData.min() ?? xyhs[2]
            }
        }
    }

    
    public func checkInEntranceMatchingArea(x: Double, y: Double, building: String, level: String) -> (Bool, [Double]) {
        var area = [Double]()
        
        let buildingName = building
        let levelName = removeLevelDirectionString(levelName: level)
        
        let key = "\(self.sector_id)_\(buildingName)_\(levelName)"
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
        let key: String = "\(self.sector_id)_\(building)_\(levelCopy)"
        
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
        let diffH = abs(currentResultHeading - pastResultHeading)
        
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
        var isPossibleNode: Bool = true
        
        let key: String = "\(self.sector_id)_\(building)_\(level)"
        if (true) {
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
                    if (updateType == .STABLE) {
                        // 현재 위치에서부터 반대 방향으로 N m 까지 확인해서 가장 가까운 Node 찾기
                        for i in 0..<roadX.count {
                            let xPath = roadX[i]
                            let yPath = roadY[i]
                            let node = mainNode[i]
                            let headingArray = mainHeading[i]
                            
                            let pathTypeLoaded = mainType[i]
                            if (pathType == 1) {
                                if pathTypeLoaded == 0 {
                                    continue
                                } else if pathTypeLoaded == 2 {
                                    isPossibleNode = false
                                } else {
                                    isPossibleNode = true
                                }
                            } else {
                                isPossibleNode = true
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
                                            
//                                            print(getLocalTimeString() + " , (Olympus) Node Find : passedNode (Phase5 (1)) = \(matchedNodeResult.1) // dist = none // index = \(passedNodeMatchedIndex) // heading = \(currentResultHeading)")
                                            currentPassedNodeInfo = PassedNodeInfo(nodeNumber: self.passedNode, nodeCoord: self.passedNodeCoord, nodeHeadings: self.passedNodeHeadings, matchedIndex: self.passedNodeMatchedIndex, userHeading: currentResultHeading)
                                            controlPassedNodeInfo(passedNodeInfo: PassedNodeInfo(nodeNumber: self.passedNode, nodeCoord: self.passedNodeCoord, nodeHeadings: self.passedNodeHeadings, matchedIndex: self.passedNodeMatchedIndex, userHeading: currentResultHeading))
                                            controlPassedNodeInfoForMulti(passedNodeInfo: PassedNodeInfo(nodeNumber: self.passedNode, nodeCoord: self.passedNodeCoord, nodeHeadings: self.passedNodeHeadings, matchedIndex: self.passedNodeMatchedIndex, userHeading: currentResultHeading))
                                            break
                                        }
                                    }
                                }
                                
                                self.linkCoord = [xPath, yPath]
                                self.linkDirections = ppHeadingValues
                                if (node != 0 && isPossibleNode) {
                                    self.isInNode = true
                                    self.passedNode = node
                                    self.passedNodeMatchedIndex = uvdIndex
                                    self.passedNodeCoord = [xPath, yPath]
                                    self.passedNodeHeadings = ppHeadingValues
                                    self.distFromNode = sqrt((xPath-x)*(xPath-x) + (yPath-y)*(yPath-y))
//                                    print(getLocalTimeString() + " , (Olympus) Node Find : passedNode (Phase5 (2)) = \(self.passedNode) // dist = \(self.distFromNode) // index = \(passedNodeMatchedIndex) // heading = \(currentResultHeading)")
                                    currentPassedNodeInfo = PassedNodeInfo(nodeNumber: self.passedNode, nodeCoord: self.passedNodeCoord, nodeHeadings: self.passedNodeHeadings, matchedIndex: self.passedNodeMatchedIndex, userHeading: currentResultHeading)
                                    controlPassedNodeInfo(passedNodeInfo: PassedNodeInfo(nodeNumber: self.passedNode, nodeCoord: self.passedNodeCoord, nodeHeadings: self.passedNodeHeadings, matchedIndex: self.passedNodeMatchedIndex, userHeading: currentResultHeading))
                                    controlPassedNodeInfoForMulti(passedNodeInfo: PassedNodeInfo(nodeNumber: self.passedNode, nodeCoord: self.passedNodeCoord, nodeHeadings: self.passedNodeHeadings, matchedIndex: self.passedNodeMatchedIndex, userHeading: currentResultHeading))
                                } else {
                                    self.isInNode = false
//                                    self.linkCoord = [xPath, yPath]
//                                    self.linkDirections = ppHeadingValues
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
                                if pathTypeLoaded == 0 {
                                    continue
                                } else if pathTypeLoaded == 2 {
                                    isPossibleNode = false
                                } else {
                                    isPossibleNode = true
                                }
                            } else {
                                isPossibleNode = true
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
                                        self.linkCoord = [xPath, yPath]
                                        self.linkDirections = ppHeadingValues
                                        
                                        if (node != 0 && isPossibleNode) {
//                                            self.linkCoord = [xPath, yPath]
                                            
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
                                            let passedNodeInfo = PassedNodeInfo(nodeNumber: node, nodeCoord: [xPath, yPath], nodeHeadings: ppHeadingValues, matchedIndex: uvdIndex, userHeading: currentResultHeading)
                                            passedNodeInfoBuffer.append(passedNodeInfo)
                                        } else {
                                            self.isInNode = false
//                                            self.linkCoord = [xPath, yPath]
//                                            self.linkDirections = ppHeadingValues
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
                            self.passedNode = passedNodeInfo.nodeNumber
                            self.passedNodeMatchedIndex = passedNodeInfo.matchedIndex
                            self.passedNodeCoord = passedNodeInfo.nodeCoord
                            self.passedNodeHeadings = passedNodeInfo.nodeHeadings
                            
                            currentPassedNodeInfo = passedNodeInfo
                            controlPassedNodeInfo(passedNodeInfo: passedNodeInfo)
                            controlPassedNodeInfoForMulti(passedNodeInfo: PassedNodeInfo(nodeNumber: self.passedNode, nodeCoord: self.passedNodeCoord, nodeHeadings: self.passedNodeHeadings, matchedIndex: self.passedNodeMatchedIndex, userHeading: currentResultHeading))
                        }
//                        print(getLocalTimeString() + " , (Olympus) Node Find : passedNode (PATH_TRAJ_MATCHING) = \(self.passedNode) // index = \(self.passedNodeMatchedIndex) // heading = \(self.passedNodeHeadings)")
                    } else {
                        for i in 0..<roadX.count {
                            let xPath = roadX[i]
                            let yPath = roadY[i]
                            let node = mainNode[i]
                            let headingArray = mainHeading[i]
                            
                            let pathTypeLoaded = mainType[i]
                            if (pathType == 1) {
                                if pathTypeLoaded == 0 {
                                    continue
                                } else if pathTypeLoaded == 2 {
                                    isPossibleNode = false
                                } else {
                                    isPossibleNode = true
                                }
                            } else {
                                isPossibleNode = true
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
                                        self.linkDirections = ppHeadingValues
                                        if (node != 0 && isPossibleNode) {
                                            self.isInNode = true
                                            isNodePassed = true
                                            self.passedNode = node
                                            self.passedNodeMatchedIndex = uvdIndex
                                            self.passedNodeCoord = [xPath, yPath]
                                            self.passedNodeHeadings = ppHeadingValues
                                            self.distFromNode = sqrt((xPath-x)*(xPath-x) + (yPath-y)*(yPath-y))
//                                            print(getLocalTimeString() + " , (Olympus) Node Find : passedNode (Normal) = \(self.passedNode) // dist = \(self.distFromNode) // index = \(passedNodeMatchedIndex) // heading = \(currentResultHeading)")
                                            currentPassedNodeInfo = PassedNodeInfo(nodeNumber: self.passedNode, nodeCoord: self.passedNodeCoord, nodeHeadings: self.passedNodeHeadings, matchedIndex: self.passedNodeMatchedIndex, userHeading: currentResultHeading)
                                            controlPassedNodeInfo(passedNodeInfo: PassedNodeInfo(nodeNumber: self.passedNode, nodeCoord: self.passedNodeCoord, nodeHeadings: self.passedNodeHeadings, matchedIndex: self.passedNodeMatchedIndex, userHeading: currentResultHeading))
                                            controlPassedNodeInfoForMulti(passedNodeInfo: PassedNodeInfo(nodeNumber: self.passedNode, nodeCoord: self.passedNodeCoord, nodeHeadings: self.passedNodeHeadings, matchedIndex: self.passedNodeMatchedIndex, userHeading: currentResultHeading))
                                        } else {
                                            self.isInNode = false
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
                                            
                                            self.linkCoord = [currentResult.x, currentResult.y]
                                            self.linkDirections = ppHeadingValues
                                            
//                                            print(getLocalTimeString() + " , (Olympus) Node Find : passedNode (Jump) = \(self.passedNode) // dist = \(self.distFromNode) // index = \(passedNodeMatchedIndex) // heading = \(currentResultHeading)")
                                            
                                            currentPassedNodeInfo = PassedNodeInfo(nodeNumber: self.passedNode, nodeCoord: self.passedNodeCoord, nodeHeadings: self.passedNodeHeadings, matchedIndex: self.passedNodeMatchedIndex, userHeading: currentResultHeading)
                                            controlPassedNodeInfo(passedNodeInfo: PassedNodeInfo(nodeNumber: self.passedNode, nodeCoord: self.passedNodeCoord, nodeHeadings: self.passedNodeHeadings, matchedIndex: self.passedNodeMatchedIndex, userHeading: currentResultHeading))
                                            controlPassedNodeInfoForMulti(passedNodeInfo: PassedNodeInfo(nodeNumber: self.passedNode, nodeCoord: self.passedNodeCoord, nodeHeadings: self.passedNodeHeadings, matchedIndex: self.passedNodeMatchedIndex, userHeading: currentResultHeading))
                                        } else {
//                                            print(getLocalTimeString() + " , (Olympus) Node Find : passedNode (Jump) // minValue over 20 (minValue = \(minValue))")
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
//            print(getLocalTimeString() + " , (Olympus) Node Find : passedNode = \(currentNode)")
        }
        
        self.passedNodeInfoBuffer.append(passedNodeInfo)
        if (self.passedNodeInfoBuffer.count > 30) {
            self.passedNodeInfoBuffer.remove(at: 0)
        }
        
        if (isNeedClearBuffer) {
//            print(getLocalTimeString() + " , (Olympus) Node Find : before -> passedNodeInfoBuffer = \(passedNodeInfoBuffer)")
            let pastBuffer = self.passedNodeInfoBuffer
            var newBuffer = [PassedNodeInfo]()
            var startIndex: Int = 0
            var isFind: Bool = false
            for i in 0..<pastBuffer.count {
                if pastBuffer[i].nodeNumber == self.anchorNode.nodeNumber {
                    startIndex = i
                    isFind = true
                    break
                }
            }
            
            if (isFind) {
                for i in startIndex..<pastBuffer.count {
                    newBuffer.append(pastBuffer[i])
                }
            } else {
                newBuffer.append(self.anchorNode)
            }
            
            self.passedNodeInfoBuffer = newBuffer
            isNeedClearBuffer = false
//            print(getLocalTimeString() + " , (Olympus) Node Find : after -> passedNodeInfoBuffer = \(passedNodeInfoBuffer)")
        }
    }
    
    private func controlPassedNodeInfoForMulti(passedNodeInfo: PassedNodeInfo) {
        if (self.passedNodeInfoBufferForMulti.count > 1) {
            let currentNode = passedNodeInfo.nodeNumber
            let pastNode = passedNodeInfoBufferForMulti[passedNodeInfoBufferForMulti.count-1].nodeNumber
            
            if (currentNode == pastNode) {
                self.passedNodeInfoBufferForMulti.remove(at: passedNodeInfoBufferForMulti.count-1)
            }
        }
        self.passedNodeInfoBufferForMulti.append(passedNodeInfo)
        if (self.passedNodeInfoBufferForMulti.count > 5) {
            self.passedNodeInfoBufferForMulti.remove(at: 0)
        }
    }
    
    public func getPassedNodeInfoBuffer() -> [PassedNodeInfo] {
        return self.passedNodeInfoBuffer
    }
    
    public func getPaddingValues(mode: String, isPhaseBreak: Bool, PADDING_VALUE: Double) -> [Double] {
        var paddingValues: [Double] = [0, 0, 0, 0]
        
        if (isPhaseBreak) {
            paddingValues = [Double] (repeating: PADDING_VALUE, count: 4)
            return paddingValues
        }
        
        let directions = linkDirections
        
        var isDefault: Bool = true
        if directions.count == 2 {
            var xyLimitValue: Double = 30
            if (mode == OlympusConstants.MODE_PDR) {
                xyLimitValue = xyLimitValue - 5
            }
            if (directions.contains(0) && directions.contains(180)) {
                paddingValues = [xyLimitValue, 1, xyLimitValue, 1]
                isDefault = false
            } else if (directions.contains(90) && directions.contains(270)) {
                paddingValues = [1, xyLimitValue, 1, xyLimitValue]
                isDefault = false
            } else {
                if let closestDir = determineClosestDirection(for: (directions[0], directions[1])) {
                    if closestDir == "hor" {
                        paddingValues = [xyLimitValue/2, 3, xyLimitValue/2, 3]
                    } else {
                        paddingValues = [3, xyLimitValue/2, 3, xyLimitValue/2]
                    }
                    isDefault = false
                }
            }
        }
        
        var defaultPaddingValue = PADDING_VALUE
        if (mode == OlympusConstants.MODE_PDR) {
            defaultPaddingValue = defaultPaddingValue/2
        }
        
        if (isDefault) {
            paddingValues = [Double] (repeating: defaultPaddingValue, count: 4)
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
    
    public func checkIsInMapEnd(resultStandard: FineLocationTrackingFromServer, tuResult: FineLocationTrackingFromServer, pathType: Int) -> Bool {
        var isInMapEnd: Bool = false
        let modeInput = pathType == 1 ? OlympusConstants.MODE_DR : OlympusConstants.MODE_PDR
        let coordHeadings = getPathMatchingHeadings(building: resultStandard.building_name, level: resultStandard.level_name, x: resultStandard.x, y: resultStandard.y, PADDING_VALUE: 0.0, mode: modeInput)
        let tuHeading = resultStandard.absolute_heading
        
        if !coordHeadings.isEmpty {
//            print(getLocalTimeString() + " , (Olympus) Check Map End : Index = \(resultStandard.index) // xyh = [\(resultStandard.x), \(resultStandard.y), \(resultStandard.absolute_heading)]")
//            print(getLocalTimeString() + " , (Olympus) Check Map End : coordHeadings = \(coordHeadings)")
//            print(getLocalTimeString() + " , (Olympus) Check Map End : tuHeading = \(tuHeading)")
            var diffHeading = [Double]()
            var bestHeading: Double = tuResult.absolute_heading
            for dir in coordHeadings {
                var diffValue: Double = 0
                if (tuHeading > 270 && (dir >= 0 && dir < 90)) {
                    diffValue = abs(tuHeading - (dir+360))
                } else if (dir > 270 && (tuHeading >= 0 && tuHeading < 90)) {
                    diffValue = abs(dir - (tuHeading+360))
                } else {
                    diffValue = abs(tuHeading - dir)
                }
                diffHeading.append(diffValue)
            }
//            print(getLocalTimeString() + " , (Olympus) Check Map End : diffHeading = \(diffHeading)")
            let minHeading = diffHeading.min()!
            if let minIndex = diffHeading.firstIndex(of: minHeading) {
                bestHeading = coordHeadings[minIndex]
            }
//            print(getLocalTimeString() + " , (Olympus) Check Map End : bestHeading = \(bestHeading)")
            if bestHeading.truncatingRemainder(dividingBy: 90.0) == 0 {
                var resultForEndCheck = resultStandard
                resultForEndCheck.x += cos(bestHeading*OlympusConstants.D2R)
                resultForEndCheck.y += sin(bestHeading*OlympusConstants.D2R)
//                print(getLocalTimeString() + " , (Olympus) Check Map End (1) : \(resultForEndCheck.building_name) \(resultForEndCheck.level_name) // xyh = [\(resultForEndCheck.x), \(resultForEndCheck.y), \(resultForEndCheck.absolute_heading)]")
                let pathMatchingResult = OlympusPathMatchingCalculator.shared.pathMatching(building: resultForEndCheck.building_name, level: resultForEndCheck.level_name, x: resultForEndCheck.x, y: resultForEndCheck.y, heading: resultForEndCheck.absolute_heading, HEADING_RANGE: OlympusConstants.HEADING_RANGE, isUseHeading: false, pathType: pathType, PADDING_VALUES: [0, 0, 0, 0])
//                print(getLocalTimeString() + " , (Olympus) Check Map End (1) : pathMatchingResult = \(pathMatchingResult)")
                if !pathMatchingResult.isSuccess {
                    isInMapEnd = true
//                    print(getLocalTimeString() + " , (Olympus) Check Map End (1) : isInMapEnd = \(isInMapEnd)")
                }
            } else {
                var checkValues = [[Double]]()
                let dividedValue = round(bestHeading/90)
//                print(getLocalTimeString() + " , (Olympus) Check Map End : dividedValue = \(dividedValue)")
                if dividedValue == 0 || dividedValue == 4 {
                    // 0도에 가깝
                    checkValues = [[1, 1], [1, 0], [1, -1]]
                } else if dividedValue == 1 {
                    // 90도에 가깝
                    checkValues = [[-1, 1], [0, 1], [1, 1]]
                } else if dividedValue == 2 {
                    // 180도에 가깝
                    checkValues = [[-1, 1], [-1, 0], [-1, -1]]
                } else {
                    // 270도에 가깝
                    checkValues = [[-1, -1], [0, -1], [1, -1]]
                }
                
                var failCount = 0
                for v in checkValues {
                    let xToCheck = resultStandard.x + v[0]
                    let yToCheck = resultStandard.y + v[1]
//                    print(getLocalTimeString() + " , (Olympus) Check Map End : Index = \(tuResult.index) // xyToCheck = [\(xToCheck), \(yToCheck)]")
                    let pathMatchingResult = OlympusPathMatchingCalculator.shared.pathMatching(building: resultStandard.building_name, level: resultStandard.level_name, x: xToCheck, y: yToCheck, heading: resultStandard.absolute_heading, HEADING_RANGE: OlympusConstants.HEADING_RANGE, isUseHeading: false, pathType: pathType, PADDING_VALUES: [0, 0, 0, 0])
                    if !pathMatchingResult.isSuccess {
//                        print(getLocalTimeString() + " , (Olympus) Check Map End : isSuccess = \(pathMatchingResult.isSuccess)")
                        failCount += 1
                    }
                }
//                print(getLocalTimeString() + " , (Olympus) Check Map End : failCount = \(failCount) // checkValues.count = \(checkValues.count)")
                if failCount == checkValues.count {
                    isInMapEnd = true
                }
            }
        }
        
        return isInMapEnd
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
        self.isNeedClearUVDBuffer = true
//        print(getLocalTimeString() + " , (Olympus) Node Find : Anchor Node After PathTrajMatching = \(self.anchorNode)")
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
                self.isNeedClearUVDBuffer = true
            }
        }
//        print(getLocalTimeString() + " , (Olympus) Node Find : Anchor Node = \(self.anchorNode)")
    }
    
    public func updateAnchorNodeAfterRecovery(badCaseNodeInfo: NodeCandidateInfo, nodeNumber: Int) {
        let nodeCandidatesInfo = badCaseNodeInfo.nodeCandidatesInfo
        for item in nodeCandidatesInfo {
            if item.nodeNumber == nodeNumber {
                self.anchorNode = item
            }
        }
//        print(getLocalTimeString() + " , (Olympus) Node Find : Anchor Node Recover = \(self.anchorNode)")
    }
    
    public func getCurrentAnchorNodeInfo() -> PassedNodeInfo {
        if self.anchorNode.nodeCoord.isEmpty {
            self.anchorNode.nodeCoord = self.buildingLevelChangedCoord
        }
        return self.anchorNode
    }
    
    public func setBuildingLevelChangedCoord(coord: [Double]) {
        self.buildingLevelChangedCoord = coord
    }
    
    public func controlUVDforAccBias(unitDRInfo: UnitDRInfo) {
        self.unitDRInfoBuffer.append(unitDRInfo)
//        if (self.unitDRInfoBuffer.count > 30) {
//            self.unitDRInfoBuffer.remove(at: 0)
//        }

        if (isNeedClearUVDBuffer) {
            let pastBuffer = self.unitDRInfoBuffer
            var newBuffer = [UnitDRInfo]()
            var startIndex: Int = 0
            var isFind: Bool = false
            for i in 0..<pastBuffer.count {
                if pastBuffer[i].index == self.anchorNode.matchedIndex {
                    startIndex = i
                    isFind = true
                    break
                }
            }
            
            if (isFind) {
                for i in startIndex..<pastBuffer.count {
                    newBuffer.append(pastBuffer[i])
                }
            }
            
            self.unitDRInfoBuffer = newBuffer
            isNeedClearUVDBuffer = false
        }
    }
    
    public func getUnitDRInfoBuffer() -> [UnitDRInfo] {
        return self.unitDRInfoBuffer
    }
    
    public func calScVelocity(resultIndex: Int, scCompensation: Double) -> (Bool, Double, Double) {
        let drBuffer = self.unitDRInfoBuffer
        if drBuffer.isEmpty {
            return (false, -1, -1)
        }
        
        var distance: Double = 0
        var diffTime: Double = 0
        for value in drBuffer {
            if value.index <= resultIndex {
                distance += value.length
            }
            
            if value.index == resultIndex {
                diffTime = value.time - drBuffer[0].time
            }
        }
        
        distance *= scCompensation
        print(getLocalTimeString() + " , (Olympus) SC Velocity : \(distance) , \(diffTime) , \(distance/(diffTime*1e-3))")
        return (false, distance, diffTime)
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
//            print(getLocalTimeString() + " , (Olympus) Node Find : getAnchorNodeCandidatesForBadCase // anchorNode is Empty")
            return NodeCandidateInfo(isPhaseBreak: true, nodeCandidatesInfo: [])
        } else {
            let anchorNodeInfo = self.anchorNode
            let nodeCoord = anchorNodeInfo.nodeCoord
            let nodeHeadings = anchorNodeInfo.nodeHeadings
            let nodeMatchedIndex = anchorNodeInfo.matchedIndex
            
            var heading = fltResult.absolute_heading
            if (nodeCoord != linkCoord) {
                heading = getUserDirection(from: nodeCoord, to: linkCoord)
//                print(getLocalTimeString() + " , (Olympus) Node Find : getAnchorNodeCandidatesForBadCase // getUserDirection = \(heading)")
            } else {
                var minValue: Double = 360
                for mapHeading in nodeHeadings {
                    var diffValue: Double = 0
                    if (heading > 270 && (mapHeading >= 0 && mapHeading < 90)) {
                        diffValue = abs(heading - (mapHeading+360))
                    } else if (mapHeading > 270 && (heading >= 0 && heading < 90)) {
                        diffValue = abs(mapHeading - (heading+360))
                    } else {
                        diffValue = abs(heading - mapHeading)
                    }
                    if diffValue < minValue {
                        heading = mapHeading
                        minValue = diffValue
                    }
                }
//                print(getLocalTimeString() + " , (Olympus) Node Find : getAnchorNodeCandidatesForBadCase // else = \(heading)")
            }
//            print(getLocalTimeString() + " , (Olympus) Node Find : getAnchorNodeCandidatesForBadCase // heading = \(heading) , anchorNodeInfo = \(anchorNodeInfo)")
            
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
//            print(getLocalTimeString() + " , (Olympus) Node Find : getAnchorNodeCandidatesForBadCase // candidateDirections = \(candidateDirections)")
            
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
//                    print(getLocalTimeString() + " , (Olympus) Node Find : getAnchorNodeCandidatesForBadCase // nodeCoord = \(nodeCoord) // xy = \(x),\(y) // dir = \(direction) // paddingValues = \(paddingValues)")
//                    print(getLocalTimeString() + " , (Olympus) Node Find : getAnchorNodeCandidatesForBadCase // matchedNodeResult = \(matchedNodeResult)")
                    if (matchedNodeResult.0) {
                        break
                    } else {
                        if (matchedNodeResult.1 != -1) {
                            let nearestHeading = getNearestNodeHeading(userHeading: heading, nodeHeadings: matchedNodeResult.2)
                            let coordToCheck: [Double] = [x+cos(nearestHeading*OlympusConstants.D2R), y+sin(nearestHeading*OlympusConstants.D2R)]
                            let isPossibleNode = checkPathPixelHasCoords(fltResult: fltResult, coordToCheck: coordToCheck)
//                            print(getLocalTimeString() + " , (Olympus) Node Find : getAnchorNodeCandidatesForBadCase // isPossibleNode = \(isPossibleNode) // coordToCheck = \(coordToCheck) // heading = \(heading)")
                            if (isPossibleNode) {
                                let nodeInfo = PassedNodeInfo(nodeNumber: matchedNodeResult.1, nodeCoord: [x, y], nodeHeadings: matchedNodeResult.2, matchedIndex: nodeMatchedIndex, userHeading: heading)
                                nodeCandidatesInfo.append(nodeInfo)
//                                break
                            }
                        }
                    }
                }
            }
            
            badCaseNodeInfo = NodeCandidateInfo(isPhaseBreak: false, nodeCandidatesInfo: nodeCandidatesInfo)
//            print(getLocalTimeString() + " , (Olympus) Node Find : getAnchorNodeCandidatesForBadCase // candidateNodeNumbers = \(nodeCandidatesInfo)")
        }
        
        return badCaseNodeInfo
    }
    
    public func getAnchorNodeCandidatesForRecovery(fltResult: FineLocationTrackingFromServer, inputNodeCandidateInfo: NodeCandidateInfo, pathType: Int) -> NodeCandidateInfo {
        var recoveryCaseNodeInfo = NodeCandidateInfo(isPhaseBreak: false, nodeCandidatesInfo: [])
        let nodeCandidatesInfo = inputNodeCandidateInfo.nodeCandidatesInfo
        
//        print(getLocalTimeString() + " , (Olympus) Node Find : fltResult node_number = \(fltResult.node_number)")
//        print(getLocalTimeString() + " , (Olympus) Node Find : inputNodeCandidateInfo = \(inputNodeCandidateInfo)")
        var anchorNodeInfo = PassedNodeInfo(nodeNumber: -1, nodeCoord: [], nodeHeadings: [], matchedIndex: -1, userHeading: 0)
        for item in nodeCandidatesInfo {
            if item.nodeNumber == fltResult.node_number {
                anchorNodeInfo = item
            }
        }
        
//        print(getLocalTimeString() + " , (Olympus) Node Find : getAnchorNodeCandidatesForRecovery (1) // anchorNodeInfo = \(anchorNodeInfo)")
        
        if anchorNodeInfo.matchedIndex == -1 {
            return recoveryCaseNodeInfo
        } else {
            let nodeCoord = anchorNodeInfo.nodeCoord
            let nodeHeadings = anchorNodeInfo.nodeHeadings
            let nodeMatchedIndex = anchorNodeInfo.matchedIndex
            
            let heading = getUserDirection(from: nodeCoord, to: linkCoord)
//            print(getLocalTimeString() + " , (Olympus) Node Find : getAnchorNodeCandidatesForRecovery (2) // anchorNodeInfo = \(anchorNodeInfo)")
            
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
//            print(getLocalTimeString() + " , (Olympus) Node Find : getAnchorNodeCandidatesForRecovery // candidateDirections = \(candidateDirections)")
            
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
                            let nearestHeading = getNearestNodeHeading(userHeading: heading, nodeHeadings: matchedNodeResult.2)
                            let coordToCheck: [Double] = [x+cos(nearestHeading*OlympusConstants.D2R), y+sin(nearestHeading*OlympusConstants.D2R)]
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
            recoveryCaseNodeInfo = NodeCandidateInfo(isPhaseBreak: false, nodeCandidatesInfo: nodeCandidatesInfo)
//            print(getLocalTimeString() + " , (Olympus) Node Find : getAnchorNodeCandidatesForRecovery // candidateNodeNumbers = \(nodeCandidatesInfo)")
        }
        
        return recoveryCaseNodeInfo
    }
    
    public func getMultipleAnchorNodeCandidates(fltResult: FineLocationTrackingFromServer, pathType: Int) -> NodeCandidateInfo {
        var multipleNodeInfo = NodeCandidateInfo(isPhaseBreak: false, nodeCandidatesInfo: [])
        let anchorNodeInfo = self.anchorNode
//        print(getLocalTimeString() + " , (Olympus) Node Find : getMultipleAnchorNodeCandidates (1) // anchorNodeInfo = \(anchorNodeInfo)")
        if anchorNodeInfo.matchedIndex == -1 {
            return multipleNodeInfo
        } else {
            let nodeCoord = anchorNodeInfo.nodeCoord
            let nodeHeadings = anchorNodeInfo.nodeHeadings
            let nodeMatchedIndex = anchorNodeInfo.matchedIndex
            
            let heading = nodeCoord == linkCoord ? anchorNodeInfo.userHeading : getUserDirection(from: nodeCoord, to: linkCoord)
//            print(getLocalTimeString() + " , (Olympus) Node Find : getMultipleAnchorNodeCandidates (2) // anchorNodeInfo = \(anchorNodeInfo)")
            
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
//            print(getLocalTimeString() + " , (Olympus) Node Find : getMultipleAnchorNodeCandidates // candidateDirections = \(candidateDirections)")
            
            let PIXEL_LENGTH = OlympusConstants.PIXEL_LENGTH_TO_FIND_NODE*2
            let PIXELS_TO_CHECK = Int(PIXEL_LENGTH)
            
            var nodeCandidatesInfo = [PassedNodeInfo]()
            nodeCandidatesInfo.append(anchorNodeInfo)
            
            for direction in candidateDirections {
                if direction.truncatingRemainder(dividingBy: 90) != 0 {
                    let defaultValue = PIXEL_LENGTH+10
                    var distanceValue: Double = defaultValue
                    let x: Double = nodeCoord[0]
                    let y: Double = nodeCoord[1]
                    
                    let dx = cos(direction*OlympusConstants.D2R)*PIXEL_LENGTH
                    let dy = sin(direction*OlympusConstants.D2R)*PIXEL_LENGTH
                    
                    // xMin xMax yMin yMax
                    var nodeSearchRange: [Double] = [0, 0, 0, 0]
                    if dx > 0 {
                        nodeSearchRange[0] = x
                        nodeSearchRange[1] = x+dx
                    } else {
                        nodeSearchRange[0] = x+dx
                        nodeSearchRange[1] = x
                    }
                    
                    if dy > 0 {
                        nodeSearchRange[2] = y
                        nodeSearchRange[3] = y+dy
                    } else {
                        nodeSearchRange[2] = y+dy
                        nodeSearchRange[3] = y
                    }
                    
                    var matchedNodeInfo = PassedNodeInfo(nodeNumber: -1, nodeCoord: [], nodeHeadings: [], matchedIndex: nodeMatchedIndex, userHeading: heading)
                    let matchedNodeCandidates = getNodesInRange(fltResult: fltResult, pathType: pathType, nodeDirection: direction, SEARCH_RANGE: nodeSearchRange)
                    for n in matchedNodeCandidates {
                        let nearestHeading = getNearestNodeHeading(userHeading: heading, nodeHeadings: n.nodeHeadings)
                        let coordToCheck: [Double] = [n.nodeCoord[0]+cos(nearestHeading*OlympusConstants.D2R), n.nodeCoord[1]+sin(nearestHeading*OlympusConstants.D2R)]
                        let isPossibleNode = checkPathPixelHasCoords(fltResult: fltResult, coordToCheck: coordToCheck)
                        if (isPossibleNode) {
                            let distanceX = n.nodeCoord[0]-x
                            let distanceY = n.nodeCoord[1]-y
                            let newDistance = sqrt(distanceX*distanceX + distanceY*distanceY)
                            if newDistance < distanceValue {
                                distanceValue = newDistance
                                matchedNodeInfo = PassedNodeInfo(nodeNumber: n.nodeNumber, nodeCoord: n.nodeCoord, nodeHeadings: n.nodeHeadings, matchedIndex: nodeMatchedIndex, userHeading: heading)
                            }
                        }
                    }
                    if distanceValue != defaultValue {
                        nodeCandidatesInfo.append(matchedNodeInfo)
                    }
                } else {
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
                                let nearestHeading = getNearestNodeHeading(userHeading: heading, nodeHeadings: matchedNodeResult.2)
                                let coordToCheck: [Double] = [x+cos(nearestHeading*OlympusConstants.D2R), y+sin(nearestHeading*OlympusConstants.D2R)]
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
            }
            multipleNodeInfo = NodeCandidateInfo(isPhaseBreak: false, nodeCandidatesInfo: nodeCandidatesInfo)
//            print(getLocalTimeString() + " , (Olympus) Node Find : getMultipleAnchorNodeCandidates // candidateNodeNumbers = \(nodeCandidatesInfo)")
        }
        
        return multipleNodeInfo
    }
    
    public func getPreviousPassedNode(nodeCandidateInfo: NodeCandidateInfo) -> PassedNodeInfo {
        let nodeInfoBuffer = self.passedNodeInfoBufferForMulti
        
        let nodeNumbers = nodeInfoBuffer.map { $0.nodeNumber }
        
        let nodeCandidates = nodeCandidateInfo.nodeCandidatesInfo
        let inputNodeNumbers = nodeCandidates.map { $0.nodeNumber }
        
        var passedNodeInfo = PassedNodeInfo(nodeNumber: -1, nodeCoord: [0, 0], nodeHeadings: [], matchedIndex: 0, userHeading: 0)
        if nodeCandidates.isEmpty {
            return passedNodeInfo
        }
            
        let anchorNodeInfo = nodeCandidates[0]
        let anchorNodes: [Int] = nodeCandidates.map { $0.nodeNumber }
        
        for i in 0..<nodeInfoBuffer.count {
            if anchorNodeInfo.nodeNumber == nodeInfoBuffer[i].nodeNumber {
                break
            }
            passedNodeInfo = nodeInfoBuffer[i]
        }
        
//        print(getLocalTimeString() + " , (Olympus) Node Find : prevPassedNodesNumbers = \(nodeNumbers)")
//        print(getLocalTimeString() + " , (Olympus) Node Find : prevPassedNode = \(passedNodeInfo)")
        return passedNodeInfo
    }
    
    private func findAnchorNode(fltResult: FineLocationTrackingFromServer, pathType: Int) -> PassedNodeInfo {
        let startNodeHeading = passedNodeHeadings
        let nodeInfoBuffer = passedNodeInfoBuffer
//        print(getLocalTimeString() + " , (Olympus) Node Find : nodeInfoBuffer = \(nodeInfoBuffer)")
        
        var resultPassedNodeInfo = PassedNodeInfo(nodeNumber: -1, nodeCoord: [], nodeHeadings: [], matchedIndex: -1, userHeading: 0)
        
        let startCoord = linkCoord
//        print(getLocalTimeString() + " , (Olympus) Node Find : linkCoord = \(self.linkCoord) // linkDirections = \(self.linkDirections)")
        let heading = compensateHeading(heading: fltResult.absolute_heading)
        
        var diffHeading = [Double]()
        var candidateDirections = [Double]()
//        print(getLocalTimeString() + " , (Olympus) Node Find : passedNodeHeadings = \(passedNodeHeadings)")
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
//        print(getLocalTimeString() + " , (Olympus) Node Find : heading = \(heading) // candidateDirections = \(candidateDirections)")

        let sectionLength: Double = 100
        let PIXELS_TO_CHECK = Int(sectionLength)
        
        if (candidateDirections.count == 1) {
            let direction = candidateDirections[0]
            var candidateNodeNumbers = [Int]()
            
            // Add
            if direction.truncatingRemainder(dividingBy: 90) != 0 {
                let linkDirs = linkDirections
                for item in nodeInfoBuffer.reversed() {
                    var validCount = 0
                    for heading in linkDirs {
                        if item.nodeHeadings.contains(heading) {
                            validCount += 1
                        }
                    }
                    if validCount == linkDirs.count {
                        resultPassedNodeInfo = item
                        return resultPassedNodeInfo
                    }
                }
            }
            
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
            
//            print(getLocalTimeString() + " , (Olympus) Node Find : paddingValues = \(paddingValues) // direction = \(direction)")
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
            
//            print(getLocalTimeString() + " , (Olympus) Node Find : candidateNodeNumbers = \(candidateNodeNumbers)")
            for nodeNumber in candidateNodeNumbers.reversed() {
                for item in nodeInfoBuffer {
                    if item.nodeNumber == nodeNumber {
                        resultPassedNodeInfo = item
                        return resultPassedNodeInfo
                    }
                }
            }
        } else {
            let linkDirs = linkDirections
            for item in nodeInfoBuffer.reversed() {
                var validCount = 0
                for heading in linkDirs {
                    if item.nodeHeadings.contains(heading) {
                        validCount += 1
                    }
                }
                if validCount == linkDirs.count {
                    resultPassedNodeInfo = item
                    return resultPassedNodeInfo
                }
            }
        }
        
        if resultPassedNodeInfo.nodeNumber == -1 {
            if nodeInfoBuffer.isEmpty {
                return resultPassedNodeInfo
            }
            
            let currentNodeCoord = nodeInfoBuffer[nodeInfoBuffer.count-1].nodeCoord
            if startCoord[0] == currentNodeCoord[0] && startCoord[1] == currentNodeCoord[1] {
                return nodeInfoBuffer[nodeInfoBuffer.count-1]
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
        let key: String = "\(self.sector_id)_\(building)_\(levelCopy)"
        
        if (!(building.isEmpty) && !(level.isEmpty)) {
            guard let mainRoad: [[Double]] = self.PpCoord[key] else { return false }
            
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
        let key: String = "\(self.sector_id)_\(building)_\(levelCopy)"
        
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
                    // XY 범위 안에 있는 값 중에 검사
                    if (xPath >= xMin && xPath <= xMax) {
                        if (yPath >= yMin && yPath <= yMax) {
                            if (x == xPath && y == yPath) {
                                if (pathType == 1) {
                                    if (pathType != pathTypeLoaded) {
                                        return (false, matchedNode, matchedNodeHeadings)
                                    }
                                }

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
                                    if ppHeadingValues.contains(fltResult.absolute_heading) {
                                        return (false, node, matchedNodeHeadings)
                                    } else {
                                        let userHeading = fltResult.absolute_heading
                                        var diffHeading = [Double]()
                                        for mapHeading in matchedNodeHeadings {
                                            var diffValue: Double = 0
                                            if (userHeading > 270 && (mapHeading >= 0 && mapHeading < 90)) {
                                                diffValue = abs(userHeading - (mapHeading+360))
                                            } else if (mapHeading > 270 && (userHeading >= 0 && userHeading < 90)) {
                                                diffValue = abs(mapHeading - (userHeading+360))
                                            } else {
                                                diffValue = abs(userHeading - mapHeading)
                                            }
                                            diffHeading.append(diffValue)
                                        }
                                        
                                        if let minHeading = diffHeading.min() {
                                            if minHeading < OlympusConstants.HEADING_RANGE-10 {
                                                return (false, node, matchedNodeHeadings)
                                            } else {
                                                return (false, matchedNode, matchedNodeHeadings)
                                            }
                                        } else {
                                            return (false, matchedNode, matchedNodeHeadings)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        return (isPpEndPoint, matchedNode, matchedNodeHeadings)
    }
    
    private func getNodesInRange(fltResult: FineLocationTrackingFromServer, pathType: Int, nodeDirection: Double, SEARCH_RANGE: [Double]) -> [PassedNodeInfo] {
        let building = fltResult.building_name
        let level = fltResult.level_name
        let levelCopy: String = removeLevelDirectionString(levelName: level)
        let key: String = "\(self.sector_id)_\(building)_\(levelCopy)"
        
        let isPpEndPoint: Bool = true
        var nodeCandidates = [PassedNodeInfo]()
        if (!(building.isEmpty) && !(level.isEmpty)) {
            guard let mainType: [Int] = self.PpType[key] else { return nodeCandidates }
            guard let mainRoad: [[Double]] = self.PpCoord[key] else { return nodeCandidates }
            guard let mainNode: [Int] = self.PpNode[key] else { return nodeCandidates }
            guard let mainHeading: [String] = self.PpHeading[key] else { return nodeCandidates }
            
            if (!mainRoad.isEmpty) {
                let roadX = mainRoad[0]
                let roadY = mainRoad[1]
                
                let xMin = SEARCH_RANGE[0]
                let xMax = SEARCH_RANGE[1]
                let yMin = SEARCH_RANGE[2]
                let yMax = SEARCH_RANGE[3]
                
                for i in 0..<roadX.count {
                    let xPath = roadX[i]
                    let yPath = roadY[i]
                    let node = mainNode[i]
                    let headingArray = mainHeading[i]
                    
                    let pathTypeLoaded = mainType[i]
                    // XY 범위 안에 있는 값 중에 검사
                    if (xPath > xMin && xPath < xMax) {
                        if (yPath > yMin && yPath < yMax) {
                            if (pathType == 1) {
                                if (pathType != pathTypeLoaded) {
                                    continue
                                }
                            }
                            
                            if node == 0 {
                                continue
                            } else {
                                var ppHeadingValues = [Double]()
                                let headingData = headingArray.components(separatedBy: ",")
                                for j in 0..<headingData.count {
                                    if(!headingData[j].isEmpty) {
                                        let mapHeading = Double(headingData[j])!
                                        ppHeadingValues.append(mapHeading)
                                    }
                                }
                                if ppHeadingValues.contains(nodeDirection) {
                                    nodeCandidates.append(PassedNodeInfo(nodeNumber: node, nodeCoord: [xPath, yPath], nodeHeadings: ppHeadingValues, matchedIndex: -1, userHeading: 0))
                                }
                            }
                        }
                    }
                }
            }
        }
        return nodeCandidates
    }
    
    private func getNearestNodeHeading(userHeading: Double, nodeHeadings: [Double]) -> Double {
        var nearestHeading = userHeading
        
        var diffHeading = [Double]()
        for mapHeading in nodeHeadings {
            var diffValue: Double = 0
            if (userHeading > 270 && (mapHeading >= 0 && mapHeading < 90)) {
                diffValue = abs(userHeading - (mapHeading+360))
            } else if (mapHeading > 270 && (userHeading >= 0 && userHeading < 90)) {
                diffValue = abs(mapHeading - (userHeading+360))
            } else {
                diffValue = abs(userHeading - mapHeading)
            }
            diffHeading.append(diffValue)
        }
        
        if let minHeading = diffHeading.min() {
            if let minIndex = diffHeading.firstIndex(of: minHeading) {
                nearestHeading = nodeHeadings[minIndex]
            }
        }
        return nearestHeading
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
        
//        print(getLocalTimeString() + " , (Olympus) Path-Matching : userXY = \(x) , \(y)")
//        print(getLocalTimeString() + " , (Olympus) Path-Matching : startHeading = \(startHeading)")
//        print(getLocalTimeString() + " , (Olympus) Path-Matching : diffHeadings = \(diffHeadings)")
//        print(getLocalTimeString() + " , (Olympus) Path-Matching : candidateDirections = \(candidateDirections)")
        var uvdLength: Double = 0
        for uvd in uvdBuffer {
            uvdLength += uvd.length
        }
        
        let PIXELS_TO_CHECK = Int(round(uvdLength + uvdLength*0.2))
//        print(getLocalTimeString() + " , (Olympus) Path-Matching : PIXELS_TO_CHECK = \(PIXELS_TO_CHECK)")
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
//                            break
                        }
                    }
                    
                    if (matchedNodeNumber != -1) {
//                        print(getLocalTimeString() + " , (Olympus) Path-Matching : matchedNodeNumber = \(matchedNodeNumber) // matchedNodeCoord = \(matchedNodeCoord)")
                        let nodeInfo = PathMatchingNodeCandidateInfo(nodeNumber: matchedNodeNumber, nodeCoord: matchedNodeCoord, nodeHeadings: matchedNodeHeadings)
                        pathMatchingNodeCandidates.append(nodeInfo)
                    }
                }
            }
        }
        
        return pathMatchingNodeCandidates
    }
    
    public func getTimeUpdateLimitation(level:String, mode: String) -> (limitType: LimitationType, limitValues: [Double]) {
        var limitType: LimitationType = .NO_LIMIT
        var limitValues: [Double] = [0, 0]
        var LIMIT: Double = 0.8
        
        if (level == "B0") {
            return (limitType, limitValues)
        }
        
        if (mode == OlympusConstants.MODE_PDR) {
            LIMIT = 0.4
        }
        
        let isInNode = self.isInNode
        let coordX = linkCoord[0]
        let coordY = linkCoord[1]
        
        let directions = linkDirections
        
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
                if (pathTypeLoaded == 0) {
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
