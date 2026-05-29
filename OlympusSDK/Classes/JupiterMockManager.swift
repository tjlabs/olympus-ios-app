
import Foundation
import TJLabsCommon
import TJLabsResource

public enum JupiterMockMode: String {
    case NONE = "NONE"
    case VEHICLE_INDOOR_OUTDOOR = "indoor_outdoor"
    case VEHICLE_OUTDOOR_PARKING = "outdoor_parking"
    case PEDESTRIAN_INDOOR_PARKING = "indoor_parking"
    case PEDESTRIAN_PARKING_INDOOR = "parking_indoor"
}

protocol MockResultDelegate: AnyObject {
    func onMockResult(_ manager: JupiterMockManager, result: MockResult)
}

public class JupiterMockManager {
    public static let shared = JupiterMockManager()
    init() { }
    
    public var mockMode: Bool = false
    var sectorId: Int = 0
    var simulationInfo = [Int: [SimulationInfo]]()
    
    private var fileName: String = ""
    private var mockResultData = [MockResult]()
    private var scheduledMockWorkItems = [DispatchWorkItem]()
    private var isPlaybackActive = false
    private var loadingTask: URLSessionDataTask?
    private var currentLoadRequestId = UUID()
    weak var delegate: MockResultDelegate?
    
    public func initialize() {
        cancelPendingMockResults()
        loadingTask?.cancel()
        loadingTask = nil
        currentLoadRequestId = UUID()
        mockMode = false
        sectorId = 0
        fileName = ""
        mockResultData = []
    }
    
    public func isMockAvailable() -> Bool {
        return !self.mockResultData.isEmpty
    }
    
    func setSimulationInfo(data: [SimulationInfo]) {
        self.simulationInfo[self.sectorId] = data
        JupiterLogger.i(tag: "JupiterMockManager", message: "setSimulationInfo : sectorId=\(self.sectorId), count=\(data.count)")
    }
    
    public func setMockMode(mode: JupiterMockMode, completion: @escaping (Bool) -> Void) {
        var isVehicle = false
        let name = mode.rawValue
        JupiterLogger.i(tag: "JupiterMockManager", message: "setMockMode : start, sectorId=\(sectorId), mode=\(mode.rawValue)")
        switch mode {
        case .NONE:
            JupiterLogger.i(tag: "JupiterMockManager", message: "setMockMode : mode NONE, reset mock state")
            initialize()
            DispatchQueue.main.async {
                completion(false)
            }
            return
        case .VEHICLE_OUTDOOR_PARKING:
            isVehicle = true
        case .VEHICLE_INDOOR_OUTDOOR:
            isVehicle = true
        case .PEDESTRIAN_PARKING_INDOOR:
            isVehicle = false
        case .PEDESTRIAN_INDOOR_PARKING:
            isVehicle = false
        }
        
        guard let infos = self.simulationInfo[self.sectorId] else {
            let availableSectorIds = self.simulationInfo.keys.sorted().map(String.init).joined(separator: ",")
            DispatchQueue.main.async {
                completion(false)
            }
            return
        }
        
        var matchedData: SimulationItem?
        for data in infos {
            if data.is_vehicle == isVehicle {
                for item in data.items {
                    if item.name == name {
                        matchedData = item
                    }
                }
            }
        }
        guard let matchedData = matchedData else {
            let candidateNames = infos
                .filter { $0.is_vehicle == isVehicle }
                .flatMap { $0.items.map(\.name) }
                .joined(separator: ",")
            DispatchQueue.main.async {
                completion(false)
            }
            return
        }
        
        let mockDataName = matchedData.name
        let mockDataUrl = matchedData.url

        cancelPendingMockResults()
        if loadingTask != nil {
            JupiterLogger.i(tag: "JupiterMockManager", message: "setMockMode : cancel previous loading task")
        }
        loadingTask?.cancel()
        loadingTask = nil
        mockMode = false
        fileName = mockDataName
        mockResultData = []
        let requestId = UUID()
        currentLoadRequestId = requestId
        loadFileForMock(mockSource: mockDataUrl) { [weak self] result in
            guard let self = self else { return }

            DispatchQueue.main.async {
                guard self.currentLoadRequestId == requestId else {
                    completion(false)
                    return
                }

                self.loadingTask = nil
                self.mockResultData = result
                self.mockMode = !result.isEmpty
                completion(self.mockMode)
            }
        }
    }
    
    private func loadFileForMock(mockSource: String, completion: @escaping ([MockResult]) -> Void) {
        guard let mockUrl = resolveMockURL(mockSource: mockSource) else {
            completion([])
            return
        }

        if mockUrl.isFileURL {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else { return }
                do {
                    let data = try Data(contentsOf: mockUrl)
                    completion(try self.parseMockResults(data: data))
                } catch {
                    completion([])
                }
            }
            return
        }

        var request = URLRequest(url: mockUrl)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("no-cache, no-store, max-age=0", forHTTPHeaderField: "Cache-Control")
        request.setValue("no-cache", forHTTPHeaderField: "Pragma")
        request.setValue("0", forHTTPHeaderField: "Expires")

