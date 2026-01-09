import Foundation

public enum InOutState: Int, Codable {
    case OUT_TO_IN = 0
    case INDOOR = 1
    case IN_TO_OUT = 2
    case OUTDOOR = 3
    case UNKNOWN = -1
}


final class JupiterResultState {
    static var isEntTrack = false
    static var isInRecoveryProcess = false
    static var isIndoor = false
    static var isInMapEnd = false
    static var isBecomeForeground = false
    static var isSleepMode = false
    static var isVenus = false
    static var isDRMode = false
    static var isGetFirstResponse = false
    
    static func reset() {
        isEntTrack = false
        isInRecoveryProcess = false
        isIndoor = false
        isInMapEnd = false
        isBecomeForeground = false
        isSleepMode = false
        isVenus = false
        isDRMode = false
        isGetFirstResponse = false
    }
}

final class JupiterTimeState {
    static var timeForInit: Double = JupiterTime.TIME_INIT
    static var timeBleOff: Double = 0
    static var timeBecomeForeground: Double = 0
    static var timeEmptyRF: Double = 0
    static var timeTrimFailRF: Double = 0

    static func reset() {
        timeForInit = JupiterTime.TIME_INIT
        timeBleOff = 0
        timeBecomeForeground = 0
        timeEmptyRF = 0
        timeTrimFailRF = 0
    }
}

final class JupiterBleState {
    static var checkBleEmptyStateThreshold: TimeInterval = 10
    static var isBleEmptyState = false
    static var isReadyBleScan = true

    static func reset() {
        checkBleEmptyStateThreshold = 10
        isBleEmptyState = false
        isReadyBleScan = true
    }
}

final class KalmanState {
    static var isKalmanFilterRunning = false
    static var isTimeUpdateRunning = false
    static var isMeasurementUpdateRunning = false

    static func reset() {
        isKalmanFilterRunning = false
        isTimeUpdateRunning = false
        isMeasurementUpdateRunning = false
    }
}

final class NetworkState {
    static var networkStatus = true

    static func reset() {
        networkStatus = true
    }
}

final class GeofenceState {
    static var isInEntranceLevel = false

    static func reset() {
        isInEntranceLevel = false
    }
}

final class BackgroundState {
    static var isBackground = false

    static func reset() {
        isBackground = false
    }
}

final class JupiterInOutState {
    static var curInOutState = InOutState.OUTDOOR
}

final class JupiterSimulatorState {
    static var simulationFlag = false
    
    static func reset() {
        simulationFlag = false
    }
}


final class JupiterStates {
    static func resetAll(isStopService: Bool) {
        //JupiterState
        JupiterBleState.reset()
        JupiterResultState.reset()
        JupiterTimeState.reset()
        KalmanState.reset()
        NetworkState.reset()
        GeofenceState.reset()
        BackgroundState.reset()
        JupiterSimulatorState.reset()
        
        if (isStopService) {
            
        }
    }
}
