import Foundation

public class OlympusTrajectoryController {
    let defaultTrajCompensataionArray: [Double] = [0.8, 1.0, 1.2]
    
    var isMovePhase2To4: Bool = false
    var distanceAfterPhase2To4: Double = 0
    
    public var userTrajectoryInfo: [TrajectoryInfo] = []
    public var pastTrajectoryInfo: [TrajectoryInfo] = []
    public var pastSearchInfo = SearchInfo()
    public var pastMatchedDirection: Int = 0
    public var accumulatedLengthWhenPhase2: Double = 0
    
    public var isNeedTrajCheck: Bool = false
    public var isUnknownTraj: Bool = false
    public var sendFailUvdIndexes = [Int]()
    public var validIndex: Int = 0
    public var isNeedRemoveIndexSendFailArray: Bool = false
    
    var phase2ReqCount: Int = 0
    
    // Trajectory Compensation
    var trajCompensation: Double = 1.0
    var trajCompensationBadCount: Int = 0
    var isFltRequested: Bool = false
    var fltRequestTime: Int = 0
    
    init() {}
    
    public func initialize() {
        self.isMovePhase2To4 = false
        self.distanceAfterPhase2To4 = 0
        
        self.userTrajectoryInfo = []
        self.pastTrajectoryInfo = []
        self.pastSearchInfo = SearchInfo()
        self.pastMatchedDirection = 0
        
        self.isNeedTrajCheck = false
        self.isUnknownTraj = false
        self.sendFailUvdIndexes = [Int]()
        self.validIndex = 0
        self.isNeedRemoveIndexSendFailArray = false
        
        self.phase2ReqCount = 0
        
        self.trajCompensation = 1.0
        self.trajCompensationBadCount = 0
        self.isFltRequested = false
        self.fltRequestTime = 0
    }
    
    public func clearUserTrajectoryInfo() {
        self.userTrajectoryInfo = [TrajectoryInfo]()
    }
    
    public func calculateTrajectoryLength(trajectoryInfo: [TrajectoryInfo]) -> Double {
        var trajLength = 0.0
        for unitTraj in trajectoryInfo {
            trajLength += unitTraj.length
        }
        
        let roundedTrajLength = (trajLength * 1e4).rounded() / 1e4
        
        return roundedTrajLength
    }
    
    public func calculateAccumulatedDiagonal(trajectoryInfo: [TrajectoryInfo]) -> Double {
        var trajDiagonal = 0.0
        
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
                xyFromHead[0] = xyFromHead[0] + trajectoryInfo[i].length*cos(headAngle*OlympusConstants.D2R)
                xyFromHead[1] = xyFromHead[1] + trajectoryInfo[i].length*sin(headAngle*OlympusConstants.D2R)
                trajectoryFromHead.append(xyFromHead)
            }
            
            let trajectoryMinMax = getMinMaxValues(for: trajectoryFromHead)
            let dx = trajectoryMinMax[2] - trajectoryMinMax[0]
            let dy = trajectoryMinMax[3] - trajectoryMinMax[1]
            
