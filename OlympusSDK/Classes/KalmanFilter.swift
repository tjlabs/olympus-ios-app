
import TJLabsCommon

class KalmanFilter {
    init(stackManager: StackManager) {
        self.stackManager = stackManager
        
        tuResult = nil
        tuResultBuffer = [ixyhs]()
        usedUvdIndex = 0
        pathTrajMatchingIndex = 0
        pathTrajTurnIndex = 0
    }
    
    var kalmanP: Float = 1
    var kalmanQ: Float = 0.3
    var kalmanR: Float = 0.5
    var kalmanK: Float = 1
    
    var headingKalmanP: Float = 0.5
    var headingKalmanQ: Float = 0.5
    var headingKalmanR: Float = 1
    var headingKalmanK: Float = 1
    
    var pastKalmanP: Float = 1
    var pastKalmanQ: Float = 0.3
    var pastKalmanR: Float = 0.5
    var pastKalmanK: Float = 1
    
    var pastHeadingKalmanP: Float = 0.5
    var pastHeadingKalmanQ: Float = 0.5
    var pastHeadingKalmanR: Float = 1
    var pastHeadingKalmanK: Float = 1
    
    var stackManager: StackManager?
    var tuResult: FineLocationTrackingOutput?
    
    private var tuResultBuffer = [ixyhs]()
    private var usedUvdIndex: Int = 0
    private var pathTrajMatchingIndex: Int = 0
    private var pathTrajTurnIndex: Int = 0
    
    // MARK: - Constants
    let DR_BUFFER_SIZE_FOR_STRAIGHT: Int = 10 // COEX 12 // DS 6 //default 10 // tips : 4
    let DR_BUFFER_SIZE_FOR_HEAD_STRAIGHT: Int = 3
    let DR_HEADING_CORR_NUM_IDX: Int = 10
    
    func minimizeKalmanR() {
        kalmanR = 0.01
        headingKalmanR = 0.01
    }

    func resetKalmanR() {
        kalmanR = 0.5
        headingKalmanR = 1
    }
    
    private func saveKalmanParam() {
        pastKalmanP = kalmanP
        pastKalmanQ = kalmanQ
        pastKalmanR = kalmanR
        pastKalmanK = kalmanK
        
        pastHeadingKalmanP = headingKalmanP
        pastHeadingKalmanQ = headingKalmanQ
        pastHeadingKalmanR = headingKalmanR
        pastHeadingKalmanK = headingKalmanK
    }
    
    private func backKalmanParam() {
        kalmanP = pastKalmanP
        kalmanQ = pastKalmanQ
        kalmanR = pastKalmanR
        kalmanK = pastKalmanK

        headingKalmanP = pastHeadingKalmanP
        headingKalmanQ = pastHeadingKalmanQ
        headingKalmanR = pastHeadingKalmanR
        headingKalmanK = pastHeadingKalmanK
    }
    
    func updateTuResult(result: FineLocationTrackingOutput) {
        self.tuResult = result
    }
    
    func getTuResultWithUvdIndex(index: Int) -> ixyhs? {
        for tu in self.tuResultBuffer {
            if tu.index == index { return tu }
        }
        return nil
    }
    
    func getTuResult() -> FineLocationTrackingOutput? {
        return self.tuResult
    }
    
    func updateTuPosition(coord: [Float]) {
        self.tuResult?.x = coord[0]
        self.tuResult?.y = coord[1]
    }
    
    func updateTuBuildingLevel(building: String, level: String) {
        tuResult?.building_name = building
        tuResult?.level_name = level
    }
    
    func activateKalmanFilter(fltResult: FineLocationTrackingOutput) {
        JupiterLogger.i(tag: "KalmanFilter", message: "(activateKalmanFilter) - fltResult:\(fltResult)")
        tuResult = fltResult
        KalmanState.isTimeUpdateRunning = true
        KalmanState.isKalmanFilterRunning = true
    }
    
