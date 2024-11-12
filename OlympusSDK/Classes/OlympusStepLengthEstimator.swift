import Foundation

public class OlympusStepLengthEstimator: NSObject {
    
    public override init() {
        
    }

    public var preStepLength = OlympusConstants.DEFAULT_STEP_LENGTH
    
    public func estStepLength(accPeakQueue: LinkedList<TimestampDouble>, accValleyQueue: LinkedList<TimestampDouble>) -> Double {
        if (accPeakQueue.count < 1 || accValleyQueue.count < 1) {
            return OlympusConstants.DEFAULT_STEP_LENGTH
        }
        
        let differencePV = accPeakQueue.last!.value.valuestamp - accValleyQueue.last!.value.valuestamp
        var stepLength = OlympusConstants.DEFAULT_STEP_LENGTH
        
        if (differencePV > OlympusConstants.DIFFERENCE_PV_THRESHOLD) {
            stepLength = calLongStepLength(differencePV: differencePV)
        } else {
            stepLength = calShortStepLength(differencePV: differencePV)
        }
        stepLength = limitStepLength(stepLength: stepLength)
        
        return compensateStepLength(curStepLength: stepLength)
    }
    
    public func calLongStepLength(differencePV: Double) -> Double {
        return (OlympusConstants.ALPHA * (differencePV - OlympusConstants.DIFFERENCE_PV_STANDARD) + OlympusConstants.DEFAULT_STEP_LENGTH)
    }
    
    public func calShortStepLength(differencePV: Double) -> Double {
        return ((OlympusConstants.MID_STEP_LENGTH - OlympusConstants.MIN_STEP_LENGTH) / (OlympusConstants.DIFFERENCE_PV_THRESHOLD - OlympusConstants.MIN_DIFFERENCE_PV)) * (differencePV - OlympusConstants.DIFFERENCE_PV_THRESHOLD) + OlympusConstants.MID_STEP_LENGTH
    }
    
    public func compensateStepLength(curStepLength: Double) -> Double {
        let compensateStepLength = OlympusConstants.COMPENSATION_WEIGHT * (curStepLength) - (curStepLength - preStepLength) * (1 - OlympusConstants.COMPENSATION_WEIGHT) + OlympusConstants.COMPENSATION_BIAS
        preStepLength = compensateStepLength
        
        return compensateStepLength
    }
    
    public func limitStepLength(stepLength: Double) -> Double {
        if (stepLength > OlympusConstants.MAX_STEP_LENGTH) {
            return OlympusConstants.MAX_STEP_LENGTH
        } else if (stepLength < OlympusConstants.MIN_STEP_LENGTH) {
            return OlympusConstants.MIN_STEP_LENGTH
        } else {
            return stepLength
        }
    }
}
