import Foundation

public class OlympusPacingDetectFunctions: NSObject {
    
    public override init() {
        
    }
    
    public func isPacing(queue: LinkedList<StepLengthWithTimestamp>) -> Bool {
        if (queue.count < 5) {
            return false
        }
        var Buffer: [Double] = []
        
        for i in 0..<queue.count {
            let stepLength = queue.node(at: i)!.value.stepLength
            Buffer += stepLength
        }
        
        let diffStepLengthBuffer = calDiffDoubleBuffer(buffer: Buffer)
        let diffStepLengthVariance = OlympusMathFunctions().calVariance(buffer: diffStepLengthBuffer, bufferMean: diffStepLengthBuffer.average)
        
        return diffStepLengthVariance >= 0.09
    }

    public func calDiffDoubleBuffer(buffer: [Double]) -> [Double] {
        var diffBuffer: [Double] = []
        for i in 1..<buffer.count {
            diffBuffer += buffer[i] - buffer[i-1]
        }
        return diffBuffer
    }
    
    
    public func updateNormalStepCheckCount(accPeakQueue: LinkedList<TimestampDouble>, accValleyQueue: LinkedList<TimestampDouble>, normalStepCheckCount: Int) -> Int {
        if (accPeakQueue.count <= 2 || accValleyQueue.count <= 2) {
            return normalStepCheckCount + 1
        }
        
        guard let condition1 = accPeakQueue.last?.value.timestamp else { return 0 }
        guard let condition2 = accPeakQueue.node(at: accPeakQueue.count-2)?.value.timestamp else { return 0 }
        guard let condition3 = accPeakQueue.last?.value.valuestamp else { return 0 }
        guard let condition4 = accPeakQueue.node(at: accPeakQueue.count-2)?.value.valuestamp else { return 0 }
        
        if (condition1 - condition2 < 2000) {
            return normalStepCheckCount + 1
        }
        
        return 0
    }
    
    public func isNormalStep(normalStepCount: Int, normalStepCountSet: Int) -> Bool {
        if (normalStepCount >= normalStepCountSet) {
            return true
        } else {
            return false
        }
    }
    
    public func checkLossStep(normalStepCountBuffer: LinkedList<Int>) -> Bool {
        if (normalStepCountBuffer.count < 3) {
            return false
        } else if (normalStepCountBuffer.node(at: 0)!.value == 0 &&
                   normalStepCountBuffer.node(at: 1)!.value == 1 &&
                   normalStepCountBuffer.node(at: 2)!.value == 2) {
            return true
        } else {
            return false
        }
    }
    
    public func checkAutoModeLossStep(normalStepCountBuffer: LinkedList<Int>) -> Bool {
        var checkString: String = ""
        for i in 0..<normalStepCountBuffer.count {
            checkString.append(String(normalStepCountBuffer.node(at: i)!.value))
            checkString.append(" , ")
        }
        if (normalStepCountBuffer.count < OlympusConstants.AUTO_MODE_NORMAL_STEP_LOSS_CHECK_SIZE) {
            return false
        } else {
            var count: Int = 0
            for i in 0..<normalStepCountBuffer.count {
                if (normalStepCountBuffer.node(at: i)!.value == i) {
                    count += 1
                }
            }
            if count == OlympusConstants.AUTO_MODE_NORMAL_STEP_LOSS_CHECK_SIZE {
                return true
            } else {
                return false
            }
        }
    }
}