    func updateTuInformation(uvd: UserVelocity, olderPeakIndex: Int?) {
        guard let tuResult = self.tuResult else { return }

        if let olderPeakIndex {
            JupiterLogger.i(tag: "KalmanFilter", message: "(updateTuInformation) - olderPeakIndex:\(olderPeakIndex)")
            if let firstKeep = tuResultBuffer.firstIndex(where: { $0.index >= olderPeakIndex }) {
                if firstKeep > 0 {
                    tuResultBuffer.removeSubrange(0..<firstKeep)
                    JupiterLogger.i(tag: "KalmanFilter", message: "(updateTuInformation) - tuResultBuffer size: \(tuResultBuffer.count+firstKeep) -> \(tuResultBuffer.count)")
                }
            } else {
                tuResultBuffer.removeAll(keepingCapacity: true)
                JupiterLogger.i(tag: "KalmanFilter", message: "(updateTuInformation) - tuResultBuffer removed all")
            }
        }

        tuResultBuffer.append(ixyhs(index: uvd.index,
                                    x: tuResult.x,
                                    y: tuResult.y,
                                    heading: tuResult.absolute_heading))
    }
    
    
    func timeUpdate(uvd: UserVelocity, pastUvd: UserVelocity) -> FineLocationTrackingOutput? {
        guard var tuResult = self.tuResult else { return nil }
        JupiterLogger.i(tag: "KalmanFilter", message: "(timeUpdate) - tuResult before :[\(tuResult.x),\(tuResult.y),\(tuResult.absolute_heading)]")
        let length = uvd.length
        let diffHeading = uvd.heading - pastUvd.heading
        let updatedHeading = TJLabsUtilFunctions.shared.compensateDegree(Double(tuResult.absolute_heading) + Double(diffHeading))
        let updatedHeadingRadian = TJLabsUtilFunctions.shared.degree2radian(degree: updatedHeading)
        let dx = length*cos(updatedHeadingRadian)
        let dy = length*sin(updatedHeadingRadian)
        
        tuResult.x += Float(dx)
        tuResult.y += Float(dy)
        tuResult.absolute_heading = Float(updatedHeading)
        JupiterLogger.i(tag: "KalmanFilter", message: "(timeUpdate) - tuResult after :[\(tuResult.x),\(tuResult.y),\(tuResult.absolute_heading)]")
        return tuResult
    }
    
//    func pdrTimeUpdate(region: String, sectorId: Int, uvd: UserVelocity, pastUvd: UserVelocity, pathMatchingCondition: PathMatchingCondition) -> (FineLocationTrackingOutput, Bool, Bool) {
//        guard let stackManager = self.stackManager else { return }
//        var isNeedRequestPhase4 = false
//        var isDidPathTrajMatching = false
//        var nextTuResult = timeUpdate(uvd: uvd, pastUvd: pastUvd)
//        let currentUvdIndex = uvd.index
//        let currentUvdLength = uvd.length
//        let updatedHeading = nextTuResult?.absolute_heading
//        var pathTrajMatchingHeading = nextTuResult?.absolute_heading
//        let inputUnitDrInfoBuffer = Array(stackManager.userVelocityBuffer.suffix(DR_BUFFER_SIZE_FOR_STRAIGHT))
//
//        var isPossiblePathTrajMatching = checkIsPossiblePathTrajMatching(buffer: inputUnitDrInfoBuffer)
//        var straightThreshold = DR_BUFFER_SIZE_FOR_STRAIGHT
//        if (!isPossiblePathTrajMatching && inputUnitDrInfoBuffer.count < 5) {
//            straightThreshold -= inputUnitDrInfoBuffer.count
//            isPossiblePathTrajMatching = true
//        }
//        let (isDrStraight, turnAngle) = stackManager.isDrBufferStraightCircularStd(numIndex: DR_HEADING_CORR_NUM_IDX, condition: 60)
//        let (isDrVeryStraight, _) = stackManager.isDrBufferStraightCircularStd(numIndex: DR_BUFFER_SIZE_FOR_STRAIGHT, condition: 10)
//
//        if (!isDrStraight && isPossiblePathTrajMatching) {
//            if (pathMatchingCondition.turn && turnAngle <= 135) {
//                isNeedRequestPhase4 = true
//                let linkDirArray = JupiterNodeChecker.shared.linkDirections
//                if (!linkDirArray.isEmpty) {
//                    let inputUserMaskBuffer = Array(stackManager.userMaskBuffer.suffix(straightThreshold))
//
//                    var turnIndex: Int = 0
//                    var uvdIndexMatchedWithTurn: Int = 0
//                    var uvdHeadings = [Double]()
//                    for unitUvd in inputUnitDrInfoBuffer {
//                        uvdHeadings.append(unitUvd.heading)
//                    }
//                    turnIndex = indexOfMaxRateOfChange(in: uvdHeadings)
//
//                    let userX = inputUserMaskBuffer[inputUserMaskBuffer.count-1].x
//                    let userY = inputUserMaskBuffer[inputUserMaskBuffer.count-1].y
//                    let userHeading = inputUserMaskBuffer[inputUserMaskBuffer.count-1].absolute_heading
//
//                    var directionCount = [Int](repeating: 0, count: linkDirArray.count)
//                    for idx in 0..<inputUserMaskBuffer.count {
//                        if (idx > turnIndex) {
//                            break
//                        }
//
//                        var diffValues = [Double]()
//                        for direction in linkDirArray {
//                            var diffDirValue = abs(direction - inputUserMaskBuffer[idx].absolute_heading)
//                            if (diffDirValue > 270) {
//                                diffDirValue = 360 - diffDirValue
//                            }
//                            diffValues.append(Double(diffDirValue))
//                        }
//                        let minIndex = diffValues.firstIndex(of: diffValues.min()!)
//                        directionCount[minIndex!] = directionCount[minIndex!] + 1
//                    }
//
//                    let maxIndex = directionCount.firstIndex(of: directionCount.max()!)
//                    let startHeading = linkDirArray[maxIndex!]
//                    let endHeading = Float(TJLabsUtilFunctions.shared.compensateDegree(Double(userHeading)))
//
//                    let findPathMatchingNodeResult = JupiterPathMatcher.shared.findPathTrajMatchingNode(sectorId: sectorId, fltResult: nextTuResult, x: Float(userX), y: Float(userY), heading: startHeading, uvdBuffer: inputUnitDrInfoBuffer, pathType: 0, linkDirections: linkDirArray)
//
//                    var pathMatchingNodeInfoCandidates = [PassedNodeInfo]()
//                    if !findPathMatchingNodeResult.isEmpty {
//                        var resultCoordX = [Float]()
//                        var resultCoordY = [Float]()
//                        let MARGIN: Double = 44
//
//                        for pathMatchingNode in findPathMatchingNodeResult {
//                            var candidateDirections = [Float]()
//                            var bestMapHeading: Float = endHeading
//
//                            var minDiffValue: Float = 360
//                            let endHeadingCandidates: [Float] = pathMatchingNode.nodeHeadings.filter { !linkDirArray.contains($0) }
//                            for eh in endHeadingCandidates {
//                                var diffValue: Float = 0
//
//                                if (eh > 270 && (updatedHeading >= 0 && updatedHeading < 90)) {
//                                    diffValue = abs(eh - (updatedHeading+360))
//                                } else if (updatedHeading > 270 && (eh >= 0 && eh < 90)) {
//                                    diffValue = abs(updatedHeading - (eh+360))
//                                } else {
//                                    diffValue = abs(eh - updatedHeading)
//                                }
//
//                                if diffValue < minDiffValue {
//                                    minDiffValue = diffValue
//                                    bestMapHeading = eh
//                                }
//                            }
//
//                            candidateDirections.append(bestMapHeading)
//                            if (candidateDirections.count == 1) {
//                                pathTrajMatchingHeading = candidateDirections[0]
//                                let nodeCoord = pathMatchingNode.nodeCoord
//                                let turnType = determineTurnType(headings: uvdHeadings)
//                                var distanceCompensation: Float = 0
//
//                                var startX = nodeCoord[0]
//                                var startY = nodeCoord[1]
//                                for i in (0..<turnIndex).reversed() {
//                                    let startHeadingInRad = TJLabsUtilFunctions.shared.degree2radian(degree: Double(startHeading)-180)
//                                    startX += Float(inputUnitDrInfoBuffer[i].length*cos(startHeadingInRad))
//                                    startY += Float(inputUnitDrInfoBuffer[i].length*sin(startHeadingInRad))
//                                }
//
//                                let startPaddingValues = getPaddingByHeading(startHeading)
//                                let startXy = JupiterPathMatcher.shared.pathMatching(sectorId: sectorId,
//                                                                                     building: nextTuResult.building_name,
//                                                                                     level: nextTuResult.level_name,
//                                                                                     x: startX,
//                                                                                     y: startY,
//                                                                                     heading: startHeading,
//                                                                                     isUseHeading: false,
//                                                                                     mode: .MODE_PEDESTRIAN,
//                                                                                     paddingValues: startPaddingValues)
//
//                                if (startXy.0) {
//                                    let compensationDirection = candidateDirections[0]
//                                    let compensationDirInRad = Float(TJLabsUtilFunctions.shared.degree2radian(degree: Double(compensationDirection)))
//
//                                    var endX = nodeCoord[0]
//                                    var endY = nodeCoord[1]
//                                    for i in turnIndex..<inputUnitDrInfoBuffer.count {
//                                        endX += Float(inputUnitDrInfoBuffer[i].length)*cos(compensationDirInRad)
//                                        endY += Float(inputUnitDrInfoBuffer[i].length)*sin(compensationDirInRad)
//                                    }
//
//                                    if (turnType == 1) {
//                                        distanceCompensation = 0.7
//                                        endX += distanceCompensation*cos(compensationDirInRad)
//                                        endY += distanceCompensation*sin(compensationDirInRad)
//                                    }
//
//                                    let endPaddingValues = getPaddingByHeading(compensationDirection)
//                                    let endXy = JupiterPathMatcher.shared.pathMatching(sectorId: sectorId,
//                                                                                       building: nextTuResult.building_name,
//                                                                                       level: nextTuResult.level_name,
//                                                                                       x: endX,
//                                                                                       y: endY,
//                                                                                       heading: compensationDirection,
//                                                                                       isUseHeading: false,
//                                                                                       mode: .MODE_PEDESTRIAN,
//                                                                                       paddingValues: endPaddingValues)
//                                    if (endXy.0) {
//                                        uvdIndexMatchedWithTurn = inputUnitDrInfoBuffer[turnIndex].index
//                                        // 후보군 중에 하나로 포함
//                                        resultCoordX.append(endX)
//                                        resultCoordY.append(endY)
//                                        pathMatchingNodeInfoCandidates.append(PassedNodeInfo(nodeNumber: pathMatchingNode.nodeNumber, nodeCoord: pathMatchingNode.nodeCoord, nodeHeadings: pathMatchingNode.nodeHeadings, matchedIndex: currentUvdIndex, userHeading: compensationDirection))
//                                    }
//                                }
//                            }
//                        }
//
//                        if (!resultCoordX.isEmpty) {
//                            var minDist: Float = 100
//                            var bestIndex = -1
//                            var bestCoord = [Float]()
//                            for c in 0..<resultCoordX.count {
//                                let diffX = nextTuResult.x - resultCoordX[c]
//                                let diffY = nextTuResult.y - resultCoordY[c]
//                                let distWithUser = sqrt(diffX*diffX + diffY*diffY)
//                                if (distWithUser < minDist) {
//                                    minDist = distWithUser
//                                    bestIndex = c
//                                    bestCoord = [resultCoordX[c], resultCoordY[c]]
//                                }
//                            }
//
//                            if (!bestCoord.isEmpty) {
//                                self.pathTrajTurnIndex = uvdIndexMatchedWithTurn
//                                self.pathTrajMatchingIndex = currentUvdIndex
//                                nextTuResult.x = bestCoord[0]
//                                nextTuResult.y = bestCoord[1]
//                                nextTuResult.absolute_heading = weightedAverageHeading(A: nextTuResult.absolute_heading, B: pathTrajMatchingHeading, weightA: 4, weightB: 6)
//
//                                let headingCompensation: Float = userHeading - Float(inputUnitDrInfoBuffer[inputUnitDrInfoBuffer.count-1].heading)
//                                var headingBuffer: [Float] = []
//                                for uvd in inputUnitDrInfoBuffer {
//                                    let compensatedHeading = TJLabsUtilFunctions.shared.compensateDegree(uvd.heading + Double(headingCompensation) - 180)
//                                    headingBuffer.append(Float(compensatedHeading))
//                                }
//
//                                var xyFromHead: [Float] = [bestCoord[0], bestCoord[1]]
//                                var trajectoryFromHead = [[Float]]()
//                                trajectoryFromHead.append([bestCoord[0], bestCoord[1]])
//                                for i in (0..<inputUnitDrInfoBuffer.count).reversed() {
//                                    let headAngleInRad = Float(TJLabsUtilFunctions.shared.degree2radian(degree: Double(headingBuffer[i])))
//                                    xyFromHead[0] = xyFromHead[0] + Float(inputUnitDrInfoBuffer[i].length)*cos(headAngleInRad)
//                                    xyFromHead[1] = xyFromHead[1] + Float(inputUnitDrInfoBuffer[i].length)*sin(headAngleInRad)
//                                    trajectoryFromHead.append(xyFromHead)
//                                }
//                                isDidPathTrajMatching = true
//                                isNeedRequestPhase4 = false
//                            }
//                        }
//                    }
//                }
//            }
//        } else {
//            if isDrStraight {
//                if (pathMatchingCondition.straight) {
//                    isNeedRequestPhase4 = true
//                }
//
//                let levelName = TJLabsUtilFunctions.shared.removeLevelDirectionString(levelName: tuResult.level_name)
//                let pathMatchingResult = JupiterPathMatcher.shared.pathMatching(sectorId: sectorId,
//                                                                                building: tuResult.building_name,
//                                                                                level: levelName,
//                                                                                x: nextTuResult.x,
//                                                                                y: nextTuResult.y,
//                                                                                heading: nextTuResult.absolute_heading,
//                                                                                isUseHeading: false,
//                                                                                mode: .MODE_PEDESTRIAN,
//                                                                                paddingValues: JupiterMode.PADDING_VALUES_PDR)
//
//                let compensatedHeading = Float(TJLabsUtilFunctions.shared.compensateDegree(Double(pathMatchingResult.1.heading)))
//                let compensatedHeadingInRad = Float(TJLabsUtilFunctions.shared.degree2radian(degree: Double(compensatedHeading)))
//                let dx = Float(currentUvdLength)*cos(compensatedHeadingInRad)
//                let dy = Float(currentUvdLength)*sin(compensatedHeadingInRad)
//
//                let updatedX = self.tuResult.x + dx
//                let updatedY = self.tuResult.y + dy
//
//                nextTuResult.x = updatedX
//                nextTuResult.y = updatedY
//                if (pathMatchingResult.0) { nextTuResult.absolute_heading = compensatedHeading }
//            }
//            initPathTrajMatchingInfo()
//        }
//
//        if !isDidPathTrajMatching {
//            nextTuResult = updateLimitationResult(nextTuResult: nextTuResult, mode: .MODE_PEDESTRIAN)
//        }
//
//        KalmanState.isMeasurementUpdateRunning = true
//        return (nextTuResult, isDidPathTrajMatching, isNeedRequestPhase4)
//    }
    
