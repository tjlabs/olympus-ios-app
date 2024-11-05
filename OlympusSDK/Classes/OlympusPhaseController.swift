import Foundation

public class OlympusPhaseController {
    let LOOKING_RECOGNITION_LENGTH: Int = 5
    
    var PHASE3_LENGTH_THRESHOLD_PDR: Double = 30
    var PHASE2_LENGTH_THRESHOLD_PDR: Double = 20
    
    var PHASE3_LENGTH_THRESHOLD_DR: Double = 60
    var PHASE2_LENGTH_THRESHOLD_DR: Double = 50
    
    public var phase2BadCount: Int = 0
    var phase2count: Int = 0
    var phase3count: Int = 0
    
    private var phaseObserver: Any!
    public var PHASE: Int = 1
    
    init() {
        self.notificationCenterAddObserver()
        self.PHASE2_LENGTH_THRESHOLD_PDR = self.PHASE3_LENGTH_THRESHOLD_PDR - Double(OlympusConstants.PDR_LENGTH_MARGIN)
        self.PHASE2_LENGTH_THRESHOLD_DR = self.PHASE3_LENGTH_THRESHOLD_DR - Double(OlympusConstants.DR_LENGTH_MARGIN)
    }
    
    deinit {
        self.notificationCenterRemoveObserver()
    }
    
    public func initialize() {
        self.phase2BadCount = 0
        self.phase2count = 0
        self.phase3count = 0
        self.PHASE = 1
    }
    
    public func setPhaseLengthParam(lengthConditionPdr: Double, lengthConditionDr: Double) {
        self.PHASE3_LENGTH_THRESHOLD_PDR = lengthConditionPdr
        self.PHASE3_LENGTH_THRESHOLD_DR = lengthConditionDr
        
        self.PHASE2_LENGTH_THRESHOLD_PDR = self.PHASE3_LENGTH_THRESHOLD_PDR - Double(OlympusConstants.PDR_LENGTH_MARGIN)
        self.PHASE2_LENGTH_THRESHOLD_DR = self.PHASE3_LENGTH_THRESHOLD_DR - Double(OlympusConstants.DR_LENGTH_MARGIN)
    }
    
    public func setPhase2BadCount(value: Int) {
        self.phase2BadCount = value
    }
     
    public func phase1control(serverResult: FineLocationTrackingFromServer, mode: String) -> Int {
        var phase: Int = 0
        
        let building_name = serverResult.building_name
        let level_name = serverResult.level_name
        let scc = serverResult.scc
        
        if (building_name != "" && level_name != "") {
            if (scc >= OlympusConstants.PHASE_BECOME3_SCC) {
                phase = 3
            } else {
                phase = 1
            }
        }
        
        return phase
    }
    
