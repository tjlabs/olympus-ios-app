
import Foundation
import UIKit
import TJLabsCommon

protocol StateManagerDelegate: AnyObject {
    func onStateReported(_ code: JupiterServiceCode)
}

class JupiterStateManager {
    
    init() {
        registerAppStateNotifications()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - BLE
    private var timeBleOff: Double = 0
    private var bleOffReported: Bool = false
    private var bleScanStopReportedTime: Double = 0
    let BLE_OFF_THRESHOLD: Double = 10
    
    // MARK: - Network
    private var networkCount: Int = 0
    private var networkFailReported: Bool = false
    let NETWORK_FAIL_THRESHOLD: Int = 10
    
    weak var delegate: StateManagerDelegate?
    
    private func registerAppStateNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
    }
    
    @objc private func handleWillEnterForeground() {
        delegate?.onStateReported(.BECOME_FOREGROUND)
    }
    
    @objc private func handleDidEnterBackground() {
        delegate?.onStateReported(.BECOME_BACKGROUND)
    }
    
    func checkBleOff(bluetoothReady: Bool, bleLastScannedTime: Double) {
        if !bluetoothReady {
            timeBleOff += JupiterTime.RFD_INTERVAL
            if (timeBleOff >= BLE_OFF_THRESHOLD) && !bleOffReported {
                timeBleOff = 0
                bleOffReported = true
                delegate?.onStateReported(.BLUETOOTH_OFF)
            }
        } else {
            let currentTime = TJLabsUtilFunctions.shared.getCurrentTimeInMilliseconds(as: .double) as! Double
            let scannedTime = Double(currentTime - bleLastScannedTime)*1e-3
            let reportedTime = Double(currentTime) - bleScanStopReportedTime
            if scannedTime >= 5 && reportedTime >= 5 {
                bleScanStopReportedTime = currentTime
                delegate?.onStateReported(.BLUETOOTH_SCAN_STOP)
            }
        }
    }
    
    func checkNetworkConnection() {
        let (isConnected, _) = JupiterNetworkManager.shared.isConnectedToInternet()
        if !isConnected {
            networkCount += 1
            if (networkCount >= NETWORK_FAIL_THRESHOLD) && !networkFailReported {
                networkCount = 0
                networkFailReported = true
                delegate?.onStateReported(.NETWORK_DISCONNECT)
            }
        }
    }
}
