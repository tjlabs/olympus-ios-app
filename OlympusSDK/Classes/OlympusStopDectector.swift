import Foundation

public class OlympusStopDetector: NSObject {
    
    public override init() {
        
    }
    
    public var MF = OlympusMathFunctions()
    public var PDF = OlympusPacingDetectFunctions()
    
    public var peakValleyDetector = OlympusStopPeakValleyDetector()
    public var stepLengthEstimator = OlympusStepLengthEstimator()
    public var preAccNormEMA: Double = 0
    public var accNormEMAQueue = LinkedList<TimestampDouble>()
    public var finalUnitResult = UnitDistance()
    
    public var accPeakQueue = LinkedList<TimestampDouble>()
    public var accValleyQueue = LinkedList<TimestampDouble>()
    public var stepLengthQueue = LinkedList<StepLengthWithTimestamp>()
    
    var pastIndexChangedTime: Double = 0
    
    public func estimateDistanceInfo(time: Double, sensorData: OlympusSensorData) -> UnitDistance {
        let accNorm = MF.l2Normalize(originalVector: sensorData.acc)
        
        // EMA를 통해 센서의 노이즈를 줄임
        let accNormEMA = MF.exponentialMovingAverage(preEMA: preAccNormEMA, curValue: accNorm, windowSize: OlympusConstants.AVG_NORM_ACC_WINDOW)
        preAccNormEMA = accNormEMA
        
        if (accNormEMAQueue.count < OlympusConstants.ACC_NORM_EMA_QUEUE_SIZE) {
            accNormEMAQueue.append(TimestampDouble(timestamp: time, valuestamp: accNormEMA))
            return UnitDistance()
        } else {
            accNormEMAQueue.pop()
            accNormEMAQueue.append(TimestampDouble(timestamp: time, valuestamp: accNormEMA))
        }
        
        let foundAccPV = peakValleyDetector.findPeakValley(smoothedNormAcc: accNormEMAQueue)
        updateAccQueue(pvStruct: foundAccPV)
        
        finalUnitResult.isIndexChanged = false
        
        if (foundAccPV.type == Type.PEAK) {
            finalUnitResult.index += 1
            finalUnitResult.isIndexChanged = true
            
            let isIndexChangedTime = foundAccPV.timestamp
            var diffTime: Double = (isIndexChangedTime - self.pastIndexChangedTime)*1e-3
            if (diffTime > 1000) {
                diffTime = 1000
            }
            self.pastIndexChangedTime = isIndexChangedTime
            finalUnitResult.length = OlympusConstants.DEFAULT_STEP_LENGTH
            updateStepLengthQueue(stepLengthWithTimeStamp: StepLengthWithTimestamp(timestamp: foundAccPV.timestamp, stepLength: finalUnitResult.length))
            var tempVelocity: Double = (finalUnitResult.length/diffTime)
            if (tempVelocity > 1.45) {
                tempVelocity = 1.45
            }
            finalUnitResult.velocity = tempVelocity
        }
        
        return finalUnitResult
    }
    
    public func updateAccQueue(pvStruct: PeakValleyStruct) {
        if (pvStruct.type == Type.PEAK) {
            updateAccPeakQueue(pvStruct: pvStruct)
        } else if (pvStruct.type == Type.VALLEY) {
            updateAccValleyQueue(pvStruct: pvStruct)
        }
    }
    
    public func updateAccPeakQueue(pvStruct: PeakValleyStruct) {
        if (accPeakQueue.count >= OlympusConstants.ACC_PV_QUEUE_SIZE) {
            accPeakQueue.pop()
        }
        accPeakQueue.append(TimestampDouble(timestamp: pvStruct.timestamp, valuestamp: pvStruct.pvValue))
    }
    
    public func updateAccValleyQueue(pvStruct: PeakValleyStruct) {
        if (accValleyQueue.count >= OlympusConstants.ACC_PV_QUEUE_SIZE) {
            accValleyQueue.pop()
        }
        accValleyQueue.append(TimestampDouble(timestamp: pvStruct.timestamp, valuestamp: pvStruct.pvValue))
    }
    
    public func updateStepLengthQueue(stepLengthWithTimeStamp: StepLengthWithTimestamp) {
        if (stepLengthQueue.count >= OlympusConstants.STEP_LENGTH_QUEUE_SIZE) {
            stepLengthQueue.pop()
        }
        stepLengthQueue.append(stepLengthWithTimeStamp)
    }
}
