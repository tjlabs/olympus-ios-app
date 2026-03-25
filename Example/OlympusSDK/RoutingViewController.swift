
import UIKit
import SnapKit
import Then
import DropDown

class RoutingViewController: UIViewController {
    
    //MARK: - 출발지 설정
    private let fromTitleLabel: UILabel = {
        let label = UILabel()
        label.backgroundColor = .clear
        label.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        label.textColor = .black
        label.textAlignment = .left
        label.text = "출발지 설정"
        return label
    }()
    
    private var fromMenuView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.white
        view.isUserInteractionEnabled = true
        view.addShadow(offset: CGSize(width: 0.5, height: 0.5), opacity: 0.5)
        view.cornerRadius = 10
        view.isHidden = false
        return view
    }()

    private let fromMenuChevronImageView: UIImageView = {
        let iv = UIImageView(image: UIImage(systemName: "chevron.down"))
        iv.tintColor = .systemGray3
        iv.contentMode = .scaleAspectFit
        return iv
    }()
    
    private var fromMenuLabel: UILabel = {
        let label = UILabel()
        label.backgroundColor = .clear
        label.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        label.textColor = .systemGray4
        label.textAlignment = .left
        label.text = "선택 안함"
        return label
    }()
    
    //MARK: - 목적지 설정
    private let destTitleLabel: UILabel = {
        let label = UILabel()
        label.backgroundColor = .clear
        label.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        label.textColor = .black
        label.textAlignment = .left
        label.text = "목적지 설정"
        return label
    }()
    
    private var destMenuView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.white
        view.isUserInteractionEnabled = true
        view.addShadow(offset: CGSize(width: 0.5, height: 0.5), opacity: 0.5)
        view.cornerRadius = 10
        view.isHidden = false
        return view
    }()

    private let destMenuChevronImageView: UIImageView = {
        let iv = UIImageView(image: UIImage(systemName: "chevron.down"))
        iv.tintColor = .systemGray3
        iv.contentMode = .scaleAspectFit
        return iv
    }()
    
    private var destMenuLabel: UILabel = {
        let label = UILabel()
        label.backgroundColor = .clear
        label.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        label.textColor = .systemGray4
        label.textAlignment = .left
        label.text = "선택 안함"
        return label
    }()
    
    private var mapButton: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(hex: "#3fb1e5")
        view.isUserInteractionEnabled = true
        view.addShadow(offset: CGSize(width: 0.5, height: 0.5), opacity: 0.5)
        view.cornerRadius = 8
        view.isHidden = false
        return view
    }()
    
    private let mapButtonTitleLabel: UILabel = {
        let label = UILabel()
        label.backgroundColor = .clear
        label.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        label.textColor = .white
        label.textAlignment = .center
        label.text = "실내 지도"
        return label
    }()
    
    private var routingButton: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(hex: "#3fb1e5")
        view.isUserInteractionEnabled = true
        view.addShadow(offset: CGSize(width: 0.5, height: 0.5), opacity: 0.5)
        view.cornerRadius = 8
        view.isHidden = false
        return view
    }()
    
    private let routingButtonTitleLabel: UILabel = {
        let label = UILabel()
        label.backgroundColor = .clear
        label.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        label.textColor = .white
        label.textAlignment = .center
        label.text = "길안내 시작"
        return label
    }()
    
    private var safeDrivingButton: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(hex: "#3fb1e5")
        view.isUserInteractionEnabled = true
        view.addShadow(offset: CGSize(width: 0.5, height: 0.5), opacity: 0.5)
        view.cornerRadius = 8
        view.isHidden = false
        return view
    }()
    
    private let safeDrivingButtonTitleLabel: UILabel = {
        let label = UILabel()
        label.backgroundColor = .clear
        label.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        label.textColor = .white
        label.textAlignment = .center
        label.text = "안전 주행 시작"
        return label
    }()
    
    let fromDropDown = DropDown()
    let destDropDown = DropDown()
    var region: String = ""
    var userId: String = ""

    // Currently selected 'from' item (fromDropDown)
    private var selectedFromItem: String?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupLayout()
        bindActions()

        // Initial state
        fromMenuLabel.text = "1번 진출입로"
        fromMenuLabel.textColor = .black
        selectedFromItem = fromMenuLabel.text
        
        destMenuLabel.text = "COEX 아쿠아리움"
        destMenuLabel.textColor = .black
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setupDropDown()
    }
    
    func setupLayout() {
        view.backgroundColor = UIColor(hex: "#F3F5F7")

        view.addSubview(fromTitleLabel)
        view.addSubview(fromMenuView)
        fromMenuView.addSubview(fromMenuLabel)
        fromMenuView.addSubview(fromMenuChevronImageView)
        
        view.addSubview(destTitleLabel)
        view.addSubview(destMenuView)
        destMenuView.addSubview(destMenuLabel)
        destMenuView.addSubview(destMenuChevronImageView)
        
        view.addSubview(mapButton)
        mapButton.addSubview(mapButtonTitleLabel)
        
        view.addSubview(routingButton)
        routingButton.addSubview(routingButtonTitleLabel)

        view.addSubview(safeDrivingButton)
        safeDrivingButton.addSubview(safeDrivingButtonTitleLabel)
        
        fromTitleLabel.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top).offset(24)
            make.left.equalToSuperview().offset(24)
            make.right.lessThanOrEqualToSuperview().offset(-24)
        }

        fromMenuView.snp.makeConstraints { make in
            make.top.equalTo(fromTitleLabel.snp.bottom).offset(12)
            make.left.equalToSuperview().offset(24)
            make.right.equalToSuperview().offset(-24)
            make.height.equalTo(48)
        }

        fromMenuLabel.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.left.equalToSuperview().offset(16)
            make.right.lessThanOrEqualTo(fromMenuChevronImageView.snp.left).offset(-12)
        }

        fromMenuChevronImageView.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.right.equalToSuperview().offset(-16)
            make.width.height.equalTo(24)
        }
        
        destTitleLabel.snp.makeConstraints { make in
            make.top.equalTo(fromMenuView.snp.bottom).offset(24)
            make.left.equalToSuperview().offset(24)
            make.right.lessThanOrEqualToSuperview().offset(-24)
        }

        destMenuView.snp.makeConstraints { make in
            make.top.equalTo(destTitleLabel.snp.bottom).offset(12)
            make.left.equalToSuperview().offset(24)
            make.right.equalToSuperview().offset(-24)
            make.height.equalTo(48)
        }

        destMenuLabel.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.left.equalToSuperview().offset(16)
            make.right.lessThanOrEqualTo(destMenuChevronImageView.snp.left).offset(-12)
        }

        destMenuChevronImageView.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.right.equalToSuperview().offset(-16)
            make.width.height.equalTo(24)
        }

        safeDrivingButton.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(24)
            make.right.equalToSuperview().offset(-24)
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom).offset(-24)
            make.height.equalTo(52)
        }

        safeDrivingButtonTitleLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }

        routingButton.snp.makeConstraints { make in
            make.left.right.height.equalTo(safeDrivingButton)
            make.bottom.equalTo(safeDrivingButton.snp.top).offset(-12)
        }

        routingButtonTitleLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
        
        mapButton.snp.makeConstraints { make in
            make.left.right.height.equalTo(routingButton)
            make.bottom.equalTo(routingButton.snp.top).offset(-12)
        }

        mapButtonTitleLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
    }
    
    func setupDropDown() {
        // MARK: - From
        fromDropDown.anchorView = fromMenuView
        fromDropDown.direction = .bottom
        fromDropDown.dismissMode = .automatic
        fromDropDown.backgroundColor = .white
        fromDropDown.shadowRadius = 6
        fromDropDown.cellHeight = 44

        fromDropDown.dataSource = [
            "1번 진출입로",
            "3번 진출입로",
            "4번 진출입로",
        ]

        // Full width under the menu view
        fromDropDown.width = fromMenuView.frame.width
        fromDropDown.bottomOffset = CGPoint(x: 0, y: 49)
        
        fromDropDown.customCellConfiguration = { [weak self] (index: Index, item: String, cell: DropDownCell) in
            cell.optionLabel.font = UIFont.systemFont(ofSize: 16, weight: .regular)
            cell.optionLabel.textColor = .black
            _ = self
        }

        fromDropDown.selectionAction = { [weak self] (index: Int, item: String) in
            guard let self = self else { return }
            self.selectedFromItem = item
            self.fromMenuLabel.text = item
            self.fromMenuLabel.textColor = .black
            self.fromMenuChevronImageView.image = UIImage(systemName: "chevron.down")
        }

        fromDropDown.cancelAction = { [weak self] in
            self?.fromMenuChevronImageView.image = UIImage(systemName: "chevron.down")
        }
        
        // MARK: - Dest
        destDropDown.anchorView = destMenuView
        destDropDown.direction = .bottom
        destDropDown.dismissMode = .automatic
        destDropDown.backgroundColor = .white
        destDropDown.shadowRadius = 6
        destDropDown.cellHeight = 44

        destDropDown.dataSource = [
            "COEX 별마당 도서관",
            "COEX 메가박스",
            "COEX 아쿠아리움",
            "COEX 전시장"
        ]

        // Full width under the menu view
        destDropDown.width = destMenuView.frame.width
        destDropDown.bottomOffset = CGPoint(x: 0, y: 49)
        
        destDropDown.customCellConfiguration = { [weak self] (index: Index, item: String, cell: DropDownCell) in
            cell.optionLabel.font = UIFont.systemFont(ofSize: 16, weight: .regular)
            cell.optionLabel.textColor = .black
            _ = self
        }

        destDropDown.selectionAction = { [weak self] (index: Int, item: String) in
            guard let self = self else { return }
            self.destMenuLabel.text = item
            self.destMenuLabel.textColor = .black
            self.destMenuChevronImageView.image = UIImage(systemName: "chevron.down")
        }

        destDropDown.cancelAction = { [weak self] in
            self?.destMenuChevronImageView.image = UIImage(systemName: "chevron.down")
        }
    }
    
    func bindActions() {
        let fromMenuTap = UITapGestureRecognizer(target: self, action: #selector(didTapFromMenu))
        fromMenuView.addGestureRecognizer(fromMenuTap)
        
        let destMenuTap = UITapGestureRecognizer(target: self, action: #selector(didTapDestMenu))
        destMenuView.addGestureRecognizer(destMenuTap)
        
        let mapTap = UITapGestureRecognizer(target: self, action: #selector(didTapIndoorMap))
        mapButton.addGestureRecognizer(mapTap)
        
        let routingTap = UITapGestureRecognizer(target: self, action: #selector(didTapRoutingStart))
        routingButton.addGestureRecognizer(routingTap)

        let safeTap = UITapGestureRecognizer(target: self, action: #selector(didTapSafeDrivingStart))
        safeDrivingButton.addGestureRecognizer(safeTap)
    }

    @objc private func didTapFromMenu() {
        fromDropDown.width = fromMenuView.bounds.width

        if fromDropDown.isHidden {
            fromMenuChevronImageView.image = UIImage(systemName: "chevron.up")
            fromDropDown.show()
        } else {
            fromMenuChevronImageView.image = UIImage(systemName: "chevron.down")
            fromDropDown.hide()
        }
    }
    
    @objc private func didTapDestMenu() {
        destDropDown.width = destMenuView.bounds.width

        if destDropDown.isHidden {
            destMenuChevronImageView.image = UIImage(systemName: "chevron.up")
            destDropDown.show()
        } else {
            destMenuChevronImageView.image = UIImage(systemName: "chevron.down")
            destDropDown.hide()
        }
    }
    
    @objc private func didTapIndoorMap() {
        goToMapViewController(userId: userId)
    }

    @objc private func didTapRoutingStart() {
//        goToNaviViewController(userId: userId)
        goToCardViewController(region: region, userId: userId)
    }

    @objc private func didTapSafeDrivingStart() {
        goToCardViewController(region: region, userId: userId, isSafeDriving: true)
//        goToNaviViewController(userId: userId, isSafeDriving: true)
//        goToIndoorViewController(userId: userId)
    }
    
    func goToCardViewController(region: String, userId: String, isSafeDriving: Bool = false) {
        guard let cardVC = self.storyboard?.instantiateViewController(withIdentifier: "CardViewController") as? CardViewController else { return }
        cardVC.region = region
        cardVC.userId = userId
        cardVC.fromSelectedName = selectedFromItem ?? fromMenuLabel.text
        cardVC.isSafeDriving = isSafeDriving
        
        self.navigationController?.pushViewController(cardVC, animated: true)
    }
    
    func goToMapViewController(userId: String) {
        guard let mapVC = self.storyboard?.instantiateViewController(withIdentifier: "MapViewController") as? MapViewController else { return }
        mapVC.userId = userId
        self.navigationController?.pushViewController(mapVC, animated: true)
    }
    
    func goToNaviViewController(userId: String, isSafeDriving: Bool = false) {
        guard let naviVC = self.storyboard?.instantiateViewController(withIdentifier: "NaviViewController") as? NaviViewController else { return }
        naviVC.userId = userId
        naviVC.fromSelectedName = selectedFromItem ?? fromMenuLabel.text
        naviVC.isSafeDriving = isSafeDriving
        self.navigationController?.pushViewController(naviVC, animated: true)
    }
    
    func goToIndoorViewController(userId: String, isSafeDriving: Bool = false) {
        guard let indoorVC = self.storyboard?.instantiateViewController(withIdentifier: "IndoorViewController") as? IndoorViewController else { return }
        indoorVC.userId = userId
        self.navigationController?.pushViewController(indoorVC, animated: true)
    }
}
