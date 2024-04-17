
public class OlympusTrajectoryController {
    
    var isMovePhase2To4: Bool = false
    var distanceAfterPhase2To4: Double = 0
    
    public var userTrajectoryInfo: [TrajectoryInfo] = []
    public var pastTrajectoryInfo: [TrajectoryInfo] = []
    public var pastSearchInfo = SearchInfo()
    
    public var isNeedTrajCheck: Bool = false
    public var isUnknownTraj: Bool = false
    public var sendFailUvdIndexes = [Int]()
    public var validIndex: Int = 0
    public var isNeedRemoveIndexSendFailArray: Bool = false
    
    var phase2ReqCount: Int = 0
    
    // Trajectory Compensation
    let defaultTrajCompensataionArray: [Double] = [0.8, 1.0, 1.2]
    var trajCompensation: Double = 1.0
    var trajCompensationBadCount: Int = 0
    var isFltRequested: Bool = false
    var fltRequestTime: Int = 0
    
    init() {}
    
    public func calculateTrajectoryLength(trajectoryInfo: [TrajectoryInfo]) -> Double {
        var trajLength = 0.0
        for unitTraj in trajectoryInfo {
            trajLength += unitTraj.length
        }
        
        let roundedTrajLength = (trajLength * 1e4).rounded() / 1e4
        
        return roundedTrajLength
    }
    
    func getTrajectoryFromLast(from trajectoryInfo: [TrajectoryInfo], N: Int) -> [TrajectoryInfo] {
        let size = trajectoryInfo.count
        guard size >= N else {
            return trajectoryInfo
        }
        
        let startIndex = size - N
        let endIndex = size
        
        var result: [TrajectoryInfo] = []
        for i in startIndex..<endIndex {
            result.append(trajectoryInfo[i])
        }

        return result
    }
    
    func getTrajectoryFromN(from trajectoryInfo: [TrajectoryInfo], N: Int) -> [TrajectoryInfo] {
        let size = trajectoryInfo.count
        guard size >= N else {
            return trajectoryInfo
        }
        
        let startIndex = N
        let endIndex = size
        
        var result: [TrajectoryInfo] = []
        for i in startIndex..<endIndex {
            result.append(trajectoryInfo[i])
        }

        return result
    }
    
    public func checkPhase2To4(unitLength: Double) {
        if (self.isMovePhase2To4) {
            self.distanceAfterPhase2To4 += unitLength
            if (self.distanceAfterPhase2To4 >= OlympusConstants.USER_TRAJECTORY_LENGTH*0.8) {
                self.distanceAfterPhase2To4 = 0
                self.isMovePhase2To4 = false
            }
        }
    }
    
    public func stackPostUvdFailData(inputUvd: [UserVelocity]) {
        if (self.isNeedRemoveIndexSendFailArray) {
            var updatedArray = [Int]()
            for i in 0..<self.sendFailUvdIndexes.count {
                if self.sendFailUvdIndexes[i] > self.validIndex {
                    updatedArray.append(self.sendFailUvdIndexes[i])
                }
            }
            self.sendFailUvdIndexes = updatedArray
            self.isNeedRemoveIndexSendFailArray = false
        }
        
        for i in 0..<inputUvd.count {
            self.sendFailUvdIndexes.append(inputUvd[i].index)
        }
    }
    
    private func checkIsTailIndexSendFail(trajectoryInfo: [TrajectoryInfo], sendFailUvdIndexes: [Int]) -> Bool {
        var isTailIndexSendFail: Bool = false
        let tailIndex = trajectoryInfo[0].index
        if sendFailUvdIndexes.contains(tailIndex) {
            isTailIndexSendFail = true
        }
        
        return isTailIndexSendFail
    }
    
    func getValidTrajectory(trajectoryInfo: [TrajectoryInfo], sendFailUvdIndexes: [Int], mode: String) -> ([TrajectoryInfo], Int) {
        var result = [TrajectoryInfo]()
        var isFindValidIndex: Bool = false
        var validIndex: Int = 0
        var validUvdIndex: Int = trajectoryInfo[0].index
        
        for i in 0..<trajectoryInfo.count{
            let uvdIndex = trajectoryInfo[i].index
            var uvdLookingFlag = trajectoryInfo[i].lookingFlag
            if (mode == OlympusConstants.MODE_DR) {
                uvdLookingFlag = true
            }
            if !sendFailUvdIndexes.contains(uvdIndex) && uvdLookingFlag {
                isFindValidIndex = true
                validIndex = i
                validUvdIndex = uvdIndex
                break
            }
        }
        if (isFindValidIndex) {
            for i in validIndex..<trajectoryInfo.count {
                result.append(trajectoryInfo[i])
            }
        }
        return (result, validUvdIndex)
    }
    
