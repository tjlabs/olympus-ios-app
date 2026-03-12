
import UIKit
import SnapKit
import Then
import OlympusSDK

class IndoorViewController: UIViewController {
    var region: String = JupiterRegion.KOREA.rawValue
    var sectorId: Int = 6
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
        indoorView.initialize(region: self.region, sectorId: self.sectorId)
        indoorView.configureFrame(to: mainView)
        mainView.addSubview(indoorView)
    }
    
    private func bindActions() {
//        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleSaveButton))
    }
    
    @objc func handleSaveButton() {

    }
    
}
