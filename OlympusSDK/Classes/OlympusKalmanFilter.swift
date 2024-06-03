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
    var matchedTraj = [[Double]]()
    var inputTraj = [[Double]]()
    var distanceLost: Double = 0
    
    var uvdIndexBuffer = [Int]()
    var uvdHeadingBuffer = [Double]()
    var tuResultBuffer = [[Double]]()
    var isNeedUvdIndexBufferClear: Bool = false
    var usedUvdIndex: Int = 0
    
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
        self.matchedTraj = [[Double]]()
        self.inputTraj = [[Double]]()
        
        self.uvdIndexBuffer = [Int]()
        self.uvdHeadingBuffer = [Double]()
        self.tuResultBuffer = [[Double]]()
        self.isNeedUvdIndexBufferClear = false
        self.usedUvdIndex = 0
        
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
    
    public func timeUpdate(recentResult: FineLocationTrackingResult, length: Double, diffHeading: Double, isPossibleHeadingCorrection: Bool, unitDRInfoBuffer: [UnitDRInfo], userMaskBuffer: [UserMask], isNeedPathTrajMatching: Bool, mode: String) -> FineLocationTrackingFromServer {
        var outputResult: FineLocationTrackingFromServer = self.tuResult
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
            var isDidPathTrajMatching: Bool = false
            let currentUvdIndex = unitDRInfoBuffer[unitDRInfoBuffer.count-1].index

            let inputUnitDrInfoBuffer = Array(unitDRInfoBuffer.suffix(OlympusConstants.DR_BUFFER_SIZE_FOR_STRAIGHT))
            var isPossiblePathTrajMatching: Bool = true
            for unitUvd in inputUnitDrInfoBuffer {
                if (unitUvd.index == self.pathTrajMatchingIndex) {
                    isPossiblePathTrajMatching = false
                    break
                }
            }
            
            print(getLocalTimeString() + " , (Olympus) Path-Matching : isPossiblePathTrajMatching = \(isPossiblePathTrajMatching)")
            let drBufferStraightResult = isDrBufferStraight(unitDRInfoBuffer: unitDRInfoBuffer, numIndex: OlympusConstants.DR_BUFFER_SIZE_FOR_STRAIGHT, condition: 60.0)
            
            let isDrStraight: Bool = drBufferStraightResult.0
            let turnAngle = drBufferStraightResult.1
            
            if (!isDrStraight && isPossiblePathTrajMatching) {
                // 사용자는 Turn 하는 궤적이다
                if (isNeedPathTrajMatching && turnAngle <= 135) {
                    // Node를 옮기자
                    
                    if (!linkDirections.isEmpty) {
                        let inputUserMaskBuffer = Array(userMaskBuffer.suffix(OlympusConstants.DR_BUFFER_SIZE_FOR_STRAIGHT))
                        let userX = inputUserMaskBuffer[inputUserMaskBuffer.count-1].x
                        let userY = inputUserMaskBuffer[inputUserMaskBuffer.count-1].y
                        let userHeading = inputUserMaskBuffer[inputUserMaskBuffer.count-1].absolute_heading
                        let startHeading = inputUserMaskBuffer[0].absolute_heading
                        let findPathMatchingNodeResult = OlympusPathMatchingCalculator.shared.findPathTrajMatchingNode(fltResult: outputResult, x: Double(userX), y: Double(userY), heading: startHeading, uvdBuffer: inputUnitDrInfoBuffer, pathType: 0, linkDirections: linkDirections)
                        print(getLocalTimeString() + " , (Olympus) Path-Matching : findPathMatchingNodeResult = \(findPathMatchingNodeResult)")
                        if findPathMatchingNodeResult.0 != -1 {
                            let MARGIN: Double = 30
                            let endHeading = compensateHeading(heading: userHeading)
                            var diffHeadings = [Double]()
                            var candidateDirections = [Double]()
                            for mapHeading in findPathMatchingNodeResult.2 {
                                var diffValue: Double = 0
                                if (endHeading > 270 && (mapHeading >= 0 && mapHeading < 90)) {
                                    diffValue = abs(endHeading - (mapHeading+360))
                                } else if (mapHeading > 270 && (endHeading >= 0 && endHeading < 90)) {
                                    diffValue = abs(mapHeading - (endHeading+360))
                                } else {
                                    diffValue = abs(endHeading - mapHeading)
                                }
                                diffHeadings.append(diffValue)
                                
                                if (diffValue <= MARGIN) {
                                    candidateDirections.append(mapHeading)
                                }
                            }
                            
                            print(getLocalTimeString() + " , (Olympus) Path-Matching : endHeading = \(endHeading)")
                            print(getLocalTimeString() + " , (Olympus) Path-Matching : diffHeadings = \(diffHeadings)")
                            print(getLocalTimeString() + " , (Olympus) Path-Matching : candidateDirections = \(candidateDirections)")
                            if (candidateDirections.count == 1) {
                                self.pathTrajMatchingIndex = currentUvdIndex
                                var uvdHeadings = [Double]()
                                for unitUvd in inputUnitDrInfoBuffer {
                                    uvdHeadings.append(unitUvd.heading)
                                }
                                print(getLocalTimeString() + " , (Olympus) Path-Matching : UVD Headings = \(uvdHeadings)")
                                let turnIndex = indexOfMaxRateOfChange(in: uvdHeadings)
                                let compensationDirection = candidateDirections[0]
                                let nodeCoord = findPathMatchingNodeResult.1
                                var startX = nodeCoord[0]
                                var startY = nodeCoord[1]
                                
                                var endX = nodeCoord[0]
                                var endY = nodeCoord[1]
                                for i in turnIndex..<inputUnitDrInfoBuffer.count {
                                    endX += inputUnitDrInfoBuffer[i].length*cos(compensationDirection*OlympusConstants.D2R)
                                    endY += inputUnitDrInfoBuffer[i].length*sin(compensationDirection*OlympusConstants.D2R)
                                }
                                for i in (0..<turnIndex).reversed() {
                                    startX += inputUnitDrInfoBuffer[i].length*cos((startHeading-180)*OlympusConstants.D2R)
                                    startY += inputUnitDrInfoBuffer[i].length*sin((startHeading-180)*OlympusConstants.D2R)
                                }
                                outputResult.x = endX
                                outputResult.y = endY
                                
                                let headingCompensation: Double = userHeading - inputUnitDrInfoBuffer[inputUnitDrInfoBuffer.count-1].heading
                                var headingBuffer: [Double] = []
                                for uvd in inputUnitDrInfoBuffer {
                                    let compensatedHeading = compensateHeading(heading: uvd.heading + headingCompensation - 180)
                                    headingBuffer.append(compensatedHeading)
                                }
                                
                                var xyFromHead :[Double] = [endX, endY]
                                var trajectoryFromHead = [[Double]]()
                                trajectoryFromHead.append([endX, endY])
                                for i in (0..<inputUnitDrInfoBuffer.count).reversed() {
                                    let headAngle = headingBuffer[i]
                                    xyFromHead[0] = xyFromHead[0] + inputUnitDrInfoBuffer[i].length*cos(headAngle*OlympusConstants.D2R)
                                    xyFromHead[1] = xyFromHead[1] + inputUnitDrInfoBuffer[i].length*sin(headAngle*OlympusConstants.D2R)
                                    trajectoryFromHead.append(xyFromHead)
                                }
                                self.inputTraj = trajectoryFromHead
                            }
                        }
                    }
                    isDidPathTrajMatching = true
                }
            } else {
                let drBufferVeryStraightResult = isDrBufferStraight(unitDRInfoBuffer: unitDRInfoBuffer, numIndex: OlympusConstants.DR_BUFFER_SIZE_FOR_STRAIGHT, condition: 10.0)
                let isDrVeryStraight: Bool = drBufferVeryStraightResult.0
                if (isDrVeryStraight) {
                    let pathMatchingResult = OlympusPathMatchingCalculator.shared.pathMatching(building: self.tuResult.building_name, level: levelName, x: updatedX, y: updatedY, heading: updatedHeading, HEADING_RANGE: OlympusConstants.HEADING_RANGE, isUseHeading: true, pathType: 0, PADDING_VALUES: OlympusConstants.PADDING_VALUES)
                    outputResult.x = pathMatchingResult.xyhs[0]*0.5 + updatedX*0.5
                    outputResult.y = pathMatchingResult.xyhs[1]*0.5 + updatedY*0.5
                    if (pathMatchingResult.0) { outputResult.absolute_heading = compensateHeading(heading: pathMatchingResult.xyhs[2]) }
                }
                initPathTrajMatchingInfo()
            }
            
            if (!isDidPathTrajMatching) {
                let limitationResult = OlympusPathMatchingCalculator.shared.getTimeUpdateLimitation(mode: mode)
                if (limitationResult.limitType == .Y_LIMIT) {
//                    print("(Link Info) : Y Limit // before = \(outputResult.x) , \(outputResult.y)")
                    if (outputResult.y < limitationResult.limitValues[0]) {
                        outputResult.y = limitationResult.limitValues[0]
                    } else if (outputResult.y > limitationResult.limitValues[1]) {
                        outputResult.y = limitationResult.limitValues[1]
                    }
//                    print("(Link Info) : Y Limit // after = \(outputResult.x) , \(outputResult.y)")
//                    print("(Link Info) -------------------------------------- ")
                } else if (limitationResult.limitType == .X_LIMIT) {
//                    print("(Link Info) : X Limit // before = \(outputResult.x) , \(outputResult.y)")
                    if (outputResult.x < limitationResult.limitValues[0]) {
                        outputResult.x = limitationResult.limitValues[0]
                    } else if (outputResult.x > limitationResult.limitValues[1]) {
                        outputResult.x = limitationResult.limitValues[1]
                    }
//                    print("(Link Info) : X Limit // after = \(outputResult.x) , \(outputResult.y)")
//                    print("(Link Info) -------------------------------------- ")
                }
            } else {
                let pathMatching = OlympusPathMatchingCalculator.shared.pathMatching(building: self.tuResult.building_name, level: levelName, x: outputResult.x, y: outputResult.y, heading: outputResult.absolute_heading, HEADING_RANGE: OlympusConstants.HEADING_RANGE, isUseHeading: false, pathType: 0, PADDING_VALUES: OlympusConstants.PADDING_VALUES)
                outputResult.x = pathMatching.xyhs[0]
                outputResult.y = pathMatching.xyhs[1]
            }
        } else {
            let drBufferStraightResult = isDrBufferStraight(unitDRInfoBuffer: unitDRInfoBuffer, numIndex: OlympusConstants.DR_HEADING_CORR_NUM_IDX, condition: 10.0)
            let isDrStraight: Bool = drBufferStraightResult.0
            let pathMatchingResult =  OlympusPathMatchingCalculator.shared.pathMatching(building: self.tuResult.building_name, level: levelName, x: updatedX, y: updatedY, heading: updatedHeading, HEADING_RANGE: OlympusConstants.HEADING_RANGE, isUseHeading: true, pathType: 1, PADDING_VALUES: OlympusConstants.PADDING_VALUES)
            
            if (pathMatchingResult.isSuccess) {
                outputResult.x = (pathMatchingResult.1[0]*0.5 + updatedX*0.5)
                outputResult.y = (pathMatchingResult.1[1]*0.5 + updatedY*0.5)
                outputResult.absolute_heading = compensateHeading(heading: updatedHeading)

                if (pathMatchingResult.0 && isDrStraight){
                    outputResult.absolute_heading = compensateHeading(heading: pathMatchingResult.1[2])
                }
            } else {
                let pathMatchingResult =  OlympusPathMatchingCalculator.shared.pathMatching(building: self.tuResult.building_name, level: levelName, x: updatedX, y: updatedY, heading: updatedHeading, HEADING_RANGE: OlympusConstants.HEADING_RANGE, isUseHeading: false, pathType: 1, PADDING_VALUES: OlympusConstants.PADDING_VALUES)
                outputResult.x = (pathMatchingResult.1[0]*0.5 + updatedX*0.5)
                outputResult.y = (pathMatchingResult.1[1]*0.5 + updatedY*0.5)
                outputResult.absolute_heading = compensateHeading(heading: updatedHeading)
            }
            
            // DR
            let limitationResult = OlympusPathMatchingCalculator.shared.getTimeUpdateLimitation(mode: mode)
            if (limitationResult.limitType == .Y_LIMIT) {
//                    print("(Link Info) : Y Limit // before = \(outputResult.x) , \(outputResult.y)")
                if (outputResult.y < limitationResult.limitValues[0]) {
                    outputResult.y = limitationResult.limitValues[0]
                } else if (outputResult.y > limitationResult.limitValues[1]) {
                    outputResult.y = limitationResult.limitValues[1]
                }
//                    print("(Link Info) : Y Limit // after = \(outputResult.x) , \(outputResult.y)")
//                    print("(Link Info) -------------------------------------- ")
            } else if (limitationResult.limitType == .X_LIMIT) {
//                    print("(Link Info) : X Limit // before = \(outputResult.x) , \(outputResult.y)")
                if (outputResult.x < limitationResult.limitValues[0]) {
                    outputResult.x = limitationResult.limitValues[0]
                } else if (outputResult.x > limitationResult.limitValues[1]) {
                    outputResult.x = limitationResult.limitValues[1]
                }
//                    print("(Link Info) : X Limit // after = \(outputResult.x) , \(outputResult.y)")
//                    print("(Link Info) -------------------------------------- ")
            }
        }
        
        
        tuResult = outputResult
        
        kalmanP += kalmanQ
        headingKalmanP += headingKalmanQ
        muFlag = true
        
        return outputResult
    }
    
    