    public func setIsNeedTrajCheck(flag: Bool) {
        self.isNeedTrajCheck = flag
    }
    
    public func checkTrajectoryInfo(isPhaseBreak: Bool, isBecomeForeground: Bool, isGetFirstResponse: Bool, timeForInit: Double) {
        var isNeedAllClear: Bool = false
        if (self.isNeedTrajCheck) {
            if (isPhaseBreak) {
                let cutIdx = Int(ceil(OlympusConstants.USER_TRAJECTORY_LENGTH*0.5))
                let newTraj = getTrajectoryFromLast(from: self.userTrajectoryInfo, N: cutIdx)
                if (newTraj.count > 1) {
                    for i in 1..<newTraj.count {
                        let diffX = abs(newTraj[i].userX - newTraj[i-1].userX)
                        let diffY = abs(newTraj[i].userY - newTraj[i-1].userY)
                        if (sqrt(diffX*diffX + diffY*diffY) > 3) {
                            isNeedAllClear = true
                            break
                        }
                    }
                }
                self.userTrajectoryInfo = newTraj
            }
            self.isNeedTrajCheck = false
        } else if (isBecomeForeground) {
            NotificationCenter.default.post(name: .trajEditedBecomeForground, object: nil, userInfo: nil)
            isNeedAllClear = true
        } else if (isGetFirstResponse && timeForInit < OlympusConstants.TIME_INIT_THRESHOLD) {
            isNeedAllClear = true
        }
        
        if (isNeedAllClear) {
            self.userTrajectoryInfo = [TrajectoryInfo]()
        }
    }
    
    
    public func getTrajectoryInfo(unitDRInfo: UnitDRInfo, unitLength: Double, olympusResult: FineLocationTrackingResult, tuHeading: Double, isPmSuccess: Bool, numBleChannels: Int, mode: String, isDetermineSpot: Bool, spotCutIndex: Int) -> [TrajectoryInfo] {
        if (olympusResult.x != 0 && olympusResult.y != 0) {
            var unitTrajectoryInfo = TrajectoryInfo()
            unitTrajectoryInfo.index = unitDRInfo.index
            unitTrajectoryInfo.length = unitLength
            unitTrajectoryInfo.heading = unitDRInfo.heading
            unitTrajectoryInfo.velocity = unitDRInfo.velocity
            unitTrajectoryInfo.lookingFlag = unitDRInfo.lookingFlag
            unitTrajectoryInfo.isIndexChanged = unitDRInfo.isIndexChanged
            unitTrajectoryInfo.numBleChannels = numBleChannels
            unitTrajectoryInfo.scc = olympusResult.scc
            unitTrajectoryInfo.userBuilding = olympusResult.building_name
            unitTrajectoryInfo.userLevel = olympusResult.level_name
            
//            if (self.isActiveKf) {
//                userTrajectory.userX = self.timeUpdateResult[0]
//                userTrajectory.userY = self.timeUpdateResult[1]
//                userTrajectory.userHeading = self.timeUpdateResult[2]
//            } else {
//                userTrajectory.userX = resultToReturn.x
//                userTrajectory.userY = resultToReturn.y
//                userTrajectory.userHeading = resultToReturn.absolute_heading
//            }
            
            unitTrajectoryInfo.userX = olympusResult.x
            unitTrajectoryInfo.userY = olympusResult.y
            unitTrajectoryInfo.userHeading = olympusResult.absolute_heading
            
            unitTrajectoryInfo.userTuHeading = tuHeading
            unitTrajectoryInfo.userPmSuccess = isPmSuccess
            self.userTrajectoryInfo.append(unitTrajectoryInfo)
            
            if (mode == OlympusConstants.MODE_PDR) {
                // PDR
                controlPdrTrajectoryInfo(LENGTH_CONDITION: OlympusConstants.USER_TRAJECTORY_LENGTH)
            } else {
                // DR
                controlDrTrajectoryInfo(isDetermineSpot: isDetermineSpot, spotCutIndex: spotCutIndex, isUnknownTraj: self.isUnknownTraj, LENGTH_CONDITION: OlympusConstants.USER_TRAJECTORY_LENGTH)
            }
            self.pastTrajectoryInfo = self.userTrajectoryInfo
        }
        
        return self.userTrajectoryInfo
    }
    
