import Foundation

public class OlympusDRDistanceEstimator: NSObject {
    
    public override init() {
        
    }
    
    public let MF = OlympusMathFunctions()
    
    public var epoch = 0
    public var index = 0
    public var finalUnitResult = UnitDistance()
    public var output: [Float] = [0,0]
    
    public var accQueue = LinkedList<SensorAxisValue>()
    public var magQueue = LinkedList<SensorAxisValue>()
    public var navGyroZQueue = [Double]()
    public var accNormQueue = [Double]()
    public var magNormQueue = [Double]()
    public var magNormSmoothingQueue = [Double]()
    public var magNormVarQueue = [Double]()
    public var velocityQueue = [Double]()
    var accNormBuffer = [Double]()
    var gyroNormBuffer = [Double]()
    var drStateBuffer = [DrState]()
    
    public var mlpEpochCount: Double = 0
    public var featureExtractionCount: Double = 0
    
    public var preAccNormSmoothing: Double = 0
    public var preNavGyroZSmoothing: Double = 0
    public var preMagNormSmoothing: Double = 0
    public var preMagVarFeature: Double = 0
    public var preVelocitySmoothing: Double = 0
    
    public var velocityScale: Double = 1.0
    public var entranceVelocityScale: Double = 1.0
    public var scCompensation: Double = 1.0
    
    public var preTime: Double = 0
    public var velocityAcc: Double = 0
    public var distance: Double = 0
    
    var preRoll: Double = 0
    var prePitch: Double = 0
    
    public var rflow: Double = 0
    public var rflowForVelocity: Double = 0
    public var rflowForAutoMode: Double = 0
    public var isSufficientRfdBuffer: Bool = false
    public var isSufficientRfdVelocityBuffer: Bool = false
    public var isSufficientRfdAutoModeBuffer: Bool = false
    public var isStartRouteTrack: Bool = false
    
    public func argmax(array: [Float]) -> Int {
        let output1 = array[0]
        let output2 = array[1]
        
        if (output1 > output2){
            return 0
        } else {
            return 1
        }
    }
    
