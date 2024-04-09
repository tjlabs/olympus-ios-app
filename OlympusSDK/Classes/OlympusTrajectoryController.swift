
public class OlympusTrajectoryController {
    
    var isMovePhase2To4: Bool = false
    var distanceAfterPhase2To4: Double = 0
    
    public var userTrajectoryInfo: [TrajectoryInfo] = []
    
    public var isNeedTrajCheck: Bool = false
    public var sendFailUvdIndexes = [Int]()
    public var validIndex: Int = 0
    public var isNeedRemoveIndexSendFailArray: Bool = false
    
    init() {
        
    }
    
    public func getTrajectoryFromLast(from userTrajectory: [TrajectoryInfo], N: Int) -> [TrajectoryInfo] {
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
    
    public func getTrajectoryForDiagonal(from userTrajectory: [TrajectoryInfo], N: Int) -> [TrajectoryInfo] {
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
    
    public func calculateTrajectoryLength(userTrajectory: [TrajectoryInfo]) -> Double {
        var trajLength = 0.0
        for unitTraj in userTrajectory {
            trajLength += unitTraj.length
        }
        return trajLength
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
    
    public func setIsNeedTrajCheck(flag: Bool) {
        self.isNeedTrajCheck = flag
    }
    
    public func checkIsNeedTrajAllClear(isPhaseBreak: Bool, isBecomeForeground: Bool, isGetFirstResponse: Bool, timeForInit: Double) -> Bool {
        var isNeedAllClear: Bool = false
        if (self.isNeedTrajCheck) {
            if (isPhaseBreak) {
                let cutIdx = Int(ceil(OlympusConstants.USER_TRAJECTORY_DIAGONAL*0.5))
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
            }
            self.isNeedTrajCheck = false
        } else if (isBecomeForeground) {
            let cutIdx = Int(ceil(OlympusConstants.USER_TRAJECTORY_DIAGONAL*0.5))
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
        } else if (isGetFirstResponse && timeForInit < OlympusConstants.TIME_INIT_THRESHOLD) {
            isNeedAllClear = true
        }
        return isNeedAllClear
    }
    
    public func controlTrajectoryInfo() {
        
    }
    
    public func makeTrajectoryInfo(unitDRInfo: UnitDRInfo, unitLength: Double, resultToReturn: FineLocationTrackingResult, tuHeading: Double, isPmSuccess: Bool, numBleChannels: Int, mode: String) {
        if (resultToReturn.x != 0 && resultToReturn.y != 0) {
            if (mode == OlympusConstants.MODE_PDR) {
                // PDR
                // PhaseBreak의 의미는 무엇인가..? (칼만필터 동작 중에 Phase가 1로 떨어진 경우가 PhaseBreak다)
                // PhaseBreak 상황
                // 1. Phase 2 -> 1
                // 2.
                
//                if (self.isMoveNotLookingToLooking) {
//                    let newTraj = getTrajectoryFromLast(from: self.userTrajectoryInfo, N: 15)
//                    self.userTrajectoryInfo = newTraj
//                    self.isMoveNotLookingToLooking = false
//                } else {
//                    if (self.isNeedTrajInit) {
//                        if (self.isPhaseBreak) {
//                            let cutIdx = Int(ceil(USER_TRAJECTORY_DIAGONAL*0.5))
//                            let newTraj = getTrajectoryFromLast(from: self.userTrajectoryInfo, N: cutIdx)
//                            var isNeedAllClear: Bool = false
//                            
//                            if (newTraj.count > 1) {
//                                for i in 1..<newTraj.count {
//                                    let diffX = abs(newTraj[i].userX - newTraj[i-1].userX)
//                                    let diffY = abs(newTraj[i].userY - newTraj[i-1].userY)
//                                    if (sqrt(diffX*diffX + diffY*diffY) > 3) {
//                                        isNeedAllClear = true
//                                        break
//                                    }
//                                }
//                            }
//                            
//                            if (isNeedAllClear) {
//                                self.userTrajectoryInfo = [TrajectoryInfo]()
//                            } else {
//                                self.userTrajectoryInfo = newTraj
//                            }
//                        } else {
//                            self.userTrajectoryInfo = [TrajectoryInfo]()
//                        }
//                        self.isNeedTrajInit = false
//                    } else if (!self.isGetFirstResponse && (self.timeForInit < TIME_INIT_THRESHOLD)) {
//                        self.userTrajectoryInfo = [TrajectoryInfo]()
//                    } else if (self.isForeground) {
//                        let cutIdx = Int(ceil(USER_TRAJECTORY_DIAGONAL*0.2))
//                        let newTraj = getTrajectoryFromLast(from: self.userTrajectoryInfo, N: cutIdx)
//                        var isNeedAllClear: Bool = false
//                        
//                        if (newTraj.count > 1) {
//                            for i in 1..<newTraj.count {
//                                let diffX = abs(newTraj[i].userX - newTraj[i-1].userX)
//                                let diffY = abs(newTraj[i].userY - newTraj[i-1].userY)
//                                if (sqrt(diffX*diffX + diffY*diffY) > 3) {
//                                    isNeedAllClear = true
//                                    break
//                                }
//                            }
//                        }
//                        if (isNeedAllClear) {
//                            self.userTrajectoryInfo = [TrajectoryInfo]()
//                        } else {
//                            self.userTrajectoryInfo = newTraj
//                        }
//                        self.isForeground = false
//                    } else {
//                        self.userTrajectory.index = unitDRInfo.index
//                        self.userTrajectory.length = uvdLength
//                        self.userTrajectory.heading = unitDRInfo.heading
//                        self.userTrajectory.velocity = unitDRInfo.velocity
//                        self.userTrajectory.lookingFlag = unitDRInfo.lookingFlag
//                        self.userTrajectory.isIndexChanged = unitDRInfo.isIndexChanged
//                        self.userTrajectory.numChannels = bleChannels
//                        self.userTrajectory.scc = resultToReturn.scc
//                        self.userTrajectory.userBuilding = resultToReturn.building_name
//                        self.userTrajectory.userLevel = resultToReturn.level_name
//                        if (self.isActiveKf) {
//                            self.userTrajectory.userX = self.timeUpdateResult[0]
//                            self.userTrajectory.userY = self.timeUpdateResult[1]
//                            self.userTrajectory.userHeading = self.timeUpdateResult[2]
//                        } else {
//                            self.userTrajectory.userX = resultToReturn.x
//                            self.userTrajectory.userY = resultToReturn.y
//                            self.userTrajectory.userHeading = resultToReturn.absolute_heading
//                        }
//                        
//                        self.userTrajectory.userTuHeading = tuHeading
//                        self.userTrajectory.userPmSuccess = isPmSuccess
//                        
//                        self.userTrajectoryInfo.append(self.userTrajectory)
//                        self.accumulateDiagonalAndRemoveOldest(LENGTH_CONDITION: self.USER_TRAJECTORY_DIAGONAL)
//                    }
//                }
            } else {
                // DR
//                if (self.isNeedTrajInit) {
//                    if (self.isPhaseBreak) {
//                        let cutIdx = Int(ceil(USER_TRAJECTORY_LENGTH*0.5))
//                        let newTraj = getTrajectoryFromLast(from: self.userTrajectoryInfo, N: cutIdx)
//                        var isNeedAllClear: Bool = false
//                        
//                        if (newTraj.count > 1) {
//                            for i in 1..<newTraj.count {
//                                let diffX = abs(newTraj[i].userX - newTraj[i-1].userX)
//                                let diffY = abs(newTraj[i].userY - newTraj[i-1].userY)
//                                if (sqrt(diffX*diffX + diffY*diffY) > 3) {
//                                    isNeedAllClear = true
//                                    break
//                                }
//                            }
//                        }
//                        
//                        if (isNeedAllClear) {
//                            self.userTrajectoryInfo = [TrajectoryInfo]()
//                        } else {
//                            self.userTrajectoryInfo = newTraj
//                        }
//                    } else {
//                        self.userTrajectoryInfo = [TrajectoryInfo]()
//                    }
//                    self.isNeedTrajInit = false
//                } else if (!self.isGetFirstResponse && (self.timeForInit < TIME_INIT_THRESHOLD)) {
//                    self.userTrajectoryInfo = [TrajectoryInfo]()
//                } else if (self.isForeground) {
//                    let cutIdx = Int(ceil(USER_TRAJECTORY_LENGTH*0.2))
//                    let newTraj = getTrajectoryFromLast(from: self.userTrajectoryInfo, N: cutIdx)
//                    var isNeedAllClear: Bool = false
//                    
//                    if (newTraj.count > 1) {
//                        for i in 1..<newTraj.count {
//                            let diffX = abs(newTraj[i].userX - newTraj[i-1].userX)
//                            let diffY = abs(newTraj[i].userY - newTraj[i-1].userY)
//                            if (sqrt(diffX*diffX + diffY*diffY) > 3) {
//                                isNeedAllClear = true
//                                break
//                            }
//                        }
//                    }
//                    
//                    if (isNeedAllClear) {
//                        self.userTrajectoryInfo = [TrajectoryInfo]()
//                    } else {
//                        self.userTrajectoryInfo = newTraj
//                    }
//                    self.isForeground = false
//                } else {
//                    self.userTrajectory.index = unitDRInfo.index
//                    self.userTrajectory.length = uvdLength
//                    self.userTrajectory.heading = unitDRInfo.heading
//                    self.userTrajectory.velocity = unitDRInfo.velocity
//                    self.userTrajectory.lookingFlag = unitDRInfo.lookingFlag
//                    self.userTrajectory.isIndexChanged = unitDRInfo.isIndexChanged
//                    self.userTrajectory.numChannels = bleChannels
//                    self.userTrajectory.scc = resultToReturn.scc
//                    self.userTrajectory.userBuilding = resultToReturn.building_name
//                    self.userTrajectory.userLevel = resultToReturn.level_name
//                    if (self.isActiveKf) {
//                        self.userTrajectory.userX = self.timeUpdateResult[0]
//                        self.userTrajectory.userY = self.timeUpdateResult[1]
//                        self.userTrajectory.userHeading = self.timeUpdateResult[2]
//                    } else {
//                        self.userTrajectory.userX = resultToReturn.x
//                        self.userTrajectory.userY = resultToReturn.y
//                        self.userTrajectory.userHeading = resultToReturn.absolute_heading
//                    }
//                    self.userTrajectory.userTuHeading = tuHeading
//                    self.userTrajectory.userPmSuccess = isPmSuccess
//                    
//                    self.userTrajectoryInfo.append(self.userTrajectory)
//                    self.accumulateLengthAndRemoveOldest(isDetermineSpot: self.isDetermineSpot, isUnknownTraj: self.isUnknownTraj, isMovePhase2To4: self.isMovePhase2To4, LENGTH_CONDITION: self.USER_TRAJECTORY_LENGTH)
//                }
            }
        }
    }
}
