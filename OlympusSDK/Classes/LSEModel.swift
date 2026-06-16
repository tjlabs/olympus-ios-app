
import Foundation

struct UserTenantSectorsResponse: Decodable {
    let id: Int
    let name: String
    let sectors: [TenantSector]
}

struct TenantSector: Decodable {
    let id: Int
    let name: String
    let description: String
    let timezone: String
    let image: String
}

struct UserSectorResponse: Decodable {
    let id: Int
    let name: String
    let timezone: String
    let buildings: [UserSectorBuilding]
}

struct UserSectorBuilding: Decodable {
    let id: Int
    let name: String
    let latitude: Double
    let longitude: Double
}

struct Building: Decodable {
    let id: Int
    let name: String
    let latitude: Double
    let longitude: Double
    let levels: [Level]
}

struct Level: Decodable {
    let id: Int
    let name: String
}

struct SimulationFilePair: Equatable {
    let displayName: String
    let rfdFileName: String
    let eventFileName: String
}


// LSE
struct LocationRequestPayload: Codable {
    let trace_id: String?
    let sector_code: Int
    let building_code: Int?
    let algorithm_mode: String
    let os_type: String
    let measurements: [LSEMeas]
    
    init(trace_id: String? = nil, sector_code: Int, building_code: Int? = nil, algorithm_mode: String, os_type: String = "iOS", measurements: [LSEMeas]) {
        self.trace_id = trace_id
        self.sector_code = sector_code
        self.building_code = building_code
        self.algorithm_mode = algorithm_mode
        self.os_type = os_type
        self.measurements = measurements
    }
}

struct LSEMeas: Codable {
    let timestamp: Int
    let ward_name: String
    let rssi: Int
    
    init(timestamp: Int, ward_name: String, rssi: Int) {
        self.timestamp = timestamp
        self.ward_name = ward_name
        self.rssi = rssi
    }
}

struct LocationSingleEpochResponse: Decodable {
    let location: LSEEstimatedLocation?
    let algo_version: String
    let message: String?
}

struct LSEEstimatedLocation: Decodable {
    let timestamp: Int
    let x: Double
    let y: Double
    let building_id: Int
    let level_id: Int
    let floor: String
}

struct LocationSingleEpochMessage: Decodable {
    let error: String?
    let message: String?
}

struct LocationSingleEpochSuccess {
    let response: LocationSingleEpochResponse
    let location: LSEEstimatedLocation
}

struct LocationSingleEpochNoLocation {
    let response: LocationSingleEpochResponse
    let details: LocationSingleEpochMessage?
}

struct LocationSingleEpochFailure {
    let statusCode: Int
    let message: String
}

struct LSERequestContext {
    let index: Int
    let buildingName: String
    let buildingId: Int
    let levelName: String
    let levelId: Int?
    let x: Float
    let y: Float
}

struct SingleEpochSnapshot {
    let requestContext: LSERequestContext?
    let result: FineLocationTrackingOutput
}

enum LocationSingleEpochResult {
    case success(LocationSingleEpochSuccess)
    case noLocation(LocationSingleEpochNoLocation)
    case failure(LocationSingleEpochFailure)
}

protocol LSEManagerDelegate: AnyObject {
    func lseManager(
        _ manager: LSEManager,
        didReceiveSingleEpochResult result: LocationSingleEpochResult,
        requestPayload: LocationRequestPayload,
        requestContext: LSERequestContext?
    )
}