    public func estimateDistanceInfo(time: Double, sensorData: OlympusSensorData) -> UnitDistance {
        // feature extraction
        // ACC X, Y, Z, Norm Smoothing
        // Use y, z, norm variance (2sec)
        let acc = sensorData.acc
        let gyro = sensorData.gyro
        let mag = sensorData.mag
        
        var accRoll = MF.callRollUsingAcc(acc: acc)
        var accPitch = MF.callPitchUsingAcc(acc: acc)

        if (accRoll.isNaN) {
            accRoll = preRoll
        } else {
            preRoll = accRoll
        }

        if (accPitch.isNaN) {
            accPitch = prePitch
        } else {
            prePitch = accPitch
        }
        
        let accAttitude = Attitude(Roll: accRoll, Pitch: accPitch, Yaw: 0)
        let gyroNav = MF.transBody2Nav(att: accAttitude, data: gyro)[2]
        let gyroNavZ = abs(gyroNav)
        
        let accNorm = MF.l2Normalize(originalVector: sensorData.acc)
        let userAccNorm = accNorm - OlympusConstants.G
        let gyroNorm = MF.l2Normalize(originalVector: sensorData.gyro)
        let magNorm = MF.l2Normalize(originalVector: sensorData.mag)
        
        updateAccNormBuffer(value: userAccNorm)
        updateGyroNormBuffer(value: gyroNorm)
        let accRMS = calRMS(buffer: accNormBuffer)
        let gyroRMS = calRMS(buffer: gyroNormBuffer)
        let accVar = variance(accNormBuffer)
        let gyroVar = variance(gyroNormBuffer)
        
        if accRMS > OlympusConstants.ACC_STOP_THRESHOLD && accVar <= OlympusConstants.ACC_VAR_STOP_THRESHOLD && gyroVar <= OlympusConstants.GYRO_VAR_STOP_THRESHOLD {
            let curValue = accRMS
            let preValue = OlympusConstants.ACC_STOP_THRESHOLD
            let newValue = (curValue + preValue)*0.5
            OlympusConstants.setRmsStopThreshold(type: .ACC, value: newValue)
        }
        if gyroRMS > OlympusConstants.GYRO_STOP_THRESHOLD && accVar <= OlympusConstants.ACC_VAR_STOP_THRESHOLD && gyroVar <= OlympusConstants.GYRO_VAR_STOP_THRESHOLD {
            let curValue = gyroRMS
            let preValue = OlympusConstants.GYRO_STOP_THRESHOLD
            let newValue = (curValue + preValue)*0.5
            OlympusConstants.setRmsStopThreshold(type: .GYRO, value: newValue)
        }
        
        var temporalDrState: DrState = .UNKNOWN
        if accRMS <= OlympusConstants.ACC_STOP_THRESHOLD && gyroRMS <= OlympusConstants.GYRO_STOP_THRESHOLD && accVar <= OlympusConstants.ACC_VAR_STOP_THRESHOLD && gyroVar <= OlympusConstants.GYRO_VAR_STOP_THRESHOLD {
            temporalDrState = .STOP
        } else {
            temporalDrState = .MOVE
        }
        updateDrStateBuffer(value: temporalDrState)
//        let temporalDrState: DrState = accRMS > OlympusConstants.ACC_STOP_THRESHOLD || gyroRMS > OlympusConstants.GYRO_STOP_THRESHOLD ? .MOVE : .STOP
//        updateDrStateBuffer(value: temporalDrState)
        let drState = determineDrState(drStateBuffer: drStateBuffer)
//        let drState: DrState = .UNKNOWN
        
        // ----- Acc ----- //
        var accNormSmoothing: Double = 0
        if (accNormQueue.count == 0) {
            accNormSmoothing = accNorm
        } else if (featureExtractionCount < 5) {
            accNormSmoothing = MF.exponentialMovingAverage(preEMA: preAccNormSmoothing, curValue: accNorm, windowSize: accNormQueue.count)
        } else {
            accNormSmoothing = MF.exponentialMovingAverage(preEMA: preAccNormSmoothing, curValue: accNorm, windowSize: 5)
        }
        preAccNormSmoothing = accNormSmoothing
        updateAccNormQueue(data: accNormSmoothing)
        // --------------- //
        
        // ----- Gyro ----- //
        updateNavGyroZQueue(data: gyroNavZ)
        var navGyroZSmoothing: Double = 0
        if (magNormVarQueue.count == 0) {
            navGyroZSmoothing = gyroNavZ
        } else if (featureExtractionCount < OlympusConstants.FEATURE_EXTRACTION_SIZE) {
            navGyroZSmoothing = MF.exponentialMovingAverage(preEMA: preNavGyroZSmoothing, curValue: gyroNavZ, windowSize: navGyroZQueue.count)
        } else {
            navGyroZSmoothing = MF.exponentialMovingAverage(preEMA: preNavGyroZSmoothing, curValue: gyroNavZ, windowSize: Int(OlympusConstants.FEATURE_EXTRACTION_SIZE))
        }
        preNavGyroZSmoothing = navGyroZSmoothing
        // --------------- //
        
        // ----- Mag ------ //
        updateMagNormQueue(data: magNorm)
        var magNormSmooting: Double = 0
        if (featureExtractionCount == 0) {
            magNormSmooting = magNorm
        } else if (featureExtractionCount < 5) {
            magNormSmooting = MF.exponentialMovingAverage(preEMA: preMagNormSmoothing, curValue: magNorm, windowSize: magNormQueue.count)
        } else {
            magNormSmooting = MF.exponentialMovingAverage(preEMA: preMagNormSmoothing, curValue: magNorm, windowSize: 5)
        }
        preMagNormSmoothing = magNormSmooting
        updateMagNormSmoothingQueue(data: magNormSmooting)

        var magNormVar = MF.calVariance(buffer: magNormSmoothingQueue, bufferMean: magNormSmoothingQueue.average)
        if (magNormVar > 7) {
            magNormVar = 7
        }
        updateMagNormVarQueue(data: magNormVar)

        var magVarFeature: Double = magNormVar
        if (magNormVarQueue.count == 1) {
            magVarFeature = magNormVar
        } else if (magNormVarQueue.count < Int(OlympusConstants.SAMPLE_HZ*2)) {
            magVarFeature = MF.exponentialMovingAverage(preEMA: preMagVarFeature, curValue: magNormVar, windowSize: magNormVarQueue.count)
        } else {
            magVarFeature = MF.exponentialMovingAverage(preEMA: preMagVarFeature, curValue: magNormVar, windowSize: Int(OlympusConstants.SAMPLE_HZ*2))
        }
        preMagVarFeature = magVarFeature
        // --------------- //
        
        let velocityRaw = log10(magVarFeature+1)/log10(1.1)
        let velocity = velocityRaw
        updateVelocityQueue(data: velocity)

        var velocitySmoothing: Double = 0
        if (velocityQueue.count == 1) {
            velocitySmoothing = velocity
        } else if (velocityQueue.count < Int(OlympusConstants.SAMPLE_HZ)) {
            velocitySmoothing = MF.exponentialMovingAverage(preEMA: preVelocitySmoothing, curValue: velocity, windowSize: velocityQueue.count)
        } else {
            velocitySmoothing = MF.exponentialMovingAverage(preEMA: preVelocitySmoothing, curValue: velocity, windowSize: Int(OlympusConstants.SAMPLE_HZ))
        }
        preVelocitySmoothing = velocitySmoothing
        var turnScale = exp(-navGyroZSmoothing/2) // Default 1.6
        if (turnScale > 0.87) {
            turnScale = 1.0
        }
        
        var velocityInput = velocitySmoothing
        if velocityInput < OlympusConstants.VELOCITY_MIN {
            velocityInput = 0
        } else if velocityInput > OlympusConstants.VELOCITY_MAX {
            velocityInput = OlympusConstants.VELOCITY_MAX
        }
        
        let rflowScale: Double = calRflowVelocityScale(rflowForVelocity: self.rflowForVelocity, isSufficientForVelocity: self.isSufficientRfdVelocityBuffer)
        
        let velocityStop = velocityInput*self.velocityScale*self.entranceVelocityScale*0.7
        let velocityNotStop = velocityInput*self.velocityScale*self.entranceVelocityScale
        var velocityInputScale = velocityNotStop
        
        if velocityInputScale < OlympusConstants.VELOCITY_MIN {
            velocityInputScale = 0
            if (self.isSufficientRfdBuffer && self.rflow < 0.4) {
//                print(getLocalTimeString() + " , (Olympus) DRDistanceEstimator : rflow = \(rflow) // velocityInputScale = \(velocityInputScale) ")
                velocityInputScale = OlympusConstants.VELOCITY_MAX*rflowScale
            }
        } else if velocityInputScale > OlympusConstants.VELOCITY_MAX {
            velocityInputScale = OlympusConstants.VELOCITY_MAX
        }
        // RFlow Stop Detection
        if (self.isSufficientRfdBuffer && self.rflow >= OlympusConstants.RF_SC_THRESHOLD_DR) {
            velocityInputScale = 0
        }
        
        let delT = self.preTime == 0 ? 1/OlympusConstants.SAMPLE_HZ : (time-self.preTime)*1e-3

        if (velocityInputScale == 0 && self.isStartRouteTrack) {
            velocityInputScale = OlympusConstants.VELOCITY_MIN
        }
        
        if velocityInputScale != 0 && drState == .STOP {
            print(getLocalTimeString() + " , (Olympus) DRDistanceEstimator : DR State : \((velocityInputScale/3.6)*turnScale) -> STOP")
            velocityInputScale = 0
        }
        
        let velocityMps = (velocityInputScale/3.6)*turnScale
        let velocityFinal = velocityMps
        
        finalUnitResult.isIndexChanged = false
        finalUnitResult.velocity = velocityFinal
        
        distance += velocityMps*delT
        if (distance > Double(OlympusConstants.OUTPUT_DISTANCE_SETTING)) {
            index += 1
            finalUnitResult.length = distance
            finalUnitResult.index = index
            finalUnitResult.isIndexChanged = true

            distance = 0
        }

        featureExtractionCount += 1
        preTime = time
        return finalUnitResult
    }
    