    private func getPaddingByHeading(_ heading: Float, headingRange: Float = 10.0) -> [Float] {
        switch heading {
        case -headingRange...headingRange,
             (180 - headingRange)...(180 + headingRange):
            return [1.0, 1.0, 0.45, 0.45]
            
        case (90 - headingRange)...(90 + headingRange),
             (270 - headingRange)...(270 + headingRange):
            return [0.45, 0.45, 1.0, 1.0]
            
        default:
            return [1.0, 1.0, 1.0, 1.0]
        }
    }
    
    private func indexOfMaxRateOfChange(in array: [Double]) -> Int {
        var maxRateOfChange: Double = 0.0
        var indexOfMaxChange: Int = 0

        for i in 1..<array.count {
            let rateOfChange = abs(array[i] - array[i - 1])
            if rateOfChange > maxRateOfChange {
                maxRateOfChange = rateOfChange
                indexOfMaxChange = i
            }
        }
        return indexOfMaxChange
    }
    
    private func checkIsPossiblePathTrajMatching(buffer: [UserVelocity]) -> Bool {
        return buffer.allSatisfy { $0.index != pathTrajMatchingIndex }
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
        
        if (turnCount >= 1) || (maxChange > 55 && maxChange < 125) {
            return 0
        } else if absoluteChanges.allSatisfy({ $0 < 30 }) {
            return 1
        } else {
            return 2
        }
    }
    
