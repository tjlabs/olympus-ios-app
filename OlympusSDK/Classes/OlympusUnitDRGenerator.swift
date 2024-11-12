import Foundation

public class OlympusUnitDRGenerator: NSObject {
    
    public override init() { }
    
    public var unitMode = String()
    
    public let MF = OlympusMathFunctions()
    public let unitAttitudeEstimator = OlympusUnitAttitudeEstimator()
    public let unitStatusEstimator = OlympusUnitStatusEstimator()
    public let pdrDistanceEstimator = OlympusPDRDistanceEstimator()
    public let drDistanceEstimator = OlympusDRDistanceEstimator()
//    public let stopDetector = OlympusStopDetector()
    
    var pdrQueue = LinkedList<DistanceInfo>()
    var drQueue = LinkedList<DistanceInfo>()
    var autoMode: Int = 0
    var lastModeChangedTime: Double = 0
    var lastStepChangedTime: Double = 0
    var routeTrackFinishedTime: Double = 0
    var lastHighRfSccTime: Double = 0
    var isPdrMode: Bool = false
    var trackIsPdrMode: Bool = true
    
    var normalStepTime: Double = 0
    var unitIndexAuto = 0
    
    var preRoll: Double = 0
    var prePitch: Double = 0
    
    public var isInEntranceLevel: Bool = false
    public var isStartRoutTrack: Bool = false
    public var isBackground: Bool = false
    public var rflow: Double = 0
    public var rflowForVelocity: Double = 0
    public var rflowForAutoMode: Double = 0
    
    public var isSufficientRfdBuffer: Bool = false
    public var isSufficientRfdVelocityBuffer: Bool = false
    public var isSufficientRfdAutoMode: Bool = false

    
    public func setMode(mode: String) {
        unitMode = mode
    }
    