    private func controlPdrTrajectoryInfo(LENGTH_CONDITION: Double) {
        var isNeedAllClear: Bool = false
        let updatedTrajectoryInfoWithLength = updateTrajectoryInfoWithLength(trajectoryInfo: self.userTrajectoryInfo, LENGTH_CONDITION: LENGTH_CONDITION)
        print("(Olympus) traj length : \(calculateTrajectoryLength(trajectoryInfo: updatedTrajectoryInfoWithLength))")
        let isTailIndexSendFail = checkIsTailIndexSendFail(trajectoryInfo: updatedTrajectoryInfoWithLength, sendFailUvdIndexes: self.sendFailUvdIndexes)
        if (isTailIndexSendFail) {
            let validTrajectoryInfoResult = getValidTrajectory(trajectoryInfo: updatedTrajectoryInfoWithLength, sendFailUvdIndexes: self.sendFailUvdIndexes, mode: OlympusConstants.MODE_PDR)
            if (!validTrajectoryInfoResult.0.isEmpty) {
                let trajLength = calculateTrajectoryLength(trajectoryInfo: validTrajectoryInfoResult.0)
                if (trajLength > 5) {
                    self.userTrajectoryInfo = validTrajectoryInfoResult.0
                    self.validIndex = validTrajectoryInfoResult.1
                    self.isNeedRemoveIndexSendFailArray = true
                } else {
                    isNeedAllClear = true
                }
            } else {
                isNeedAllClear = true
            }
        } else {
            if (!updatedTrajectoryInfoWithLength[0].lookingFlag) {
                let validTrajectoryInfoResult = getValidTrajectory(trajectoryInfo: updatedTrajectoryInfoWithLength, sendFailUvdIndexes: self.sendFailUvdIndexes, mode: OlympusConstants.MODE_PDR)
                if (!validTrajectoryInfoResult.0.isEmpty) {
                    let trajLength = calculateTrajectoryLength(trajectoryInfo: validTrajectoryInfoResult.0)
                    if (trajLength > 5) {
                        self.userTrajectoryInfo = validTrajectoryInfoResult.0
                        self.validIndex = validTrajectoryInfoResult.1
                        self.isNeedRemoveIndexSendFailArray = true
                    } else {
                        isNeedAllClear = true
                    }
                } else {
                    isNeedAllClear = true
                }
            } else {
                self.userTrajectoryInfo = updatedTrajectoryInfoWithLength
            }
        }
        
        if (isNeedAllClear) {
            NotificationCenter.default.post(name: .phaseChanged, object: nil, userInfo: ["phase": OlympusConstants.PHASE_1])
            self.userTrajectoryInfo = [TrajectoryInfo]()
        }
    }
    
