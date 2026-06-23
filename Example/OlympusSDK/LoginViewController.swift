import UIKit
import OlympusSDK
import TJLabsAuth

class LoginViewController: UIViewController, UITextFieldDelegate {
    private enum ConfigKeys {
        static let accessKey = "TJLABS_AUTH_ACCESS_KEY"
        static let secretAccessKey = "TJLABS_AUTH_SECRET_ACCESS_KEY"
    }

    @IBOutlet weak var idTextField: UITextField!
    @IBOutlet weak var saveIdButton: UIButton!
    @IBOutlet weak var guideLabel: UILabel!
    @IBOutlet weak var sdkVersionLabel: UILabel!
    
    let userDefaults = UserDefaults.standard
    
    var isSaveId: Bool = false
    var userId: String = ""
    var deviceModel: String = ""
    var deviceOsInfo: String = ""
    var deviceOsVersion: Int = 0
    var sdkVersion: String = ""
    
    var regions: [String] = ["Korea", "Canada", "US-East"]
    var currentRegion: String = "Korea"
    var defaultMeasage: String = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setDeviceInfo()
        setLocaleInfo()
        let clientMeta = self.makeClientMeta()
        SecretConfig.set(customerKey: "JUPITER", clientMeta: clientMeta)
        TJLabsAuthConstants.setServerURL(cloud: "GCP", region: AuthRegion.KOREA.rawValue, serverType: "jupiter")
        guard
            let accessKey = nonEmptyInfoValue(forKey: ConfigKeys.accessKey),
            let secretAccessKey = nonEmptyInfoValue(forKey: ConfigKeys.secretAccessKey)
        else {
            print("(LoginVC) Missing TJLabs auth config in Info.plist")
            return
        }

        TJLabsAuthManager.shared.auth(accessKey: accessKey, secretAccessKey: secretAccessKey, completion: { [self] statusCode, success in
            print("(TJLabsAuthManager) TJLabsAuth : \(statusCode), \(success)")
        })
        
        if let name = userDefaults.string(forKey: "uuid") {
            idTextField.text = name
            saveIdButton.isSelected.toggle()
            isSaveId = true
        }
        idTextField.delegate = self
        setServerURL(region: self.currentRegion)
    }
    
    private func makeClientMeta() -> ClientMeta {
        let clientSdks = [
            SdkMeta(name: "TJLabsCommon", version: "0.1.3"),
            SdkMeta(name: "TJLabsResource", version: "0.1.4"),
            SdkMeta(name: "TJLabsJupiter", version: "2.0.7"),
        ]
        
        let bundleIdentifier = Bundle.main.bundleIdentifier ?? ""
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
        
        let appVersion: String = version + "(\(build))"
        let appPackage: String = bundleIdentifier
        let deviceMode: String = self.deviceModel
        let osVersion: String = self.deviceOsInfo
        
        let clientMeta = ClientMeta(
            app_version: appVersion,
            app_package: appPackage,
            device_model: deviceMode,
            os_version: osVersion,
            sdks: clientSdks
        )
        
        return clientMeta
    }

    private func nonEmptyInfoValue(forKey key: String) -> String? {
        guard let rawValue = Bundle.main.object(forInfoDictionaryKey: key) as? String else {
            return nil
        }

        let trimmedValue = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedValue.isEmpty else {
            return nil
        }

        return trimmedValue
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        self.idTextField.resignFirstResponder()
        return true
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?){
             self.view.endEditing(true)
       }
    
    func goToCardViewController(region: String, userId: String) {
        guard let cardVC = self.storyboard?.instantiateViewController(withIdentifier: "CardViewController") as? CardViewController else { return }
        cardVC.region = region
        cardVC.userId = userId
        
        self.navigationController?.pushViewController(cardVC, animated: true)
    }
    
    func goToMapViewController(userId: String) {
        guard let mapVC = self.storyboard?.instantiateViewController(withIdentifier: "MapViewController") as? MapViewController else { return }
        mapVC.userId = userId
        self.navigationController?.pushViewController(mapVC, animated: true)
    }
    
    func goToRoutingViewController(region: String, userId: String) {
        guard let routingVC = self.storyboard?.instantiateViewController(withIdentifier: "RoutingViewController") as? RoutingViewController else { return }
        routingVC.region = region
        routingVC.userId = userId
        self.navigationController?.pushViewController(routingVC, animated: true)
    }
    
    @IBAction func tapSaveUserIdButton(_ sender: UIButton) {
        UIView.animate(withDuration: 0.2, delay: 0.0, options: .curveLinear, animations: {
        }) { (success) in
            sender.isSelected = !sender.isSelected
            UIView.animate(withDuration: 0.2, delay: 0.0, options: .curveLinear, animations: {
                sender.transform = .identity
            }, completion: nil)
        }
        
        if sender.isSelected == false {
            isSaveId = true
        }
        else {
            isSaveId = false
        }
    }
    
    @IBAction func tapLoginButton(_ sender: UIButton) {
        self.userId = idTextField.text ?? ""
        if (userId == "" || userId.contains(" ")) {
            guideLabel.isHidden = false
        } else {
            if (isSaveId) {
                userDefaults.set(self.userId, forKey: "uuid")
            } else {
                userDefaults.set(nil, forKey: "uuid")
            }
            userDefaults.synchronize()
            
            loginUser()
        }
    }
    
    func setDeviceInfo() {
        deviceModel = UIDevice.modelName
        deviceOsInfo = UIDevice.current.systemVersion
        let arr = deviceOsInfo.components(separatedBy: ".")
        deviceOsVersion = Int(arr[0]) ?? 0
        self.sdkVersionLabel.text = self.sdkVersion
    }
    
    func setLocaleInfo() {
        let locale = Locale.current
        if let countryCode = locale.regionCode, countryCode == "KR" {
            self.currentRegion = "Korea"
        } else {
            self.currentRegion = "Canada"
        }
    }
    
    func loginUser() {
        let loginInfo = LoginInfo(user_id: self.userId, device_model: self.deviceModel, os_version: self.deviceOsVersion, sdk_version: self.sdkVersion)
        NetworkManager.shared.postUserLogin(url: USER_LOGIN_URL, input: loginInfo, completion: { statusCode, returnedString in
            if (statusCode == 200) {
//                print(getLocalTimeString() + " , (InnerLabs) Success : User Login")
//                self.goToRoutingViewController(region: "Korea", userId: self.userId)
                self.goToCardViewController(region: "Korea", userId: self.userId)
//                self.goToMapViewController(userId: self.userId)
//                self.goToMapScaleViewController(userId: self.userId)
            } else {
                print("(LoginVC) Fail : User Login \(statusCode)")
                print(returnedString)
            }
        })
    }
}
