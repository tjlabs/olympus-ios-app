import Foundation

extension Notification.Name {
    public static let bluetoothReady      = Notification.Name("bluetoothReady")
    public static let startScan           = Notification.Name("startScan")
    public static let stopScan            = Notification.Name("stopScan")
    public static let foundDevice         = Notification.Name("foundDevice")
    public static let deviceConnected     = Notification.Name("deviceConnected")
    public static let deviceReady         = Notification.Name("deviceReady")
    public static let didReceiveData      = Notification.Name("didReceiveData")
    public static let scanInfo            = Notification.Name("scanInfo")
    public static let notificationEnabled = Notification.Name("notificationEnabled")
    public static let didEnterBackground  = Notification.Name("didEnterBackground")
    public static let didBecomeActive     = Notification.Name("didBecomeActive")
    public static let didBecomeVenus      = Notification.Name("didBecomeActive")
    public static let didBecomeJupiter    = Notification.Name("didBecomeJupiter")
}