    private func controlDrTrajectoryInfo(isDetermineSpot: Bool, spotCutIndex: Int, isUnknownTraj: Bool, LENGTH_CONDITION: Double) {
        if (isDetermineSpot) {
            let newTraj = getTrajectoryFromLast(from: self.userTrajectoryInfo, N: spotCutIndex)
            self.userTrajectoryInfo = newTraj
            self.phase2ReqCount = 0
            
            NotificationCenter.default.post(name: .trajEditedAfterOsr, object: nil, userInfo: nil)
            NotificationCenter.default.post(name: .phaseChanged, object: nil, userInfo: ["phase": OlympusConstants.PHASE_2])
        } else if (isUnknownTraj) {
            self.isUnknownTraj = false
            
            var cutIdx = Int(OlympusConstants.USER_TRAJECTORY_LENGTH_DR) - OlympusConstants.UNKNOWN_TRAJ_CUT_IDX
            if cutIdx <= OlympusConstants.UNKNOWN_TRAJ_CUT_IDX {
                cutIdx = OlympusConstants.UNKNOWN_TRAJ_CUT_IDX
            }
            
            let newTraj = getTrajectoryFromLast(from: self.userTrajectoryInfo, N: cutIdx)
            self.userTrajectoryInfo = newTraj
            
        } else {
            let trajLength = calculateTrajectoryLength(trajectoryInfo: self.userTrajectoryInfo)
            if trajLength > LENGTH_CONDITION {
                self.userTrajectoryInfo.removeFirst()
            }
        }
        
        var isNeedAllClear: Bool = false
        if (!self.userTrajectoryInfo.isEmpty) {
            let isTailIndexSendFail = checkIsTailIndexSendFail(trajectoryInfo: self.userTrajectoryInfo, sendFailUvdIndexes: self.sendFailUvdIndexes)
            if (isTailIndexSendFail) {
                let validTrajectoryInfoResult = getValidTrajectory(trajectoryInfo: self.userTrajectoryInfo, sendFailUvdIndexes: self.sendFailUvdIndexes, mode: OlympusConstants.MODE_DR)
                if (!validTrajectoryInfoResult.0.isEmpty) {
                    let trajLength = calculateTrajectoryLength(trajectoryInfo: validTrajectoryInfoResult.0)
                    if (trajLength > 10) {
                        self.userTrajectoryInfo = validTrajectoryInfoResult.0
                        self.validIndex = validTrajectoryInfoResult.1
                        self.isNeedRemoveIndexSendFailArray = true
                    } else {
                        // Phase 깨줘야한다
                        isNeedAllClear = true
                    }
                } else {
                    // Phase 깨줘야한다
                    isNeedAllClear = true
                }
            }
        }
        
        if (isNeedAllClear) {
            NotificationCenter.default.post(name: .phaseChanged, object: nil, userInfo: ["phase": OlympusConstants.PHASE_1])
            self.userTrajectoryInfo = [TrajectoryInfo]()
        }
    }
    
    private func updateTrajectoryInfoWithLength(trajectoryInfo: [TrajectoryInfo], LENGTH_CONDITION: Double) -> [TrajectoryInfo] {
        var accumulatedLength = 0.0

        var longTrajIndex: Int = 0
        var isFindLong: Bool = false
        var shortTrajIndex: Int = 0
        var isFindShort: Bool = false

        if (!trajectoryInfo.isEmpty) {
            let startHeading = trajectoryInfo[0].heading
            let headInfo = trajectoryInfo[trajectoryInfo.count-1]
            var xyFromHead: [Double] = [headInfo.userX, headInfo.userY]

            var headingFromHead = [Double] (repeating: 0, count: trajectoryInfo.count)
            for i in 0..<trajectoryInfo.count {
                headingFromHead[i] = compensateHeading(heading: trajectoryInfo[i].heading  - 180 - startHeading)
            }

            var trajectoryFromHead = [[Double]]()
            trajectoryFromHead.append(xyFromHead)
            for i in (1..<trajectoryInfo.count).reversed() {
                let headAngle = headingFromHead[i]
                let uvdLength = trajectoryInfo[i].length
                accumulatedLength += uvdLength

                if ((accumulatedLength >= LENGTH_CONDITION*2) && !isFindLong) {
                    isFindLong = true
                    longTrajIndex = i
                }

                if ((accumulatedLength >= LENGTH_CONDITION) && !isFindShort) {
                    isFindShort = true
                    shortTrajIndex = i
                }

                xyFromHead[0] = xyFromHead[0] + uvdLength*cos(headAngle*OlympusConstants.D2R)
                xyFromHead[1] = xyFromHead[1] + uvdLength*sin(headAngle*OlympusConstants.D2R)
                trajectoryFromHead.append(xyFromHead)
            }

            let trajectoryMinMax = getMinMaxValues(for: trajectoryFromHead)
            let width = trajectoryMinMax[2] - trajectoryMinMax[0]
            let height = trajectoryMinMax[3] - trajectoryMinMax[1]

            if (width <= 3 || height <= 3) {
                let newTrajectory = getTrajectoryFromN(from: trajectoryInfo, N: longTrajIndex)
                return newTrajectory
            } else {
                let newTrajectory = getTrajectoryFromN(from: trajectoryInfo, N: shortTrajIndex)
                return newTrajectory
            }
        }

        return trajectoryInfo
    }
    