//    public func timeUpdate(recentResult: FineLocationTrackingResult, length: Double, diffHeading: Double, isPossibleHeadingCorrection: Bool, unitDRInfoBuffer: [UnitDRInfo], userMaskBuffer: [UserMask], mode: String) -> FineLocationTrackingFromServer {
//        var outputResult: FineLocationTrackingFromServer = self.tuResult
//        let levelName = removeLevelDirectionString(levelName: self.tuResult.level_name)
//        
//        let updatedHeading = compensateHeading(heading: self.tuResult.absolute_heading + diffHeading)
//        let dx = length*cos(updatedHeading*OlympusConstants.D2R)
//        let dy = length*sin(updatedHeading*OlympusConstants.D2R)
//        
//        let updatedX = self.tuResult.x + dx
//        let updatedY = self.tuResult.y + dy
//        
//        outputResult.x = updatedX
//        outputResult.y = updatedY
//        outputResult.absolute_heading = updatedHeading
//        
//        if (mode == OlympusConstants.MODE_PDR) {
//            // PDR
//            var isDidPathTrajMatching: Bool = false
//            let currentUvdIndex = unitDRInfoBuffer[unitDRInfoBuffer.count-1].index
////            let isDrStraight: Bool = isDrBufferStraight(unitDRInfoBuffer: unitDRInfoBuffer, numIndex: OlympusConstants.DR_BUFFER_SIZE_FOR_STRAIGHT, condition: 80.0)
//            let drBufferStraightResult = isDrBufferStraight(unitDRInfoBuffer: unitDRInfoBuffer, numIndex: OlympusConstants.DR_BUFFER_SIZE_FOR_STRAIGHT, condition: 60.0)
//            
//            let inputUnitDrInfoBuffer = Array(unitDRInfoBuffer.suffix(OlympusConstants.DR_BUFFER_SIZE_FOR_STRAIGHT))
//            let circularStd = calCircularStd(for: inputUnitDrInfoBuffer)
//            
//            let isDrStraight: Bool = drBufferStraightResult.0
//            let turnAngle = drBufferStraightResult.1
//            print(getLocalTimeString() + " , (Olympus) Path-Matching : ----------------------------")
//            print(getLocalTimeString() + " , (Olympus) Path-Matching : circularStd = \(circularStd)")
//            print(getLocalTimeString() + " , (Olympus) Path-Matching : drBufferStraightResult = \(drBufferStraightResult)")
//            // 이전 Path-Traj Matching 수행한 Index와 현재 Index 수의 차이
//            let diffPathTrajMatchingIndex = currentUvdIndex - self.pathTrajMatchingIndex
//            print(getLocalTimeString() + " , (Olympus) Path-Matching : diffPathTrajMatchingIndex = \(diffPathTrajMatchingIndex)")
//            if (!isDrStraight && diffPathTrajMatchingIndex >= OlympusConstants.REQUIRED_PATH_TRAJ_MATCHING_INDEX) {
//                var isPossiblePathTrajMatching: Bool = true
//                
////                let drBufferForPathMatching = Array(unitDRInfoBuffer.suffix(OlympusConstants.DR_BUFFER_SIZE_FOR_STRAIGHT/2))
//                let drBufferForPathMatching = Array(unitDRInfoBuffer.suffix(OlympusConstants.DR_BUFFER_SIZE_FOR_HEAD_STRAIGHT))
//                
//                
//                for unitUvd in inputUnitDrInfoBuffer {
//                    if (unitUvd.index == self.pathTrajMatchingIndex) {
//                        isPossiblePathTrajMatching = false
//                        break
//                    }
//                }
//                
//                let headStraightResult = isDrBufferStraight(unitDRInfoBuffer: drBufferForPathMatching, numIndex: OlympusConstants.DR_BUFFER_SIZE_FOR_HEAD_STRAIGHT, condition: 24)
//                let circularStdHead = calCircularStd(for: drBufferForPathMatching)
//                print(getLocalTimeString() + " , (Olympus) Path-Matching : inputUnitDrInfoBuffer = \(inputUnitDrInfoBuffer)")
//                print(getLocalTimeString() + " , (Olympus) Path-Matching : circularStdHead = \(circularStdHead)")
//                print(getLocalTimeString() + " , (Olympus) Path-Matching : headStraightResult = \(headStraightResult)")
//                let isHeadStraight: Bool = headStraightResult.0
////                if (isHeadStraight && isPossiblePathTrajMatching) {
//                if (circularStdHead <= 12 && isPossiblePathTrajMatching) {
//                    self.pathTrajMatchingIndex = unitDRInfoBuffer[unitDRInfoBuffer.count-1].index
//                    
//                    var inputUserMaskBuffer = [UserMask]()
//                    for userMask in userMaskBuffer {
//                        if (userMask.index >= inputUnitDrInfoBuffer[0].index) {
//                            inputUserMaskBuffer.append(userMask)
//                        }
//                    }
////                    let paddingValues = getPathTrajMatchingPaddingValues(uvdArray: inputUnitDrInfoBuffer, startHeading: inputUserMaskBuffer[0].absolute_heading)
//                    let paddingValues: [Double] = [5, 5, 5, 5]
//                    print(getLocalTimeString() + " , (Olympus) Path-Matching : paddingValues = \(paddingValues)")
//                    let pathTrajMatchingResult = OlympusPathMatchingCalculator.shared.extendedPathTrajectoryMatching(building: self.tuResult.building_name, level: levelName, x: updatedX, y: updatedY, heading: updatedHeading, pastResult: recentResult, unitDRInfoBuffer: inputUnitDrInfoBuffer, userMaskBuffer: inputUserMaskBuffer, turnAngle: turnAngle, pathType: 0, mode: mode, PADDING_VALUES: paddingValues)
////                    let pathTrajMatchingResult = OlympusPathMatchingCalculator.shared.pathTrajectoryMatching(building: self.tuResult.building_name, level: levelName, x: Double(inputUserMaskBuffer[0].x), y: Double(inputUserMaskBuffer[0].y), heading: updatedHeading, pastResult: recentResult, unitDRInfoBuffer: inputUnitDrInfoBuffer, userMaskBuffer: inputUserMaskBuffer, turnAngle: turnAngle, pathType: 0, mode: mode, PADDING_VALUES: paddingValues)
//                    print(getLocalTimeString() + " , (Olympus) Path-Matching : pathTrajMatchingResult = \(pathTrajMatchingResult)")
//                    if (pathTrajMatchingResult.isSuccess) {
//                        let diffNorm = sqrt((pathTrajMatchingResult.xyd[0]-updatedX)*(pathTrajMatchingResult.xyd[0]-updatedX) + (pathTrajMatchingResult.xyd[1]-updatedY)*(pathTrajMatchingResult.xyd[1]-updatedY))
//                        if (diffNorm < 1) {
//                            outputResult.x = pathTrajMatchingResult.xyd[0]*0.5 + updatedX*0.5
//                            outputResult.y = pathTrajMatchingResult.xyd[1]*0.5 + updatedY*0.5
//                        } else {
//                            outputResult.x = pathTrajMatchingResult.xyd[0]
//                            outputResult.y = pathTrajMatchingResult.xyd[1]
//                        }
//                        
//                        self.matchedTraj = pathTrajMatchingResult.matchedTraj
//                        self.inputTraj = pathTrajMatchingResult.inputTraj
//                        self.distanceLost = pathTrajMatchingResult.xyd[5]
//                    } else {
//                        self.distanceLost = -100
//                        initPathTrajMatchingInfo()
//                    }
//                    isDidPathTrajMatching = true
//                }
////                self.pathTrajMatchingIndex = unitDRInfoBuffer[unitDRInfoBuffer.count-1].index
////                let drBufferForPathMatching = Array(unitDRInfoBuffer.suffix(OlympusConstants.DR_BUFFER_SIZE_FOR_STRAIGHT))
////                let pathTrajMatchingResult = OlympusPathMatchingCalculator.shared.pathTrajectoryMatching(building: self.tuResult.building_name, level: levelName, x: updatedX, y: updatedY, heading: updatedHeading, pastResult: recentResult, unitDRInfoBuffer: drBufferForPathMatching, HEADING_RANGE: OlympusConstants.HEADING_RANGE, pathType: 0, mode: mode, PADDING_VALUE: 5)
////                if (pathTrajMatchingResult.isSuccess) {
////                    outputResult.x = pathTrajMatchingResult.xyd[0]*0.5 + updatedX*0.5
////                    outputResult.y = pathTrajMatchingResult.xyd[1]*0.5 + updatedY*0.5
////                    self.matchedTraj = pathTrajMatchingResult.matchedTraj
////                    self.inputTraj = pathTrajMatchingResult.inputTraj
////                } else {
////                    initPathTrajMatchingInfo()
////                }
////                isDidPathTrajMatching = true
//            } else {
//                let drBufferVeryStraightResult = isDrBufferStraight(unitDRInfoBuffer: unitDRInfoBuffer, numIndex: OlympusConstants.DR_BUFFER_SIZE_FOR_STRAIGHT, condition: 10.0)
//                let isDrVeryStraight: Bool = drBufferVeryStraightResult.0
//                if (isDrVeryStraight) {
//                    let pathMatchingResult = OlympusPathMatchingCalculator.shared.pathMatching(building: self.tuResult.building_name, level: levelName, x: updatedX, y: updatedY, heading: updatedHeading, HEADING_RANGE: OlympusConstants.HEADING_RANGE, isUseHeading: true, pathType: 0, PADDING_VALUES: OlympusConstants.PADDING_VALUES)
//                    outputResult.x = pathMatchingResult.xyhs[0]*0.5 + updatedX*0.5
//                    outputResult.y = pathMatchingResult.xyhs[1]*0.5 + updatedY*0.5
//                    if (pathMatchingResult.0) { outputResult.absolute_heading = compensateHeading(heading: pathMatchingResult.xyhs[2]) }
//                }
//                initPathTrajMatchingInfo()
//            }
//            
//            if (!isDidPathTrajMatching) {
//                let limitationResult = OlympusPathMatchingCalculator.shared.getTimeUpdateLimitation(mode: mode)
//                if (limitationResult.limitType == .Y_LIMIT) {
////                    print("(Link Info) : Y Limit // before = \(outputResult.x) , \(outputResult.y)")
//                    if (outputResult.y < limitationResult.limitValues[0]) {
//                        outputResult.y = limitationResult.limitValues[0]
//                    } else if (outputResult.y > limitationResult.limitValues[1]) {
//                        outputResult.y = limitationResult.limitValues[1]
//                    }
////                    print("(Link Info) : Y Limit // after = \(outputResult.x) , \(outputResult.y)")
////                    print("(Link Info) -------------------------------------- ")
//                } else if (limitationResult.limitType == .X_LIMIT) {
////                    print("(Link Info) : X Limit // before = \(outputResult.x) , \(outputResult.y)")
//                    if (outputResult.x < limitationResult.limitValues[0]) {
//                        outputResult.x = limitationResult.limitValues[0]
//                    } else if (outputResult.x > limitationResult.limitValues[1]) {
//                        outputResult.x = limitationResult.limitValues[1]
//                    }
////                    print("(Link Info) : X Limit // after = \(outputResult.x) , \(outputResult.y)")
////                    print("(Link Info) -------------------------------------- ")
//                }
//            } else {
//                let pathMatching = OlympusPathMatchingCalculator.shared.pathMatching(building: self.tuResult.building_name, level: levelName, x: outputResult.x, y: outputResult.y, heading: outputResult.absolute_heading, HEADING_RANGE: OlympusConstants.HEADING_RANGE, isUseHeading: true, pathType: 0, PADDING_VALUES: OlympusConstants.PADDING_VALUES)
//                outputResult.x = pathMatching.xyhs[0]
//                outputResult.y = pathMatching.xyhs[1]
//            }
//        } else {
//            let drBufferStraightResult = isDrBufferStraight(unitDRInfoBuffer: unitDRInfoBuffer, numIndex: OlympusConstants.DR_HEADING_CORR_NUM_IDX, condition: 10.0)
//            let isDrStraight: Bool = drBufferStraightResult.0
//            let pathMatchingResult =  OlympusPathMatchingCalculator.shared.pathMatching(building: self.tuResult.building_name, level: levelName, x: updatedX, y: updatedY, heading: updatedHeading, HEADING_RANGE: OlympusConstants.HEADING_RANGE, isUseHeading: true, pathType: 1, PADDING_VALUES: OlympusConstants.PADDING_VALUES)
//            
//            if (pathMatchingResult.isSuccess) {
//                outputResult.x = (pathMatchingResult.1[0]*0.5 + updatedX*0.5)
//                outputResult.y = (pathMatchingResult.1[1]*0.5 + updatedY*0.5)
//                outputResult.absolute_heading = compensateHeading(heading: updatedHeading)
//
//                if (pathMatchingResult.0 && isDrStraight){
//                    outputResult.absolute_heading = compensateHeading(heading: pathMatchingResult.1[2])
//                }
//            } else {
//                let pathMatchingResult =  OlympusPathMatchingCalculator.shared.pathMatching(building: self.tuResult.building_name, level: levelName, x: updatedX, y: updatedY, heading: updatedHeading, HEADING_RANGE: OlympusConstants.HEADING_RANGE, isUseHeading: false, pathType: 1, PADDING_VALUES: OlympusConstants.PADDING_VALUES)
//                outputResult.x = (pathMatchingResult.1[0]*0.5 + updatedX*0.5)
//                outputResult.y = (pathMatchingResult.1[1]*0.5 + updatedY*0.5)
//                outputResult.absolute_heading = compensateHeading(heading: updatedHeading)
//            }
//            
//            // DR
//            let limitationResult = OlympusPathMatchingCalculator.shared.getTimeUpdateLimitation(mode: mode)
//            if (limitationResult.limitType == .Y_LIMIT) {
////                    print("(Link Info) : Y Limit // before = \(outputResult.x) , \(outputResult.y)")
//                if (outputResult.y < limitationResult.limitValues[0]) {
//                    outputResult.y = limitationResult.limitValues[0]
//                } else if (outputResult.y > limitationResult.limitValues[1]) {
//                    outputResult.y = limitationResult.limitValues[1]
//                }
////                    print("(Link Info) : Y Limit // after = \(outputResult.x) , \(outputResult.y)")
////                    print("(Link Info) -------------------------------------- ")
//            } else if (limitationResult.limitType == .X_LIMIT) {
////                    print("(Link Info) : X Limit // before = \(outputResult.x) , \(outputResult.y)")
//                if (outputResult.x < limitationResult.limitValues[0]) {
//                    outputResult.x = limitationResult.limitValues[0]
//                } else if (outputResult.x > limitationResult.limitValues[1]) {
//                    outputResult.x = limitationResult.limitValues[1]
//                }
////                    print("(Link Info) : X Limit // after = \(outputResult.x) , \(outputResult.y)")
////                    print("(Link Info) -------------------------------------- ")
//            }
//        }
//        
//        
//        tuResult = outputResult
//        
//        kalmanP += kalmanQ
//        headingKalmanP += headingKalmanQ
//        muFlag = true
//        
//        return outputResult
//    }
    
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
    
    func measurementUpdate(fltResult: FineLocationTrackingFromServer, pmFltResult: FineLocationTrackingFromServer, propagatedPmFltResult: FineLocationTrackingFromServer, unitDRInfoBuffer: [UnitDRInfo], isPossibleHeadingCorrection: Bool, mode: String) -> FineLocationTrackingFromServer {
        var updatedResult: FineLocationTrackingFromServer = propagatedPmFltResult
        
        // Path-Matching propagatedPmFltResult
        var isPmSuccess: Bool = false
        var pmPropagatedPmFltResult = propagatedPmFltResult
        if (mode == OlympusConstants.MODE_PDR) {
            let pmResult = OlympusPathMatchingCalculator.shared.pathMatching(building: propagatedPmFltResult.building_name, level: propagatedPmFltResult.level_name, x: propagatedPmFltResult.x, y: propagatedPmFltResult.y, heading: propagatedPmFltResult.absolute_heading, HEADING_RANGE: OlympusConstants.HEADING_RANGE, isUseHeading: false, pathType: 0, PADDING_VALUES: OlympusConstants.PADDING_VALUES)
            isPmSuccess = pmResult.isSuccess
            pmPropagatedPmFltResult.x = pmResult.xyhs[0]
            pmPropagatedPmFltResult.y = pmResult.xyhs[1]
            pmPropagatedPmFltResult.absolute_heading = pmResult.xyhs[2]
        } else {
            let pmResult = OlympusPathMatchingCalculator.shared.pathMatching(building: propagatedPmFltResult.building_name, level: propagatedPmFltResult.level_name, x: propagatedPmFltResult.x, y: propagatedPmFltResult.y, heading: propagatedPmFltResult.absolute_heading, HEADING_RANGE: OlympusConstants.HEADING_RANGE, isUseHeading: true, pathType: 1, PADDING_VALUES: OlympusConstants.PADDING_VALUES)
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
            let pmResult = OlympusPathMatchingCalculator.shared.pathMatching(building: muResult.building_name, level: muResult.level_name, x: muResult.x, y: muResult.y, heading: muResult.absolute_heading, HEADING_RANGE: OlympusConstants.HEADING_RANGE, isUseHeading: false, pathType: 0, PADDING_VALUES: OlympusConstants.PADDING_VALUES)
            isPmMuSuccess = pmResult.isSuccess
            pmMuResult.x = pmResult.xyhs[0]
            pmMuResult.y = pmResult.xyhs[1]
            pmMuResult.absolute_heading = pmResult.xyhs[2]
        } else {
            let pmResult = OlympusPathMatchingCalculator.shared.pathMatching(building: muResult.building_name, level: muResult.level_name, x: muResult.x, y: muResult.y, heading: muResult.absolute_heading, HEADING_RANGE: OlympusConstants.HEADING_RANGE, isUseHeading: true, pathType: 1, PADDING_VALUES: OlympusConstants.PADDING_VALUES)
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
                        let pathMatchingResult = OlympusPathMatchingCalculator.shared.pathMatching(building: fltResult.building_name, level: fltResult.level_name, x: propagatedResult[0], y: propagatedResult[1], heading: propagatedResult[2], HEADING_RANGE: OlympusConstants.HEADING_RANGE, isUseHeading: false, pathType: 0, PADDING_VALUES: OlympusConstants.PADDING_VALUES)
                        propagatedResult = pathMatchingResult.xyhs
                    } else {
                        let pathMatchingResult = OlympusPathMatchingCalculator.shared.pathMatching(building: fltResult.building_name, level: fltResult.level_name, x: propagatedResult[0], y: propagatedResult[1], heading: propagatedResult[2], HEADING_RANGE: OlympusConstants.HEADING_RANGE, isUseHeading: true, pathType: 1, PADDING_VALUES: OlympusConstants.PADDING_VALUES)
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
            let pmResult = OlympusPathMatchingCalculator.shared.pathMatching(building: muResult.building_name, level: muResult.level_name, x: muResult.x, y: muResult.y, heading: muResult.absolute_heading, HEADING_RANGE: OlympusConstants.HEADING_RANGE, isUseHeading: false, pathType: pathType, PADDING_VALUES: OlympusConstants.PADDING_VALUES)
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
