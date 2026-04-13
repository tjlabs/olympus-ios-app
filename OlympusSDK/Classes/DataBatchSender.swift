
import TJLabsCommon

class DataBatchSender {
    static let shared = DataBatchSender()
    init() { }
    
    private let MOBILE_RESULT_BUFFER_LENGTH: Int = 20
    private var inputMobileResultArray = [MobileResult]()
    
    var sendRfdLength = 2
    var sendUvdLength = 4
    
    var lastPostedUvdIndex = 0
    
    func initialize() {
        inputMobileResultArray = [MobileResult]()
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