    public func makeSearchInfo(trajectoryInfo: [TrajectoryInfo], pastTrajectoryInfo: [TrajectoryInfo], mode: String, PHASE: Int) -> SearchInfo {
        var searchInfo = SearchInfo()
        
        let trajLength = calculateTrajectoryLength(trajectoryInfo: trajectoryInfo)
        searchInfo.trajLength = trajLength
        var reqLengthForMajorHeading: Double = OlympusConstants.REQUIRED_LENGTH_FOR_MAJOR_HEADING
        if (OlympusConstants.USER_TRAJECTORY_LENGTH <= 20) {
            reqLengthForMajorHeading = (OlympusConstants.USER_TRAJECTORY_LENGTH-5)/2
        }
        
        if (!trajectoryInfo.isEmpty) {
            var uvRawHeading = [Double]()
            var uvHeading = [Double]()
            for value in trajectoryInfo {
                uvRawHeading.append(value.heading)
                uvHeading.append(compensateHeading(heading: value.heading))
            }
            let userBuilding    = trajectoryInfo[trajectoryInfo.count-1].userBuilding
            let userLevel       = trajectoryInfo[trajectoryInfo.count-1].userLevel
            var userX           = trajectoryInfo[trajectoryInfo.count-1].userX
            var userY           = trajectoryInfo[trajectoryInfo.count-1].userY
            let userHeading     = trajectoryInfo[trajectoryInfo.count-1].userHeading
            
            if (mode == OlympusConstants.MODE_PDR) {
                // PDR
                let PADDING_VALUE = OlympusConstants.USER_TRAJECTORY_LENGTH_PDR*0.8
                if (PHASE < 4) {
                    // Phase 1 ~ 3
//                    if (isPhaseBreak && (self.phaseBreakResult.building_name != "" && self.phaseBreakResult.level_name != "")) {
//                        userX = self.phaseBreakResult.x
//                        userY = self.phaseBreakResult.y
//                    }
                    let areaMinMax: [Double] = [userX - PADDING_VALUE, userY - PADDING_VALUE, userX + PADDING_VALUE, userY + PADDING_VALUE]
                    let searchArea = getSearchCoordinates(areaMinMax: areaMinMax, interval: 1.0)
                    searchInfo.searchRange = areaMinMax.map { Int($0) }
                    
                    var searchHeadings: [Double] = []
                    var hasMajorDirection: Bool = false
                    if (trajLength > reqLengthForMajorHeading) {
                        let ppHeadings = OlympusPathMatchingCalculator.shared.getPathMatchingHeadings(building: userBuilding, level: userLevel, x: userX, y: userY, heading: userHeading, PADDING_VALUE: PADDING_VALUE, mode: mode)
                        let headingLeastChangeSection = extractSectionWithLeastChange(inputArray: uvRawHeading)
                        if (headingLeastChangeSection.isEmpty) {
                            hasMajorDirection = false
                        } else {
                            let headingForCompensation = headingLeastChangeSection.average - uvRawHeading[0]
                            for ppHeading in ppHeadings {
                                let tailHeading = ppHeading - headingForCompensation
                                searchHeadings.append(compensateHeading(heading: tailHeading))
                            }
                            hasMajorDirection = true
                        }
                    }
                    
                    if (!hasMajorDirection) {
                        searchHeadings = [0, 90, 180, 270]
                        searchInfo.trajType = TrajType.PDR_IN_PHASE3_NO_MAJOR_DIR
                    } else {
                        searchInfo.trajType = TrajType.PDR_IN_PHASE3_HAS_MAJOR_DIR
                    }
                    searchInfo.searchDirection = searchHeadings.map { Int($0) }
                    
                    let headInfo = trajectoryInfo[trajectoryInfo.count-1]
                    var xyFromHead: [Double] = [headInfo.userX, headInfo.userY]
                    
                    let headingCorrectionFromServer: Double = headInfo.userHeading - uvHeading[uvHeading.count-1]
                    var headingFromHead = [Double] (repeating: 0, count: uvHeading.count)
                    
                    for i in 0..<uvHeading.count {
                        headingFromHead[i] = compensateHeading(heading: uvHeading[i] - 180 + headingCorrectionFromServer)
                    }
                    
                    var trajectoryFromHead = [[Double]]()
                    trajectoryFromHead.append(xyFromHead)
                    for i in (1..<trajectoryInfo.count).reversed() {
                        let headAngle = headingFromHead[i]
                        xyFromHead[0] = xyFromHead[0] + trajectoryInfo[i].length*cos(headAngle*OlympusConstants.D2R)
                        xyFromHead[1] = xyFromHead[1] + trajectoryInfo[i].length*sin(headAngle*OlympusConstants.D2R)
                        trajectoryFromHead.append(xyFromHead)
                    }
                    
                    searchInfo.tailIndex = trajectoryInfo[0].index
                    
                    // 임시
                    searchInfo.trajShape = trajectoryFromHead
                    searchInfo.trajStartCoord = [headInfo.userX, headInfo.userY]
                } else {
                    // Phase 4
                }
            } else {
                // DR
            }
        } else {
            // Empty TrajectoryInfo
            print("Traj is Empty")
        }
        
        return searchInfo
    }
    