    public func generateDRInfo(sensorData: OlympusSensorData) -> UnitDRInfo {
        if (unitMode != OlympusConstants.MODE_PDR && unitMode != OlympusConstants.MODE_DR && unitMode != OlympusConstants.MODE_AUTO) {
            print(getLocalTimeString() + " , (Olympus) uniMode is forcibly set to auto (\(unitMode) - > MODR_AUTO)")
            unitMode = OlympusConstants.MODE_AUTO
        }
        
        let currentTime = getCurrentTimeInMillisecondsDouble()
        
        var curAttitudeDr = Attitude(Roll: 0, Pitch: 0, Yaw: 0)
        var curAttitudePdr = Attitude(Roll: 0, Pitch: 0, Yaw: 0)
        var curAttitudeAuto = Attitude(Roll: 0, Pitch: 0, Yaw: 0)
        
        var unitDistanceDr = UnitDistance()
        var unitDistancePdr = UnitDistance()
        var unitDistanceAuto = UnitDistance()
        var unitStop = UnitDistance()
        
        switch (unitMode) {
        case OlympusConstants.MODE_PDR:
            pdrDistanceEstimator.isAutoMode(autoMode: false)
            pdrDistanceEstimator.normalStepCountSet(normalStepCountSet: pdrDistanceEstimator.normalStepCountSetting)
            unitDistancePdr = pdrDistanceEstimator.estimateDistanceInfo(time: currentTime, sensorData: sensorData)
            self.autoMode = 0
            
            var sensorAtt = sensorData.att
            
            if (sensorAtt[0].isNaN) {
                sensorAtt[0] = preRoll
            } else {
                preRoll = sensorAtt[0]
            }

            if (sensorAtt[1].isNaN) {
                sensorAtt[1] = prePitch
            } else {
                prePitch = sensorAtt[1]
            }
            
            curAttitudePdr = unitAttitudeEstimator.estimateAtt(time: currentTime, acc: sensorData.acc, gyro: sensorData.gyro, rotMatrix: sensorData.rotationMatrix)
            
            let unitStatus = unitStatusEstimator.estimateStatus(Attitude: curAttitudePdr, isIndexChanged: unitDistancePdr.isIndexChanged, unitMode: unitMode)
            if (!unitStatus && unitMode == OlympusConstants.MODE_PDR) {
                unitDistancePdr.length = OlympusConstants.STEP_LENGTH_RANGE_TOP
            }
            
            let heading = MF.radian2degree(radian: curAttitudePdr.Yaw)
            
            return UnitDRInfo(time: currentTime, index: unitDistancePdr.index, length: unitDistancePdr.length, heading: heading, velocity: unitDistancePdr.velocity, lookingFlag: unitStatus, isIndexChanged: unitDistancePdr.isIndexChanged, autoMode: 0)
        case OlympusConstants.MODE_DR:
            unitDistanceDr = drDistanceEstimator.estimateDistanceInfo(time: currentTime, sensorData: sensorData, isStopDetect: false)
            self.autoMode = 1
            curAttitudeDr = unitAttitudeEstimator.estimateAtt(time: currentTime, acc: sensorData.acc, gyro: sensorData.gyro, rotMatrix: sensorData.rotationMatrix)
            
            let heading = MF.radian2degree(radian: curAttitudeDr.Yaw)
            
            let unitStatus = unitStatusEstimator.estimateStatus(Attitude: curAttitudeDr, isIndexChanged: unitDistanceDr.isIndexChanged, unitMode: unitMode)
            return UnitDRInfo(time: currentTime, index: unitDistanceDr.index, length: unitDistanceDr.length, heading: heading, velocity: unitDistanceDr.velocity, lookingFlag: unitStatus, isIndexChanged: unitDistanceDr.isIndexChanged, autoMode: 0)
        case OlympusConstants.MODE_AUTO:
            pdrDistanceEstimator.isAutoMode(autoMode: true)
//            unitStop = stopDetector.estimateDistanceInfo(time: currentTime, sensorData: sensorData)
//            let isStopDetect = (self.isInEntranceLevel || self.isStartRoutTrack) ? false : unitStop.isIndexChanged
            unitDistancePdr = pdrDistanceEstimator.estimateDistanceInfo(time: currentTime, sensorData: sensorData)
            unitDistanceDr = drDistanceEstimator.estimateDistanceInfo(time: currentTime, sensorData: sensorData, isStopDetect: false)
            
            if (self.isSufficientRfdBuffer) {
                if (self.isPdrMode && self.rflow >= OlympusConstants.RF_SC_THRESHOLD_PDR) {
                    self.lastHighRfSccTime = currentTime
                }
            }
            
            if (self.isBackground) {
                self.lastModeChangedTime = currentTime
            }
            
            let isNormalStep = pdrDistanceEstimator.normalStepCountFlag
            if (currentTime - lastModeChangedTime >= OlympusConstants.MODE_CHANGE_TIME_CONDITION) {
                if (!self.isPdrMode && isNormalStep) {
                    // 현재 DR 모드
                    if (isNormalStep) {
                        self.isPdrMode = true
                        self.lastModeChangedTime = currentTime
                    }
                } else {
                    // 현재 PDR 모드
                    let diffTime = currentTime - self.lastStepChangedTime
                    if (self.isSufficientRfdAutoMode && diffTime >= OlympusConstants.MODE_CHANGE_TIME_CONDITION) {
                        if (self.rflowForAutoMode < OlympusConstants.MODE_CHANGE_RFLOW_TIME_OVER) {
                            self.isPdrMode = false
                            self.lastModeChangedTime = currentTime
                        }
                    } else if (self.isSufficientRfdAutoMode) {
                        if (self.rflowForAutoMode < OlympusConstants.MODE_CHANGE_RFLOW_FORCE) {
                            self.isPdrMode = false
                            self.lastModeChangedTime = currentTime
                        }
                    }
                }
                
                let diffRouteTrackTime = currentTime - self.routeTrackFinishedTime
                if (self.isInEntranceLevel || self.isStartRoutTrack) {
                    self.isPdrMode = false
                    self.lastModeChangedTime = currentTime
                } else if diffRouteTrackTime > 0 && diffRouteTrackTime < OlympusConstants.MODE_CHANGE_TIME_AFTER_ROUTE_TRACK {
//                    print(getLocalTimeString() + " , (Olympus) Mode Change : cannot change mode // diffRouteTrackTime = \(diffRouteTrackTime)")
                    self.isPdrMode = false
                    self.lastModeChangedTime = currentTime
                }
            }
            
            if (self.isPdrMode) {
                // PDR 가능 영역
                if (unitDistancePdr.isIndexChanged) {
                    self.lastStepChangedTime = currentTime
                    unitIndexAuto += 1
                }
                unitDistanceAuto = unitDistancePdr
                self.autoMode = 0
                normalStepTime = currentTime
            } else {
                // PDR 불가능 영역
                unitDistanceAuto = unitDistanceDr
                if (unitDistanceDr.isIndexChanged) {
                    unitIndexAuto += 1
                }
                self.autoMode = 1
            }
            
            if (self.isPdrMode != self.trackIsPdrMode) {
                if (self.autoMode == 0) {
                    pdrDistanceEstimator.setModeDrToPdr(isModeDrToPdr: true)
                    pdrDistanceEstimator.normalStepCountSet(normalStepCountSet: OlympusConstants.NORMAL_STEP_LOSS_CHECK_SIZE-1)
                } else {
                    pdrDistanceEstimator.setModeDrToPdr(isModeDrToPdr: false)
                    pdrDistanceEstimator.normalStepCountSet(normalStepCountSet: OlympusConstants.MODE_AUTO_NORMAL_STEP_COUNT_SET)
                }
            }
            self.trackIsPdrMode = self.isPdrMode
            
            var sensorAtt = sensorData.att
            if (sensorAtt[0].isNaN) {
                sensorAtt[0] = preRoll
            } else {
                preRoll = sensorAtt[0]
            }

            if (sensorAtt[1].isNaN) {
                sensorAtt[1] = prePitch
            } else {
                prePitch = sensorAtt[1]
            }
            
            curAttitudeAuto = unitAttitudeEstimator.estimateAtt(time: currentTime, acc: sensorData.acc, gyro: sensorData.gyro, rotMatrix: sensorData.rotationMatrix)
            let headingAuto = MF.radian2degree(radian: curAttitudeAuto.Yaw)
            
            let unitStatusPdr = unitStatusEstimator.estimateStatus(Attitude: curAttitudeAuto, isIndexChanged: unitDistancePdr.isIndexChanged, unitMode: OlympusConstants.MODE_PDR)
            let unitStatusDr = unitStatusEstimator.estimateStatus(Attitude: curAttitudeDr, isIndexChanged: unitDistanceDr.isIndexChanged, unitMode: OlympusConstants.MODE_DR)
            
            if (self.autoMode == 0) {
                return UnitDRInfo(time: currentTime, index: unitIndexAuto, length: unitDistanceAuto.length, heading: headingAuto, velocity: unitDistanceAuto.velocity, lookingFlag: unitStatusPdr, isIndexChanged: unitDistanceAuto.isIndexChanged, autoMode: self.autoMode)
            } else {
                return UnitDRInfo(time: currentTime, index: unitIndexAuto, length: unitDistanceAuto.length, heading: headingAuto, velocity: unitDistanceAuto.velocity, lookingFlag: unitStatusDr, isIndexChanged: unitDistanceAuto.isIndexChanged, autoMode: self.autoMode)
            }
        default:
            // (Default : DR Mode)
            unitDistanceDr = drDistanceEstimator.estimateDistanceInfo(time: currentTime, sensorData: sensorData, isStopDetect: false)
            self.autoMode = 1
            curAttitudeDr = unitAttitudeEstimator.estimateAtt(time: currentTime, acc: sensorData.acc, gyro: sensorData.gyro, rotMatrix: sensorData.rotationMatrix)
            
            let heading = MF.radian2degree(radian: curAttitudeDr.Yaw)
            
            let unitStatus = unitStatusEstimator.estimateStatus(Attitude: curAttitudeDr, isIndexChanged: unitDistanceDr.isIndexChanged, unitMode: unitMode)
            return UnitDRInfo(time: currentTime, index: unitDistanceDr.index, length: unitDistanceDr.length, heading: heading, velocity: unitDistanceDr.velocity, lookingFlag: unitStatus, isIndexChanged: unitDistanceDr.isIndexChanged, autoMode: 0)
        }
    }
    
