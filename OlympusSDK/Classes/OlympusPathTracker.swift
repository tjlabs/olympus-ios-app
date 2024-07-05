
public class OlympusPathTracker {
    static let shared = OlympusPathTracker()
    
    // Path-Pixel Route
    public var PpRouteOrder = [String: [Int]]()
    public var PpRouteCoord = [String: [[Double]]]()
    public var PpRouteHeading = [String: [String]]()
    
    var routeIndex: Int = 0
    var routeOrder: Int = 0
    var pathTrackKey: String = ""
    var pathTrackResult = FineLocationTrackingFromServer()
    
    init() { }
    
    
    public func initialize() {
        routeIndex = 0
        routeOrder = 0
        pathTrackKey = ""
        pathTrackResult = FineLocationTrackingFromServer()
    }
    
    public func setPathTrackStartCoord(fltResult: FineLocationTrackingFromServer, levelDestination: String, entranceNumber: Int, spotInfo: [Double]) {
        pathTrackResult.building_name = fltResult.building_name
        let levelDestinationName = removeLevelDirectionString(levelName: levelDestination)
        pathTrackResult.level_name = levelDestinationName
        pathTrackResult.x = spotInfo[0]
        pathTrackResult.y = spotInfo[1]
        pathTrackResult.absolute_heading = spotInfo[2]
        
        // make pathTrackKey
        if levelDestination == "B2" {
            pathTrackKey = "Route_\(fltResult.building_name)_\(levelDestinationName)_E\(entranceNumber)"
        } else {
            pathTrackKey = "Route_\(fltResult.building_name)_\(levelDestinationName)"
        }
        routeIndex = 0
        routeOrder = 0
        
        print(getLocalTimeString() + " , (Olympus) PathTrack : Init // \(fltResult)")
        print(getLocalTimeString() + " , (Olympus) PathTrack : Init // routeIndex = \(routeIndex)")
        print(getLocalTimeString() + " , (Olympus) PathTrack : Init // routeOrder = \(routeOrder)")
    }
    
    public func getPathTrackResult(length: Double, diffHeading: Double, HEADING_RANGE: Double) -> (isPathTrackFinished: Bool, FineLocationTrackingFromServer) {
        var result = self.pathTrackResult
        
        let updatedHeading = compensateHeading(heading: self.pathTrackResult.absolute_heading + diffHeading)
        let dx = length*cos(updatedHeading*OlympusConstants.D2R)
        let dy = length*sin(updatedHeading*OlympusConstants.D2R)
        
        let updatedX = self.pathTrackResult.x + dx
        let updatedY = self.pathTrackResult.y + dy
        
        result.x = updatedX
        result.y = updatedY
        result.absolute_heading = updatedHeading
        
        let pmResult = pathMatchingInPathTrack(pmResult: result, HEADING_RANGE: HEADING_RANGE)
        
        result.x = pmResult.1[0]
        result.y = pmResult.1[1]
        
        self.pathTrackResult = result
        
        return (pmResult.0, result)
    }
    
    public func pathMatchingInPathTrack(pmResult: FineLocationTrackingFromServer, HEADING_RANGE: Double) -> (isPathTrackFinished: Bool, [Double]) {
        var result = pmResult
        let heading = pmResult.absolute_heading
        
        var xyh: [Double] = [pmResult.x, pmResult.y, heading]
        var bestHeading: Double = heading
        
        let key = self.pathTrackKey
        guard let ppRouteOrder: [Int] = self.PpRouteOrder[key] else {
            return (true, xyh)
        }
        guard let ppRouteCoord: [[Double]] = self.PpRouteCoord[key] else {
            return (true, xyh)
        }
        guard let ppRouteHeading: [String] = self.PpRouteHeading[key] else {
            return (true, xyh)
        }
        
        let routeX = ppRouteCoord[0]
        let routeY = ppRouteCoord[1]
        
        var idhArray = [[Double]]()
        var idhArrayWhenFail = [[Double]]()
        
        for i in (routeIndex+1)..<ppRouteOrder.count {
            if routeOrder == ppRouteOrder[i] || (routeOrder+1) == ppRouteOrder[i] {
                let xPath = routeX[i]
                let yPath = routeY[i]
                
                let index = Double(i)
                let distance = sqrt(pow(pmResult.x-xPath, 2) + pow(pmResult.y-yPath, 2))
                
                var idh: [Double] = [index, distance, heading]
                idhArrayWhenFail.append(idh)
                
                let headingArray = ppRouteHeading[i]
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
                        idh[2] = minHeading
                        
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
                }
                
                if (isValidIdh) {
                    idhArray.append(idh)
                }
            }
        }
        
