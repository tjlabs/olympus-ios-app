import Foundation

public class OlympusUnitStatusEstimator: NSObject {
    public override init() {
        
    }
    public var lookingFlagStepQueue = LinkedList<Bool>()
    
    public func estimateStatus(Attitude: Attitude, isIndexChanged: Bool, unitMode: String) -> Bool {
        if (unitMode == OlympusConstants.MODE_PDR) {
            if (isIndexChanged) {
                let isLookingAttitude = (abs(Attitude.Roll) < degree2radian(degree: 25) && Attitude.Pitch > degree2radian(degree: -20) && Attitude.Pitch < degree2radian(degree: 80))
                
                updateIsLookingAttitudeQueue(lookingFlag: isLookingAttitude)
                let flag: Bool = checkLookingAttitude(lookingFlagStepQueue: lookingFlagStepQueue)
                
                return flag
            } else {
                return false
            }
        } else {
            return true
        }
    }
    
    public func checkLookingAttitude(lookingFlagStepQueue: LinkedList<Bool>) -> Bool {
        if (lookingFlagStepQueue.count <= 2) {
            return true
        } else {
            var bufferSum = 0
            for i in 0..<lookingFlagStepQueue.count {
                let value = lookingFlagStepQueue.node(at: i)!.value
                if (value) { bufferSum += 1 }
            }
            
            if (bufferSum >= 2) {
                return true
            } else {
                return false
            }
        }
    }
    
    public func updateIsLookingAttitudeQueue(lookingFlag: Bool) {
        if (lookingFlagStepQueue.count >= OlympusConstants.LOOKING_FLAG_STEP_CHECK_SIZE) {
            lookingFlagStepQueue.pop()
        }
        
        if (lookingFlag) {
            lookingFlagStepQueue.append(true)
        } else {
            lookingFlagStepQueue.append(false)
        }
    }
    
    public func degree2radian(degree: Double) -> Double {
        return degree * Double.pi / 180
    }
    
    public func radian2degree(radian: Double) -> Double {
        return radian * 180 / Double.pi
    }
}
