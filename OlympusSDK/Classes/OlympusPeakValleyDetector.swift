import Darwin
import Foundation

public enum Type {
    case NONE, PEAK, VALLEY
}

public class OlympusPeakValleyDetector: NSObject {
    
    public override init() {
        
    }
    
    public func updatePeakValley(localPeakValley: PeakValleyStruct, lastPeakValley: PeakValleyStruct) -> PeakValleyStruct {
        var updatePeakValley: PeakValleyStruct = lastPeakValley
        if (lastPeakValley.type == Type.PEAK && localPeakValley.type == Type.PEAK) {
            updatePeakValley = updatePeakIfBigger(localPeak: localPeakValley, lastPeak: lastPeakValley)
        } else if (lastPeakValley.type == Type.VALLEY && localPeakValley.type == Type.VALLEY) {
            updatePeakValley = updateValleyIfSmaller(localValley: localPeakValley, lastValley: lastPeakValley)
        }
        return updatePeakValley
    }
    
    public func updatePeakIfBigger(localPeak: PeakValleyStruct, lastPeak: PeakValleyStruct) -> PeakValleyStruct {
        var updatePeakValley: PeakValleyStruct = lastPeak
        
        if (localPeak.pvValue > lastPeak.pvValue) {
            updatePeakValley.timestamp = localPeak.timestamp
            updatePeakValley.pvValue = localPeak.pvValue
        }
        
        return updatePeakValley
    }
    
    public func updateValleyIfSmaller(localValley: PeakValleyStruct, lastValley: PeakValleyStruct) -> PeakValleyStruct {
        var updatePeakValley: PeakValleyStruct = lastValley
        
        if (localValley.pvValue < lastValley.pvValue) {
            updatePeakValley.timestamp = localValley.timestamp
            updatePeakValley.pvValue = localValley.pvValue
        }
        
        return updatePeakValley
    }
    
    
    public var lastPeakValley: PeakValleyStruct = PeakValleyStruct(type: Type.PEAK, timestamp: Double.greatestFiniteMagnitude, pvValue: Double.leastNormalMagnitude)
    
//    public func findLocalPeakValley(queue: LinkedList<TimestampDouble>) -> PeakValleyStruct {
//        if (isLocalPeak(data: queue)) {
//            let timestamp = queue.node(at: 1)!.value.timestamp
//            let valuestamp = queue.node(at: 1)!.value.valuestamp
//            
//            return PeakValleyStruct(type: Type.PEAK, timestamp: timestamp, pvValue: valuestamp)
//        } else if (isLocalValley(data: queue)) {
//            let timestamp = queue.node(at: 1)!.value.timestamp
//            let valuestamp = queue.node(at: 1)!.value.valuestamp
//            
//            return PeakValleyStruct(type: Type.VALLEY, timestamp: timestamp, pvValue: valuestamp)
//        } else {
//            return PeakValleyStruct()
//        }
//    }
    
    public func findLocalPeakValley(queue: LinkedList<TimestampDouble>) -> PeakValleyStruct {
        guard queue.count > 1 else {
            return PeakValleyStruct()
        }

        if let node = queue.node(at: 1) {
            if isLocalPeak(data: queue) {
                return PeakValleyStruct(type: .PEAK, timestamp: node.value.timestamp, pvValue: node.value.valuestamp)
            } else if isLocalValley(data: queue) {
                return PeakValleyStruct(type: .VALLEY, timestamp: node.value.timestamp, pvValue: node.value.valuestamp)
            }
        }
        
        return PeakValleyStruct()
    }
    
    public func isLocalPeak(data: LinkedList<TimestampDouble>) -> Bool {
        let valuestamp0 = data.node(at: 0)!.value.valuestamp
        let valuestamp1 = data.node(at: 1)!.value.valuestamp
        let valuestamp2 = data.node(at: 2)!.value.valuestamp
        
        return (valuestamp0 < valuestamp1) && (valuestamp1 >= valuestamp2)
    }
    
    public func isLocalValley(data: LinkedList<TimestampDouble>) -> Bool {
        let valuestamp0 = data.node(at: 0)!.value.valuestamp
        let valuestamp1 = data.node(at: 1)!.value.valuestamp
        let valuestamp2 = data.node(at: 2)!.value.valuestamp
        
        return (valuestamp0 > valuestamp1) && (valuestamp1 <= valuestamp2)
    }
    
    public func findGlobalPeakValley(localPeakValley: PeakValleyStruct) -> PeakValleyStruct {
        var foundPeakValley = PeakValleyStruct()
        if (lastPeakValley.type == Type.PEAK && localPeakValley.type == Type.VALLEY) {
            if (isGlobalPeak(lastPeak: lastPeakValley, localValley: localPeakValley)) {
                foundPeakValley = lastPeakValley
                lastPeakValley = localPeakValley
            }
        } else if (lastPeakValley.type == Type.VALLEY && localPeakValley.type == Type.PEAK) {
            if (isGlobalValley(lastValley: lastPeakValley, localPeak: localPeakValley)) {
                foundPeakValley = lastPeakValley
                lastPeakValley = localPeakValley
            }
        }
        
        return foundPeakValley
    }
    
    public func isGlobalPeak(lastPeak: PeakValleyStruct, localValley: PeakValleyStruct) -> Bool {
        let amp = lastPeak.pvValue - localValley.pvValue
        let time = localValley.timestamp - lastPeak.timestamp
        
        return (amp > OlympusConstants.AMP_THRESHOLD) && (time > OlympusConstants.TIME_THRESHOLD)
    }
    
    public func isGlobalValley(lastValley: PeakValleyStruct, localPeak: PeakValleyStruct) -> Bool {
        let amp = localPeak.pvValue - lastValley.pvValue
        let time = localPeak.timestamp - lastValley.timestamp
        
        return (amp > OlympusConstants.AMP_THRESHOLD) && (time > OlympusConstants.TIME_THRESHOLD)
    }
    
    public func findPeakValley(smoothedNormAcc: LinkedList<TimestampDouble>) -> PeakValleyStruct {
        let localPeakValley = findLocalPeakValley(queue: smoothedNormAcc)
        let foundGlobalPeakValley = findGlobalPeakValley(localPeakValley: localPeakValley)
        
        lastPeakValley = updatePeakValley(localPeakValley: localPeakValley, lastPeakValley: lastPeakValley)
        return foundGlobalPeakValley
    }
}
