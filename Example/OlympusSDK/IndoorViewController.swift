
import UIKit
import SnapKit
import Then
import OlympusSDK

class IndoorViewController: UIViewController {
    var region: String = JupiterRegion.KOREA.rawValue
    var sectorId: Int = 20
    var userId: String = ""
    
    private let mainView = UIView().then {
        $0.backgroundColor = .clear
    }
    
    let indoorView = TJLabsIndoorView()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        setupLayout()
        bindActions()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: false)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: false)
    }
    
    func setupLayout() {
        view.addSubview(mainView)
        mainView.snp.makeConstraints { make in
            make.top.bottom.leading.trailing.equalToSuperview()
        }
        
        setupIndoorView()
    }
    
    func setupIndoorView() {
        indoorView.setSimulationMode(flag: true, bleFileName: "ble_251013_songdo_test01_ent1.csv", sensorFileName: "sensor_251013_songdo_test01_ent1.csv")
        indoorView.initialize(region: self.region, sectorId: self.sectorId, userId: self.userId)
        indoorView.configureFrame(to: mainView)
        mainView.addSubview(indoorView)
    }
    
    private func bindActions() {
//        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleSaveButton))
    }
    
    @objc func handleSaveButton() {

    }
    
}
