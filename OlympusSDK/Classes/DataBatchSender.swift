
import TJLabsCommon

class DataBatchSender {
    static let shared = DataBatchSender()
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
    
    func sendMobileResult(mobileResult: MobileResult) {
        inputMobileResultArray.append(mobileResult)
        if inputMobileResultArray.count >= MOBILE_RESULT_BUFFER_LENGTH {
            let resultURL = JupiterNetworkConstants.getRecMobileResultURL()
            JupiterNetworkManager.shared.postMobileResult(url: resultURL, input: inputMobileResultArray, completion: { statusCode, returnedString, _ in
                let successRange = 200..<300
                if !successRange.contains(statusCode) {
                    JupiterLogger.e(tag: "DataBatchSender", message: "(sendMobileResult) \(statusCode), \(returnedString)")
                }
            })
            inputMobileResultArray.removeAll()
        }
    }
    
    func sendMobileReport(report: MobileReport) {
        let reportURL = JupiterNetworkConstants.getRecMobileReportURL()
        JupiterNetworkManager.shared.postMobileReport(url: reportURL, input: report, completion: { [self] _,_,_ in
        })
    }
}