    public func controlPhase2SearchRange(searchInfo: SearchInfo, trajLength: Double) -> SearchInfo {
        var result = searchInfo
        self.phase2ReqCount += 1
        if (self.phase2ReqCount > 2) {
            let expandRange: Int = Int((trajLength - OlympusConstants.REQUIRED_LENGTH_PHASE2)/2)
            result.searchRange = [result.searchRange[0]-expandRange, result.searchRange[1]-expandRange, result.searchRange[2]+expandRange, result.searchRange[3]+expandRange]
        }
        
        return result
    }
    
    private func extractSectionWithLeastChange(inputArray: [Double]) -> [Double] {
        var resultArray = [Double]()
        guard inputArray.count > 7 else {
            return []
        }
        
        var compensatedArray = [Double] (repeating: 0, count: inputArray.count)
        for i in 0..<inputArray.count {
            compensatedArray[i] = compensateHeading(heading: inputArray[i])
        }
        
        var bestSliceStartIndex = 0
        var bestSliceEndIndex = 0

        for startIndex in 0..<(inputArray.count-6) {
            for endIndex in (startIndex+7)..<inputArray.count {
                let slice = Array(compensatedArray[startIndex...endIndex])
                let circularStd = circularStandardDeviation(for: slice)
                if circularStd < 5 && slice.count > bestSliceEndIndex - bestSliceStartIndex {
                    bestSliceStartIndex = startIndex
                    bestSliceEndIndex = endIndex
                }
            }
        }
        
        resultArray = Array(inputArray[bestSliceStartIndex...bestSliceEndIndex])
        if resultArray.count > 7 {
            return resultArray
        } else {
            return []
        }
    }
    
    private func getSearchCoordinates(areaMinMax: [Double], interval: Double) -> [[Double]] {
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
    
    public func setPastInfo(trajInfo: [TrajectoryInfo], searchInfo: SearchInfo) {
        self.pastTrajectoryInfo = trajInfo
        self.pastSearchInfo = searchInfo
    }
    
    
    // Trajectory Compensation
    public func getTrajCompensationArray(currentTime: Int, trajLength: Double) -> [Double] {
        var trajCompensationArray: [Double] = [self.trajCompensation]
        if (trajLength < OlympusConstants.USER_TRAJECTORY_LENGTH) {
            trajCompensationArray = [1.01]
        } else {
            if (self.isFltRequested) {
                trajCompensationArray = [1.01]
            } else {
                trajCompensationArray = self.defaultTrajCompensataionArray
                self.fltRequestTime = currentTime
                self.isFltRequested = true
            }
        }
        
        return trajCompensationArray
    }
    
    public func updateTrajCompensationArray(result: FineLocationTrackingFromServer) {
        if (self.isFltRequested) {
            let compensationCheckTime = abs(result.mobile_time - self.fltRequestTime)
            if (compensationCheckTime < 100) {
                if (result.scc < 0.55) {
                    self.trajCompensationBadCount += 1
                } else {
                    if (result.scc > 0.6) {
                        let digit: Double = pow(10, 4)
                        self.trajCompensation = round((result.sc_compensation*digit)/digit)
                    }
                    self.trajCompensationBadCount = 0
                }
                if (self.trajCompensationBadCount > 1) {
                    self.trajCompensationBadCount = 0
                    self.isFltRequested = false
                }
            } else if (compensationCheckTime > 3000) {
                self.isFltRequested = false
            }
        }
    }
}
