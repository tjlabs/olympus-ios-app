
import Foundation
import TJLabsCommon

class LSEManager: RFDGeneratorDelegate {
    weak var delegate: LSEManagerDelegate?
    
    private let rfdBufferQueue = DispatchQueue(label: "com.tjlabs.lse.rfd-buffer")
    private let maxRfdBufferCount = 20
    private let postIntervalSeconds: TimeInterval = 1
    private let payloadWindowMillis = 5_000
    private var rfdBuffer: [ReceivedForce] = []
    private var postTimer: Timer?

    func onRfdResult(_ generator: TJLabsCommon.RFDGenerator, receivedForce: TJLabsCommon.ReceivedForce) {
        if !mockMode { JupiterFileManager.shared.writeRFD(rfd: receivedForce) }
        appendRfdToBuffer(receivedForce)
    }
    
    func onRfdError(_ generator: TJLabsCommon.RFDGenerator, code: Int, msg: String) {
        // TODO
    }
    
    func onRfdEmptyMillis(_ generator: TJLabsCommon.RFDGenerator, time: Double) {
        self.rfdEmptyMillis = time
    }
    
    // MARK: Payload
    let algorithmMode = "dr"
    
    var traceId: String?
    var headingOffset: Double = 0
    var userId: String = "LSE"
    
    var selectedSector: UserSectorResponse?
    var selectedBuilding: UserSectorBuilding?
    
    var sectorId: Int = 0
    var buildingId: Int = 0
    
    var mockMode: Bool = false
    // MARK: RFD
    var rfdGenerator: RFDGenerator?
    private var rfdEmptyMillis: Double = 0
    private var pressure: Float = 0
    
    init(selectedSector: UserSectorResponse, selectedBuilding: UserSectorBuilding) {
        self.selectedSector = selectedSector
        self.selectedBuilding = selectedBuilding
        
        self.sectorId = selectedSector.id
        self.buildingId = selectedBuilding.id
    }
    
    deinit {
        stopPostTimer()
        clearRfdBuffer()
    }
    
    private func makeUniqueId(uuid: String) -> String {
        let currentTime = TJLabsUtilFunctions.shared.getCurrentTimeInMilliseconds(as: .int) as! Int
        let unique_id: String = "\(uuid)_\(currentTime)"
        
        return unique_id
    }
    
    func setMockMode(flag: Bool) {
        self.mockMode = flag
    }
    
    func startGenerator(mode: UserMode, completion: @escaping (Bool, String) -> Void) {
        let id = makeUniqueId(uuid: self.userId)
        rfdGenerator = RFDGenerator(userId: id)
        
        guard let rfd = rfdGenerator else {
            completion(false, "rfdGenerator is nil")
            return
        }
        
        let (isRfdSuccess, rfdMsg) = rfd.checkIsAvailableRfd()
        guard isRfdSuccess else {
            completion(false, rfdMsg)
            return
        }

        clearRfdBuffer()
        rfdGenerator?.delegate = self
        rfdGenerator?.pressureProvider = { [self] in
            return self.pressure
        }
        JupiterReplayer.shared.replayMode ? rfdGenerator?.generateReplayRfd() : rfdGenerator?.generateRfd()
        
        JupiterFileManager.shared.setDebugOption(flag: true)
        JupiterFileManager.shared.createFiles(id: id, os: "iOS")
        
        if !simulationMode {
            let currentTime = TJLabsUtilFunctions.shared.getCurrentTimeInMilliseconds(as: .int) as! Int
            JupiterFileManager.shared.writeEvent(event: JupiterEvent(mobile_time: currentTime, event_code: JupiterServiceCode.SERVICE_SUCCESS.rawValue))
        }

        startPostTimer()
        
        completion(true, "")
    }
    
    func stopGenerator() {
        stopPostTimer()
        clearRfdBuffer()
        rfdGenerator?.delegate = nil
        rfdGenerator?.stopRfdGeneration()
        rfdGenerator = nil
    }