    func normalizeAngle(_ angle: Double) -> Double {
        let normalizedAngle = fmod(angle, 360)
        return normalizedAngle < 0 ? normalizedAngle + 360 : normalizedAngle
    }

    public func weightedAverageHeading(A: Float, B: Float, weightA: Float, weightB: Float) -> Float {
        let A_rad = Float(TJLabsUtilFunctions.shared.degree2radian(degree: normalizeAngle(Double(A))))
        let B_rad = Float(TJLabsUtilFunctions.shared.degree2radian(degree: normalizeAngle(Double(B))))
        
        // Compute the weighted components
        let x = weightA * cos(A_rad) + weightB * cos(B_rad)
        let y = weightA * sin(A_rad) + weightB * sin(B_rad)
        
        let result_rad = atan2(y, x)

        var result_deg = Float(TJLabsUtilFunctions.shared.radian2degree(radian: Double(result_rad)))

        if result_deg < 0 {
            result_deg += 360
        }
        
        return result_deg
    }
    
    func drTimeUpdate(region: String, sectorId: Int, uvd: UserVelocity, pastUvd: UserVelocity) -> FineLocationTrackingOutput? {
        guard let stackManager = self.stackManager else { return nil }
        guard var nextTuResult = timeUpdate(uvd: uvd, pastUvd: pastUvd) else { return nil }
        let paddingValues = JupiterMode.PADDING_VALUES_DR
        
        let drBufferStraightResults = stackManager.isDrBufferStraightCircularStd(numIndex: DR_HEADING_CORR_NUM_IDX, condition: 5)
        let isDrStraight = nextTuResult.level_name == "B0" ? false : drBufferStraightResults.0
        
        if let pmResults = PathMatcher.shared.pathMatching(sectorId: sectorId, building: nextTuResult.building_name, level: nextTuResult.level_name, x: nextTuResult.x, y: nextTuResult.y, heading: nextTuResult.absolute_heading, isUseHeading: true, mode: .MODE_VEHICLE, paddingValues: paddingValues) {
            nextTuResult.absolute_heading = isDrStraight ? Float(TJLabsUtilFunctions.shared.compensateDegree(Double(pmResults.heading))) : Float(TJLabsUtilFunctions.shared.compensateDegree(Double(nextTuResult.absolute_heading)))
            JupiterLogger.i(tag: "KalmanFilter", message: "(timeUpdate) - pmResults :[\(nextTuResult.x),\(nextTuResult.y),\(nextTuResult.absolute_heading)]")
        } else {
            if let pmResultsWithoutHeading = PathMatcher.shared.pathMatching(sectorId: sectorId, building: nextTuResult.building_name, level: nextTuResult.level_name, x: nextTuResult.x, y: nextTuResult.y, heading: nextTuResult.absolute_heading, isUseHeading: false, mode: .MODE_VEHICLE, paddingValues: paddingValues) {
                
                nextTuResult.x = pmResultsWithoutHeading.x*0.2 + nextTuResult.x*0.8
                nextTuResult.y = pmResultsWithoutHeading.y*0.2 + nextTuResult.y*0.8
                nextTuResult.absolute_heading = Float(TJLabsUtilFunctions.shared.compensateDegree(Double(nextTuResult.absolute_heading)))
                JupiterLogger.i(tag: "KalmanFilter", message: "(timeUpdate) - pmResultsWithoutHeading :[\(nextTuResult.x),\(nextTuResult.y),\(nextTuResult.absolute_heading)]")
            }
        }
        nextTuResult = updateLimitationResult(nextTuResult: nextTuResult)
        updateTuResult(result: nextTuResult)
        kalmanP += kalmanQ
        headingKalmanP += headingKalmanQ
        KalmanState.isMeasurementUpdateRunning = true
        
        return nextTuResult
    }
    
