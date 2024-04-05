import Foundation

public class OlympusPhaseController {
    let LOOKING_RECOGNITION_LENGTH: Int = 5
    
    var PHASE3_LENGTH_CONDITION_PDR: Double = 30
    var PHASE2_LENGTH_CONDITION_PDR: Double = 20
    
    var PHASE3_LENGTH_CONDITION_DR: Double = 60
    var PHASE2_LENGTH_CONDITION_DR: Double = 50
    var TRAJ_BIAS: Double = 10
    
    var phase2count: Int = 0
    var phase3count: Int = 0
    
//    var pmCalculator = PathMatchingCalculator()
    
    init() {
        self.PHASE2_LENGTH_CONDITION_PDR = self.PHASE3_LENGTH_CONDITION_PDR-self.TRAJ_BIAS
        self.PHASE2_LENGTH_CONDITION_DR = self.PHASE3_LENGTH_CONDITION_DR-self.TRAJ_BIAS
    }
    
    public func setPhaseLengthParam(lengthConditionPdr: Double, lengthConditionDr: Double) {
        self.PHASE3_LENGTH_CONDITION_PDR = lengthConditionPdr
        self.PHASE3_LENGTH_CONDITION_DR = lengthConditionDr
        
        self.PHASE2_LENGTH_CONDITION_PDR = self.PHASE3_LENGTH_CONDITION_PDR - self.TRAJ_BIAS
        self.PHASE2_LENGTH_CONDITION_DR = self.PHASE3_LENGTH_CONDITION_DR - self.TRAJ_BIAS
    }
    
//    public func controlJupiterPhase(serverResult: FineLocationTrackingFromServer, inputPhase: Int, mode: String, isVenusMode: Bool) -> (Int, Bool) {
//        var phase: Int = 0
//        var isPhaseBreak: Bool = false
//        
//        if (isVenusMode) {
//            phase = 1
//            return (phase, isPhaseBreak)
//        }
//        
//        switch (inputPhase) {
//        case 0:
//            phase = self.phase1control(serverResult: serverResult, mode: mode)
//        case 1:
//            phase = self.phase1control(serverResult: serverResult, mode: mode)
//        case 2:
//            phase = self.phase2control(serverResult: serverResult, mode: mode)
//        case 3:
//            phase = self.phase3control(serverResult: serverResult, mode: mode)
//        case 4:
//            phase = self.phase4control(serverResult: serverResult, mode: mode)
//        default:
//            phase = 0
//        }
//        
//        if (inputPhase >= 1 && phase < 2) {
//            isPhaseBreak = true
//        }
//        
//        return (phase, isPhaseBreak)
//    }
//    
//    public func phase1control(serverResult: FineLocationTrackingFromServer, mode: String) -> Int {
//        var phase: Int = 0
//        
//        let building_name = serverResult.building_name
//        let level_name = serverResult.level_name
//        let scc = serverResult.scc
//        
//        if (building_name != "" && level_name != "") {
//            if (scc >= 0.62) {
//                phase = 3
//            } else {
//                phase = 1
//            }
//        }
//        
//        return phase
//    }
//    
//    public func phase2control(serverResult: FineLocationTrackingFromServer, mode: String) -> Int {
//        var phase: Int = 2
//        
//        let building_name = serverResult.building_name
//        let level_name = serverResult.level_name
//        let scc = serverResult.scc
//        let cumulative_length = serverResult.cumulative_length
//        let channel_condition = serverResult.channel_condition
//        
//        if (building_name != "" && level_name != "") {
//            if (scc >= 0.55 && channel_condition && cumulative_length >= self.PHASE2_LENGTH_CONDITION_DR) {
//                self.phase2count += 1
//                if (self.phase2count >= 2) {
//                    self.phase2count = 0
//                    phase = 4
//                }
//            } else {
//                self.phase2count = 0
//            }
//        } else {
//            phase = 1
//            self.phase2count = 0
//        }
//        return phase
//    }
//    
//    public func phase3control(serverResult: FineLocationTrackingFromServer, mode: String) -> Int {
//        var phase: Int = 3
//        
//        let scc = serverResult.scc
//
//        let cumulative_length = serverResult.cumulative_length
//        let channel_condition = serverResult.channel_condition
//        
//        var length_condition: Double = 0
//        if (mode == "pdr") {
//            length_condition = self.PHASE3_LENGTH_CONDITION_PDR
//        } else {
//            length_condition = self.PHASE3_LENGTH_CONDITION_DR
//        }
//        
//        if (scc < 0.45) {
//            phase = 1
//            self.phase3count = 0
//        } else if (scc >= 0.6 && scc < 0.62 && cumulative_length >= length_condition && channel_condition) {
//            self.phase3count += 1
//            if (self.phase3count >= 4) {
//                self.phase3count = 0
//                phase = 4
//            }
//        } else if (scc >= 0.62 && scc < 0.65 && cumulative_length >= length_condition && channel_condition) {
//            self.phase3count += 1
//            if (self.phase3count >= 3) {
//                self.phase3count = 0
//                phase = 4
//            }
//        } else if (scc >= 0.65 && cumulative_length >= length_condition && channel_condition) {
//            self.phase3count += 1
//            if (self.phase3count >= 2) {
//                self.phase3count = 0
//                phase = 4
//            }
//        } else {
//            self.phase3count = 0
//        }
//        
//        return phase
//    }
//    
//    public func phase4control(serverResult: FineLocationTrackingFromServer, mode: String) -> Int {
//        var phase: Int = 4
//        
//        let scc = serverResult.scc
//        
//        if (scc < 0.45) {
//            phase = 1
//        }
//        
//        return phase
//    }
//    
//    public func isNotLooking(inputUserTrajectory: [TrajectoryInfo]) -> Bool {
//        var isNotLooking: Bool = false
//        
//        if (inputUserTrajectory.count >= LOOKING_RECOGNITION_LENGTH) {
//            let recentDrInfo = getTrajectoryFromLast(from: inputUserTrajectory, N: LOOKING_RECOGNITION_LENGTH)
//            
//            var count: Int = 0
//            for i in 0..<LOOKING_RECOGNITION_LENGTH {
//                let lookingFlag = recentDrInfo[i].lookingFlag
//                if (!lookingFlag) {
//                    count += 1
//                }
//            }
//            
//            if (count >= LOOKING_RECOGNITION_LENGTH) {
//                isNotLooking = true
//            }
//        }
//        
//        return isNotLooking
//    }
//    
//    public func phaseInterrupt(inputPhase: Int, inputUserTrajectory: [TrajectoryInfo]) -> (Bool, Int) {
//        var isInterrupt: Bool = false
//        var phase: Int = inputPhase
//        
//        if (inputUserTrajectory.isEmpty) {
//            isInterrupt = true
//            phase = 0
//        }
//        
//        if (self.isNotLooking(inputUserTrajectory: inputUserTrajectory)) {
//            isInterrupt = true
//            phase = 1
//        }
//        
//        return (isInterrupt, phase)
//    }
//    
//    public func controlPhase(serverResultArray: [FineLocationTrackingFromServer], drBuffer: [UnitDRInfo], UVD_INTERVAL: Int, TRAJ_LENGTH: Double, inputPhase: Int, mode: String, isVenusMode: Bool) -> (Int, Bool) {
//        var phase: Int = 0
//        var isPhaseBreak: Bool = false
//        
//        if (isVenusMode) {
//            phase = 1
//            return (phase, isPhaseBreak)
//        }
//        
//        let currentResult: FineLocationTrackingFromServer = serverResultArray[serverResultArray.count-1]
//        switch (inputPhase) {
//        case 0:
//            phase = self.phase1control(serverResult: currentResult, mode: mode)
//        case 1:
//            phase = self.phase1control(serverResult: currentResult, mode: mode)
//        case 2:
//            phase = self.checkScResultConnectionForPhase4(inputPhase: inputPhase, serverResultArray: serverResultArray, drBuffer: drBuffer, UVD_INTERVAL: UVD_INTERVAL, TRAJ_LENGTH: TRAJ_LENGTH, mode: mode)
//        case 3:
//            if (currentResult.scc < 0.45) {
//                phase = 1
//            } else {
//                phase = self.checkScResultConnectionForPhase4(inputPhase: inputPhase, serverResultArray: serverResultArray, drBuffer: drBuffer, UVD_INTERVAL: UVD_INTERVAL, TRAJ_LENGTH: TRAJ_LENGTH, mode: mode)
//            }
//        case 4:
//            phase = self.phase4control(serverResult: currentResult, mode: mode)
//        default:
//            phase = 0
//        }
//        
//        if (inputPhase >= 1 && phase < 2) {
//            isPhaseBreak = true
//        }
//        
//        return (phase, isPhaseBreak)
//    }
//    
//    public func checkScResultConnectionForPhase4(inputPhase: Int, serverResultArray: [FineLocationTrackingFromServer], drBuffer: [UnitDRInfo], UVD_INTERVAL: Int, TRAJ_LENGTH: Double, mode: String) -> Int {
//        var phase: Int = inputPhase
//        
//        // Conditions //
//        var sccCondition: Double = 0.5
//        var isPoolChannel: Bool = false
//        let indexCondition: Int = Int(Double(UVD_INTERVAL)*1.5)
//        if (inputPhase == 2) {
//            sccCondition = 0.5
//        }
//        var pathType: Int = 1
//        var distanceCondition: Double = 15
//        var headingCondition: Double = 30
//        if (mode == "pdr") {
//            pathType = 0
//            distanceCondition = 2
//            headingCondition = 10
//        }
//        
//        // Check Phase
//        if (serverResultArray.count < 2) {
//            return phase
//        } else {
//            let currentResult: FineLocationTrackingFromServer = serverResultArray[serverResultArray.count-1]
//            let previousResult: FineLocationTrackingFromServer = serverResultArray[serverResultArray.count-2]
//            if (currentResult.scc < sccCondition) {
//                return phase
//            } else if (previousResult.index == 0 || currentResult.index == 0) {
//                return phase
//            } else if (currentResult.cumulative_length < (TRAJ_LENGTH/2)) {
//                return phase
//            } else {
//                if (inputPhase != 2) {
//                    isPoolChannel = !currentResult.channel_condition && !previousResult.channel_condition
//                }
//                if (isPoolChannel) {
//                    return phase
//                } else {
//                    if (currentResult.index - previousResult.index) > indexCondition {
//                        return phase
//                    } else if (currentResult.index <= previousResult.index) {
//                        return phase
//                    } else {
//                        var drBufferStartIndex: Int = 0
//                        var drBufferEndIndex: Int = 0
//                        var headingCompensation: Double = 0
//                        for i in 0..<drBuffer.count {
//                            if drBuffer[i].index == previousResult.index {
//                                drBufferStartIndex = i
//                                headingCompensation = previousResult.absolute_heading -  drBuffer[i].heading
//                            }
//                            
//                            if drBuffer[i].index == currentResult.index {
//                                drBufferEndIndex = i
//                            }
//                        }
//                        let previousPmResult = pmCalculator.pathMatching(building: previousResult.building_name, level: previousResult.level_name, x: previousResult.x, y: previousResult.y, heading: previousResult.absolute_heading, isPast: false, HEADING_RANGE: HEADING_RANGE, isUseHeading: false, pathType: pathType, range: 10)
//                        let currentPmResult = pmCalculator.pathMatching(building: currentResult.building_name, level: currentResult.level_name, x: currentResult.x, y: currentResult.y, heading: currentResult.absolute_heading, isPast: false, HEADING_RANGE: HEADING_RANGE, isUseHeading: false, pathType: pathType, range: 10)
//                        
//                        var propagatedXyh: [Double] = [previousPmResult.xyhs[0], previousPmResult.xyhs[1], previousPmResult.xyhs[2]]
//                        for i in drBufferStartIndex..<drBufferEndIndex {
//                            let length = drBuffer[i].length
//                            let heading = drBuffer[i].heading + headingCompensation
//                            let dx = length*cos(heading*D2R)
//                            let dy = length*sin(heading*D2R)
//                             
//                            propagatedXyh[0] += dx
//                            propagatedXyh[1] += dy
//                        }
//                        let dh = drBuffer[drBufferEndIndex].heading - drBuffer[drBufferStartIndex].heading
//                        propagatedXyh[2] += dh
//                        propagatedXyh[2] = compensateHeading(heading: propagatedXyh[2])
//                        
//                        let pathMatchingResult = pmCalculator.pathMatching(building: currentResult.building_name, level: currentResult.level_name, x: propagatedXyh[0], y: propagatedXyh[1], heading: propagatedXyh[2], isPast: false, HEADING_RANGE: HEADING_RANGE, isUseHeading: false, pathType: pathType, range: 10)
//                        let diffX = abs(pathMatchingResult.xyhs[0] - currentPmResult.xyhs[0])
//                        let diffY = abs(pathMatchingResult.xyhs[1] - currentPmResult.xyhs[1])
//                        let currentResultHeading = compensateHeading(heading: currentPmResult.xyhs[2])
//                        var diffH = abs(pathMatchingResult.xyhs[2] - currentResultHeading)
//                        if (diffH > 270) {
//                            diffH = 360 - diffH
//                        }
//                        
//                        let rendezvousDistance = sqrt(diffX*diffX + diffY*diffY)
//                        if (rendezvousDistance <= distanceCondition) && diffH <= headingCondition {
//                            phase = 4
//                        }
//                        return phase
//                    }
//                }
//            }
//        }
//    }
}