    public func phaseControlInStable(serverResult: FineLocationTrackingFromServer, mode: String, inputPhase: Int) -> Int {
        var phaseBreakSCC = OlympusConstants.PHASE_BREAK_SCC_DR
        if (mode == OlympusConstants.MODE_PDR) {
            phaseBreakSCC = OlympusConstants.PHASE_BREAK_SCC_PDR
        }
        var phase: Int = inputPhase
        
        let scc = serverResult.scc
        
        if (scc < phaseBreakSCC) {
            phase = 1
        } else if (serverResult.x == 0 && serverResult.y == 0) {
            phase = 1
        }
        
        return phase
    }
    
    
    public func controlPhase(serverResultArray: [FineLocationTrackingFromServer], drBuffer: [UnitDRInfo], UVD_INTERVAL: Int, TRAJ_LENGTH: Double, INDEX_THRESHOLD: Int, inputPhase: Int, inputTrajType: TrajType, mode: String, isVenusMode: Bool) -> (Int, Bool) {
        var phaseBreakSCC = OlympusConstants.PHASE_BREAK_SCC_DR
        if (mode == OlympusConstants.MODE_PDR) {
            phaseBreakSCC = OlympusConstants.PHASE_BREAK_SCC_PDR
        }
        
        var phase: Int = 0
        var isPhaseBreak: Bool = false
        if (isVenusMode) {
            phase = 1
            return (phase, isPhaseBreak)
        }
        
        let currentResult: FineLocationTrackingFromServer = serverResultArray[serverResultArray.count-1]
        switch (inputPhase) {
        case 0:
            phase = self.phase1control(serverResult: currentResult, mode: mode)
        case 1:
            phase = self.phase1control(serverResult: currentResult, mode: mode)
        case 2:
            phase = self.checkScResultConnectionForStable(inputPhase: inputPhase, serverResultArray: serverResultArray, drBuffer: drBuffer, inputTrajType: inputTrajType, UVD_INTERVAL: UVD_INTERVAL, TRAJ_LENGTH: TRAJ_LENGTH, INDEX_THRESHOLD: INDEX_THRESHOLD, mode: mode)
        case 3:
            if (currentResult.scc < phaseBreakSCC) {
                phase = 1
            } else {
                phase = self.checkScResultConnectionForStable(inputPhase: inputPhase, serverResultArray: serverResultArray, drBuffer: drBuffer, inputTrajType: inputTrajType, UVD_INTERVAL: UVD_INTERVAL, TRAJ_LENGTH: TRAJ_LENGTH, INDEX_THRESHOLD: INDEX_THRESHOLD, mode: mode)
            }
        case 4:
            phase = self.phaseControlInStable(serverResult: currentResult, mode: mode, inputPhase: 4)
        case 5:
            phase = self.phaseControlInStable(serverResult: currentResult, mode: mode, inputPhase: 6)
        case 6:
            phase = self.phaseControlInStable(serverResult: currentResult, mode: mode, inputPhase: 6)
        default:
            phase = 0
        }
        
        if (inputPhase >= 1 && phase < 2) {
            isPhaseBreak = true
        }
        
        self.PHASE = phase
        return (phase, isPhaseBreak)
    }
    