    private func updateLimitationResult(nextTuResult: FineLocationTrackingOutput) -> FineLocationTrackingOutput {
        var updatedTuResult = nextTuResult
        let limitationResult = PathMatcher.shared.getTimeUpdateLimitation(level: nextTuResult.level_name)
//        JupiterLogger.i(tag: "KalmanFilter", message: "(updateLimitationResult) - limitationResult: \(limitationResult)")
        
        if (limitationResult.limitType == LimitationType.Y_LIMIT) {
            if (nextTuResult.y < limitationResult.limitValues[0]) {
                updatedTuResult.y = limitationResult.limitValues[0]
            } else if (nextTuResult.y > limitationResult.limitValues[1]) {
                updatedTuResult.y = limitationResult.limitValues[1]
            }
        } else if (limitationResult.limitType == LimitationType.X_LIMIT) {
            if (nextTuResult.x < limitationResult.limitValues[0]) {
                updatedTuResult.x = limitationResult.limitValues[0]
            } else if (nextTuResult.x > limitationResult.limitValues[1]) {
                updatedTuResult.x = limitationResult.limitValues[1]
            }
        }
        return updatedTuResult
    }
    
    
    func measurementUpdate(sectorId: Int, resultForCorrection: FineLocationTrackingOutput, mode: UserMode) -> FineLocationTrackingOutput? {
        guard let tuResult = self.tuResult else { return nil }
        let paddingValues = mode == .MODE_PEDESTRIAN ? JupiterMode.PADDING_VALUES_PDR : JupiterMode.PADDING_VALUES_DR
        
        var updatedResult = resultForCorrection
        JupiterLogger.i(tag: "KalmanFilter", message: "(measurementUpdate) - resultForCorrection:[\(resultForCorrection.x),\(resultForCorrection.y),\(resultForCorrection.absolute_heading)]")
        if let pmResult = performPathMatching(sectorId: sectorId, fltResult: resultForCorrection, PADDING_VALUES: paddingValues, mode: mode) {
            var pmFltResult = updateResultWithPathMatching(pmResult: pmResult, correctionResult: resultForCorrection)
            let muResult = applyKalmanFilter(tuResult: tuResult, correctionResult: pmFltResult)
            
            if let pmResultAfterMu = performPathMatching(sectorId: sectorId, fltResult: muResult, PADDING_VALUES: paddingValues, mode: mode) {
                updatedResult = updateResultWithPathMatching(pmResult: pmResultAfterMu, correctionResult: muResult)
            } else {
                if let pmResult = fallbackPathMatching(sectorId: sectorId, muResult: muResult, PADDING_VALUES: paddingValues, mode: mode) {
                    updateResultWithFallback(&updatedResult, pmResult: pmResult)
                    backKalmanParam()
                }
            }
        }
        JupiterLogger.i(tag: "KalmanFilter", message: "(measurementUpdate) - updatedResult:[\(updatedResult.x),\(updatedResult.y),\(updatedResult.absolute_heading)]")
        self.tuResult = updatedResult
        return updatedResult
    }

