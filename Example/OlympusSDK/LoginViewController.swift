import UIKit
import OlympusSDK
import TJLabsAuth

class LoginViewController: UIViewController, UITextFieldDelegate {

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
        SecretConfig.set(clientKey: "3c5df65e643ba2668aba5c6e5cab9f68", clientSecret: "4b05476b158bce1df2afe9b0c6760b679be378669da117924e2f4e36de5e46d4")
        TJLabsAuthManager.shared.auth(accessKey: "AK_-xVNF3MeRzQMhBIVLU5GQ", secretAccessKey: "SK1nVeBlJldifxC7z8vD8ZeercMgrSqmzNzz5RItSrDaM", completion: { [self] statusCode, success in
            print("(TJLabsAuthManager) TJLabsAuth : \(statusCode), \(success)")
        })
        
        if let name = userDefaults.string(forKey: "uuid") {
            idTextField.text = name
            saveIdButton.isSelected.toggle()
            isSaveId = true
        }
        idTextField.delegate = self
        
        setDeviceInfo()
        setLocaleInfo()
        setServerURL(region: self.currentRegion)
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
                self.goToRoutingViewController(region: "Korea", userId: self.userId)
//                self.goToCardViewController(region: "Korea", userId: self.userId)
//                self.goToMapViewController(userId: self.userId)
//                self.goToMapScaleViewController(userId: self.userId)
            } else {
                print("(LoginVC) Fail : User Login \(statusCode)")
                print(returnedString)
            }
        })
    }
}
