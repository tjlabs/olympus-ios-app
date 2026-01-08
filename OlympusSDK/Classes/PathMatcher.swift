
import TJLabsCommon
import TJLabsResource

class PathMatcher {
    static var shared = PathMatcher()
    init() { }
        
    var pathPixelData = [String: PathPixelData]()
    var nodeData = [String: [Int: NodeData]]()
    var linkData = [String: [Int: LinkData]]()
    var entranceMatchingArea = [String: [[Float]]]()
    var entranceArea = [String: [[Float]]]()
    
    func setPathPixelData(key: String, data: PathPixelData) {
        self.pathPixelData[key] = data
    }
    
    func setNodeData(key: String, data: [Int: NodeData]) {
        self.nodeData[key] = data
    }
    
    func setLinkData(key: String, data: [Int: LinkData]) {
        self.linkData[key] = data
    }
    
    func setEntranceMatchingArea(key: String, data: [[Float]]) {
        self.entranceMatchingArea[key] = data
    }
    
    func getEntranceMatchingArea(key: String) -> [[Float]]? {
        return self.entranceMatchingArea[key]
    }
    
    func setEntranceArea(key: String, data: [[Float]]) {
        self.entranceArea[key] = data
    }
    
    func getEntranceArea(key: String) -> [[Float]]? {
        return self.entranceArea[key]
    }
    