    public func updateAccQueue(data: SensorAxisValue) {
        if (accQueue.count >= Int(OlympusConstants.FEATURE_EXTRACTION_SIZE)) {
            accQueue.pop()
        }
        accQueue.append(data)
    }
    
    public func updateMagQueue(data: SensorAxisValue) {
        if (magQueue.count >= Int(OlympusConstants.FEATURE_EXTRACTION_SIZE)) {
            magQueue.pop()
        }
        magQueue.append(data)
    }
    
    public func updateNavGyroZQueue(data: Double) {
        if (navGyroZQueue.count >= Int(OlympusConstants.FEATURE_EXTRACTION_SIZE)) {
            navGyroZQueue.remove(at: 0)
        }
        navGyroZQueue.append(data)
    }
    
    public func updateAccNormQueue(data: Double) {
        if (accNormQueue.count >= Int(OlympusConstants.SAMPLE_HZ)) {
            accNormQueue.remove(at: 0)
        }
        accNormQueue.append(data)
    }
    
    public func updateMagNormQueue(data: Double) {
        if (magNormQueue.count >= 5) {
            magNormQueue.remove(at: 0)
        }
        magNormQueue.append(data)
    }
    
    public func updateMagNormSmoothingQueue(data: Double) {
        if (magNormSmoothingQueue.count >= Int(OlympusConstants.SAMPLE_HZ)) {
            magNormSmoothingQueue.remove(at: 0)
        }
        magNormSmoothingQueue.append(data)
    }
    