    private func performPathMatching(sectorId: Int, fltResult: FineLocationTrackingOutput, PADDING_VALUES: [Float], mode: UserMode) -> ixyhs? {
        let pmResult = PathMatcher.shared.pathMatching(sectorId: sectorId,
                                                              building: fltResult.building_name,
                                                              level: fltResult.level_name,
                                                              x: fltResult.x,
                                                              y: fltResult.y,
                                                              heading: fltResult.absolute_heading,
                                                              isUseHeading: mode != .MODE_PEDESTRIAN,
                                                              mode: mode,
                                                              paddingValues: PADDING_VALUES)
        return pmResult
    }

    private func updateResultWithPathMatching(pmResult: ixyhs, correctionResult: FineLocationTrackingOutput, useHeading: Bool = false) -> FineLocationTrackingOutput {
        var updatedResult = correctionResult
        updatedResult.x = pmResult.x
        updatedResult.y = pmResult.y
        if useHeading {
            updatedResult.absolute_heading = pmResult.heading
        }
        return updatedResult
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

    private func applyKalmanFilter(tuResult: FineLocationTrackingOutput, correctionResult: FineLocationTrackingOutput) -> FineLocationTrackingOutput {
        var muResult = correctionResult
        let kalmanK = kalmanP / (kalmanP + kalmanR)
        let headingKalmanK = headingKalmanP / (headingKalmanP + headingKalmanR)
        
        muResult.x = tuResult.x + kalmanK * (correctionResult.x - tuResult.x)
        muResult.y = tuResult.y + kalmanK * (correctionResult.y - tuResult.y)
        
        let muHeading: Float = tuResult.absolute_heading + headingKalmanK * adjustHeading(correctionResult.absolute_heading, tuResult.absolute_heading)
        muResult.absolute_heading = Float(TJLabsUtilFunctions.shared.compensateDegree(Double(muHeading)))
        
        kalmanP -= kalmanK * kalmanP
        headingKalmanP -= headingKalmanK * headingKalmanP
        JupiterLogger.i(tag: "KalmanFilter", message: "(applyKalmanFilter) - tuResult:[\(tuResult.x),\(tuResult.y),\(tuResult.absolute_heading)], muResult:[\(muResult.x),\(muResult.y),\(muResult.absolute_heading)]")
        return muResult
    }


    // Update result from propagation
    private func updateResultFromPropagation(sectorId: Int, _ updatedResult: inout FineLocationTrackingOutput, propagationResult: ixyhs?, fltResult: FineLocationTrackingOutput, pmFltResult: FineLocationTrackingOutput, mode: UserMode, PADDING_VALUES: [Float]) {
        if let propagationResult {
            let propagatedResult = [pmFltResult.x + propagationResult.x, pmFltResult.y + propagationResult.y, pmFltResult.absolute_heading + propagationResult.heading]
            guard let pmResult = PathMatcher.shared.pathMatching(sectorId: sectorId,
                                                                  building: fltResult.building_name,
                                                                  level: fltResult.level_name,
                                                                  x: propagatedResult[0],
                                                                  y: propagatedResult[1],
                                                                  heading: propagatedResult[2],
                                                                  isUseHeading: mode != .MODE_PEDESTRIAN,
                                                                  mode: mode,
                                                                     paddingValues: PADDING_VALUES) else { return }
            updatedResult.x = pmResult.x
            updatedResult.y = pmResult.y
            updatedResult.absolute_heading = pmResult.heading
        } else {
            guard let tuResult = self.tuResult else { return }
            updatedResult.x = tuResult.x
            updatedResult.y = tuResult.y
            updatedResult.absolute_heading = tuResult.absolute_heading
        }
    }

    // Fallback path matching if the previous one failed
    private func fallbackPathMatching(sectorId: Int, muResult: FineLocationTrackingOutput, PADDING_VALUES: [Float], mode: UserMode) -> ixyhs? {
        return PathMatcher.shared.pathMatching(sectorId: sectorId,
                                                      building: muResult.building_name,
                                                      level: muResult.level_name,
                                                      x: muResult.x, y: muResult.y, heading: muResult.absolute_heading,
                                                      isUseHeading: false,
                                                      mode: mode,
                                                      paddingValues: PADDING_VALUES)
    }

    // Update result with fallback path matching
    private func updateResultWithFallback(_ updatedResult: inout FineLocationTrackingOutput, pmResult: ixyhs) {
        updatedResult.x = pmResult.x
        updatedResult.y = pmResult.y
        updatedResult.absolute_heading = pmResult.heading
    }
}
