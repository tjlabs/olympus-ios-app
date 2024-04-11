
public class OlympusTrajectoryController {
    
    var isMovePhase2To4: Bool = false
    var distanceAfterPhase2To4: Double = 0
    
    public var userTrajectoryInfo: [TrajectoryInfo] = []
    
    public var isNeedTrajCheck: Bool = false
    public var isUnknownTraj: Bool = false
    public var sendFailUvdIndexes = [Int]()
    public var validIndex: Int = 0
    public var isNeedRemoveIndexSendFailArray: Bool = false
    
    init() {}
    
    public func calculateTrajectoryLength(userTrajectory: [TrajectoryInfo]) -> Double {
        var trajLength = 0.0
        for unitTraj in userTrajectory {
            trajLength += unitTraj.length
        }
        return trajLength
    }
    
    func getTrajectoryFromLast(from userTrajectory: [TrajectoryInfo], N: Int) -> [TrajectoryInfo] {
        let size = userTrajectory.count
        guard size >= N else {
            return userTrajectory
        }
        
        let startIndex = size - N
        let endIndex = size
        
        var result: [TrajectoryInfo] = []
        for i in startIndex..<endIndex {
            result.append(userTrajectory[i])
        }

        return result
    }
    
    func getTrajectoryFromN(from userTrajectory: [TrajectoryInfo], N: Int) -> [TrajectoryInfo] {
        let size = userTrajectory.count
        guard size >= N else {
            return userTrajectory
        }
        
        let startIndex = N
        let endIndex = size
        
        var result: [TrajectoryInfo] = []
        for i in startIndex..<endIndex {
            result.append(userTrajectory[i])
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
    
    private func checkIsTailIndexSendFail(userTrajectory: [TrajectoryInfo], sendFailUvdIndexes: [Int]) -> Bool {
        var isTailIndexSendFail: Bool = false
        let tailIndex = userTrajectory[0].index
        if sendFailUvdIndexes.contains(tailIndex) {
            isTailIndexSendFail = true
        }
        
        return isTailIndexSendFail
    }
    
    func getValidTrajectory(userTrajectory: [TrajectoryInfo], sendFailUvdIndexes: [Int], mode: String) -> ([TrajectoryInfo], Int) {
        var result = [TrajectoryInfo]()
        var isFindValidIndex: Bool = false
        var validIndex: Int = 0
        var validUvdIndex: Int = userTrajectory[0].index
        
        for i in 0..<userTrajectory.count{
            let uvdIndex = userTrajectory[i].index
            var uvdLookingFlag = userTrajectory[i].lookingFlag
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
            for i in validIndex..<userTrajectory.count {
                result.append(userTrajectory[i])
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
            var userTrajectory = TrajectoryInfo()
            userTrajectory.index = unitDRInfo.index
            userTrajectory.length = unitLength
            userTrajectory.heading = unitDRInfo.heading
            userTrajectory.velocity = unitDRInfo.velocity
            userTrajectory.lookingFlag = unitDRInfo.lookingFlag
            userTrajectory.isIndexChanged = unitDRInfo.isIndexChanged
            userTrajectory.numBleChannels = numBleChannels
            userTrajectory.scc = olympusResult.scc
            userTrajectory.userBuilding = olympusResult.building_name
            userTrajectory.userLevel = olympusResult.level_name
            
//            if (self.isActiveKf) {
//                userTrajectory.userX = self.timeUpdateResult[0]
//                userTrajectory.userY = self.timeUpdateResult[1]
//                userTrajectory.userHeading = self.timeUpdateResult[2]
//            } else {
//                userTrajectory.userX = resultToReturn.x
//                userTrajectory.userY = resultToReturn.y
//                userTrajectory.userHeading = resultToReturn.absolute_heading
//            }
            
            userTrajectory.userX = olympusResult.x
            userTrajectory.userY = olympusResult.y
            userTrajectory.userHeading = olympusResult.absolute_heading
            
            userTrajectory.userTuHeading = tuHeading
            userTrajectory.userPmSuccess = isPmSuccess
            self.userTrajectoryInfo.append(userTrajectory)
            
            if (mode == OlympusConstants.MODE_PDR) {
                // PDR
                controlPdrTrajectoryInfo(LENGTH_CONDITION: OlympusConstants.USER_TRAJECTORY_LENGTH)
            } else {
                // DR
                controlDrTrajectoryInfo(isDetermineSpot: isDetermineSpot, spotCutIndex: spotCutIndex, isUnknownTraj: self.isUnknownTraj, LENGTH_CONDITION: OlympusConstants.USER_TRAJECTORY_LENGTH)
            }
        }
        
        return self.userTrajectoryInfo
    }
    
    private func controlPdrTrajectoryInfo(LENGTH_CONDITION: Double) {
        var isNeedAllClear: Bool = false
        let updatedTrajectoryInfoWithLength = updateTrajectoryInfoWithLength(userTrajectory: self.userTrajectoryInfo, LENGTH_CONDITION: LENGTH_CONDITION)
        let isTailIndexSendFail = checkIsTailIndexSendFail(userTrajectory: updatedTrajectoryInfoWithLength, sendFailUvdIndexes: self.sendFailUvdIndexes)
        if (isTailIndexSendFail) {
            let validTrajectoryInfoResult = getValidTrajectory(userTrajectory: updatedTrajectoryInfoWithLength, sendFailUvdIndexes: self.sendFailUvdIndexes, mode: OlympusConstants.MODE_PDR)
            if (!validTrajectoryInfoResult.0.isEmpty) {
                let trajLength = calculateTrajectoryLength(userTrajectory: validTrajectoryInfoResult.0)
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
                let validTrajectoryInfoResult = getValidTrajectory(userTrajectory: updatedTrajectoryInfoWithLength, sendFailUvdIndexes: self.sendFailUvdIndexes, mode: OlympusConstants.MODE_PDR)
                if (!validTrajectoryInfoResult.0.isEmpty) {
                    let trajLength = calculateTrajectoryLength(userTrajectory: validTrajectoryInfoResult.0)
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
            NotificationCenter.default.post(name: .phaseBecome1, object: nil, userInfo: nil)
            self.userTrajectoryInfo = [TrajectoryInfo]()
        }
    }
    
    private func controlDrTrajectoryInfo(isDetermineSpot: Bool, spotCutIndex: Int, isUnknownTraj: Bool, LENGTH_CONDITION: Double) {
        if (isDetermineSpot) {
            let newTraj = getTrajectoryFromLast(from: self.userTrajectoryInfo, N: spotCutIndex)
            self.userTrajectoryInfo = newTraj
            
            NotificationCenter.default.post(name: .trajEditedAfterOsr, object: nil, userInfo: nil)
            NotificationCenter.default.post(name: .phaseBecome2, object: nil, userInfo: nil)
        } else if (isUnknownTraj) {
            self.isUnknownTraj = false
            
            var cutIdx = Int(OlympusConstants.USER_TRAJECTORY_LENGTH_DR) - OlympusConstants.UNKNOWN_TRAJ_CUT_IDX
            if cutIdx <= OlympusConstants.UNKNOWN_TRAJ_CUT_IDX {
                cutIdx = OlympusConstants.UNKNOWN_TRAJ_CUT_IDX
            }
            
            let newTraj = getTrajectoryFromLast(from: self.userTrajectoryInfo, N: cutIdx)
            self.userTrajectoryInfo = newTraj
            
        } else {
            let trajLength = calculateTrajectoryLength(userTrajectory: self.userTrajectoryInfo)
            if trajLength > LENGTH_CONDITION {
                self.userTrajectoryInfo.removeFirst()
            }
        }
        
        var isNeedAllClear: Bool = false
        if (!self.userTrajectoryInfo.isEmpty) {
            let isTailIndexSendFail = checkIsTailIndexSendFail(userTrajectory: self.userTrajectoryInfo, sendFailUvdIndexes: self.sendFailUvdIndexes)
            if (isTailIndexSendFail) {
                let validTrajectoryInfoResult = getValidTrajectory(userTrajectory: self.userTrajectoryInfo, sendFailUvdIndexes: self.sendFailUvdIndexes, mode: OlympusConstants.MODE_DR)
                if (!validTrajectoryInfoResult.0.isEmpty) {
                    let trajLength = calculateTrajectoryLength(userTrajectory: validTrajectoryInfoResult.0)
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
            NotificationCenter.default.post(name: .phaseBecome1, object: nil, userInfo: nil)
            self.userTrajectoryInfo = [TrajectoryInfo]()
        }
    }
    
    private func updateTrajectoryInfoWithLength(userTrajectory: [TrajectoryInfo], LENGTH_CONDITION: Double) -> [TrajectoryInfo] {
        var accumulatedLength = 0.0

        var longTrajIndex: Int = 0
        var isFindLong: Bool = false
        var shortTrajIndex: Int = 0
        var isFindShort: Bool = false

        if (!userTrajectory.isEmpty) {
            let startHeading = userTrajectory[0].heading
            let headInfo = userTrajectory[userTrajectory.count-1]
            var xyFromHead: [Double] = [headInfo.userX, headInfo.userY]

            var headingFromHead = [Double] (repeating: 0, count: userTrajectory.count)
            for i in 0..<userTrajectory.count {
                headingFromHead[i] = compensateHeading(heading: userTrajectory[i].heading  - 180 - startHeading)
            }

            var trajectoryFromHead = [[Double]]()
            trajectoryFromHead.append(xyFromHead)
            for i in (1..<userTrajectory.count).reversed() {
                let headAngle = headingFromHead[i]
                let uvdLength = userTrajectory[i].length
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
                let newTrajectory = getTrajectoryFromN(from: userTrajectory, N: longTrajIndex)
                return newTrajectory
            } else {
                let newTrajectory = getTrajectoryFromN(from: userTrajectory, N: shortTrajIndex)
                return newTrajectory
            }
        }

        return userTrajectory
    }
    
    public func makeSearchAreaAndDirection() {
        
    }
}