    public func updateMagNormVarQueue(data: Double) {
        if (magNormVarQueue.count >= Int(OlympusConstants.SAMPLE_HZ*2)) {
            magNormVarQueue.remove(at: 0)
        }
        magNormVarQueue.append(data)
    }
    
    public func updateVelocityQueue(data: Double) {
        if (velocityQueue.count >= Int(OlympusConstants.SAMPLE_HZ)) {
            velocityQueue.remove(at: 0)
        }
        velocityQueue.append(data)
    }
    
    public func setRflow(rflow: Double, rflowForVelocity: Double, rflowForAutoMode: Double, isSufficient: Bool, isSufficientForVelocity: Bool, isSufficientForAutoMode: Bool) {
        self.rflow = rflow
        self.rflowForVelocity = rflowForVelocity
        self.rflowForAutoMode = rflowForAutoMode
        
        self.isSufficientRfdBuffer = isSufficient
        self.isSufficientRfdVelocityBuffer = isSufficientForVelocity
        self.isSufficientRfdAutoModeBuffer = isSufficientForAutoMode
    }
    
    public func calRflowVelocityScale(rflowForVelocity: Double, isSufficientForVelocity: Bool) -> Double {
        var scale: Double = 1.0
        if (isSufficientForVelocity) {
            scale = (-1/(1+exp(10*(-rflowForVelocity+0.66)))) + 1
            if (scale < 0.5) {
                scale = 0.5
            }
        }
        
        return scale
    }
    
    public func setIsStartRouteTrack(isStartRouteTrack: Bool) {
        self.isStartRouteTrack = isStartRouteTrack
    }
    
    // DR STATE
    func updateAccNormBuffer(value: Double) {
        if (accNormBuffer.count >= OlympusConstants.STOP_STATE_WINDOW) {
            accNormBuffer.remove(at: 0)
        }
        accNormBuffer.append(value)
    }
    
    func updateGyroNormBuffer(value: Double) {
        if (gyroNormBuffer.count >= OlympusConstants.STOP_STATE_WINDOW) {
            gyroNormBuffer.remove(at: 0)
        }
        gyroNormBuffer.append(value)
    }
    
    func updateDrStateBuffer(value: DrState) {
        if (drStateBuffer.count >= OlympusConstants.STOP_STATE_WINDOW) {
            drStateBuffer.remove(at: 0)
        }
        drStateBuffer.append(value)
    }
    
    func calRMS(buffer: [Double]) -> Double {
        guard !buffer.isEmpty, buffer.count >= 10 else { return 1.0 }
        
        let slice: [Double] = buffer
        let squaredSum = slice.reduce(0.0) { $0 + $1 * $1 }
        let mean = squaredSum / Double(slice.count)
        let rms = sqrt(mean)
        return rms
    }
    
    func determineDrState(drStateBuffer: [DrState]) -> DrState {
        let windowSize = drStateBuffer.count
        guard windowSize >= 10 else {
            return .UNKNOWN
        }
        
        let stopCount = drStateBuffer.filter { $0 == .STOP }.count
        let stopRatio = Double(stopCount) / Double(windowSize)
//        print(getLocalTimeString() + " , (Olympus) determineDrState : stopCount = \(stopCount) // stopRatio = \(stopRatio)")
        
        // 버퍼 내에서 가장 긴 연속 STOP 길이 계산
        var maxConsecutiveStop = 0
        var currentConsecutive = 0
        for state in drStateBuffer {
            if state == .STOP {
                currentConsecutive += 1
                maxConsecutiveStop = max(maxConsecutiveStop, currentConsecutive)
            } else {
                currentConsecutive = 0
            }
        }
        
//        print(getLocalTimeString() + " , (Olympus) determineDrState : maxConsecutiveStop = \(maxConsecutiveStop)")
        
        // 최근 5개가 모두 STOP인지 확인
        let last5 = drStateBuffer.suffix(5)
        let allLast5Stop = last5.allSatisfy { $0 == .STOP }
//        print(getLocalTimeString() + " , (Olympus) determineDrState : allLast5Stop = \(allLast5Stop)")
//        print(getLocalTimeString() + " , (Olympus) determineDrState : ----------------------------------------")
        if stopRatio >= 0.7, maxConsecutiveStop >= 10, allLast5Stop {
            return .STOP
        } else {
            return .MOVE
        }
    }
}
