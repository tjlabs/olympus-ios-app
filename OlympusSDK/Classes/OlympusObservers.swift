let START_FLAG: Int = -2
let BLACK_LIST_FLAG: Int = -1
let OUTDOOR_FLAG: Int = 0
let INDOOR_FLAG: Int = 1
let BLE_OFF_FLAG: Int = 2
let VENUS_FLAG: Int = 3
let JUPITER_FLAG: Int = 4
let NETWORK_WAITING_FLAG: Int = 5
let NETWORK_CONNECTION_FLAG: Int = 6
let BACKGROUND_FLAG: Int = 7
let FOREGROUND_FLAG: Int = 8
let RFD_FLAG: Int = 9
let UVD_FLAG: Int = 10
let BLE_SCAN_STOP_FLAG: Int = 11
let BLE_ERROR_FLAG: Int = 12

public enum InOutState: Int, Codable {
    case OUT_TO_IN = 0
    case INDOOR = 1
    case IN_TO_OUT = 2
    case OUTDOOR = 3
    case UNKNOWN = -1
}

public struct LLH: Codable {
    let lat: Double
    let lon: Double
    let heading: Double
}

protocol StateTrackingObserver: AnyObject {
    func isStateDidChange(newValue: Int)
}

protocol BuildingLevelChangeObserver: AnyObject {
    func isBuildingLevelChanged(isChanged: Bool, newBuilding: String, newLevel: String, newCoord: [Double])
}

public protocol Observable {
    func addObserver(_ observer: Observer)
    func removeObserver(_ observer: Observer)
}

public protocol Observer: class {
    func update(result: FineLocationTrackingResult)
    func report(flag: Int)
}

public class Observation: Observable {
    var observers = [Observer]()
    public func addObserver(_ observer: Observer) {
        observers.append(observer)
    }
    public func removeObserver(_ observer: Observer) {
        observers = observers.filter({ $0 !== observer })
    }
}