        if (!idhArray.isEmpty) {
            let sortedIdh = idhArray.sorted(by: {$0[1] < $1[1] })
            var index: Int = 0
            var correctedHeading: Double = heading

            if (!sortedIdh.isEmpty) {
                let minData: [Double] = sortedIdh[0]
                index = Int(minData[0])
                correctedHeading = minData[2]
                routeIndex = index
                routeOrder = ppRouteOrder[index]
            }
            xyh = [routeX[index], routeY[index], correctedHeading]
            bestHeading = correctedHeading
        } else {
//            let sortedIdh = idhArrayWhenFail.sorted(by: {$0[1] < $1[1] })
//            var index: Int = 0
//            
//            if (!sortedIdh.isEmpty) {
//                let minData: [Double] = sortedIdh[0]
//                index = Int(minData[0])
//                routeIndex = index
//                routeOrder = ppRouteOrder[index]
//            }
//            xyh = [routeX[index], routeY[index], heading]
//            
//            let headingArray = ppRouteHeading[index]
//            if (!headingArray.isEmpty) {
//                let headingData = headingArray.components(separatedBy: ",")
//                var diffHeading = [Double]()
//                for j in 0..<headingData.count {
//                    if(!headingData[j].isEmpty) {
//                        let mapHeading = Double(headingData[j])!
//                        if (heading > 270 && (mapHeading >= 0 && mapHeading < 90)) {
//                            diffHeading.append(abs(heading - (mapHeading+360)))
//                        } else if (mapHeading > 270 && (heading >= 0 && heading < 90)) {
//                            diffHeading.append(abs(mapHeading - (heading+360)))
//                        } else {
//                            diffHeading.append(abs(heading - mapHeading))
//                        }
//                    }
//                }
//                
//                if (!diffHeading.isEmpty) {
//                    let idxHeading = diffHeading.firstIndex(of: diffHeading.min()!)
//                    let minHeading = Double(headingData[idxHeading!])!
//                    bestHeading = minHeading
//                }
//            }
        }
        
        print(getLocalTimeString() + " , (Olympus) PathTrack : tracking // routeIndex = \(routeIndex)")
        print(getLocalTimeString() + " , (Olympus) PathTrack : tracking // routeOrder = \(routeOrder)")
        
        if routeIndex == (ppRouteOrder.count-1) {
            return (true, xyh)
        } else {
            return (false, xyh)
        }
    }
    
    
    public func loadPathPixelRoute() {
        // 첫 시작과 동일하게 다운로드 받아오기
        let key = "Route_COEX_B2_E5"
//        let building_n_level = key.split(separator: "_")
        let ppUrl: String = "https://storage.googleapis.com/jupiter_image/ios/pp-7/6/\(key).csv"
        let urlComponents = URLComponents(string: ppUrl)
        OlympusFileDownloader.shared.downloadCSVFile(from: (urlComponents?.url)!, fname: key, completion: { [self] url, error in
            if error == nil {
                do {
                    let contents = try String(contentsOf: url!)
                    ( PpRouteOrder[key], PpRouteCoord[key], PpRouteHeading[key] ) = parsePathPixelRoute(data: contents)
//                    print("PpRoute : Node = \(PpRouteNode[key])")
//                    print("PpRoute : Coord = \(PpRouteCoord[key])")
//                    print("PpRoute : Heading = \(PpRouteHeading[key])")
                } catch {
                    print("Error reading file:", error.localizedDescription)
                }
            } else {
                
            }
        })
    }
    
    public func parsePathPixelRoute(data: String) -> ([Int], [[Double]], [String]) {
        var roadOrder = [Int]()
        var road = [[Double]]()
        var roadHeading = [String]()
        
        var roadX = [Double]()
        var roadY = [Double]()
        
        let roadString = data.components(separatedBy: .newlines)
        for i in 0..<roadString.count {
            if (roadString[i] != "" && roadString[i].count > 4) {
                let lineString = roadString[i]
                let lineData = roadString[i].components(separatedBy: ",")
                
                roadOrder.append(Int(Double(lineData[0])!))
                roadX.append(Double(lineData[1])!)
                roadY.append(Double(lineData[2])!)
                
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
        
        return (roadOrder, road, roadHeading)
    }
}