    public func checkScResultConnectionForStable(inputPhase: Int, serverResultArray: [FineLocationTrackingFromServer], drBuffer: [UnitDRInfo], inputTrajType: TrajType, UVD_INTERVAL: Int, TRAJ_LENGTH: Double, INDEX_THRESHOLD: Int, mode: String) -> Int {
        var phase: Int = inputPhase
        
        // Conditions //
        var sccCondition: Double = 0.5
        var isPoolChannel: Bool = false
        let indexCondition: Int = Int(Double(INDEX_THRESHOLD)*2)
        if (inputPhase == OlympusConstants.PHASE_2) {
            sccCondition = 0.5
        }
        var pathType: Int = 1
        var distanceCondition: Double = 15
        var headingCondition: Double = 30
        if (mode == OlympusConstants.MODE_PDR) {
            pathType = 0
            distanceCondition = 3
            headingCondition = 5
        }
        
        // Check Phase
        if (serverResultArray.count < 2) {
            return phase
        } else {
            let currentResult: FineLocationTrackingFromServer = serverResultArray[serverResultArray.count-1]
            let previousResult: FineLocationTrackingFromServer = serverResultArray[serverResultArray.count-2]
            if (currentResult.scc < sccCondition) {
                return phase
            } else if (previousResult.index == 0 || currentResult.index == 0) {
//                print(getLocalTimeString() + " , (Olympus) Check Phase3->6: preIndex = \(previousResult.index) // curIndex = \(currentResult.index)")
                return phase
            } else if (currentResult.cumulative_length < OlympusConstants.STABLE_ENTER_LENGTH) {
//                print(getLocalTimeString() + " , (Olympus) Check Phase3->6 : cumulative_length = \(currentResult.cumulative_length) // STABLE_ENTER_LENGTH = \(OlympusConstants.STABLE_ENTER_LENGTH)")
                return phase
            } else if (inputTrajType == .PDR_IN_PHASE3_NO_MAJOR_DIR) {
                return phase
            } else {
                if (inputPhase != 2) {
                    isPoolChannel = !currentResult.channel_condition && !previousResult.channel_condition
                }
                if (isPoolChannel) {
                    return phase
                } else {
                    if (currentResult.index - previousResult.index) > indexCondition {
//                        print(getLocalTimeString() + " , (Olympus) Check Phase3->6 : preIndex = \(previousResult.index) // curIndex = \(currentResult.index) // indexCondition = \(indexCondition)")
                        return phase
                    } else if (currentResult.index <= previousResult.index) {
//                        print(getLocalTimeString() + " , (Olympus) Check Phase3->6 : cur <= pre // preIndex = \(previousResult.index) // curIndex = \(currentResult.index)")
                        return phase
                    } else {
                        var drBufferStartIndex: Int = 0
                        var drBufferEndIndex: Int = 0
                        var headingCompensation: Double = 0
                        for i in 0..<drBuffer.count {
                            if drBuffer[i].index == previousResult.index {
                                drBufferStartIndex = i
                                headingCompensation = previousResult.absolute_heading -  drBuffer[i].heading
                            }
                            
                            if drBuffer[i].index == currentResult.index {
                                drBufferEndIndex = i
                            }
                        }

                        let previousPmResult = OlympusPathMatchingCalculator.shared.pathMatching(building: previousResult.building_name, level: previousResult.level_name, x: previousResult.x, y: previousResult.y, heading: previousResult.absolute_heading, HEADING_RANGE: OlympusConstants.HEADING_RANGE, isUseHeading: false, pathType: pathType, PADDING_VALUES: OlympusConstants.PADDING_VALUES)
                        let currentPmResult = OlympusPathMatchingCalculator.shared.pathMatching(building: currentResult.building_name, level: currentResult.level_name, x: currentResult.x, y: currentResult.y, heading: currentResult.absolute_heading, HEADING_RANGE: OlympusConstants.HEADING_RANGE, isUseHeading: false, pathType: pathType, PADDING_VALUES: OlympusConstants.PADDING_VALUES)
                        
                        var propagatedXyh: [Double] = [previousPmResult.xyhs[0], previousPmResult.xyhs[1], previousPmResult.xyhs[2]]
                        for i in drBufferStartIndex..<drBufferEndIndex {
                            let length = drBuffer[i].length
                            let heading = drBuffer[i].heading + headingCompensation
                            let dx = length*cos(heading*OlympusConstants.D2R)
                            let dy = length*sin(heading*OlympusConstants.D2R)
                             
                            propagatedXyh[0] += dx
                            propagatedXyh[1] += dy
                        }
                        let dh = drBuffer[drBufferEndIndex].heading - drBuffer[drBufferStartIndex].heading
                        propagatedXyh[2] += dh
                        propagatedXyh[2] = compensateHeading(heading: propagatedXyh[2])
                        
                        let pathMatchingResult = OlympusPathMatchingCalculator.shared.pathMatching(building: currentResult.building_name, level: currentResult.level_name, x: propagatedXyh[0], y: propagatedXyh[1], heading: propagatedXyh[2], HEADING_RANGE: OlympusConstants.HEADING_RANGE, isUseHeading: false, pathType: pathType, PADDING_VALUES: OlympusConstants.PADDING_VALUES)
                        let diffX = abs(pathMatchingResult.xyhs[0] - currentPmResult.xyhs[0])
                        let diffY = abs(pathMatchingResult.xyhs[1] - currentPmResult.xyhs[1])
                        let currentResultHeading = compensateHeading(heading: currentPmResult.xyhs[2])
                        var diffH = abs(pathMatchingResult.xyhs[2] - currentResultHeading)
                        if (diffH > 270) {
                            diffH = 360 - diffH
                        }
                        
                        let rendezvousDistance = sqrt(diffX*diffX + diffY*diffY)
                        if (rendezvousDistance <= distanceCondition) && diffH <= headingCondition {
                            phase = OlympusConstants.PHASE_6
                        }
                        return phase
                    }
                }
            }
        }
    }
    
    func notificationCenterAddObserver() {
        self.phaseObserver = NotificationCenter.default.addObserver(self, selector: #selector(onDidReceiveNotification), name: .phaseChanged, object: nil)
    }
    
    func notificationCenterRemoveObserver() {
        NotificationCenter.default.removeObserver(self.phaseObserver)
    }
    
    @objc func onDidReceiveNotification(_ notification: Notification) {
        if let intValue = notification.userInfo?["phase"] as? Int {
//            print(getLocalTimeString() + " , (Olympus) Phase Controller : Phase Become \(intValue)")
            self.PHASE = intValue
        } else {
            self.PHASE = OlympusConstants.PHASE_1
        }
    }
}
