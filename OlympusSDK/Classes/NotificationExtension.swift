import Foundation

extension Notification.Name {
    public static let bluetoothReady                  = Notification.Name("olmypusBluetoothReady")
    public static let startScan                       = Notification.Name("olmypusStartScan")
    public static let stopScan                        = Notification.Name("olmypusStopScan")
    public static let foundDevice                     = Notification.Name("olmypusFoundDevice")
    public static let deviceConnected                 = Notification.Name("olmypusDeviceConnected")
    public static let deviceReady                     = Notification.Name("olmypusDeviceReady")
    public static let didReceiveData                  = Notification.Name("olmypusDidReceiveData")
    public static let scanInfo                        = Notification.Name("olmypusScanInfo")
    public static let notificationEnabled             = Notification.Name("olmypusNotificationEnabled")
    public static let serviceStarted                  = Notification.Name("olympusStarted")
    public static let didEnterBackground              = Notification.Name("olmypusDidEnterBackground")
    public static let didBecomeActive                 = Notification.Name("olmypusDidBecomeActive")
    
}