    public func updateDrQueue(data: DistanceInfo) {
        if (drQueue.count >= Int(OlympusConstants.MODE_QUEUE_SIZE)) {
            drQueue.pop()
        }
        drQueue.append(data)
    }
    
    public func updatePdrQueue(data: DistanceInfo) {
        if (pdrQueue.count >= Int(OlympusConstants.MODE_QUEUE_SIZE)) {
            pdrQueue.pop()
        }
        pdrQueue.append(data)
    }
    
    public func setScCompensation(value: Double) {
        self.drDistanceEstimator.scCompensation = value
    }
    
    public func setVelocityScale(scale: Double) {
        self.drDistanceEstimator.velocityScale = scale
    }
    
    public func setEntranceVelocityScale(scale: Double) {
        self.drDistanceEstimator.entranceVelocityScale = scale
    }
    
    public func setIsInEntranceLevel (flag: Bool) {
        self.isInEntranceLevel = flag
    }
    
    public func setRflow(rflow: Double, rflowForVelocity: Double, rflowForAutoMode: Double, isSufficient: Bool, isSufficientForVelocity: Bool, isSufficientForAutoMode: Bool) {
        self.rflow = rflow
        self.rflowForVelocity = rflowForVelocity
        self.rflowForAutoMode = rflowForAutoMode
        
        self.isSufficientRfdBuffer = isSufficient
        self.isSufficientRfdVelocityBuffer = isSufficientForVelocity
        self.isSufficientRfdAutoMode = isSufficientForAutoMode
        
        self.drDistanceEstimator.setRflow(rflow: rflow, rflowForVelocity: rflowForVelocity, rflowForAutoMode: rflowForAutoMode, isSufficient: isSufficient, isSufficientForVelocity: isSufficientForVelocity, isSufficientForAutoMode: isSufficientForAutoMode)
    }
    
    public func setIsStartRouteTrack(isStartRoutTrack: Bool) {
        self.isStartRoutTrack = isStartRoutTrack
        self.drDistanceEstimator.setIsStartRouteTrack(isStartRouteTrack: isStartRoutTrack)
    }
    
    public func setIsBackground(isBackground: Bool) {
        self.isBackground = isBackground
    }
    
    public func setRouteTrackFinishedTime(value: Double) {
        self.routeTrackFinishedTime = value
    }
    
    public func calAccBias(unitDRInfoBuffer: [UnitDRInfo], resultIndex: Int, scCompensation: Double) {
        drDistanceEstimator.calAccBias(unitDRInfoBuffer: unitDRInfoBuffer, resultIndex: resultIndex, scCompensation: scCompensation)
    }
}
