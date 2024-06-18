public class OlympusKalmanFilter: NSObject {
    
    var tuResult = FineLocationTrackingFromServer()
    var muResult = FineLocationTrackingFromServer()
    
    public var tuFlag: Bool = false
    public var muFlag: Bool = false
    
    var kalmanP: Double = 1
    var kalmanQ: Double = 0.3
    var kalmanR: Double = 0.5
    var kalmanK: Double = 1
    
    var headingKalmanP: Double = 0.5
    var headingKalmanQ: Double = 0.5
    var headingKalmanR: Double = 1
    var headingKalmanK: Double = 1
    
    var pastKalmanP: Double = 1
    var pastKalmanQ: Double = 0.3
    var pastKalmanR: Double = 0.5
    var pastKalmanK: Double = 1
    
    var pastHeadingKalmanP: Double = 0.5
    var pastHeadingKalmanQ: Double = 0.5
    var pastHeadingKalmanR: Double = 1
    var pastHeadingKalmanK: Double = 1
    
    var pathTrajMatchingIndex: Int = 0
    var pathTrajTurnIndex: Int = 0
    var matchedTraj = [[Double]]()
    var inputTraj = [[Double]]()
    var distanceToAdd: Double = 0
    
    var uvdIndexBuffer = [Int]()
    var uvdHeadingBuffer = [Double]()
    var tuResultBuffer = [[Double]]()
    var isNeedUvdIndexBufferClear: Bool = false
    var usedUvdIndex: Int = 0
    var pathTrajMatchingNodeInfo = PassedNodeInfo(nodeNumber: -1, nodeCoord: [], nodeHeadings: [], matchedIndex: -1, userHeading: 0)
    
    var linkCoord: [Double] = [0, 0]
    var linkDirections = [Double]()
    
    var tuResultNow = FineLocationTrackingFromServer()
    var tuResultWhenUvdPosted = FineLocationTrackingFromServer()
    
    public var isRunning: Bool = false
    
    override init() { }
    
    public func initialize() {
        self.tuResult = FineLocationTrackingFromServer()
        self.muResult = FineLocationTrackingFromServer()
        
        self.tuFlag = false
        self.muFlag = false
        
        self.pathTrajMatchingIndex = 0
        self.pathTrajTurnIndex = 0
        self.matchedTraj = [[Double]]()
        self.inputTraj = [[Double]]()
        
        self.uvdIndexBuffer = [Int]()
        self.uvdHeadingBuffer = [Double]()
        self.tuResultBuffer = [[Double]]()
        self.isNeedUvdIndexBufferClear = false
        self.usedUvdIndex = 0
        self.pathTrajMatchingNodeInfo = PassedNodeInfo(nodeNumber: -1, nodeCoord: [], nodeHeadings: [], matchedIndex: -1, userHeading: 0)
        
        self.linkCoord = [0, 0]
        self.linkDirections = [Double]()

        self.tuResultNow = FineLocationTrackingFromServer()
        self.tuResultWhenUvdPosted = FineLocationTrackingFromServer()
        
        self.isRunning = false
    }
    
    public func deactivateKalmanFilter() {
        self.isRunning = false
    }
    
    public func minimizeKalmanR() {
        self.kalmanR = 0.01
        self.headingKalmanR = 0.01
    }
    
    public func resetKalmanR() {
        self.kalmanR = 0.5
        self.headingKalmanR = 1
    }
    
    public func activateKalmanFilter(fltResult: FineLocationTrackingFromServer) {
        self.tuResult = fltResult
        self.tuFlag = true
        self.isRunning = true
    }
    
    public func setLinkInfo(coord: [Double], directions: [Double]) {
        self.linkCoord = coord
        self.linkDirections = directions
    }
    
    public func refreshTuResult(xyh: [Double], inputPhase: Int, inputTrajLength: Double, mode: String) {
        self.tuResult.x = xyh[0]
        self.tuResult.y = xyh[1]
        
        if (mode == OlympusConstants.MODE_PDR) {
            self.tuResult.absolute_heading = xyh[2]
        } else {
            if (inputTrajLength > OlympusConstants.USER_TRAJECTORY_LENGTH_DR*0.4 && inputPhase != OlympusConstants.PHASE_1) {
                self.tuResult.absolute_heading = xyh[2]
            }
        }
    }
    
    public func updateTuInformation(unitDRInfo: UnitDRInfo) {
        if (self.isNeedUvdIndexBufferClear) {
            self.uvdIndexBuffer = sliceArray(self.uvdIndexBuffer, startingFrom: self.usedUvdIndex)
            self.uvdHeadingBuffer = sliceArray(self.uvdHeadingBuffer, startingFrom: self.usedUvdIndex)
            self.tuResultBuffer = sliceArray(self.tuResultBuffer, startingFrom: self.usedUvdIndex)
            self.isNeedUvdIndexBufferClear = false
        }
        
        self.uvdIndexBuffer.append(unitDRInfo.index)
        self.uvdHeadingBuffer.append(unitDRInfo.heading)
        self.tuResultBuffer.append([tuResult.x, tuResult.y, tuResult.absolute_heading])
    }
    
    public func updateTuResultNow(result: FineLocationTrackingFromServer) {
        self.tuResultNow = result
    }
    
    public func updateTuResultWhenUvdPosted(result: FineLocationTrackingFromServer) {
        self.tuResultWhenUvdPosted = result
    }
    
    public func timeUpdate(currentTime: Int, recentResult: FineLocationTrackingResult, length: Double, diffHeading: Double, isPossibleHeadingCorrection: Bool, unitDRInfoBuffer: [UnitDRInfo], userMaskBuffer: [UserMask], isNeedPathTrajMatching: IsNeedPathTrajMatching, PADDING_VALUES: [Double], mode: String) -> (FineLocationTrackingFromServer, Bool, Bool) {
        //    public func timeUpdate(currentTime: Int, recentResult: FineLocationTrackingResult, length: Double, diffHeading: Double, isPossibleHeadingCorrection: Bool, unitDRInfoBuffer: [UnitDRInfo], userMaskBuffer: [UserMask], isNeedPathTrajMatching: Bool, mode: String) -> (FineLocationTrackingFromServer, Bool, Bool) {
        var isNeedRequestPhase4: Bool = false
        var isDidPathTrajMatching: Bool = false
        
        var outputResult: FineLocationTrackingFromServer = self.tuResult
        outputResult.mobile_time = currentTime
        
        let levelName = removeLevelDirectionString(levelName: self.tuResult.level_name)
        
        let updatedHeading = compensateHeading(heading: self.tuResult.absolute_heading + diffHeading)
        let dx = length*cos(updatedHeading*OlympusConstants.D2R)
        let dy = length*sin(updatedHeading*OlympusConstants.D2R)
        
        let updatedX = self.tuResult.x + dx
        let updatedY = self.tuResult.y + dy
        
        outputResult.x = updatedX
        outputResult.y = updatedY
        outputResult.absolute_heading = updatedHeading
        
        if (mode == OlympusConstants.MODE_PDR) {
            // PDR
            let currentUvdIndex = unitDRInfoBuffer[unitDRInfoBuffer.count-1].index
            
            let inputUnitDrInfoBuffer = Array(unitDRInfoBuffer.suffix(OlympusConstants.DR_BUFFER_SIZE_FOR_STRAIGHT))
            var isPossiblePathTrajMatching: Bool = true
            
            for unitUvd in inputUnitDrInfoBuffer {
                if (unitUvd.index == self.pathTrajTurnIndex) {
                    isPossiblePathTrajMatching = false
                    print(getLocalTimeString() + " , (Olympus) Path-Matching : pathTrajTurnIndex = \(pathTrajTurnIndex) // isPossiblePathTrajMatching = \(false)")
                    break
                }
            }
            
//            for unitUvd in Array(unitDRInfoBuffer.suffix(OlympusConstants.DR_BUFFER_SIZE_FOR_STRAIGHT/2)) {
//                if (unitUvd.index == self.pathTrajTurnIndex) {
//                    isPossiblePathTrajMatching = false
//                    print(getLocalTimeString() + " , (Olympus) Path-Matching : pathTrajTurnIndex = \(pathTrajTurnIndex) // isPossiblePathTrajMatching = \(false)")
//                    break
//                }
//            }
            
            let drBufferStraightResult = isDrBufferStraight(unitDRInfoBuffer: unitDRInfoBuffer, numIndex: OlympusConstants.DR_BUFFER_SIZE_FOR_STRAIGHT, condition: 60.0)
            
            let isDrStraight: Bool = drBufferStraightResult.0
            let turnAngle = drBufferStraightResult.1
            print(getLocalTimeString() + " , (Olympus) Path-Matching : isPossiblePathTrajMatching = \(isPossiblePathTrajMatching) // turnAngle = \(turnAngle) // isDrStraight = \(isDrStraight)")
            
            if (!isDrStraight && isPossiblePathTrajMatching) {
                // 사용자는 Turn 하는 궤적이다
                if (isNeedPathTrajMatching.turn && turnAngle <= 135) {
                    // Node를 옮기자
                    isNeedRequestPhase4 = true
                    print(getLocalTimeString() + " , (Olympus) Path-Matching : isNeedRequestPhase4 (1) = \(isNeedRequestPhase4)")
                    let linkDirArray = linkDirections
                    if (!linkDirArray.isEmpty) {
                        let inputUserMaskBuffer = Array(userMaskBuffer.suffix(OlympusConstants.DR_BUFFER_SIZE_FOR_STRAIGHT))
                        
                        var turnIndex: Int = 0
                        var uvdIndexMatchedWithTurn: Int = 0
                        var uvdHeadings = [Double]()
                        for unitUvd in inputUnitDrInfoBuffer {
                            uvdHeadings.append(unitUvd.heading)
                        }
                        turnIndex = indexOfMaxRateOfChange(in: uvdHeadings)
                        
                        let userX = inputUserMaskBuffer[inputUserMaskBuffer.count-1].x
                        let userY = inputUserMaskBuffer[inputUserMaskBuffer.count-1].y
                        let userHeading = inputUserMaskBuffer[inputUserMaskBuffer.count-1].absolute_heading
                        print(getLocalTimeString() + " , (Olympus) Path-Matching : User Mask  = \(inputUserMaskBuffer)")
                        print(getLocalTimeString() + " , (Olympus) Path-Matching : linkDirArray  = \(linkDirArray)")
                        var directionCount = [Int](repeating: 0, count: linkDirArray.count)
                        for idx in 0..<inputUserMaskBuffer.count {
                            if (idx > turnIndex) {
                                break
                            }
                            
                            var diffValues = [Double]()
                            for direction in linkDirArray {
                                var diffDirValue = abs(direction - inputUserMaskBuffer[idx].absolute_heading)
                                if (diffDirValue > 270) {
                                    diffDirValue = 360 - diffDirValue
                                }
                                diffValues.append(diffDirValue)
                            }
                            let minIndex = diffValues.firstIndex(of: diffValues.min()!)
                            directionCount[minIndex!] = directionCount[minIndex!] + 1
                        }
                        print(getLocalTimeString() + " , (Olympus) Path-Matching : directionCount  = \(directionCount)")
                        let maxIndex = directionCount.firstIndex(of: directionCount.max()!)
                        let startHeading = linkDirArray[maxIndex!]
//                        let startHeading = inputUserMaskBuffer[0].absolute_heading
                        let endHeading = compensateHeading(heading: userHeading)
                        
                        let findPathMatchingNodeResult = OlympusPathMatchingCalculator.shared.findPathTrajMatchingNode(fltResult: outputResult, x: Double(userX), y: Double(userY), heading: startHeading, uvdBuffer: inputUnitDrInfoBuffer, pathType: 0, linkDirections: linkDirArray)
                        print(getLocalTimeString() + " , (Olympus) Path-Matching : findPathMatchingNodeResult = \(findPathMatchingNodeResult)")
                        var pathMatchingNodeInfoCandidates = [PassedNodeInfo]()
                        if !findPathMatchingNodeResult.isEmpty {
                            var resultCoordX = [Double]()
                            var resultCoordY = [Double]()
                            let MARGIN: Double = 44
                            
                            for pathMatchingNode in findPathMatchingNodeResult {
//                                var diffHeadings = [Double]()
                                var candidateDirections = [Double]()
                                var bestMapHeading: Double = endHeading
                                var minDiffValue: Double = 360
                                for mapHeading in pathMatchingNode.nodeHeadings {
                                    if !(linkDirArray.contains(mapHeading)) {
                                        var diffValue: Double = 0
                                        
                                        if (endHeading > 270 && (mapHeading >= 0 && mapHeading < 90)) {
                                            diffValue = abs(endHeading - (mapHeading+360))
                                        } else if (mapHeading > 270 && (endHeading >= 0 && endHeading < 90)) {
                                            diffValue = abs(mapHeading - (endHeading+360))
                                        } else {
                                            diffValue = abs(endHeading - mapHeading)
                                        }
                                        
                                        if diffValue < minDiffValue {
                                            minDiffValue = diffValue
                                            bestMapHeading = mapHeading
                                        }
                                    }
                                }
                                candidateDirections.append(bestMapHeading)
                                
                                print(getLocalTimeString() + " , (Olympus) Path-Matching : after findPathMatchingNodeResult // endHeading = \(endHeading)")
                                print(getLocalTimeString() + " , (Olympus) Path-Matching : after findPathMatchingNodeResult // candidateDirections = \(candidateDirections)")
                                if (candidateDirections.count == 1) {
                                    let nodeCoord = pathMatchingNode.nodeCoord
                                    let turnType = determineTurnType(headings: uvdHeadings)
                                    print(getLocalTimeString() + " , (Olympus) Turn Type : turnType = \(turnType)")
                                    var distanceCompensation: Double = 0
                                    
                                    var startX = nodeCoord[0]
                                    var startY = nodeCoord[1]
                                    for i in (0..<turnIndex).reversed() {
                                        startX += inputUnitDrInfoBuffer[i].length*cos((startHeading-180)*OlympusConstants.D2R)
                                        startY += inputUnitDrInfoBuffer[i].length*sin((startHeading-180)*OlympusConstants.D2R)
//                                        if (turnType == 1) {
//                                            distanceCompensation += inputUnitDrInfoBuffer[i].length
//                                            compensationCount += 1
//                                        }
                                    }
                                    
//                                    if (turnType == 1) {
//                                        let startUserX = Double(inputUserMaskBuffer[0].x)
//                                        let startUserY = Double(inputUserMaskBuffer[0].y)
//                                        let diffX = abs(startUserX - startX)
//                                        let diffY = abs(startUserY - startY)
//                                        distanceCompensation = sqrt(diffX*diffX + diffY*diffY)
//                                        print(getLocalTimeString() + " , (Olympus) Turn Type : distanceCompensation = \(distanceCompensation)")
//                                    }
                                    
                                    var startPaddingValues: [Double] = [1, 1, 1, 1]
                                    let headingRange: Double = 10
                                    if (startHeading >= -headingRange && startHeading < headingRange) || (startHeading >= 180-headingRange && startHeading < 180+headingRange) {
                                        startPaddingValues = [1, 1, 0.45, 0.45]
                                    } else if (startHeading >= 90-headingRange && startHeading < 90+headingRange) || (startHeading >= 270-headingRange && startHeading < 270+headingRange) {
                                        startPaddingValues = [0.45, 0.45, 1, 1]
                                    }
                                    
                                    let startXy = OlympusPathMatchingCalculator.shared.pathMatching(building: outputResult.building_name, level: outputResult.level_name, x: startX, y: startY, heading: startHeading, HEADING_RANGE: OlympusConstants.HEADING_RANGE, isUseHeading: false, pathType: 0, PADDING_VALUES: startPaddingValues)
                                    print(getLocalTimeString() + " , (Olympus) Path-Matching : startXY = \(startX) , \(startY) // pm = \(startXy)")
                                    if (startXy.isSuccess) {
                                        let compensationDirection = candidateDirections[0]
                                        
                                        var endX = nodeCoord[0]
                                        var endY = nodeCoord[1]
                                        for i in turnIndex..<inputUnitDrInfoBuffer.count {
                                            endX += inputUnitDrInfoBuffer[i].length*cos(compensationDirection*OlympusConstants.D2R)
                                            endY += inputUnitDrInfoBuffer[i].length*sin(compensationDirection*OlympusConstants.D2R)
                                        }
                                        
                                        if (turnType == 1) {
                                            distanceCompensation = 1.5
                                            endX += distanceCompensation*cos(compensationDirection*OlympusConstants.D2R)
                                            endY += distanceCompensation*sin(compensationDirection*OlympusConstants.D2R)
                                        }
                                        
                                        var endPaddingValues: [Double] = [1, 1, 1, 1]
                                        let headingRange: Double = 10
                                        if (compensationDirection >= -headingRange && compensationDirection < headingRange) || (compensationDirection >= 180-headingRange && compensationDirection < 180+headingRange) {
                                            endPaddingValues = [1, 1, 0.45, 0.45]
                                        } else if (compensationDirection >= 90-headingRange && compensationDirection < 90+headingRange) || (compensationDirection >= 270-headingRange && compensationDirection < 270+headingRange) {
                                            endPaddingValues = [0.45, 0.45, 1, 1]
                                        }
                                        let endXy = OlympusPathMatchingCalculator.shared.pathMatching(building: outputResult.building_name, level: outputResult.level_name, x: endX, y: endY, heading: compensationDirection, HEADING_RANGE: OlympusConstants.HEADING_RANGE, isUseHeading: false, pathType: 0, PADDING_VALUES: endPaddingValues)
                                        print(getLocalTimeString() + " , (Olympus) Path-Matching : endXy = \(endX) , \(endY) // pm = \(endXy)")
                                        if (endXy.isSuccess) {
                                            uvdIndexMatchedWithTurn = inputUnitDrInfoBuffer[turnIndex].index
                                            // 후보군 중에 하나로 포함
                                            resultCoordX.append(endX)
                                            resultCoordY.append(endY)
                                            pathMatchingNodeInfoCandidates.append(PassedNodeInfo(nodeNumber: pathMatchingNode.nodeNumber, nodeCoord: pathMatchingNode.nodeCoord, nodeHeadings: pathMatchingNode.nodeHeadings, matchedIndex: currentUvdIndex, userHeading: compensationDirection))
                                        }
                                    }
                                }
                            }
                            
                            if (!resultCoordX.isEmpty) {
                                var minDist: Double = 100
                                var bestIndex = -1
                                var bestCoord = [Double]()
                                for c in 0..<resultCoordX.count {
                                    let diffX = Double(userX) - resultCoordX[c]
                                    let diffY = Double(userY) - resultCoordY[c]
                                    let distWithUser = sqrt(diffX*diffX + diffY*diffY)
                                    if (distWithUser < minDist) {
                                        minDist = distWithUser
                                        bestIndex = c
                                        bestCoord = [resultCoordX[c], resultCoordY[c]]
                                    }
                                }
                                if (!bestCoord.isEmpty) {
                                    self.pathTrajTurnIndex = uvdIndexMatchedWithTurn
                                    self.pathTrajMatchingIndex = currentUvdIndex
                                    outputResult.x = bestCoord[0]
                                    outputResult.y = bestCoord[1]
                                    
                                    let headingCompensation: Double = userHeading - inputUnitDrInfoBuffer[inputUnitDrInfoBuffer.count-1].heading
                                    var headingBuffer: [Double] = []
                                    for uvd in inputUnitDrInfoBuffer {
                                        let compensatedHeading = compensateHeading(heading: uvd.heading + headingCompensation - 180)
                                        headingBuffer.append(compensatedHeading)
                                    }
                                    
                                    var xyFromHead :[Double] = [bestCoord[0], bestCoord[1]]
                                    var trajectoryFromHead = [[Double]]()
                                    trajectoryFromHead.append([bestCoord[0], bestCoord[1]])
                                    for i in (0..<inputUnitDrInfoBuffer.count).reversed() {
                                        let headAngle = headingBuffer[i]
                                        xyFromHead[0] = xyFromHead[0] + inputUnitDrInfoBuffer[i].length*cos(headAngle*OlympusConstants.D2R)
                                        xyFromHead[1] = xyFromHead[1] + inputUnitDrInfoBuffer[i].length*sin(headAngle*OlympusConstants.D2R)
                                        trajectoryFromHead.append(xyFromHead)
                                    }
                                    self.inputTraj = trajectoryFromHead
                                    isDidPathTrajMatching = true
                                    isNeedRequestPhase4 = false
                                    
                                    pathTrajMatchingNodeInfo = pathMatchingNodeInfoCandidates[bestIndex]
                                    print(getLocalTimeString() + " , (Olympus) Path-Matching : isNeedRequestPhase4 (2) = \(isNeedRequestPhase4)")
                                }
                            }
                        }
                    }
                }
            } else {
                let drBufferVeryStraightResult = isDrBufferStraight(unitDRInfoBuffer: unitDRInfoBuffer, numIndex: OlympusConstants.DR_BUFFER_SIZE_FOR_STRAIGHT, condition: 10.0)
                let isDrVeryStraight: Bool = drBufferVeryStraightResult.0
                print(getLocalTimeString() + " , (Olympus) Path-Matching : isDrVeryStraight = \(isDrVeryStraight)")
                if (isDrVeryStraight) {
                    if (isNeedPathTrajMatching.straight) {
                        isNeedRequestPhase4 = true
                    }
                    let pathMatchingResult = OlympusPathMatchingCalculator.shared.pathMatching(building: self.tuResult.building_name, level: levelName, x: updatedX, y: updatedY, heading: updatedHeading, HEADING_RANGE: OlympusConstants.HEADING_RANGE, isUseHeading: true, pathType: 0, PADDING_VALUES: PADDING_VALUES)
                    outputResult.x = pathMatchingResult.xyhs[0]*0.5 + updatedX*0.5
                    outputResult.y = pathMatchingResult.xyhs[1]*0.5 + updatedY*0.5
                    if (pathMatchingResult.0) { outputResult.absolute_heading = compensateHeading(heading: pathMatchingResult.xyhs[2]) }
                }
                initPathTrajMatchingInfo()
            }
            
            if (!isDidPathTrajMatching) {
                let limitationResult = OlympusPathMatchingCalculator.shared.getTimeUpdateLimitation(mode: mode)
                if (limitationResult.limitType == .Y_LIMIT) {
                    if (outputResult.y < limitationResult.limitValues[0]) {
                        outputResult.y = limitationResult.limitValues[0]
                    } else if (outputResult.y > limitationResult.limitValues[1]) {
                        outputResult.y = limitationResult.limitValues[1]
                    }
                } else if (limitationResult.limitType == .X_LIMIT) {
                    if (outputResult.x < limitationResult.limitValues[0]) {
                        outputResult.x = limitationResult.limitValues[0]
                    } else if (outputResult.x > limitationResult.limitValues[1]) {
                        outputResult.x = limitationResult.limitValues[1]
                    }
                }
            } else {
                let pathMatching = OlympusPathMatchingCalculator.shared.pathMatching(building: self.tuResult.building_name, level: levelName, x: outputResult.x, y: outputResult.y, heading: outputResult.absolute_heading, HEADING_RANGE: OlympusConstants.HEADING_RANGE, isUseHeading: false, pathType: 0, PADDING_VALUES: PADDING_VALUES)
                outputResult.x = pathMatching.xyhs[0]
                outputResult.y = pathMatching.xyhs[1]
            }
        } else {
            let drBufferStraightResult = isDrBufferStraight(unitDRInfoBuffer: unitDRInfoBuffer, numIndex: OlympusConstants.DR_HEADING_CORR_NUM_IDX, condition: 10.0)
            let isDrStraight: Bool = drBufferStraightResult.0
            let pathMatchingResult =  OlympusPathMatchingCalculator.shared.pathMatching(building: self.tuResult.building_name, level: levelName, x: updatedX, y: updatedY, heading: updatedHeading, HEADING_RANGE: OlympusConstants.HEADING_RANGE, isUseHeading: true, pathType: 1, PADDING_VALUES: PADDING_VALUES)
            
            if (pathMatchingResult.isSuccess) {
                outputResult.x = (pathMatchingResult.1[0]*0.5 + updatedX*0.5)
                outputResult.y = (pathMatchingResult.1[1]*0.5 + updatedY*0.5)
                outputResult.absolute_heading = compensateHeading(heading: updatedHeading)
                
                if (pathMatchingResult.0 && isDrStraight){
                    outputResult.absolute_heading = compensateHeading(heading: pathMatchingResult.1[2])
                }
            } else {
                let pathMatchingResult =  OlympusPathMatchingCalculator.shared.pathMatching(building: self.tuResult.building_name, level: levelName, x: updatedX, y: updatedY, heading: updatedHeading, HEADING_RANGE: OlympusConstants.HEADING_RANGE, isUseHeading: false, pathType: 1, PADDING_VALUES: PADDING_VALUES)
                outputResult.x = (pathMatchingResult.1[0]*0.5 + updatedX*0.5)
                outputResult.y = (pathMatchingResult.1[1]*0.5 + updatedY*0.5)
                outputResult.absolute_heading = compensateHeading(heading: updatedHeading)
            }
            
            // DR
            let limitationResult = OlympusPathMatchingCalculator.shared.getTimeUpdateLimitation(mode: mode)
            if (limitationResult.limitType == .Y_LIMIT) {
//                print("(Link Info) : Y Limit // before = \(outputResult.x) , \(outputResult.y)")
                if (outputResult.y < limitationResult.limitValues[0]) {
                    outputResult.y = limitationResult.limitValues[0]
                } else if (outputResult.y > limitationResult.limitValues[1]) {
                    outputResult.y = limitationResult.limitValues[1]
                }
//                print("(Link Info) : Y Limit // after = \(outputResult.x) , \(outputResult.y)")
//                print("(Link Info) -------------------------------------- ")
            } else if (limitationResult.limitType == .X_LIMIT) {
//                print("(Link Info) : X Limit // before = \(outputResult.x) , \(outputResult.y)")
                if (outputResult.x < limitationResult.limitValues[0]) {
                    outputResult.x = limitationResult.limitValues[0]
                } else if (outputResult.x > limitationResult.limitValues[1]) {
                    outputResult.x = limitationResult.limitValues[1]
                }
//                print("(Link Info) : X Limit // after = \(outputResult.x) , \(outputResult.y)")
//                print("(Link Info) -------------------------------------- ")
            }
        }
        
        
        tuResult = outputResult
        
        kalmanP += kalmanQ
        headingKalmanP += headingKalmanQ
        muFlag = true
        
        return (outputResult, isDidPathTrajMatching, isNeedRequestPhase4)
    }
    
    public func getPathTrajMatchingNode() -> PassedNodeInfo {
        return pathTrajMatchingNodeInfo
    }
    
    private func determineTurnType(headings: [Double]) -> Int {
        var angleChanges: [Double] = []
        var deltaBefore: Double = 0
        var largeTurnCount: Int = 0
        var turnCount: Int = 0
        
        for i in 1..<headings.count {
            let delta = abs(headings[i] - headings[i - 1])
            
            angleChanges.append(delta)
            if (deltaBefore >= 30 && delta >= 30) {
                largeTurnCount += 1
                
                if (largeTurnCount > turnCount) {
                    turnCount = largeTurnCount
                }
            } else {
                largeTurnCount = 0
            }
            
            deltaBefore = delta
        }
        
        let absoluteChanges = angleChanges.map { abs($0) }
        let maxChange = absoluteChanges.max() ?? 0
        
        print(getLocalTimeString() + " , (Olympus) Turn Type : angleChanges = \(angleChanges)")
        print(getLocalTimeString() + " , (Olympus) Turn Type : absoluteChanges = \(absoluteChanges)")
        print(getLocalTimeString() + " , (Olympus) Turn Type : maxChange = \(maxChange)")
        print(getLocalTimeString() + " , (Olympus) Turn Type : turnCount = \(turnCount)")
        
//        if maxChange > 40 && maxChange < 120 {
//            return 0
//        } else if absoluteChanges.allSatisfy({ $0 < 30 }) {
//            return 1
//        } else {
//            return 2
//        }
        
        if (turnCount >= 1) || (maxChange > 55 && maxChange < 125) {
            return 0
        } else if absoluteChanges.allSatisfy({ $0 < 30 }) {
            return 1
        } else {
            return 2
        }
    }
    
    
    private func calCircularStd(for uvdArray: [UnitDRInfo]) -> Double {
        var array = [Double]()
        for uvd in uvdArray {
            array.append(compensateHeading(heading: uvd.heading))
        }
        
        guard !array.isEmpty else {
            return 20.0
        }
        
        let meanAngle = circularMean(for: array)
        let circularDifferences = array.map { angleDifference($0, meanAngle) }
        
        var powSum: Double = 0
        for i in 0..<circularDifferences.count {
            powSum += circularDifferences[i]*circularDifferences[i]
        }
        let circularVariance = powSum / Double(circularDifferences.count)
        
        return sqrt(circularVariance)
    }
    
    private func getPathTrajMatchingPaddingValues(uvdArray: [UnitDRInfo], startHeading: Double) -> [Double] {
        var paddingValues: [Double] = [5, 5, 5, 5]
        var trajEndX: Double = 0
        var trajEndY: Double = 0
        let headingCompensation: Double = startHeading - uvdArray[0].heading
        for uvd in uvdArray {
            let heading = compensateHeading(heading: uvd.heading + headingCompensation)
            trajEndX = trajEndX + uvd.length*cos(heading*OlympusConstants.D2R)
            trajEndY = trajEndY + uvd.length*sin(heading*OlympusConstants.D2R)
        }
        
        print(getLocalTimeString() + " , (Olympus) Path-Matching : x = \(trajEndX) , y = \(trajEndY)")
        if (trajEndX > 0 && trajEndY > 0) {
            // 1사분면
            paddingValues = [0, 8, 0, 8]
        } else if (trajEndX < 0 && trajEndY > 0) {
            // 2사분면
            paddingValues = [8, 0, 0, 8]
        } else if (trajEndX < 0 && trajEndY < 0) {
            // 3사분면
            paddingValues = [8, 0, 8, 0]
        } else if (trajEndX > 0 && trajEndY < 0) {
            // 4사분면
            paddingValues = [0, 8, 8, 0]
        }
        
        
        return paddingValues
    }
    
    public func preProcessForMeasurementUpdate(fltResult: FineLocationTrackingFromServer, unitDRInfoBuffer: [UnitDRInfo], mode: String, isNeedCalDhFromUvd: Bool) -> [Double] {
        let uvdIndexBuffer: [Int] = self.uvdIndexBuffer
        let uvdHeadingBuffer: [Double] = self.uvdHeadingBuffer
        let tuResultBuffer: [[Double]] = self.tuResultBuffer
                
        var tuResultNow = self.tuResultNow
        var tuResultWhenUvdPosted = self.tuResultWhenUvdPosted
                
        var dx: Double = 0
        var dy: Double = 0
        var dh: Double = 0
                
        if (tuResultNow.mobile_time != 0 && tuResultWhenUvdPosted.mobile_time != 0) {
            if let idx = uvdIndexBuffer.firstIndex(of: fltResult.index) {
                var isNeedUvdPropagation: Bool = false
                if (mode == OlympusConstants.MODE_PDR) {
                    let propagationResult = propagateUsingUvd(unitDRInfoBuffer: unitDRInfoBuffer, fltResult: fltResult)
                    if (propagationResult.0) {
                        dx = propagationResult.1[0]
                        dy = propagationResult.1[1]
                        dh = propagationResult.1[2]
                        isNeedUvdPropagation = true
                    } else {
                        isNeedUvdPropagation = false
                    }
                } else {
                    isNeedUvdPropagation = false
                }
                
                if (!isNeedUvdPropagation) {
                    dx = tuResultNow.x - tuResultBuffer[idx][0]
                    dy = tuResultNow.y - tuResultBuffer[idx][1]
                    tuResultNow.absolute_heading = compensateHeading(heading: tuResultNow.absolute_heading)
                    let tuBufferHeading = compensateHeading(heading: tuResultBuffer[idx][2])
                    
                    if (isNeedCalDhFromUvd) {
                        dh = uvdHeadingBuffer[uvdHeadingBuffer.count-1] - uvdHeadingBuffer[idx]
                    } else {
                        dh = tuResultNow.absolute_heading - tuBufferHeading
                    }
                }
                
                self.usedUvdIndex = idx
                self.isNeedUvdIndexBufferClear = true
            } else {
                dx = tuResultNow.x - tuResultWhenUvdPosted.x
                dy = tuResultNow.y - tuResultWhenUvdPosted.y
                tuResultNow.absolute_heading = compensateHeading(heading: tuResultNow.absolute_heading)
                tuResultWhenUvdPosted.absolute_heading = compensateHeading(heading: tuResultWhenUvdPosted.absolute_heading)
                        
                dh = tuResultNow.absolute_heading - tuResultWhenUvdPosted.absolute_heading
            }
        }
        
        return [dx, dy, dh]
    }
    
    func measurementUpdate(fltResult: FineLocationTrackingFromServer, pmFltResult: FineLocationTrackingFromServer, propagatedPmFltResult: FineLocationTrackingFromServer, unitDRInfoBuffer: [UnitDRInfo], isPossibleHeadingCorrection: Bool, PADDING_VALUES: [Double], mode: String) -> FineLocationTrackingFromServer {
        var updatedResult: FineLocationTrackingFromServer = propagatedPmFltResult
        
        // Path-Matching propagatedPmFltResult
        var isPmSuccess: Bool = false
        var pmPropagatedPmFltResult = propagatedPmFltResult
        if (mode == OlympusConstants.MODE_PDR) {
            let pmResult = OlympusPathMatchingCalculator.shared.pathMatching(building: propagatedPmFltResult.building_name, level: propagatedPmFltResult.level_name, x: propagatedPmFltResult.x, y: propagatedPmFltResult.y, heading: propagatedPmFltResult.absolute_heading, HEADING_RANGE: OlympusConstants.HEADING_RANGE, isUseHeading: false, pathType: 0, PADDING_VALUES: PADDING_VALUES)
            isPmSuccess = pmResult.isSuccess
            pmPropagatedPmFltResult.x = pmResult.xyhs[0]
            pmPropagatedPmFltResult.y = pmResult.xyhs[1]
            pmPropagatedPmFltResult.absolute_heading = pmResult.xyhs[2]
        } else {
            let pmResult = OlympusPathMatchingCalculator.shared.pathMatching(building: propagatedPmFltResult.building_name, level: propagatedPmFltResult.level_name, x: propagatedPmFltResult.x, y: propagatedPmFltResult.y, heading: propagatedPmFltResult.absolute_heading, HEADING_RANGE: OlympusConstants.HEADING_RANGE, isUseHeading: true, pathType: 1, PADDING_VALUES: PADDING_VALUES)
            isPmSuccess = pmResult.isSuccess
            pmPropagatedPmFltResult.x = pmResult.xyhs[0]
            pmPropagatedPmFltResult.y = pmResult.xyhs[1]
            pmPropagatedPmFltResult.absolute_heading = pmResult.xyhs[2]
        }
        var tuHeading = compensateHeading(heading: tuResult.absolute_heading)
        
        if (isPmSuccess) {
            if (!isPossibleHeadingCorrection) {
                pmPropagatedPmFltResult.absolute_heading = propagatedPmFltResult.absolute_heading
            }
        } else {
            pmPropagatedPmFltResult.absolute_heading = propagatedPmFltResult.absolute_heading
        }
        
        if (tuHeading >= 270 && (pmPropagatedPmFltResult.absolute_heading >= 0 && pmPropagatedPmFltResult.absolute_heading < 90)) {
            pmPropagatedPmFltResult.absolute_heading = pmPropagatedPmFltResult.absolute_heading + 360
        } else if (pmPropagatedPmFltResult.absolute_heading >= 270 && (tuHeading >= 0 && tuHeading < 90)) {
            tuHeading = tuHeading + 360
        }
        
        var muResult = pmPropagatedPmFltResult
        
        kalmanK = kalmanP / (kalmanP + kalmanR)
        headingKalmanK = headingKalmanP / (headingKalmanP + headingKalmanR)
        
        muResult.x = tuResult.x + kalmanK * (Double(pmPropagatedPmFltResult.x) - tuResult.x)
        muResult.y = tuResult.y + kalmanK * (Double(pmPropagatedPmFltResult.y) - tuResult.y)
        muResult.absolute_heading = compensateHeading(heading: tuHeading + headingKalmanK * (pmPropagatedPmFltResult.absolute_heading - tuHeading))

        kalmanP -= kalmanK * kalmanP
        headingKalmanP -= headingKalmanK * headingKalmanP
        
        var isPmMuSuccess: Bool = false
        var pmMuResult = muResult
        if (mode == OlympusConstants.MODE_PDR) {
            let pmResult = OlympusPathMatchingCalculator.shared.pathMatching(building: muResult.building_name, level: muResult.level_name, x: muResult.x, y: muResult.y, heading: muResult.absolute_heading, HEADING_RANGE: OlympusConstants.HEADING_RANGE, isUseHeading: false, pathType: 0, PADDING_VALUES: PADDING_VALUES)
            isPmMuSuccess = pmResult.isSuccess
            pmMuResult.x = pmResult.xyhs[0]
            pmMuResult.y = pmResult.xyhs[1]
            pmMuResult.absolute_heading = pmResult.xyhs[2]
        } else {
            let pmResult = OlympusPathMatchingCalculator.shared.pathMatching(building: muResult.building_name, level: muResult.level_name, x: muResult.x, y: muResult.y, heading: muResult.absolute_heading, HEADING_RANGE: OlympusConstants.HEADING_RANGE, isUseHeading: true, pathType: 1, PADDING_VALUES: PADDING_VALUES)
            isPmMuSuccess = pmResult.isSuccess
            pmMuResult.x = pmResult.xyhs[0]
            pmMuResult.y = pmResult.xyhs[1]
            pmMuResult.absolute_heading = pmResult.xyhs[2]
        }
        
        if (isPmMuSuccess) {
            let diffX = tuResult.x - pmMuResult.x
            let diffY = tuResult.y - pmMuResult.y
            let diffXY = sqrt(diffX*diffX + diffY*diffY)
            
            var muHeading = pmMuResult.absolute_heading
            if (tuHeading >= 270 && (muHeading >= 0 && muHeading < 90)) {
                muHeading = muHeading + 360
            } else if (muHeading >= 270 && (tuHeading >= 0 && tuHeading < 90)) {
                tuHeading = tuHeading + 360
            }
            let diffH = abs(tuHeading-muHeading)
            
            if (diffXY > 30 || diffH > OlympusConstants.HEADING_RANGE) {
                let propagationResult = propagateUsingUvd(unitDRInfoBuffer: unitDRInfoBuffer, fltResult: pmFltResult)
                let propagationValues: [Double] = propagationResult.1
                
                if (propagationResult.0) {
                    var propagatedResult: [Double] = [pmFltResult.x+propagationValues[0] , pmFltResult.y+propagationValues[1], pmFltResult.absolute_heading+propagationValues[2]]
                    if (mode == OlympusConstants.MODE_PDR) {
                        let pathMatchingResult = OlympusPathMatchingCalculator.shared.pathMatching(building: fltResult.building_name, level: fltResult.level_name, x: propagatedResult[0], y: propagatedResult[1], heading: propagatedResult[2], HEADING_RANGE: OlympusConstants.HEADING_RANGE, isUseHeading: false, pathType: 0, PADDING_VALUES: PADDING_VALUES)
                        propagatedResult = pathMatchingResult.xyhs
                    } else {
                        let pathMatchingResult = OlympusPathMatchingCalculator.shared.pathMatching(building: fltResult.building_name, level: fltResult.level_name, x: propagatedResult[0], y: propagatedResult[1], heading: propagatedResult[2], HEADING_RANGE: OlympusConstants.HEADING_RANGE, isUseHeading: true, pathType: 1, PADDING_VALUES: PADDING_VALUES)
                        propagatedResult = pathMatchingResult.xyhs
                    }
                    updatedResult.x = propagatedResult[0]
                    updatedResult.y = propagatedResult[1]
                    updatedResult.absolute_heading = propagatedResult[2]
                } else {
                    updatedResult.x = tuResult.x
                    updatedResult.y = tuResult.y
                    updatedResult.absolute_heading = tuResult.absolute_heading
                }
                
                backKalmanParam()
            } else {
                if (!isPossibleHeadingCorrection && mode == OlympusConstants.MODE_DR) {
                    pmMuResult.absolute_heading = tuResult.absolute_heading
                }
                saveKalmanParam()
            }
        } else {
            var pathType: Int = 1
            if (mode == OlympusConstants.MODE_PDR) { pathType = 0 }
            let pmResult = OlympusPathMatchingCalculator.shared.pathMatching(building: muResult.building_name, level: muResult.level_name, x: muResult.x, y: muResult.y, heading: muResult.absolute_heading, HEADING_RANGE: OlympusConstants.HEADING_RANGE, isUseHeading: false, pathType: pathType, PADDING_VALUES: PADDING_VALUES)
            updatedResult.x = pmResult.xyhs[0]
            updatedResult.y = pmResult.xyhs[1]
            updatedResult.absolute_heading = pmResult.xyhs[2]
            
            backKalmanParam()
        }
        
        tuResult = updatedResult
        
        return updatedResult
    }
    
    public func getPathTrajMatchingInfo() -> ([[Double]] , [[Double]]) {
        return (self.matchedTraj, self.inputTraj)
    }
    
    private func initPathTrajMatchingInfo() {
        self.matchedTraj = [[Double]]()
        self.inputTraj = [[Double]]()
    }
    
    private func saveKalmanParam() {
        self.pastKalmanP = self.kalmanP
        self.pastKalmanQ = self.kalmanQ
        self.pastKalmanR = self.kalmanR
        self.pastKalmanK = self.kalmanK
        
        self.pastHeadingKalmanP = self.headingKalmanP
        self.pastHeadingKalmanQ = self.headingKalmanQ
        self.pastHeadingKalmanR = self.headingKalmanR
        self.pastHeadingKalmanK = self.headingKalmanK
    }
    
    private func backKalmanParam() {
        self.kalmanP = self.pastKalmanP
        self.kalmanQ = self.pastKalmanQ
        self.kalmanR = self.pastKalmanR
        self.kalmanK = self.pastKalmanK
        
        self.headingKalmanP = self.pastHeadingKalmanP
        self.headingKalmanQ = self.pastHeadingKalmanQ
        self.headingKalmanR = self.pastHeadingKalmanR
        self.headingKalmanK = self.pastHeadingKalmanK
    }
}
