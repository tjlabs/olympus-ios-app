
import Foundation
import TJLabsCommon
import TJLabsResource

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
    var externalName: String = "LSE"
    var tenantName: String = "tjlabs"
    var appName: String?
    
    var headingOffset: Double = 0
    var sectorId: Int = 0
    var mockMode: Bool = false
    
    var resourceManager: TJLabsResourceManager?
    var curPmResult: FineLocationTrackingOutput?
    
    // MARK: RFD
    var rfdGenerator: RFDGenerator?
    private var rfdEmptyMillis: Double = 0
    private var pressure: Float = 0
    
    init(sectorId: Int, traceId: String, externalName: String, resourceManager: TJLabsResourceManager) {
        self.traceId = traceId
        self.externalName = externalName
        
        self.mockMode = JupiterMockManager.shared.mockMode
        self.sectorId = sectorId
        self.resourceManager = resourceManager
    }
    
    deinit {
        stopPostTimer()
        clearRfdBuffer()
    }
    
    func setAppName(name: String) {
        self.appName = name
        JupiterLogger.i(tag: "LSEManager", message: "(setAppName) : \(name)")
    }
    
    func startService() {
        startPostTimer()
    }
    
    func stopService() {
        stopPostTimer()
        clearRfdBuffer()
    }
    
    func updateCurPmResult(curPmResult: FineLocationTrackingOutput) {
        self.curPmResult = curPmResult
    }

    private func handlePostTimerTick() {
        guard let request = makeBufferedRequestForLastFiveSeconds(curPmResult: self.curPmResult) else {
            return
        }

        JupiterNetworkManager.shared.postLSE(url: JupiterNetworkConstants.getLocationSingleEpochURL(), input: request.payload) { statusCode, returnedString, requestPayload in
//            LSELogger.i(
//                tag: "LSEManager",
//                message: "(postLSE) statusCode=\(statusCode), sectorId=\(requestPayload.sector_code), buildingId=\(requestPayload.building_code), requestContext=\(request.context), response=\(returnedString)"
//            )

            let result = self.makeSingleEpochResult(
                statusCode: statusCode,
                returnedString: returnedString
            )
            self.delegate?.lseManager(
                self,
                didReceiveSingleEpochResult: result,
                requestPayload: requestPayload,
                requestContext: request.context
            )
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

    private func makeBufferedRequestForLastFiveSeconds(curPmResult: FineLocationTrackingOutput?) -> (payload: LocationRequestPayload, context: LSERequestContext?)? {
        guard let resourceManager = self.resourceManager else { return nil }
        var requestContext: LSERequestContext?
        if let curPmResult = curPmResult {
            if let buildingId = resourceManager.getBuildingId(buildingName: curPmResult.building_name),
               let levelId = resourceManager.getLevelId(
                sectorId: self.sectorId,
                buildingName: curPmResult.building_name,
                levelName: curPmResult.level_name
            ) {
                requestContext = LSERequestContext(
                    index: curPmResult.index,
                    buildingName: curPmResult.building_name,
                    buildingId: buildingId,
                    levelName: curPmResult.level_name,
                    levelId: levelId,
                    x: curPmResult.x,
                    y: curPmResult.y
                )
            }
        }
        
        let currentTime = TJLabsUtilFunctions.shared.getCurrentTimeInMilliseconds(as: .int) as! Int
        let windowStart = currentTime - payloadWindowMillis

        return rfdBufferQueue.sync {
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

            let payload = LocationRequestPayload(
                trace_id: self.traceId,
                external_name: self.externalName,
                tenant_name: self.tenantName,
                app_name: self.algorithmMode,
                sector_code: self.sectorId,
                building_code: requestContext?.buildingId,
                algorithm_mode: self.algorithmMode,
                measurements: measurements
            )
            
            return (payload: payload, context: requestContext)
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
