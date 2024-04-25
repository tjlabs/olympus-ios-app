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
    
    var uvdIndexBuffer = [Int]()
    var uvdHeadingBuffer = [Double]()
    var tuResultBuffer = [[Double]]()
    var isNeedUvdIndexBufferClear: Bool = false
    var usedUvdIndex: Int = 0
    
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
    
    
    public func timeUpdate(recentResult: FineLocationTrackingResult, length: Double, diffHeading: Double, isPossibleHeadingCorrection: Bool, unitDRInfoBuffer: [UnitDRInfo], mode: String) -> FineLocationTrackingFromServer {
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
            
            let isDrStraight: Bool = isDrBufferStraight(unitDRInfoBuffer: unitDRInfoBuffer, condition: 80.0)
            let diffPathTrajMatchingIndex = unitDRInfoBuffer[unitDRInfoBuffer.count-1].index - self.pathTrajMatchingIndex
            if (!isDrStraight && diffPathTrajMatchingIndex >= OlympusConstants.REQUIRED_PATH_TRAJ_MATCHING_INDEX) {
                self.pathTrajMatchingIndex = unitDRInfoBuffer[unitDRInfoBuffer.count-1].index
                let drBufferForPathMatching = Array(unitDRInfoBuffer.suffix(OlympusConstants.DR_BUFFER_SIZE_FOR_STRAIGHT))
                
                let pathTrajMatchingResult = OlympusPathMatchingCalculator.shared.pathTrajectoryMatching(building: self.tuResult.building_name, level: levelName, x: updatedX, y: updatedY, heading: updatedHeading, pastResult: recentResult, unitDRInfoBuffer: drBufferForPathMatching, HEADING_RANGE: OlympusConstants.HEADING_RANGE, pathType: 0, mode: mode, PADDING_VALUE: 5)
                if (pathTrajMatchingResult.isSuccess) {
                    outputResult.x = pathTrajMatchingResult.xyd[0]*0.5 + updatedX*0.5
                    outputResult.y = pathTrajMatchingResult.xyd[1]*0.5 + updatedY*0.5
                    self.matchedTraj = pathTrajMatchingResult.matchedTraj
                    self.inputTraj = pathTrajMatchingResult.inputTraj
                } else {
                    initPathTrajMatchingInfo()
                }
                isDidPathTrajMatching = true
            } else {
                let isDrVeryStraight: Bool = isDrBufferStraight(unitDRInfoBuffer: unitDRInfoBuffer, condition: 10.0)
                if (isDrVeryStraight) {
                    let pathMatchingResult = OlympusPathMatchingCalculator.shared.pathMatching(building: self.tuResult.building_name, level: levelName, x: updatedX, y: updatedY, heading: updatedHeading, isPast: false, HEADING_RANGE: OlympusConstants.HEADING_RANGE, isUseHeading: true, pathType: 0, COORD_RANGE: OlympusConstants.COORD_RANGE)
                    outputResult.x = pathMatchingResult.xyhs[0]*0.5 + updatedX*0.5
                    outputResult.y = pathMatchingResult.xyhs[1]*0.5 + updatedY*0.5
                    if (pathMatchingResult.0) { outputResult.absolute_heading = compensateHeading(heading: pathMatchingResult.xyhs[2]) }
                }
                initPathTrajMatchingInfo()
            }
            
            if (!isDidPathTrajMatching) {
                let limitationResult = OlympusPathMatchingCalculator.shared.getTimeUpdateLimitation()
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
        } else {
            // DR
        }
        
        
        tuResult = outputResult
        
        kalmanP += kalmanQ
        headingKalmanP += headingKalmanQ
        muFlag = true
        
        return outputResult
    }
    
    public func preProcessForMeasuremetUpdate(fltResult: FineLocationTrackingFromServer, unitDRInfoBuffer: [UnitDRInfo], mode: String, isNeedCalDhFromUvd: Bool) -> [Double] {
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
            let pmResult = OlympusPathMatchingCalculator.shared.pathMatching(building: propagatedPmFltResult.building_name, level: propagatedPmFltResult.level_name, x: propagatedPmFltResult.x, y: propagatedPmFltResult.y, heading: propagatedPmFltResult.absolute_heading, isPast: false, HEADING_RANGE: OlympusConstants.HEADING_RANGE, isUseHeading: false, pathType: 0, COORD_RANGE: OlympusConstants.COORD_RANGE)
            isPmSuccess = pmResult.isSuccess
            pmPropagatedPmFltResult.x = pmResult.xyhs[0]
            pmPropagatedPmFltResult.y = pmResult.xyhs[1]
            pmPropagatedPmFltResult.absolute_heading = pmResult.xyhs[2]
        } else {
            let pmResult = OlympusPathMatchingCalculator.shared.pathMatching(building: propagatedPmFltResult.building_name, level: propagatedPmFltResult.level_name, x: propagatedPmFltResult.x, y: propagatedPmFltResult.y, heading: propagatedPmFltResult.absolute_heading, isPast: false, HEADING_RANGE: OlympusConstants.HEADING_RANGE, isUseHeading: true, pathType: 1, COORD_RANGE: OlympusConstants.COORD_RANGE)
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
            let pmResult = OlympusPathMatchingCalculator.shared.pathMatching(building: muResult.building_name, level: muResult.level_name, x: muResult.x, y: muResult.y, heading: muResult.absolute_heading, isPast: false, HEADING_RANGE: OlympusConstants.HEADING_RANGE, isUseHeading: false, pathType: 0, COORD_RANGE: OlympusConstants.COORD_RANGE)
            isPmMuSuccess = pmResult.isSuccess
            pmMuResult.x = pmResult.xyhs[0]
            pmMuResult.y = pmResult.xyhs[1]
            pmMuResult.absolute_heading = pmResult.xyhs[2]
        } else {
            let pmResult = OlympusPathMatchingCalculator.shared.pathMatching(building: muResult.building_name, level: muResult.level_name, x: muResult.x, y: muResult.y, heading: muResult.absolute_heading, isPast: false, HEADING_RANGE: OlympusConstants.HEADING_RANGE, isUseHeading: true, pathType: 1, COORD_RANGE: OlympusConstants.COORD_RANGE)
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
                        let pathMatchingResult = OlympusPathMatchingCalculator.shared.pathMatching(building: fltResult.building_name, level: fltResult.level_name, x: propagatedResult[0], y: propagatedResult[1], heading: propagatedResult[2], isPast: false, HEADING_RANGE: OlympusConstants.HEADING_RANGE, isUseHeading: false, pathType: 0, COORD_RANGE: OlympusConstants.COORD_RANGE)
                        propagatedResult = pathMatchingResult.xyhs
                    } else {
                        let pathMatchingResult = OlympusPathMatchingCalculator.shared.pathMatching(building: fltResult.building_name, level: fltResult.level_name, x: propagatedResult[0], y: propagatedResult[1], heading: propagatedResult[2], isPast: false, HEADING_RANGE: OlympusConstants.HEADING_RANGE, isUseHeading: true, pathType: 1, COORD_RANGE: OlympusConstants.COORD_RANGE)
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
            let pmResult = OlympusPathMatchingCalculator.shared.pathMatching(building: muResult.building_name, level: muResult.level_name, x: muResult.x, y: muResult.y, heading: muResult.absolute_heading, isPast: false, HEADING_RANGE: OlympusConstants.HEADING_RANGE, isUseHeading: false, pathType: pathType, COORD_RANGE: OlympusConstants.COORD_RANGE)
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