    private func handlePostTimerTick() {
        guard let payload = makeBufferedPayloadForLastFiveSeconds() else {
            return
        }

        JupiterNetworkManager.shared.postLSE(url: JupiterNetworkConstants.getLocationSingleEpochURL(), input: payload) { statusCode, returnedString, requestPayload in
            LSELogger.i(
                tag: "LSEManager",
                message: "(postLSE) statusCode=\(statusCode), sectorId=\(requestPayload.sector_code), buildingId=\(requestPayload.building_code), response=\(returnedString)"
            )

            let result = self.makeSingleEpochResult(
                statusCode: statusCode,
                returnedString: returnedString
            )
            self.delegate?.lseManager(self, didReceiveSingleEpochResult: result, requestPayload: requestPayload)
        }
    }

    private func startPostTimer() {
        stopPostTimer()

        let scheduleTimer = {
            let timer = Timer.scheduledTimer(withTimeInterval: self.postIntervalSeconds, repeats: true) { [weak self] _ in
                self?.handlePostTimerTick()
            }
            timer.tolerance = 0.2
            self.postTimer = timer
        }

        if Thread.isMainThread {
            scheduleTimer()
        } else {
            DispatchQueue.main.sync(execute: scheduleTimer)
        }
    }

    private func stopPostTimer() {
        let invalidateTimer = {
            self.postTimer?.invalidate()
            self.postTimer = nil
        }

        if Thread.isMainThread {
            invalidateTimer()
        } else {
            DispatchQueue.main.sync(execute: invalidateTimer)
        }
    }

    private func appendRfdToBuffer(_ receivedForce: ReceivedForce) {
        rfdBufferQueue.async {
            self.rfdBuffer.append(receivedForce)

            if self.rfdBuffer.count > self.maxRfdBufferCount {
                self.rfdBuffer.removeFirst(self.rfdBuffer.count - self.maxRfdBufferCount)
            }
        }
    }

    private func clearRfdBuffer() {
        rfdBufferQueue.sync {
            self.rfdBuffer.removeAll()
        }
    }

    private func makeBufferedPayloadForLastFiveSeconds() -> LocationRequestPayload? {
        let currentTime = TJLabsUtilFunctions.shared.getCurrentTimeInMilliseconds(as: .int) as! Int
        let windowStart = currentTime - payloadWindowMillis

        return rfdBufferQueue.sync {
            guard self.rfdBuffer.contains(where: { $0.mobile_time <= windowStart }) else {
                return nil
            }

            let measurements = self.rfdBuffer
                .filter { $0.mobile_time >= windowStart && $0.mobile_time <= currentTime }
                .flatMap { rfd in
                    rfd.rfs.map { key, value in
                        LSEMeas(timestamp: rfd.mobile_time, ward_name: key, rssi: Int(value))
                    }
                }

            guard !measurements.isEmpty else {
                return nil
            }

            return LocationRequestPayload(
                trace_id: self.traceId,
                sector_code: self.sectorId,
                building_code: self.buildingId,
                algorithm_mode: self.algorithmMode,
                measurements: measurements
            )
        }
    }

    private func makeSingleEpochResult(statusCode: Int, returnedString: String) -> LocationSingleEpochResult {
        guard (200..<300).contains(statusCode) else {
            return .failure(
                LocationSingleEpochFailure(
                    statusCode: statusCode,
                    message: returnedString
                )
            )
        }

        guard let responseData = returnedString.data(using: .utf8) else {
            return .failure(
                LocationSingleEpochFailure(
                    statusCode: statusCode,
                    message: "Failed to encode response string as UTF-8"
                )
            )
        }

        do {
            let response = try JSONDecoder().decode(LocationSingleEpochResponse.self, from: responseData)

            if let location = response.location {
                return .success(
                    LocationSingleEpochSuccess(
                        response: response,
                        location: location
                    )
                )
            }

            return .noLocation(
                LocationSingleEpochNoLocation(
                    response: response,
                    details: decodeMessage(response.message)
                )
            )
        } catch {
            return .failure(
                LocationSingleEpochFailure(
                    statusCode: statusCode,
                    message: "Failed to decode response: \(error.localizedDescription)"
                )
            )
        }
    }

    private func decodeMessage(_ rawMessage: String?) -> LocationSingleEpochMessage? {
        guard let rawMessage, let messageData = rawMessage.data(using: .utf8) else {
            return nil
        }

        return try? JSONDecoder().decode(LocationSingleEpochMessage.self, from: messageData)
    }
}
