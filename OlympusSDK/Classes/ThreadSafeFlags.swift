
import Foundation

@available(iOS 13.0, *)
actor TrajMatchingFlagManager {
    private var isMatchingInProgress = false
    private var isOnPointInProgress = false
    
    func canStartMatching() -> Bool {
        return !isMatchingInProgress && !isOnPointInProgress
    }
    
    func startMatching() -> Bool {
        guard !isMatchingInProgress && !isOnPointInProgress else {
            return false
        }
        isMatchingInProgress = true
        return true
    }
    
    func endMatching() {
        isMatchingInProgress = false
    }
    
    func startOnPointProcessing() -> Bool {
        guard !isOnPointInProgress else {
            return false
        }
        isOnPointInProgress = true
        return true
    }
    
    func endOnPointProcessing() {
        isOnPointInProgress = false
    }
    
    func isCurrentlyProcessing() -> Bool {
        return isMatchingInProgress || isOnPointInProgress
    }
}

class LegacyTrajMatchingFlagManager {
    private let queue = DispatchQueue(label: "TrajMatchingFlagManager", attributes: .concurrent)
    private var _isMatchingInProgress = false
    private var _isOnPointInProgress = false
    
    func canStartMatching(completion: @escaping (Bool) -> Void) {
        queue.async(flags: .barrier) {
            let canStart = !self._isMatchingInProgress && !self._isOnPointInProgress
            DispatchQueue.main.async {
                completion(canStart)
            }
        }
    }
    
    func startMatching(completion: @escaping (Bool) -> Void) {
        queue.async(flags: .barrier) {
            let canStart = !self._isMatchingInProgress && !self._isOnPointInProgress
            if canStart {
                self._isMatchingInProgress = true
            }
            DispatchQueue.main.async {
                completion(canStart)
            }
        }
    }
    
    func endMatching() {
        queue.async(flags: .barrier) {
            self._isMatchingInProgress = false
        }
    }
    
    func startOnPointProcessing(completion: @escaping (Bool) -> Void) {
        queue.async(flags: .barrier) {
            let canStart = !self._isOnPointInProgress
            if canStart {
                self._isOnPointInProgress = true
            }
            DispatchQueue.main.async {
                completion(canStart)
            }
        }
    }
    
    func endOnPointProcessing() {
        queue.async(flags: .barrier) {
            self._isOnPointInProgress = false
        }
    }
}