        let sessionConfig = URLSessionConfiguration.ephemeral
        sessionConfig.requestCachePolicy = .reloadIgnoringLocalCacheData
        sessionConfig.urlCache = nil

        let session = URLSession(configuration: sessionConfig)
        let task = session.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            defer { session.finishTasksAndInvalidate() }

            if let error = error {
                if let urlError = error as? URLError, urlError.code == .cancelled {
                    completion([])
                    return
                }
                completion([])
                return
            }

            if let httpResponse = response as? HTTPURLResponse {
                JupiterLogger.i(tag: "JupiterMockManager", message: "loadFileForMock : network response, statusCode=\(httpResponse.statusCode)")
            }

            guard let data = data else {
                completion([])
                return
            }

            do {
                completion(try self.parseMockResults(data: data))
            } catch {
                completion([])
            }
        }

        loadingTask = task
        task.resume()
    }
    
    func getMockResults() -> [MockResult] {
        return self.mockResultData
    }
    
    func generateMockResult() {
        cancelPendingMockResults()
        let mockData = self.mockResultData
        
        guard !mockData.isEmpty else { return }
        isPlaybackActive = true
        for i in 0..<mockData.count {
            let mock = mockData[i]
            let delayTime = mock.time_ms

            let workItem = DispatchWorkItem { [weak self] in
                guard let self = self else { return }
                guard self.mockMode, self.isPlaybackActive else { return }
                self.delegate?.onMockResult(
                    self,
                    result: mock
                )
            }

            scheduledMockWorkItems.append(workItem)
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(delayTime), execute: workItem)
        }
    }

    func cancelPendingMockResults() {
        isPlaybackActive = false
        scheduledMockWorkItems.forEach { $0.cancel() }
        scheduledMockWorkItems.removeAll()
    }

    private func resolveMockURL(mockSource: String) -> URL? {
        if let remoteURL = URL(string: mockSource),
           let scheme = remoteURL.scheme?.lowercased(),
           ["http", "https", "file"].contains(scheme) {
            JupiterLogger.i(tag: "JupiterMockManager", message: "resolveMockURL : use direct url, source=\(mockSource)")
            return remoteURL
        }

        let expandedPath = NSString(string: mockSource).expandingTildeInPath
        if expandedPath.hasPrefix("/") {
            JupiterLogger.i(tag: "JupiterMockManager", message: "resolveMockURL : use absolute path, source=\(mockSource), expandedPath=\(expandedPath)")
            return URL(fileURLWithPath: expandedPath)
        }

        guard let exportDir = JupiterFileManager.shared.createExportDirectory() else {
            JupiterLogger.e(tag: "JupiterMockManager", message: "resolveMockURL : failed to create export directory for source=\(mockSource)")
            return nil
        }

        let resolvedURL = exportDir.appendingPathComponent(mockSource)
        JupiterLogger.i(tag: "JupiterMockManager", message: "resolveMockURL : use export directory path, source=\(mockSource), resolvedURL=\(resolvedURL)")
        return resolvedURL
    }

    private func parseMockResults(data: Data) throws -> [MockResult] {
        let decoder = JSONDecoder()

        if let envelope = try? decoder.decode(MockTrajectoryFile.self, from: data) {
            return envelope.simulation_results.map { $0.toMockResult() }
        }

        if let array = try? decoder.decode([MockTrajectoryItem].self, from: data) {
            return array.map { $0.toMockResult() }
        }

        let jsonl = String(decoding: data, as: UTF8.self)
        let rows = jsonl.components(separatedBy: .newlines)
        var results = [MockResult]()
        for row in rows {
            let trimmed = row.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }
            guard let rowData = trimmed.data(using: .utf8) else { continue }

            do {
                let result = try decoder.decode(MockTrajectoryItem.self, from: rowData)
                results.append(result.toMockResult())
            } catch {
                JupiterLogger.e(tag: "JupiterMockManager", message: "loadFileForMock : parsing event row \(error)")
            }
        }

        return results
    }
}

private struct MockTrajectoryFile: Decodable {
    let simulation_results: [MockTrajectoryItem]
}

private struct MockTrajectoryItem: Decodable {
    let time_ms: Int
    let index: Int
    let building_name: String
    let level_name: String
    let jupiter_pos: Position
    let navi_pos: Position?
    let llh: MockTrajectoryLLH?
    let velocity: Float
    let is_vehicle: Bool
    let is_indoor: Bool
    let validity_flag: Int

    func toMockResult() -> MockResult {
        MockResult(time_ms: time_ms,
                   index: index,
                   building_name: building_name,
                   level_name: level_name,
                   jupiter_pos: jupiter_pos,
                   navi_pos: navi_pos,
                   llh: llh?.toLLH(),
                   velocity: velocity,
                   is_vehicle: is_vehicle,
                   is_indoor: is_indoor,
                   validity_flag: validity_flag)
    }
}

private struct MockTrajectoryLLH: Decodable {
    let lat: Double
    let lon: Double
    let azimuth: Double?
    let heading: Double?

    func toLLH() -> LLH {
        LLH(lat: lat, lon: lon, azimuth: heading ?? azimuth ?? 0)
    }
}