    func pathMatching(sectorId: Int, building: String, level: String, x: Float, y: Float, heading: Float, headingRange: Float = 46, isUseHeading: Bool, mode: UserMode, paddingValues: [Float]) -> ixyhs? {
        var ixyhs = ixyhs(x: x, y: y, heading: heading, scale: 1.0)
        var bestHeading = heading
        
        guard !building.isEmpty, !level.isEmpty else { return nil }
        
        let levelName = TJLabsUtilFunctions.shared.removeLevelDirectionString(levelName: level)
        let key = "\(sectorId)_\(building)_\(levelName)"
        
        guard let pathPixelData = checkIsAvailablePathPixelData(key: key) else { return nil }
        let mainType = pathPixelData.roadType
        let mainRoad = pathPixelData.road
        let mainMagScale = pathPixelData.roadScale
        let mainHeading = pathPixelData.roadHeading
        var idshArray = [[Float]]()
        var idshArrayWhenFail = [[Float]]()
        
        if !mainRoad.isEmpty {
            let roadX = mainRoad[0]
            let roadY = mainRoad[1]

            var xMin = x - paddingValues[0]
            var xMax = x + paddingValues[2]
            var yMin = y - paddingValues[1]
            var yMax = y + paddingValues[3]
            
            if paddingValues[0] != 0 || paddingValues[1] != 0 || paddingValues[2] != 0 || paddingValues[3] != 0 {
                if let pathMatchingArea = self.checkInEntranceMatchingArea(sectorId: sectorId, building: building, level: level, x: x, y: y) {
                    xMin = pathMatchingArea[0]
                    yMin = pathMatchingArea[1]
                    xMax = pathMatchingArea[2]
                    yMax = pathMatchingArea[3]
                }
            }
            
            for i in 0..<roadX.count {
                let xPath = roadX[i]
                let yPath = roadY[i]
                let pathTypeLoaded = mainType[i]

                if mode == .MODE_VEHICLE && pathTypeLoaded != 1 { continue }
                if xPath >= xMin && xPath <= xMax, yPath >= yMin && yPath <= yMax {
                    let distance = sqrt(pow(x - xPath, 2) + pow(y - yPath, 2))
                    let magScale = mainMagScale[i]
                    var idsh: [Float] = [Float(i), distance, magScale, heading]
                    idshArrayWhenFail.append(idsh)

                    if isUseHeading {
                        if let headingData = getHeadingDataArray(mainHeading[i]) {
                            let (isValid, correctedHeading) = validateHeading(heading: heading, headingRange: headingRange, headingData: headingData, x: xPath, y: yPath)
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
                let updatedIxyhs = processIdshArray(idshArray: idshArray, roadX: roadX, roadY: roadY, inputXyhs: &ixyhs, bestHeading: &bestHeading, isUseHeading: isUseHeading)
                ixyhs = updatedIxyhs
            } else {
                let updatedIxyhs = processFailedIdshArray(idshArrayWhenFail: idshArrayWhenFail, mainHeading: mainHeading, roadX: roadX, roadY: roadY, inputXyhs: &ixyhs, bestHeading: &bestHeading)
                ixyhs = updatedIxyhs
            }
        }

        ixyhs.heading = Float(TJLabsUtilFunctions.shared.compensateDegree(Double(ixyhs.heading)))
        
        return ixyhs
    }
    
    func getPathMatchingHeadings(sectorId: Int, building: String, level: String, x: Float, y: Float, paddingValue: Float, mode: UserMode) -> [Float] {
        var headings: [Float] = []
        let levelCopy: String = TJLabsUtilFunctions.shared.removeLevelDirectionString(levelName: level)
        
        if (!(building.isEmpty) && !(level.isEmpty)) {
            let key: String = "\(sectorId)_\(building)_\(levelCopy)"
            guard let pathPixelData = self.checkIsAvailablePathPixelData(key: key) else { return headings }
            let mainType = pathPixelData.roadType
            let mainRoad = pathPixelData.road
            let mainHeading = pathPixelData.roadHeading
            
            if (!mainRoad.isEmpty) {
                let roadX = mainRoad[0]
                let roadY = mainRoad[1]
                
                let xMin = x - paddingValue
                let xMax = x + paddingValue
                let yMin = y - paddingValue
                let yMax = y + paddingValue
                
                for i in 0..<roadX.count {
                    let xPath = roadX[i]
                    let yPath = roadY[i]
                    
                    let pathTypeLoaded = mainType[i]
                    if (mode == .MODE_VEHICLE) {
                        if (pathTypeLoaded != 1) {
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
                                        let value = Float(headingData[j])!
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
    
    func getMatchedNodeWithCoord(sectorId: Int, fltResult: FineLocationTrackingOutput, originCoord: [Float], coordToCheck: [Float], pathType: Int, paddingValues: [Float]) -> (Int, [Float])? {
        let building = fltResult.building_name
        let level = fltResult.level_name
        let levelName = TJLabsUtilFunctions.shared.removeLevelDirectionString(levelName: fltResult.level_name)
        let x = coordToCheck[0]
        let y = coordToCheck[1]

        let key: String = "\(sectorId)_\(building)_\(levelName)"

        var matchedNode: Int = -1
        var matchedNodeHeadings = [Float]()

        if (!(building.isEmpty) && !(level.isEmpty)) {
            guard checkIsAvailablePathPixelData(key: key) != nil else { return nil }
            guard let nodeData = self.nodeData[key] else { return nil }

            let userHeading = Double(TJLabsUtilFunctions.shared.compensateDegree(Double(fltResult.absolute_heading)))

            func circularDiff(_ a: Double, _ b: Double) -> Double {
                let d = abs(a - b).truncatingRemainder(dividingBy: 360.0)
                return min(d, 360.0 - d)
            }

            for (nodeId, value) in nodeData {
                let nodeCoord = value.coords
                if nodeCoord[0] == x && nodeCoord[1] == y {
                    matchedNode = nodeId
                    matchedNodeHeadings = value.directions.map { $0.heading }
                    return (matchedNode, matchedNodeHeadings)
                }
            }
        }
        return nil
    }
    
    func checkIsAvailablePathPixelData(key: String) -> PathPixelData? {
        guard let pathPixelData = self.pathPixelData[key] else { return nil }
        
        let mainType = pathPixelData.roadType
        if mainType.isEmpty { return nil }
        
        let mainRoad = pathPixelData.road
        if mainRoad.isEmpty { return nil }
        
        let mainMagScale = pathPixelData.roadScale
        if mainMagScale.isEmpty { return nil }
        
        let mainHeading = pathPixelData.roadHeading
        if mainHeading.isEmpty { return nil }
        
        return pathPixelData
    }
    
    func checkInEntranceMatchingArea(sectorId: Int, building: String, level: String, x: Float, y: Float) -> [Float]? {
        var area = [Float]()
        
        let levelName = TJLabsUtilFunctions.shared.removeLevelDirectionString(levelName: level)
        
        let key = "\(sectorId)_\(building)_\(levelName)"
        guard let entranceMatchingArea = self.entranceMatchingArea[key] else { return nil }
        
        for i in 0..<entranceMatchingArea.count {
            if (!entranceMatchingArea[i].isEmpty) {
                let xMin = entranceMatchingArea[i][0]
                let yMin = entranceMatchingArea[i][1]
                let xMax = entranceMatchingArea[i][2]
                let yMax = entranceMatchingArea[i][3]
                
                if (x >= xMin && x <= xMax) {
                    if (y >= yMin && y <= yMax) {
                        area = entranceMatchingArea[i]
                        return area
                    }
                }
            }
        }
        
        return nil
    }
    
    func checkIsInMapEnd(sectorId: Int, tuResult: FineLocationTrackingOutput) -> Bool {
        let key = "\(sectorId)_\(tuResult.building_name)_\(tuResult.level_name)"
        if !isInNode { return false }
        let curNode = self.curPassedNodeInfo
        if curNode.id == -1 { return false }
        guard let nodeData = nodeData[key] else { return false }
        guard let matchedNode = nodeData[curNode.id] else { return false }
        
        let curHeading = tuResult.absolute_heading
        let nodeHeadings = matchedNode.directions.map({$0.heading})
        let (bestHeading, bestIndex) = closestHeading(to: curHeading, candidates: nodeHeadings)
        let bestIsMapEnd = matchedNode.directions[bestIndex].is_end
        
        return bestIsMapEnd
    }
    
    func checkPathPixelHasCoords(sectorId: Int, fltResult: FineLocationTrackingOutput, coordToCheck: [Float]) -> Bool {
        let building = fltResult.building_name
        let level = fltResult.level_name
        let levelName: String = TJLabsUtilFunctions.shared.removeLevelDirectionString(levelName: level)
        let x = coordToCheck[0]
        let y = coordToCheck[1]
        let key: String = "\(sectorId)_\(building)_\(levelName)"
        
        if (!(building.isEmpty) && !(level.isEmpty)) {
            guard let pathPixelData = checkIsAvailablePathPixelData(key: key) else { return false }
            let mainRoad = pathPixelData.road
            
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
    
    
    private func getHeadingDataArray(_ headingString: String) -> [Float]? {
        let headingData = headingString.components(separatedBy: ",").compactMap { Float($0) }
        return headingData.isEmpty ? nil : headingData
    }

    private func validateHeading(heading: Float, headingRange: Float, headingData: [Float], x: Float, y: Float) -> (Bool, Float) {
        var diffHeading = [Float]()
        for mapHeading in headingData {
            let adjustedHeading = adjustHeading(heading, mapHeading)
            diffHeading.append((abs(adjustedHeading)))
        }
        if let minHeading = diffHeading.min() {
            let valid = minHeading < headingRange
            return (valid, headingData[diffHeading.firstIndex(of: minHeading)!])
        }
        return (false, heading)
    }

    private func adjustHeading(_ heading: Float, _ mapHeading: Float) -> Float {
        if heading > 270 && mapHeading < 90 {
            return abs(heading - (mapHeading + 360))
        } else if mapHeading > 270 && heading < 90 {
            return abs(mapHeading - (heading + 360))
        } else {
            return abs(heading - mapHeading)
        }
    }
    
    private func processIdshArray(idshArray: [[Float]], roadX: [Float], roadY: [Float], inputXyhs: inout ixyhs, bestHeading: inout Float, isUseHeading: Bool) -> ixyhs {
        let sortedIdsh = idshArray.sorted(by: { $0[1] < $1[1] })
        if let minData = sortedIdsh.first {
            let index = Int(minData[0])
            let correctedScale = max(minData[2], 0.7)
            let correctedHeading = isUseHeading ? minData[3] : inputXyhs.heading
            let updatedXyhs: ixyhs = ixyhs(x: roadX[index], y: roadY[index], heading: correctedHeading, scale: correctedScale)
            bestHeading = correctedHeading
            return updatedXyhs
        } else {
            return inputXyhs
        }
    }

    private func processFailedIdshArray(idshArrayWhenFail: [[Float]], mainHeading: [String], roadX: [Float], roadY: [Float], inputXyhs: inout ixyhs, bestHeading: inout Float) -> ixyhs {
        let sortedIdsh = idshArrayWhenFail.sorted(by: { $0[1] < $1[1] })
        if let minData = sortedIdsh.first {
            let index = Int(minData[0])
            let updatedXyhs = ixyhs(x: roadX[index], y: roadY[index], heading: inputXyhs.heading, scale: max(minData[2], 0.7))
            if let headingData = getHeadingDataArray(mainHeading[index]) {
                bestHeading = headingData.min() ?? inputXyhs.heading
            }
            return updatedXyhs
        } else {
            return inputXyhs
        }
    }
    
    func getTimeUpdateLimitation(level: String) -> (limitType: LimitationType, limitValues: [Float]) {
        var limitType: LimitationType = .NO_LIMIT
        var limitValues: [Float] = [0, 0]
        let LIMIT: Float = 0.4
        
        if (level == "B0" || self.isInNode) {
            return (limitType, limitValues)
        }
        
        guard let curLink = self.curPassedLinkInfo else { return (limitType, limitValues) }
        let coordX = curLink.user_coord[0]
        let coordY = curLink.user_coord[1]
        
        let directions = curLink.included_heading
        
        if (directions.contains(0) && directions.contains(180)) {
            limitType = .Y_LIMIT
            limitValues = [coordY - LIMIT, coordY + LIMIT]
        } else if (directions.contains(90) && directions.contains(270)) {
            limitType = .X_LIMIT
            limitValues = [coordX - LIMIT, coordX + LIMIT]
        }
        
        return (limitType, limitValues)
    }
    
    // MARK: - Node & Link
    var anchorNode = PassedNodeInfo(id: -1, coord: [], headings: [], matched_index: -1, user_heading: 0)
    var anchorSection = -1
    
    var isInNode = false
    var curPassedNodeInfo = PassedNodeInfo(id: -1, coord: [], headings: [], matched_index: -1, user_heading: 0)
    var curPassedLinkInfo: PassedLinkInfo?
    var passedNodeInfoBuffer = [PassedNodeInfo]()
    
    var isNeedClearBuffer = false
    func updateAnchorNode(sectorId: Int, fltResult: FineLocationTrackingOutput, mode: UserMode, sectionNumber: Int) {
        let pathType = mode == .MODE_PEDESTRIAN ? 0 : 1
        let anchorNode = findAnchorNode(sectorId: sectorId, fltResult: fltResult, pathType: pathType)
        if anchorNode.id != -1 {
            if anchorNode.id == self.anchorNode.id {
                anchorSection = sectionNumber
            } else {
                self.anchorNode = anchorNode
                anchorSection = sectionNumber
                isNeedClearBuffer = true
            }
        }
        JupiterLogger.i(tag: "PathMatcher", message: "(updateAnchorNode) - level: \(fltResult.level_name), x: \(fltResult.x), y: \(fltResult.y), h: \(fltResult.absolute_heading) // anchorNode: \(anchorNode)")
    }

    func findAnchorNode(sectorId: Int, fltResult: FineLocationTrackingOutput, pathType: Int) -> PassedNodeInfo {
        let startNodeHeading = self.curPassedNodeInfo.headings
        let nodeInfoBuffer = passedNodeInfoBuffer
        
        var resultPassedNodeInfo = PassedNodeInfo(id: -1, coord: [], headings: [], matched_index: -1, user_heading: 0)
        guard let curLink = getCurPassedLinkInfo() else { return resultPassedNodeInfo }
        let startCoord = curLink.user_coord
        let heading: Float = Float(TJLabsUtilFunctions.shared.compensateDegree(Double(fltResult.absolute_heading)))
        var diffHeading = [Float]()
        var candidateDirections = [Float]()

        for mapHeading in startNodeHeading {
            var diffValue: Float = 0
            if (heading > 270 && (mapHeading >= 0 && mapHeading < 90)) {
                diffValue = abs(heading - (mapHeading+360))
            } else if (mapHeading > 270 && (heading >= 0 && heading < 90)) {
                diffValue = abs(mapHeading - (heading+360))
            } else {
                diffValue = abs(heading - mapHeading)
            }
            diffHeading.append(diffValue)
            
            let MARGIN: Float = 30
            
            if (diffValue >= 180-MARGIN && diffValue <= 180+MARGIN) {
                candidateDirections.append(mapHeading)
            }
        }
        let sectionLength: Double = 100
        let PIXELS_TO_CHECK = Int(sectionLength)
        
        if (candidateDirections.count == 1) {
            let direction = candidateDirections[0]
            var candidateNodeNumbers = [Int]()
            
            if direction.truncatingRemainder(dividingBy: 90) != 0 {
                if let link = curPassedLinkInfo {
                    let linkDirs = link.included_heading
                    for item in nodeInfoBuffer.reversed() {
                        var validCount = 0
                        for heading in linkDirs {
                            if item.headings.contains(heading) {
                                validCount += 1
                            }
                        }
                        if validCount == linkDirs.count {
                            resultPassedNodeInfo = item
                            return resultPassedNodeInfo
                        }
                    }
                }
            }
            
            let paddingValues = calculatePaddingByHeading(oppositeHeading: direction, length: sectionLength)
            
            var x: Float = startCoord[0]
            var y: Float = startCoord[1]
            let directionRad = Float(TJLabsUtilFunctions.shared.degree2radian(degree: Double(direction)))
            for _ in 0..<PIXELS_TO_CHECK {
                x += cos(directionRad)
                y += sin(directionRad)
                guard let matchedNodeResult = getMatchedNodeWithCoord(sectorId: sectorId, fltResult: fltResult, originCoord: startCoord, coordToCheck: [x, y], pathType: pathType, paddingValues: paddingValues) else { break }
                candidateNodeNumbers.append(matchedNodeResult.0)
            }
            for nodeNumber in candidateNodeNumbers.reversed() {
                for item in nodeInfoBuffer {
                    if item.id == nodeNumber {
                        resultPassedNodeInfo = item
                        return resultPassedNodeInfo
                    }
                }
            }
        } else {
            if let link = curPassedLinkInfo {
                let linkDirs = link.included_heading
                for item in nodeInfoBuffer.reversed() {
                    var validCount = 0
                    for heading in linkDirs {
                        if item.headings.contains(heading) {
                            validCount += 1
                        }
                    }
                    if validCount == linkDirs.count {
                        resultPassedNodeInfo = item
                        return resultPassedNodeInfo
                    }
                }
            }
        }
        
        if resultPassedNodeInfo.id == -1 {
            if nodeInfoBuffer.isEmpty {
                return resultPassedNodeInfo
            }
            
            let currentNodeCoord = nodeInfoBuffer[nodeInfoBuffer.count-1].coord
            if startCoord[0] == currentNodeCoord[0] && startCoord[1] == currentNodeCoord[1] {
                return nodeInfoBuffer[nodeInfoBuffer.count-1]
            }
        }
        
        return resultPassedNodeInfo
    }
    
    private func controlPassedNodeInfo(passedNodeInfo: PassedNodeInfo) {
        if (self.passedNodeInfoBuffer.count > 1) {
            let currentNode = passedNodeInfo.id
            let pastNode = passedNodeInfoBuffer[passedNodeInfoBuffer.count-1].id
            
            if (currentNode == pastNode) {
                self.passedNodeInfoBuffer.remove(at: passedNodeInfoBuffer.count-1)
            }
        }
        
        self.passedNodeInfoBuffer.append(passedNodeInfo)
        if (self.passedNodeInfoBuffer.count > 30) {
            self.passedNodeInfoBuffer.remove(at: 0)
        }
        
        if (isNeedClearBuffer) {
            let pastBuffer = self.passedNodeInfoBuffer
            var newBuffer = [PassedNodeInfo]()
            var startIndex: Int = 0
            var isFind: Bool = false
            for i in 0..<pastBuffer.count {
                if pastBuffer[i].id == self.anchorNode.id {
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
        }
    }
    
    func calculateOppositeHeading(currentHeading: Float, linkDir: [Float]) -> Float {
        var opposite = TJLabsUtilFunctions.shared.compensateDegree(Double(currentHeading) - 180)
        var minDiff: Float = 360
        for mapHeading in linkDir {
            let diff: Float
            if currentHeading > 270 && mapHeading < 90 {
                diff = abs(currentHeading - (mapHeading + 360))
            } else if mapHeading > 270 && currentHeading < 90 {
                diff = abs(mapHeading - (currentHeading + 360))
            } else {
                diff = abs(currentHeading - mapHeading)
            }
            
            if (diff < minDiff) {
                minDiff = diff
                opposite = TJLabsUtilFunctions.shared.compensateDegree(Double(mapHeading) - 180)
            }
        }
        return Float(opposite)
    }
    
    func calculatePaddingByHeading(oppositeHeading: Float, length: Double) -> [Float] {
        var paddingValues = [Float] (repeating: 20, count: 4)
        let lengthFloat = Float(length)
        if (oppositeHeading == 0) {
            paddingValues = [0, lengthFloat, 1, 1]
        } else if (oppositeHeading == 90) {
            paddingValues = [1, 1, 0, lengthFloat]
        } else if (oppositeHeading == 180) {
            paddingValues = [lengthFloat, 0, 1, 1]
        } else if (oppositeHeading == 270) {
            paddingValues = [1, 1, lengthFloat, 0]
        } else {
            paddingValues = [lengthFloat, lengthFloat, lengthFloat, lengthFloat]
        }
        
        return paddingValues
    }
    
    func updateNodeAndLinkInfo(sectorId: Int, uvdIndex: Int, curResult: FineLocationTrackingOutput, mode: UserMode) {
        let x = curResult.x
        let y = curResult.y
        let building = curResult.building_name
        let level = curResult.level_name
        let heading = Float(TJLabsUtilFunctions.shared.compensateDegree(Double(curResult.absolute_heading)))
        if building.isEmpty || level.isEmpty { return }
        
        let levelName = TJLabsUtilFunctions.shared.removeLevelDirectionString(levelName: level)
        let key = "\(sectorId)_\(building)_\(levelName)"

        guard let nodeData = self.nodeData[key] else { return }
        guard let linkData = self.linkData[key] else { return }

        let correctedX = round(x)
        let correctedY = round(y)

        // 현재 Node 위에 존재하는지 확인
        var matchedNodeId: Int? = nil
        var matchedNode: NodeData? = nil
        for (nodeId, nd) in nodeData {
            if nd.coords.count >= 2,
               nd.coords[0] == correctedX,
               nd.coords[1] == correctedY {
                matchedNodeId = nodeId
                matchedNode = nd
                break
            }
        }

        if let nodeId = matchedNodeId, let nd = matchedNode {
            // 1. 현재 Node 위에 존재
            isInNode = true

            let nodeHeadings = nd.directions.map { $0.heading }
            let (bestHeading, bestIndex) = closestHeading(to: heading, candidates: nodeHeadings)
            let oppositeHeading = oppositeOf(bestHeading)
            let (bestOppHeading, bestOppIndex) = closestHeading(to: oppositeHeading, candidates: nodeHeadings)

            var bestIsEnd = true
            if bestIndex >= 0 && bestIndex < nd.directions.count {
                bestIsEnd = nd.directions[bestIndex].is_end
            }

            registerPassedNode(node: nodeId, coord: nd.coords, headings: nodeHeadings, matchedIndex: bestIndex, heading: heading)
            JupiterLogger.i(tag: "PathMatcher", message: "(updateNodeAndLinkInfo) [NODE] uvd=\(uvdIndex) key=\(key) node=\(nodeId) xy=(\(correctedX),\(correctedY)) userH=\(heading) bestH=\(bestHeading)(idx=\(bestIndex), is_end=\(bestIsEnd)) oppH=\(bestOppHeading)(idx=\(bestOppIndex))")
            return
        }

        // 2. 현재 Node 위에 존재하지 않음
        isInNode = false
        var curLinkId = -1
        var curLinkDirs = [Float]()
        var curLinkBestHeading: Float = 0
        var curLinkOppHeading: Float = 0
        
        func pointToSegmentDistance(px: Float, py: Float, ax: Float, ay: Float, bx: Float, by: Float) -> (dist: Float, t: Float) {
            let abx = bx - ax
            let aby = by - ay
            let apx = px - ax
            let apy = py - ay
            let denom = abx*abx + aby*aby
            if denom <= 1e-6 {
                let dx = px - ax
                let dy = py - ay
                return (sqrt(dx*dx + dy*dy), 0)
            }
            var t = (apx*abx + apy*aby) / denom
            t = max(0, min(1, t))
            let cx = ax + t*abx
            let cy = ay + t*aby
            let dx = px - cx
            let dy = py - cy
            return (sqrt(dx*dx + dy*dy), t)
        }

        var candidateLinkIds: [Int]
        if curPassedNodeInfo.id != -1, let curNd = nodeData[curPassedNodeInfo.id] {
            candidateLinkIds = curNd.connected_links
        } else {
            candidateLinkIds = Array(linkData.keys)
        }

        var bestLinkId: Int = -1
        var bestLinkDist: Float = Float.greatestFiniteMagnitude
        var bestLink: LinkData? = nil

        for lid in candidateLinkIds {
            guard let ld = linkData[lid] else { continue }
            guard let sNode = nodeData[ld.start_node], sNode.coords.count >= 2 else { continue }
            guard let eNode = nodeData[ld.end_node], eNode.coords.count >= 2 else { continue }

            let ax = sNode.coords[0]
            let ay = sNode.coords[1]
            let bx = eNode.coords[0]
            let by = eNode.coords[1]

            let (dist, _) = pointToSegmentDistance(px: correctedX, py: correctedY, ax: ax, ay: ay, bx: bx, by: by)
            if dist < bestLinkDist {
                bestLinkDist = dist
                bestLinkId = lid
                bestLink = ld
            }
        }

        let acceptDist: Float = 5
        guard bestLinkId != -1, let ld = bestLink, bestLinkDist <= acceptDist else {
            let coordHeadings = getPathMatchingHeadings(sectorId: sectorId,
                                                       building: curResult.building_name,
                                                       level: curResult.level_name,
                                                       x: correctedX,
                                                       y: correctedY,
                                                       paddingValue: 0,
                                                       mode: mode)
            curLinkDirs = coordHeadings
            JupiterLogger.i(tag: "PathMatcher", message: "(updateNodeAndLinkInfo) [LINK] uvd=\(uvdIndex) key=\(key) xy=(\(correctedX),\(correctedY)) userH=\(heading) -> link not detected (bestDist=\(bestLinkDist)), headingsFallback=\(coordHeadings)")
            return
        }

        curLinkId = bestLinkId
        curLinkDirs = ld.included_heading

        let (bestH, bestIdx) = closestHeading(to: heading, candidates: curLinkDirs)
        let opp = oppositeOf(bestH)
        let (bestOppH, bestOppIdx) = closestHeading(to: opp, candidates: curLinkDirs)

        curLinkBestHeading = bestH
        curLinkOppHeading = bestOppH

        self.curPassedLinkInfo = PassedLinkInfo(id: curLinkId, start_node: ld.start_node, end_node: ld.end_node, distance: ld.distance, included_heading: curLinkDirs, group_id: ld.group_id, user_coord: [correctedX, correctedY], user_heading: heading, matched_heading: curLinkBestHeading, oppsite_heading: curLinkOppHeading)
        JupiterLogger.i(tag: "PathMatcher", message: "(updateNodeAndLinkInfo) [LINK] uvd=\(uvdIndex) key=\(key) link=\(curLinkId) (\(ld.start_node)->\(ld.end_node)) dirs=\(curLinkDirs) xy=(\(correctedX),\(correctedY)) userH=\(heading) bestH=\(bestH)(idx=\(bestIdx)) oppH=\(bestOppH)(idx=\(bestOppIdx)) dist=\(bestLinkDist)")
    }
    
    private func registerPassedNode(node: Int, coord: [Float], headings: [Float], matchedIndex: Int, heading: Float) {
        curPassedNodeInfo = PassedNodeInfo(id: node, coord: coord, headings: headings, matched_index: matchedIndex, user_heading: heading)
        controlPassedNodeInfo(passedNodeInfo: curPassedNodeInfo)
//        JupiterLogger.i(tag: "PathMatcher", message: "(registerPassedNode) - registerPassedNode : passedNode = \(curPassedNodeInfo.id) // passedNodeMatchedIndex = \(curPassedNodeInfo.matched_index) // passedNodeCoord = \(curPassedNodeInfo.coord) // passedNodeHeadings = \(curPassedNodeInfo.headings)")
    }

    // MARK: - Heading helpers (0~360 circular)
    private func circularDiffDeg(_ a: Double, _ b: Double) -> Double {
        let d = abs(a - b).truncatingRemainder(dividingBy: 360.0)
        return min(d, 360.0 - d)
    }

    private func closestHeading(to userHeading: Float, candidates: [Float]) -> (Float, Int) {
        guard !candidates.isEmpty else { return (userHeading, -1) }

        var bestHeading = candidates[0]
        var bestIndex = 0
        var bestDiff = Float.greatestFiniteMagnitude

        for (i, h) in candidates.enumerated() {
            let diff = Float(circularDiffDeg(Double(userHeading), Double(h)))
            if diff < bestDiff {
                bestDiff = diff
                bestHeading = h
                bestIndex = i
            }
        }

        return (bestHeading, bestIndex)
    }

    private func oppositeOf(_ heading: Float) -> Float {
        return Float(TJLabsUtilFunctions.shared.compensateDegree(Double(heading) - 180.0))
    }
    
    func getCurPassedNodeInfo() -> PassedNodeInfo {
        return self.curPassedNodeInfo
    }
    
    func getCurPassedLinkInfo() -> PassedLinkInfo? {
        return self.curPassedLinkInfo
    }
}
