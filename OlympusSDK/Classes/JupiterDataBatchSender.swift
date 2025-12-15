
import TJLabsCommon

class JupiterDataBatchSender {
    static let shared = JupiterDataBatchSender()
    init() { }
    
    private let MOBILE_RESULT_BUFFER_LENGTH: Int = 20
    
    private var inputReceivedForceArray = [ReceivedForce]()
    private var inputUserVelocityArray = [UserVelocity]()
    private var inputMobileResultArray = [MobileResult]()
    
    var sendRfdLength = 2
    var sendUvdLength = 4
    
    var lastPostedUvdIndex = 0
    
    func initialize() {
        inputReceivedForceArray = [ReceivedForce]()
        inputUserVelocityArray = [UserVelocity]()
        inputMobileResultArray = [MobileResult]()
    }
    
    func sendRfd(rfd: ReceivedForce) {
        let rfdURL = JupiterNetworkConstants.getRecRfdURL()
        inputReceivedForceArray.append(rfd)
        if inputReceivedForceArray.count >= sendRfdLength {
            JupiterNetworkManager.shared.postReceivedForce(url: rfdURL, input: inputReceivedForceArray) { [self] statusCode, returnedString, inputRfd in
            }
            inputReceivedForceArray.removeAll()
        }
    }
    
    func sendUvd(uvd: UserVelocity) {
        let uvdURL = JupiterNetworkConstants.getRecUvdURL()
        inputUserVelocityArray.append(uvd)
        if inputUserVelocityArray.count >= sendUvdLength {
            JupiterNetworkManager.shared.postUserVelocity(url: uvdURL, input: inputUserVelocityArray) { [self] statusCode, returnedString, inputUvd in
                lastPostedUvdIndex = inputUvd[inputUvd.count-1].index
            }
            inputUserVelocityArray.removeAll()
        }
    }
    
    func sendMobileResult(userId: String, sectorId: Int, result: JupiterResult, normalizationScale: Float, deviceMinRss: Float) {
        let currentTime = TJLabsUtilFunctions.shared.getCurrentTimeInMilliseconds(as: .int) as! Int
        let mobileResult = MobileResult(tenant_user_name: userId,
                                        mobile_time: currentTime,
                                        index: result.index,
                                        sector_id: sectorId,
                                        building_name: result.building_name,
                                        level_name: result.level_name,
                                        x: result.x,
                                        y: result.y,
                                        scc: result.scc,
                                        phase: result.phase,
                                        absolute_heading: result.absolute_heading,
                                        normalization_scale: normalizationScale,
                                        device_min_rss: Int(deviceMinRss),
                                        sc_compensation: 1.0,
                                        ble_only_position: result.ble_only_position,
                                        is_indoor: result.isIndoor,
                                        in_out_state: JupiterInOutState.curInOutState.rawValue,
                                        latitude: result.llh?.lat,
                                        longitude: result.llh?.lon,
                                        velocity: result.velocity,
                                        calculated_time: result.calculated_time)
        inputMobileResultArray.append(mobileResult)
        if inputMobileResultArray.count >= MOBILE_RESULT_BUFFER_LENGTH {
            let resultURL = JupiterNetworkConstants.getRecMobileResultURL()
            JupiterNetworkManager.shared.postMobileResult(url: resultURL, input: inputMobileResultArray, completion: { [self] statusCode, returnedString, _ in
            })
            inputMobileResultArray.removeAll()
        }
    }
    
    func sendMobileReport(report: MobileReport) {
        let reportURL = JupiterNetworkConstants.getRecMobileReportURL()
        JupiterNetworkManager.shared.postMobileReport(url: reportURL, input: report, completion: { [self] _,_,_ in
        })
    }
    
    func sendRssiCompensation(sectorId: Int, deviceModel: String, deviceOsVersion: Int, normalizationScale: Float) {
        let rcURL = JupiterNetworkConstants.getUserRcURL()
        let rcInfo = RcInfoSave(sector_id: sectorId, device_model: deviceModel, os_version: deviceOsVersion, normalization_scale: normalizationScale)
        JupiterNetworkManager.shared.postParam(url: rcURL, input: rcInfo, completion: { [self] statusCode, retunedString, _ in
        })
    }
}