            trajDiagonal = sqrt(dx*dx + dy*dy)
        }
        
        return trajDiagonal
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
    
    public func checkPhase2To4(unitLength: Double, LENGTH_THRESHOLD: Double) {
        if (self.isMovePhase2To4) {
            self.distanceAfterPhase2To4 += unitLength
            if (self.distanceAfterPhase2To4 >= LENGTH_THRESHOLD*0.8) {
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
    
    public func checkTrajectoryInfo(isPhaseBreak: Bool, isBecomeForeground: Bool, isGetFirstResponse: Bool, timeForInit: Double, LENGTH_THRESHOLD: Double) {
        var isNeedAllClear: Bool = false
        if (self.isNeedTrajCheck) {
            if (isPhaseBreak) {
                let cutIdx = Int(ceil(LENGTH_THRESHOLD*0.5))
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
    
    
    public func getTrajectoryInfo(unitDRInfo: UnitDRInfo, unitLength: Double, olympusResult: FineLocationTrackingResult, isKF: Bool, tuResult: [Double], isPmSuccess: Bool, numBleChannels: Int, mode: String, isDetermineSpot: Bool, spotCutIndex: Int, LENGTH_THRESHOLD: Double) -> [TrajectoryInfo] {
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
            
            if (isKF) {
                unitTrajectoryInfo.userX = tuResult[0]
                unitTrajectoryInfo.userY = tuResult[1]
                unitTrajectoryInfo.userHeading = tuResult[2]
            } else {
                unitTrajectoryInfo.userX = olympusResult.x
                unitTrajectoryInfo.userY = olympusResult.y
                unitTrajectoryInfo.userHeading = olympusResult.absolute_heading
            }
            
            unitTrajectoryInfo.userX = olympusResult.x
            unitTrajectoryInfo.userY = olympusResult.y
            unitTrajectoryInfo.userHeading = olympusResult.absolute_heading
            
//            unitTrajectoryInfo.userTuHeading = tuHeading
            unitTrajectoryInfo.userPmSuccess = isPmSuccess
            self.userTrajectoryInfo.append(unitTrajectoryInfo)
            
            if (mode == OlympusConstants.MODE_PDR) {
                // PDR
                controlPdrTrajectoryInfo(LENGTH_THRESHOLD: LENGTH_THRESHOLD)
            } else {
                // DR
                controlDrTrajectoryInfo(isDetermineSpot: isDetermineSpot, spotCutIndex: spotCutIndex, isUnknownTraj: self.isUnknownTraj, LENGTH_THRESHOLD: LENGTH_THRESHOLD)
            }
        }
        
        return self.userTrajectoryInfo
    }
    
    private func controlPdrTrajectoryInfo(LENGTH_THRESHOLD: Double) {
        var isNeedAllClear: Bool = false
        let updatedTrajectoryInfoWithLength = updateTrajectoryInfoWithLength(trajectoryInfo: self.userTrajectoryInfo, LENGTH_THRESHOLD: LENGTH_THRESHOLD)
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
    
    private func controlDrTrajectoryInfo(isDetermineSpot: Bool, spotCutIndex: Int, isUnknownTraj: Bool, LENGTH_THRESHOLD: Double) {
        if (isDetermineSpot) {
            let newTraj = getTrajectoryFromLast(from: self.userTrajectoryInfo, N: spotCutIndex)
            self.userTrajectoryInfo = newTraj
            self.phase2ReqCount = 0
            self.accumulatedLengthWhenPhase2 = calculateTrajectoryLength(trajectoryInfo: newTraj)
            NotificationCenter.default.post(name: .trajEditedAfterOsr, object: nil, userInfo: nil)
//            NotificationCenter.default.post(name: .phaseChanged, object: nil, userInfo: ["phase": OlympusConstants.PHASE_2])
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
            if trajLength > LENGTH_THRESHOLD {
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
    
    private func updateTrajectoryInfoWithLength(trajectoryInfo: [TrajectoryInfo], LENGTH_THRESHOLD: Double) -> [TrajectoryInfo] {
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

                if ((accumulatedLength >= LENGTH_THRESHOLD*2) && !isFindLong) {
                    isFindLong = true
                    longTrajIndex = i
                }

                if ((accumulatedLength >= LENGTH_THRESHOLD) && !isFindShort) {
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
    
    public func makeSearchInfo(trajectoryInfo: [TrajectoryInfo], serverResultBuffer: [FineLocationTrackingFromServer], unitDRInfoBuffer: [UnitDRInfo], isKF: Bool, mode: String, PHASE: Int, isPhaseBreak: Bool, phaseBreakResult: FineLocationTrackingFromServer, LENGTH_THRESHOLD: Double) -> SearchInfo {
        var searchInfo = SearchInfo()
        var searchDirection: [Int] = [0, 90, 180, 270]
        
        let trajLength = calculateTrajectoryLength(trajectoryInfo: trajectoryInfo)
        searchInfo.trajLength = trajLength
        
        var reqLengthForMajorHeading: Double = OlympusConstants.REQUIRED_LENGTH_FOR_MAJOR_HEADING
        if (LENGTH_THRESHOLD <= 20) {
            reqLengthForMajorHeading = (LENGTH_THRESHOLD-5)/2
        }
        
        if (!trajectoryInfo.isEmpty) {
            var uvdRawHeading = [Double]()
            var uvdHeading = [Double]()
            for value in trajectoryInfo {
                uvdRawHeading.append(value.heading)
                uvdHeading.append(compensateHeading(heading: value.heading))
            }
            let userBuilding    = trajectoryInfo[trajectoryInfo.count-1].userBuilding
            let userLevel       = trajectoryInfo[trajectoryInfo.count-1].userLevel
            var userX           = trajectoryInfo[trajectoryInfo.count-1].userX
            var userY           = trajectoryInfo[trajectoryInfo.count-1].userY
            let userHeading     = trajectoryInfo[trajectoryInfo.count-1].userHeading
            
            if (mode == OlympusConstants.MODE_PDR) {
                // PDR
                let PADDING_VALUE = OlympusConstants.USER_TRAJECTORY_LENGTH_PDR*0.8
                let HEADING_UNCERTANTIY: Double = 2
                if (PHASE < 4) {
                    searchInfo.tailIndex = trajectoryInfo[0].index
                    
                    // PDR Phase 1 ~ 3
                    if (isPhaseBreak && (phaseBreakResult.building_name != "" && phaseBreakResult.level_name != "")) {
                        userX = phaseBreakResult.x
                        userY = phaseBreakResult.y
                    }
                    let searchRange: [Double] = [userX - PADDING_VALUE, userY - PADDING_VALUE, userX + PADDING_VALUE, userY + PADDING_VALUE]
                    searchInfo.searchRange = searchRange.map { Int($0) }
                    
                    var searchHeadings: [Double] = []
                    var hasMajorDirection: Bool = false
                    if (trajLength > reqLengthForMajorHeading) {
                        let ppHeadings = OlympusPathMatchingCalculator.shared.getPathMatchingHeadings(building: userBuilding, level: userLevel, x: userX, y: userY, PADDING_VALUE: PADDING_VALUE, mode: mode)
                        let headingLeastChangeSection = extractSectionWithLeastChange(inputArray: uvdRawHeading, requiredSize: 7)
                        if (headingLeastChangeSection.isEmpty) {
                            hasMajorDirection = false
                        } else {
                            let headingForCompensation = headingLeastChangeSection.average - uvdRawHeading[0]
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
                    
                    let headingCorrectionFromServer: Double = headInfo.userHeading - uvdHeading[uvdHeading.count-1]
                    var headingFromHead = [Double] (repeating: 0, count: uvdHeading.count)
                    
                    for i in 0..<uvdHeading.count {
                        headingFromHead[i] = compensateHeading(heading: uvdHeading[i] - 180 + headingCorrectionFromServer)
                    }
                    
                    var trajectoryFromHead = [[Double]]()
                    trajectoryFromHead.append(xyFromHead)
                    for i in (1..<trajectoryInfo.count).reversed() {
                        let headAngle = headingFromHead[i]
                        xyFromHead[0] = xyFromHead[0] + trajectoryInfo[i].length*cos(headAngle*OlympusConstants.D2R)
                        xyFromHead[1] = xyFromHead[1] + trajectoryInfo[i].length*sin(headAngle*OlympusConstants.D2R)
                        trajectoryFromHead.append(xyFromHead)
                    }

                    // 임시
                    searchInfo.searchArea = getSearchCoordinates(areaMinMax: searchRange, interval: 1.0)
                    searchInfo.trajShape = trajectoryFromHead
                    searchInfo.trajStartCoord = [headInfo.userX, headInfo.userY]
                } else {
                    // PDR Phase 4
                    searchInfo.tailIndex = trajectoryInfo[0].index
                    
                    let trajDiagonal = calculateAccumulatedDiagonal(trajectoryInfo: trajectoryInfo)
                    let headInfo = trajectoryInfo[trajectoryInfo.count-1]
                    let headInfoHeading = compensateHeading(heading: headInfo.userHeading)
                    
                    let recentServerResult: FineLocationTrackingFromServer = serverResultBuffer[serverResultBuffer.count-1]
                    let propagatedResult = propagateUsingUvd(unitDRInfoBuffer: unitDRInfoBuffer, fltResult: recentServerResult)
                    var xyFromHead: [Double] = [headInfo.userX, headInfo.userY]
                    var xyForArea: [Double] = [headInfo.userX, headInfo.userY]
                    if (propagatedResult.0) {
                        xyFromHead = [recentServerResult.x + propagatedResult.1[0], recentServerResult.y + propagatedResult.1[1]]
                        xyForArea = [recentServerResult.x + propagatedResult.1[0], recentServerResult.y + propagatedResult.1[1]]
                    }
                    
                    let headCoord: [Double] = xyFromHead
                    let serverCoord: [Double] = [recentServerResult.x, recentServerResult.y]
                    
                    var hasMajorDirection: Bool = false
                    if (trajLength < 10) {
                        hasMajorDirection = false
                    } else {
                        let ppHeadings = OlympusPathMatchingCalculator.shared.getPathMatchingHeadings(building: userBuilding, level: userLevel, x: userX, y: userY, PADDING_VALUE: PADDING_VALUE, mode: mode)
                        var searchHeadings: [Double] = []
                        var headHeadings: [Double] = []
                        let headingLeastChangeSection = extractSectionWithLeastChange(inputArray: uvdRawHeading, requiredSize: 7)
                        if (headingLeastChangeSection.isEmpty) {
                            hasMajorDirection = false
                        } else {
                            let headingForCompensation = uvdRawHeading[uvdRawHeading.count-1] - headingLeastChangeSection.average
                            for ppHeading in ppHeadings {
                                let headHeading = compensateHeading(heading: ppHeading + headingForCompensation)
                                var diffHeading = abs(headInfoHeading - headHeading)
                                if (diffHeading >= 270 && diffHeading < 360) { diffHeading = 360 - diffHeading }
                                headHeadings.append(diffHeading)
                            }
                            let minHeading = headHeadings.min() ?? 40
                            if let minIndex = zip(headHeadings.indices, headHeadings).min(by: { $0.1 < $1.1 })?.0 {
                                if (minHeading <= 20) {
                                    let trajType = TrajType.PDR_IN_PHASE4_HAS_MAJOR_DIR
                                    searchInfo.trajType = trajType
                                    
                                    let headingForCompensation = headingLeastChangeSection.average - uvdRawHeading[0]
                                    let tailHeading = ppHeadings[minIndex] - headingForCompensation
                                    searchHeadings.append(compensateHeading(heading: tailHeading - HEADING_UNCERTANTIY))
                                    searchHeadings.append(compensateHeading(heading: tailHeading))
                                    searchHeadings.append(compensateHeading(heading: tailHeading + HEADING_UNCERTANTIY))
                                    searchInfo.searchDirection = searchHeadings.map { Int($0) }

                                    let headingCorrectionForTail: Double = tailHeading - uvdHeading[0]
                                    var headingFromTail = [Double] (repeating: 0, count: uvdHeading.count)
                                    var headingFromHead = [Double] (repeating: 0, count: uvdHeading.count)
                                    for i in 0..<uvdHeading.count {
                                        headingFromTail[i] = compensateHeading(heading: uvdHeading[i] + headingCorrectionForTail)
                                        headingFromHead[i] = compensateHeading(heading: headingFromTail[i] - 180)
                                    }
                                    
                                    var trajectoryFromHead = [[Double]]()
                                    trajectoryFromHead.append(xyFromHead)
                                    var trajectoryForArea = [[Double]]()
                                    trajectoryForArea.append(xyForArea)
                                    for i in (1..<trajectoryInfo.count).reversed() {
                                        let headAngle = headingFromHead[i]
                                        xyFromHead[0] = xyFromHead[0] + trajectoryInfo[i].length*cos(headAngle*OlympusConstants.D2R)
                                        xyFromHead[1] = xyFromHead[1] + trajectoryInfo[i].length*sin(headAngle*OlympusConstants.D2R)
                                        trajectoryFromHead.append(xyFromHead)
                                        
                                        xyForArea[0] = xyForArea[0] + trajectoryInfo[i].length*1.2*cos(headAngle*OlympusConstants.D2R)
                                        xyForArea[1] = xyForArea[1] + trajectoryInfo[i].length*1.2*sin(headAngle*OlympusConstants.D2R)
                                        trajectoryForArea.append(xyForArea)
                                    }
                                    
                                    let xyMinMax: [Double] = getMinMaxValues(for: trajectoryFromHead)
                                    let headingStart = compensateHeading(heading: headingFromHead[headingFromHead.count-1]-180)
                                    let headingEnd = compensateHeading(heading: headingFromHead[0]-180)
                                    
                                    let searchRange: [Double] = getSearchAreaMinMax(xyMinMax: xyMinMax, heading: [headingStart, headingEnd], headCoord: headCoord, serverCoord: serverCoord, trajType: trajType, lengthCondition: OlympusConstants.USER_TRAJECTORY_LENGTH_PDR, diagonalLengthRatio: trajDiagonal/trajLength)
                                    searchInfo.searchRange = searchRange.map { Int($0) }
                                    
                                    // 임시
                                    searchInfo.searchArea = getSearchCoordinates(areaMinMax: searchRange, interval: 1.0)
                                    searchInfo.trajShape = trajectoryFromHead
                                    searchInfo.trajStartCoord = headCoord
                                    
                                    hasMajorDirection = true
                                } else {
                                    hasMajorDirection = false
                                }
                            } else {
                                hasMajorDirection = false
                            }
                        }
                    }
                    
                    if (!hasMajorDirection) {
                        let trajType = TrajType.PDR_IN_PHASE4_NO_MAJOR_DIR
                        searchInfo.trajType = trajType
                        
                        let pastTraj = pastTrajectoryInfo
                        let pastDirection = pastMatchedDirection
                        let pastDirectionCompensation = pastDirection - Int(round(pastTraj[0].heading))
                        
                        var pastTrajIndex = [Int]()
                        var pastTrajHeading = [Int]()
                        for i in 0..<pastTraj.count {
                            pastTrajIndex.append(pastTraj[i].index)
                            pastTrajHeading.append(Int(round(pastTraj[i].heading)) + pastDirectionCompensation)
                        }
                        
                        let closestIndex = findClosestValueIndex(to: searchInfo.tailIndex, in: pastTrajIndex)
                        if let headingIndex = closestIndex {
                            searchDirection = [pastTrajHeading[headingIndex], pastTrajHeading[headingIndex]-Int(HEADING_UNCERTANTIY), pastTrajHeading[headingIndex]+Int(HEADING_UNCERTANTIY)]
                            for i in 0..<searchDirection.count {
                                searchDirection[i] = Int(compensateHeading(heading: Double(searchDirection[i])))
                            }
                            searchInfo.searchDirection = searchDirection
                            
                            let headingCorrectionForTail: Double = Double(pastTrajHeading[headingIndex]) - uvdHeading[0]
                            var headingFromTail = [Double] (repeating: 0, count: uvdHeading.count)
                            var headingFromHead = [Double] (repeating: 0, count: uvdHeading.count)
                            for i in 0..<uvdHeading.count {
                                headingFromTail[i] = uvdHeading[i] + headingCorrectionForTail
                                headingFromHead[i] = compensateHeading(heading: headingFromTail[i] - 180)
                            }
                            
                            var trajectoryFromHead = [[Double]]()
                            trajectoryFromHead.append(xyFromHead)
                            for i in (1..<trajectoryInfo.count).reversed() {
                                let headAngle = headingFromHead[i]
                                xyFromHead[0] = xyFromHead[0] + trajectoryInfo[i].length*cos(headAngle*OlympusConstants.D2R)
                                xyFromHead[1] = xyFromHead[1] + trajectoryInfo[i].length*sin(headAngle*OlympusConstants.D2R)
                                trajectoryFromHead.append(xyFromHead)
                            }
                            
                            let xyMinMax: [Double] = getMinMaxValues(for: trajectoryFromHead)
                            let headingStart = compensateHeading(heading: headingFromHead[headingFromHead.count-1]-180)
                            let headingEnd = compensateHeading(heading: headingFromHead[0]-180)
                            
                            let searchRange: [Double] = getSearchAreaMinMax(xyMinMax: xyMinMax, heading: [headingStart, headingEnd], headCoord: headCoord, serverCoord: serverCoord, trajType: trajType, lengthCondition: OlympusConstants.USER_TRAJECTORY_LENGTH_PDR, diagonalLengthRatio: trajDiagonal/trajLength)
                            searchInfo.searchRange = searchRange.map { Int($0) }
                            let searchArea = getSearchCoordinates(areaMinMax: searchRange, interval: 1.0)
                            
                            // 임시
                            searchInfo.searchArea = searchArea
                            searchInfo.trajShape = trajectoryFromHead
                            searchInfo.trajStartCoord = [headInfo.userX, headInfo.userY]
                        } else {
                            let trajType = TrajType.PDR_IN_PHASE4_ABNORMAL
                            searchInfo.trajType = trajType
                            
                            searchDirection = [pastDirection+Int(HEADING_UNCERTANTIY), pastDirection-Int(HEADING_UNCERTANTIY), pastDirection]
                            searchInfo.searchDirection = searchDirection
                            
                            var headingCorrectionForHead: Double = 0
                            let headingCorrectionFromServer: Double = headInfo.userHeading - uvdHeading[uvdHeading.count-1]
                            if (!isKF) {
                                headingCorrectionForHead = 0
                            } else {
                                headingCorrectionForHead = headInfoHeading - headInfo.userHeading
                            }
                            
                            var headingFromHead = [Double] (repeating: 0, count: uvdHeading.count)
                            for i in 0..<uvdHeading.count {
                                headingFromHead[i] = compensateHeading(heading: (uvdHeading[i] + headingCorrectionForHead) - 180 + headingCorrectionFromServer)
                            }

                            var trajectoryFromHead = [[Double]]()
                            trajectoryFromHead.append(xyFromHead)
                            for i in (1..<trajectoryInfo.count).reversed() {
                                let headAngle = headingFromHead[i]
                                xyFromHead[0] = xyFromHead[0] + trajectoryInfo[i].length*cos(headAngle*OlympusConstants.D2R)
                                xyFromHead[1] = xyFromHead[1] + trajectoryInfo[i].length*sin(headAngle*OlympusConstants.D2R)
                                trajectoryFromHead.append(xyFromHead)
                            }
                            
                            let xyMinMax: [Double] = getMinMaxValues(for: trajectoryFromHead)

                            let headingStart = compensateHeading(heading: headingFromHead[headingFromHead.count-1]-180)
                            let headingEnd = compensateHeading(heading: headingFromHead[0]-180)
                            
                            let searchRange: [Double] = getSearchAreaMinMax(xyMinMax: xyMinMax, heading: [headingStart, headingEnd], headCoord: headCoord, serverCoord: serverCoord, trajType: trajType, lengthCondition: OlympusConstants.USER_TRAJECTORY_LENGTH_PDR, diagonalLengthRatio: trajDiagonal/trajLength)
                            searchInfo.searchRange = searchRange.map { Int($0) }
                            let searchArea = getSearchCoordinates(areaMinMax: searchRange, interval: 1.0)
                            
                            // 임시
                            searchInfo.searchArea = searchArea
                            searchInfo.trajShape = trajectoryFromHead
                            searchInfo.trajStartCoord = [headInfo.userX, headInfo.userY]
                        }
                    }
                }
            } else {
                // DR
                if (PHASE != 2 && PHASE < 4) {
                    searchInfo.tailIndex = trajectoryInfo[0].index
                    
                    let PADDING_VALUE = OlympusConstants.USER_TRAJECTORY_LENGTH_DR*1.2
                    if (isPhaseBreak && (phaseBreakResult.building_name != "" && phaseBreakResult.level_name != "")) {
                        userX = phaseBreakResult.x
                        userY = phaseBreakResult.y
                    }
                    let searchRange: [Double] = [userX - PADDING_VALUE, userY - PADDING_VALUE, userX + PADDING_VALUE, userY + PADDING_VALUE]
                    searchInfo.searchRange = searchRange.map { Int($0) }
                
                    let ppHeadings = OlympusPathMatchingCalculator.shared.getPathMatchingHeadings(building: userBuilding, level: userLevel, x: userX, y: userY, PADDING_VALUE: PADDING_VALUE, mode: mode)
                    var searchHeadings: [Double] = []
                    if (trajLength <= 30) {
                        searchHeadings = ppHeadings
                    } else {
                        let headingLeastChangeSection = extractSectionWithLeastChange(inputArray: uvdRawHeading, requiredSize: 7)
                        if (headingLeastChangeSection.isEmpty) {
                            let diffHeadingHeadTail = abs(uvdRawHeading[uvdRawHeading.count-1] - uvdRawHeading[0])
                            if (diffHeadingHeadTail < 5) {
                                for ppHeading in ppHeadings {
                                    let defaultHeading = ppHeading - diffHeadingHeadTail
                                    searchHeadings.append(compensateHeading(heading: defaultHeading))
                                }
                            } else {
                                for ppHeading in ppHeadings {
                                    let defaultHeading = ppHeading - diffHeadingHeadTail
                                    searchHeadings.append(compensateHeading(heading: defaultHeading))
                                }
                            }
                        } else {
                            let headingForCompensation = headingLeastChangeSection.average - uvdRawHeading[0]
                            for ppHeading in ppHeadings {
                                searchHeadings.append(compensateHeading(heading: ppHeading - headingForCompensation))
                            }
                        }
                    }
                    let uniqueSearchHeadings = Array(Set(searchHeadings))
                    searchInfo.searchDirection = uniqueSearchHeadings.map { Int($0) }
                    
                    let headInfo = trajectoryInfo[trajectoryInfo.count-1]
                    var xyFromHead: [Double] = [headInfo.userX, headInfo.userY]
                    
                    let headingCorrectionFromServer: Double = headInfo.userHeading - uvdHeading[uvdHeading.count-1]
                    var headingFromHead = [Double] (repeating: 0, count: uvdHeading.count)
                    
                    for i in 0..<uvdHeading.count {
                        headingFromHead[i] = compensateHeading(heading: uvdHeading[i] - 180 + headingCorrectionFromServer)
                    }
                    
                    var trajectoryFromHead = [[Double]]()
                    trajectoryFromHead.append(xyFromHead)
                    for i in (1..<trajectoryInfo.count).reversed() {
                        let headAngle = headingFromHead[i]
                        xyFromHead[0] = xyFromHead[0] + trajectoryInfo[i].length*cos(headAngle*OlympusConstants.D2R)
                        xyFromHead[1] = xyFromHead[1] + trajectoryInfo[i].length*sin(headAngle*OlympusConstants.D2R)
                        trajectoryFromHead.append(xyFromHead)
                    }

                    searchInfo.searchArea = getSearchCoordinates(areaMinMax: searchRange, interval: 1.0)
                    searchInfo.trajShape = trajectoryFromHead
                    searchInfo.trajStartCoord = [headInfo.userX, headInfo.userY]
                }
            }
        } else {
//            print(getLocalTimeString() + " , (Olympus) Warnings : Traj is Empty")
        }
        
        if searchInfo.searchDirection.isEmpty {
            searchInfo.searchDirection = [0, 90, 180, 270]
        }
        
        return searchInfo
    }
    
    public func extractSectionWithLeastChange(inputArray: [Double], requiredSize: Int) -> [Double] {
        var resultArray = [Double]()
        guard inputArray.count > requiredSize else {
            return []
        }
        
        var compensatedArray = [Double] (repeating: 0, count: inputArray.count)
        for i in 0..<inputArray.count {
            compensatedArray[i] = compensateHeading(heading: inputArray[i])
        }
        
        var bestSliceStartIndex = 0
        var bestSliceEndIndex = 0

        for startIndex in 0..<(inputArray.count-(requiredSize-1)) {
            for endIndex in (startIndex+requiredSize)..<inputArray.count {
                let slice = Array(compensatedArray[startIndex...endIndex])
                let circularStd = circularStandardDeviation(for: slice)
                if circularStd < 5 && slice.count > bestSliceEndIndex - bestSliceStartIndex {
                    bestSliceStartIndex = startIndex
                    bestSliceEndIndex = endIndex
                }
            }
        }
        
        resultArray = Array(inputArray[bestSliceStartIndex...bestSliceEndIndex])
        if resultArray.count > requiredSize {
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
    
    private func getSearchAreaMinMax(xyMinMax: [Double], heading: [Double], headCoord: [Double], serverCoord: [Double], trajType: TrajType, lengthCondition: Double, diagonalLengthRatio: Double) -> [Double] {
        var areaMinMax: [Double] = []
        
        var xMin = xyMinMax[0]
        var yMin = xyMinMax[1]
        var xMax = xyMinMax[2]
        var yMax = xyMinMax[3]
        
        let SEARCH_LENGTH: Double = lengthCondition*0.4
        
        let headingStart = heading[0]
        let headingEnd = heading[1]

        let startCos = cos(headingStart*OlympusConstants.D2R)
        let startSin = sin(headingStart*OlympusConstants.D2R)

        let endCos = cos(headingEnd*OlympusConstants.D2R)
        let endSin = sin(headingEnd*OlympusConstants.D2R)
        
        switch (trajType) {
        case .DR_IN_PHASE3:
            let areaXrange = xMax - xMin
            let areaYrange = yMax - yMin
            let search_margin: Double = 4
            if (areaXrange > areaYrange) {
                var expandRatio = areaXrange/areaYrange
                if (expandRatio > 1.5) {
                    expandRatio = 1.5
                }
                xMin -= search_margin*expandRatio
                xMax += search_margin*expandRatio
                yMin -= search_margin
                yMax += search_margin
            } else if (areaXrange < areaYrange) {
                var expandRatio = areaYrange/areaXrange
                if (expandRatio > 1.5) {
                    expandRatio = 1.5
                }
                xMin -= search_margin
                xMax += search_margin
                yMin -= search_margin*expandRatio
                yMax += search_margin*expandRatio
            } else {
                xMin -= search_margin
                xMax += search_margin
                yMin -= search_margin
                yMax += search_margin
            }
        case .DR_UNKNOWN:
            print("DR_UNKNOWN")
        case .DR_ALL_STRAIGHT:
            if (startCos > 0) {
                xMin = xMin - 1.2*SEARCH_LENGTH*startCos
                xMax = xMax + 1.2*SEARCH_LENGTH*startCos
            } else {
                xMin = xMin + 1.2*SEARCH_LENGTH*startCos
                xMax = xMax - 1.2*SEARCH_LENGTH*startCos
            }

            if (startSin > 0) {
                yMin = yMin - 1.2*SEARCH_LENGTH*startSin
                yMax = yMax + 1.2*SEARCH_LENGTH*startSin
            } else {
                yMin = yMin + 1.2*SEARCH_LENGTH*startSin
                yMax = yMax - 1.2*SEARCH_LENGTH*startSin
            }

            if (endCos > 0) {
                xMin = xMin - SEARCH_LENGTH*endCos
                xMax = xMax + SEARCH_LENGTH*endCos
            } else {
                xMin = xMin + SEARCH_LENGTH*endCos
                xMax = xMax - SEARCH_LENGTH*endCos
            }

            if (endSin > 0) {
                yMin = yMin - SEARCH_LENGTH*endSin
                yMax = yMax + SEARCH_LENGTH*endSin
            } else {
                yMin = yMin + SEARCH_LENGTH*endSin
                yMax = yMax - SEARCH_LENGTH*endSin
            }
            
            if (abs(xMin - xMax) < 5.0) {
                xMin = xMin - lengthCondition*0.05
                xMax = xMax + lengthCondition*0.05
            }

            if (abs(yMin - yMax) < 5.0) {
                yMin = yMin - lengthCondition*0.05
                yMax = yMax + lengthCondition*0.05
            }
            
        case .DR_HEAD_STRAIGHT:
            if (startCos > 0) {
                xMin = xMin - 1.2*SEARCH_LENGTH*startCos
                xMax = xMax + 1.2*SEARCH_LENGTH*startCos
            } else {
                xMin = xMin + 1.2*SEARCH_LENGTH*startCos
                xMax = xMax - 1.2*SEARCH_LENGTH*startCos
            }

            if (startSin > 0) {
                yMin = yMin - 1.2*SEARCH_LENGTH*startSin
                yMax = yMax + 1.2*SEARCH_LENGTH*startSin
            } else {
                yMin = yMin + 1.2*SEARCH_LENGTH*startSin
                yMax = yMax - 1.2*SEARCH_LENGTH*startSin
            }

            if (endCos > 0) {
                xMin = xMin - SEARCH_LENGTH*endCos
                xMax = xMax + SEARCH_LENGTH*endCos
            } else {
                xMin = xMin + SEARCH_LENGTH*endCos
                xMax = xMax - SEARCH_LENGTH*endCos
            }

            if (endSin > 0) {
                yMin = yMin - SEARCH_LENGTH*endSin
                yMax = yMax + SEARCH_LENGTH*endSin
            } else {
                yMin = yMin + SEARCH_LENGTH*endSin
                yMax = yMax - SEARCH_LENGTH*endSin
            }
            
            let diffHeading = compensateHeading(heading: abs(headingStart - headingEnd))
            let diffX = abs(xMax - xMin)
            let diffY = abs(yMax - yMin)
            let diffXy = abs(diffX - diffY)*0.2
            
            if (diffHeading > 150) {
                if (diffX < diffY) {
                    xMin = xMin - diffXy
                    xMax = xMax + diffXy
                } else {
                    yMin = yMin - diffXy
                    yMax = yMax + diffXy
                }
            } else {
                // Check ㄹ Trajectory
                if (diffHeading < 30) {
                    if (diffX < diffY) {
                        xMin = xMin - diffXy
                        xMax = xMax + diffXy
                    } else {
                        yMin = yMin - diffXy
                        yMax = yMax + diffXy
                    }
                }
            }
            
        case .DR_TAIL_STRAIGHT:
            if (startCos > 0) {
                xMin = xMin - SEARCH_LENGTH*startCos
                xMax = xMax + SEARCH_LENGTH*startCos
            } else {
                xMin = xMin + SEARCH_LENGTH*startCos
                xMax = xMax - SEARCH_LENGTH*startCos
            }

            if (startSin > 0) {
                yMin = yMin - SEARCH_LENGTH*startSin
                yMax = yMax + SEARCH_LENGTH*startSin
            } else {
                yMin = yMin + SEARCH_LENGTH*startSin
                yMax = yMax - SEARCH_LENGTH*startSin
            }

            if (endCos > 0) {
                xMin = xMin - 1.2*SEARCH_LENGTH*endCos
                xMax = xMax + 1.2*SEARCH_LENGTH*endCos
            } else {
                xMin = xMin + 1.2*SEARCH_LENGTH*endCos
                xMax = xMax - 1.2*SEARCH_LENGTH*endCos
            }

            if (endSin > 0) {
                yMin = yMin - 1.2*SEARCH_LENGTH*endSin
                yMax = yMax + 1.2*SEARCH_LENGTH*endSin
            } else {
                yMin = yMin + 1.2*SEARCH_LENGTH*endSin
                yMax = yMax - 1.2*SEARCH_LENGTH*endSin
            }
            
            let diffHeading = compensateHeading(heading: abs(headingStart - headingEnd))
            let diffX = abs(xMax - xMin)
            let diffY = abs(yMax - yMin)
            let diffXy = abs(diffX - diffY)*0.2
            
            if (diffHeading > 150) {
                if (diffX < diffY) {
                    xMin = xMin - diffXy
                    xMax = xMax + diffXy
                } else {
                    yMin = yMin - diffXy
                    yMax = yMax + diffXy
                }
            } else {
                // Check ㄹ Trajectory
                if (diffHeading < 30) {
                    if (diffX < diffY) {
                        xMin = xMin - diffXy
                        xMax = xMax + diffXy
                    } else {
                        yMin = yMin - diffXy
                        yMax = yMax + diffXy
                    }
                }
            }
        case .PDR_IN_PHASE3_NO_MAJOR_DIR:
            print("HPDR_IN_PHASE3_NO_MAJOR_DIRere")
        case .PDR_IN_PHASE3_HAS_MAJOR_DIR:
            print("PDR_IN_PHASE3_HAS_MAJOR_DIR")
        case .PDR_IN_PHASE4_ABNORMAL:
            let areaXrange = xMax - xMin
            let areaYrange = yMax - yMin
            let search_margin: Double = 4
            if (areaXrange > areaYrange) {
                var expandRatio = areaXrange/areaYrange
                if (expandRatio > 1.5) {
                    expandRatio = 1.5
                }
                xMin -= search_margin*expandRatio
                xMax += search_margin*expandRatio
                yMin -= search_margin
                yMax += search_margin
            } else if (areaXrange < areaYrange) {
                var expandRatio = areaYrange/areaXrange
                if (expandRatio > 1.5) {
                    expandRatio = 1.5
                }
                xMin -= search_margin
                xMax += search_margin
                yMin -= search_margin*expandRatio
                yMax += search_margin*expandRatio
            } else {
                xMin -= search_margin
                xMax += search_margin
                yMin -= search_margin
                yMax += search_margin
            }
        case .PDR_IN_PHASE4_NO_MAJOR_DIR:
            let areaXrange = xMax - xMin
            let areaYrange = yMax - yMin
            let search_margin: Double = 4
            if (areaXrange > areaYrange) {
                var expandRatio = areaXrange/areaYrange
                if (expandRatio > 1.5) {
                    expandRatio = 1.5
                }
                xMin -= search_margin*expandRatio
                xMax += search_margin*expandRatio
                yMin -= search_margin
                yMax += search_margin
            } else if (areaXrange < areaYrange) {
                var expandRatio = areaYrange/areaXrange
                if (expandRatio > 1.5) {
                    expandRatio = 1.5
                }
                xMin -= search_margin
                xMax += search_margin
                yMin -= search_margin*expandRatio
                yMax += search_margin*expandRatio
            } else {
                xMin -= search_margin
                xMax += search_margin
                yMin -= search_margin
                yMax += search_margin
            }
        case .PDR_IN_PHASE4_HAS_MAJOR_DIR:
            var search_margin = 2*exp(3.4 * (diagonalLengthRatio-0.44))
            if (search_margin < 2) {
                search_margin = 2
            } else if (search_margin > 10) {
                search_margin = 10
            }

            let oppsite_margin = search_margin*0.6
            
            let centerCoord = [(xMax+xMin)/2, (yMax+yMin)/2]
            let headToCenter = [headCoord[0]-serverCoord[0], headCoord[1]-serverCoord[1]]
            
            if (headToCenter[0] > 0 && headToCenter[1] > 0) {
                // 1사분면
                xMax += search_margin
                yMax += search_margin
                xMin -= oppsite_margin
                yMin -= oppsite_margin
            } else if (headToCenter[0] < 0 && headToCenter[1] > 0) {
                // 2사분면
                xMin -= search_margin
                yMax += search_margin
                xMax += oppsite_margin
                yMin -= oppsite_margin
            } else if (headToCenter[0] < 0 && headToCenter[1] < 0) {
                // 3사분면
                xMin -= search_margin
                yMin -= search_margin
                xMax += oppsite_margin
                yMax += oppsite_margin
            } else if (headToCenter[0] > 0 && headToCenter[1] < 0) {
                // 4사분면
                xMax += search_margin
                yMin -= search_margin
                xMin -= oppsite_margin
                yMax += oppsite_margin
            } else {
                xMin -= search_margin
                xMax += search_margin
                yMin -= search_margin
                yMax += search_margin
            }
            
            if (diagonalLengthRatio < 0.6) {
                let areaXrange = xMax - xMin
                let areaYrange = yMax - yMin
                let default_margin: Double = 4
                if (areaXrange > areaYrange) {
                    var expandRatio = areaXrange/areaYrange
                    if (expandRatio > 1.5) {
                        expandRatio = 1.5
                    }
                    xMin -= default_margin*expandRatio
                    xMax += default_margin*expandRatio
                } else if (areaXrange < areaYrange) {
                    var expandRatio = areaYrange/areaXrange
                    if (expandRatio > 1.5) {
                        expandRatio = 1.5
                    }
                    yMin -= default_margin*expandRatio
                    yMax += default_margin*expandRatio
                } else {
                    xMin -= default_margin
                    xMax += default_margin
                    yMin -= default_margin
                    yMax += default_margin
                }
            }
        default:
            print("Do Nothing")
        }
        
        areaMinMax = [xMin, yMin, xMax, yMax]
        
        return areaMinMax
    }
    
    private func isTrajectoryStraight(for array: [Double], size: Int, mode: String, conditionPdr: Int, conditionDr: Int) -> TrajType {
        var CONDITON: Int = 10
        if (mode == OlympusConstants.MODE_PDR) {
            CONDITON = conditionPdr
        } else {
            CONDITON = conditionDr
        }
        if (size < CONDITON) {
            return TrajType.DR_UNKNOWN
        }
        
        let straightAngle: Double = 1.5
        // All Straight
        let circularStandardDeviationAll = circularStandardDeviation(for: array)
        if (circularStandardDeviationAll <= straightAngle) {
            return TrajType.DR_ALL_STRAIGHT
        }
        
        // Head Straight
        let lastTenValues = Array(array[(size-CONDITON)..<size])
        let circularStandardDeviationHead = circularStandardDeviation(for: lastTenValues)
        if (circularStandardDeviationHead <= straightAngle) {
            return TrajType.DR_HEAD_STRAIGHT
        }
        
        // Tail Straight
        let firstTenValues = Array(array[0..<CONDITON])
        let circularStandardDeviationTail = circularStandardDeviation(for: firstTenValues)
        if (circularStandardDeviationTail <= straightAngle) {
            return TrajType.DR_TAIL_STRAIGHT
        }
        
        return TrajType.DR_UNKNOWN
    }
    
    private func findClosestValueIndex(to target: Int, in array: [Int]) -> Int? {
        guard !array.isEmpty else {
            return nil
        }

        var closestIndex = 0
        var smallestDifference = abs(array[0] - target)

        for i in 0..<array.count {
            let value = array[i]
            let difference = abs(value - target)
            if difference < smallestDifference {
                smallestDifference = difference
                closestIndex = i
            }
        }

        return closestIndex
    }
    
    public func setPastInfo(trajInfo: [TrajectoryInfo], searchInfo: SearchInfo, matchedDirection: Int) {
        self.pastTrajectoryInfo = trajInfo
        self.pastSearchInfo = searchInfo
        self.pastMatchedDirection = matchedDirection
    }
    
    // Trajectory Compensation
    public func getTrajCompensationArray(currentTime: Int, trajLength: Double, LENGTH_THRESHOLD: Double) -> [Double] {
        var trajCompensationArray: [Double] = [self.trajCompensation]
        if (trajLength < LENGTH_THRESHOLD) {
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
