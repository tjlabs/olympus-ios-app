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
    
    public var movingDirectionInfoBuffer = [MovingDirectionInfo]()
    public var clearIndex: Int = 0
    public var isNeedClearBuffer: Bool = false
    private var movingDirectionAccBiasQueue = [Double]()
    private var biasSmoothing: Double = 0
    private var preBiasSmoothing: Double = 0
    private var biasBuffer = [Double]()
    private var isPossibleUseBias: Bool = false
    
    private var stopDetectTime: Double = 0
    
    public func argmax(array: [Float]) -> Int {
        let output1 = array[0]
        let output2 = array[1]
        
        if (output1 > output2){
            return 0
        } else {
            return 1
        }
    }
    
    public func estimateDistanceInfo(time: Double, sensorData: OlympusSensorData, isStopDetect: Bool) -> UnitDistance {
        // feature extraction
        // ACC X, Y, Z, Norm Smoothing
        // Use y, z, norm variance (2sec)
        
//        if isStopDetect {
//            self.stopDetectTime = time
//            print(getLocalTimeString() + " , (Olympus) DRDistanceEstimator : index = \(index) // isStopDetect = \(isStopDetect)")
//        }
//        let diffStopDetectTime = time - self.stopDetectTime
        
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
        let accMovingDirection = MF.transBody2Nav(att: accAttitude, data: acc)[1]
        let gyroNav = MF.transBody2Nav(att: accAttitude, data: gyro)[2]
        let gyroNavZ = abs(gyroNav)
        
        let accNorm = MF.l2Normalize(originalVector: sensorData.acc)
        let magNorm = MF.l2Normalize(originalVector: sensorData.mag)
        
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
        
        let accNormVar = MF.calVariance(buffer: accNormQueue, bufferMean: accNormQueue.average)
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
        
//        let velocityStop = velocityInput*self.velocityScale*self.entranceVelocityScale*0.5
        let velocityNotStop = velocityInput*self.velocityScale*self.entranceVelocityScale
        var velocityInputScale = velocityNotStop
//        if diffStopDetectTime < 1000 {
//            print(getLocalTimeString() + " , (Olympus) DRDistanceEstimator : index = \(index) // diffStopDetectTime = \(diffStopDetectTime) // velocityStop = \(velocityStop) // velocityNotStop = \(velocityNotStop)")
//        }
        
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
        velocityAcc += (accMovingDirection + self.biasSmoothing)*delT
        velocityAcc = velocityAcc < 0 ? 0 : velocityAcc
        
        if (velocityInputScale == 0 && self.isStartRouteTrack) {
            velocityInputScale = OlympusConstants.VELOCITY_MIN
        }
        
        let velocityMps = (velocityInputScale/3.6)*turnScale
        let velocityCombine = (velocityMps*0.7) + (velocityAcc*0.3)
        let velocityFinal = isPossibleUseBias ? velocityCombine : velocityMps
        
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
        controlMovingDirectionInfoBuffer(time: time, index: index, acc: accMovingDirection, velocity: velocityMps)
        
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
    
    private func controlMovingDirectionInfoBuffer(time: Double, index: Int, acc: Double, velocity: Double) {
        self.movingDirectionInfoBuffer.append(MovingDirectionInfo(time: time, index: index, acc: acc, velocity: velocity))
        
        if isNeedClearBuffer {
            let pastBuffer = self.movingDirectionInfoBuffer
            var newBuffer = [MovingDirectionInfo]()
            for i in 0..<pastBuffer.count {
                if pastBuffer[i].index >= clearIndex {
                    newBuffer.append(pastBuffer[i])
                }
            }
            isNeedClearBuffer = false
        }
    }
        
    public func calAccBias(unitDRInfoBuffer: [UnitDRInfo], resultIndex: Int, scCompensation: Double) {
        if !unitDRInfoBuffer.isEmpty {
            let movingDirectionBuffer = self.movingDirectionInfoBuffer
            
            let startIndex = unitDRInfoBuffer[0].index
            let endIndex = resultIndex
            
            self.clearIndex = startIndex
            self.isNeedClearBuffer = true
            
            for i in 1..<movingDirectionBuffer.count {
                if movingDirectionBuffer[i].index <= endIndex {
                    if movingDirectionBuffer[i].velocity > 2 && movingDirectionBuffer[i-1].velocity > 2 {
                        let delT = (movingDirectionBuffer[i].time - movingDirectionBuffer[i-1].time)*1e-3 // Seconds
                        let trueAcc = ((movingDirectionBuffer[i].velocity - movingDirectionBuffer[i-1].velocity)*scCompensation)/delT
                        let accBias = trueAcc - movingDirectionBuffer[i].acc
                        
                        updateMovingDirectionAccBiasQueue(data: accBias)
                        if (movingDirectionAccBiasQueue.count == 1) {
                            self.biasSmoothing = accBias
                        } else if (movingDirectionAccBiasQueue.count < Int(OlympusConstants.SAMPLE_HZ*10)) {
                            self.biasSmoothing = MF.exponentialMovingAverage(preEMA: preBiasSmoothing, curValue: accBias, windowSize: movingDirectionAccBiasQueue.count)
                        } else {
                            self.biasSmoothing = MF.exponentialMovingAverage(preEMA: preBiasSmoothing, curValue: accBias, windowSize: Int(OlympusConstants.SAMPLE_HZ*10))
                        }
                        controlBiasBuffer(data: self.biasSmoothing)
                        self.preBiasSmoothing = self.biasSmoothing
//                        print(getLocalTimeString() + " , (Olympus) Acc Bias : index = \(movingDirectionBuffer[i].index) , accBias = \(accBias) , accBiasSmoothed = \(self.biasSmoothing) , isPossibleUseBias = \(isPossibleUseBias)")
                    }
                }
            }
        }
    }
    
    public func updateMovingDirectionAccBiasQueue(data: Double) {
        if (movingDirectionAccBiasQueue.count >= Int(OlympusConstants.SAMPLE_HZ)*10) {
            movingDirectionAccBiasQueue.remove(at: 0)
        }
        movingDirectionAccBiasQueue.append(data)
    }
    
    public func controlBiasBuffer(data: Double) {
        if (biasBuffer.count >= Int(OlympusConstants.SAMPLE_HZ)*10) {
            biasBuffer.remove(at: 0)
            let biasVar = MF.calVariance(buffer: biasBuffer, bufferMean: biasBuffer.average)
//            print(getLocalTimeString() + " , (Olympus) Acc Bias : Var = \(biasVar)")
            isPossibleUseBias = biasVar < 0.015 && index >= 100 ? true : false
        }
        biasBuffer.append(data)
    }
}
