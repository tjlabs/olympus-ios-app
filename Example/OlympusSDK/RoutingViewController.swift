
import UIKit
import SnapKit
import Then
import DropDown

class RoutingViewController: UIViewController {
    
    private let routingTitleLabel: UILabel = {
        let label = UILabel()
        label.backgroundColor = .clear
        label.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        label.textColor = .black
        label.textAlignment = .left
        label.text = "목적지 설정"
        return label
    }()
    
    private var routingMenuView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.white
        view.isUserInteractionEnabled = true
        view.addShadow(offset: CGSize(width: 0.5, height: 0.5), opacity: 0.5)
        view.cornerRadius = 10
        view.isHidden = false
        return view
    }()

    private let routingMenuChevronImageView: UIImageView = {
        let iv = UIImageView(image: UIImage(systemName: "chevron.down"))
        iv.tintColor = .systemGray3
        iv.contentMode = .scaleAspectFit
        return iv
    }()
    
    private var routingMenuLabel: UILabel = {
        let label = UILabel()
        label.backgroundColor = .clear
        label.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        label.textColor = .systemGray4
        label.textAlignment = .left
        label.text = "선택 안함"
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
    
    let dropDown = DropDown()
    var region: String = ""
    var userId: String = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupLayout()
        bindActions()

        // Initial state
        routingMenuLabel.text = "COEX 아쿠아리움"
        routingMenuLabel.textColor = .black
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setupDropDown()
    }
    
    func setupLayout() {
        view.backgroundColor = UIColor(hex: "#F3F5F7")

        view.addSubview(routingTitleLabel)
        view.addSubview(routingMenuView)
        routingMenuView.addSubview(routingMenuLabel)
        routingMenuView.addSubview(routingMenuChevronImageView)

        view.addSubview(routingButton)
        routingButton.addSubview(routingButtonTitleLabel)

        view.addSubview(safeDrivingButton)
        safeDrivingButton.addSubview(safeDrivingButtonTitleLabel)

        routingTitleLabel.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top).offset(24)
            make.left.equalToSuperview().offset(24)
            make.right.lessThanOrEqualToSuperview().offset(-24)
        }

        routingMenuView.snp.makeConstraints { make in
            make.top.equalTo(routingTitleLabel.snp.bottom).offset(12)
            make.left.equalToSuperview().offset(24)
            make.right.equalToSuperview().offset(-24)
            make.height.equalTo(48)
        }

        routingMenuLabel.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.left.equalToSuperview().offset(16)
            make.right.lessThanOrEqualTo(routingMenuChevronImageView.snp.left).offset(-12)
        }

        routingMenuChevronImageView.snp.makeConstraints { make in
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
    }
    
    func setupDropDown() {
        dropDown.anchorView = routingMenuView
        dropDown.direction = .bottom
        dropDown.dismissMode = .automatic
        dropDown.backgroundColor = .white
        dropDown.shadowRadius = 6
        dropDown.cellHeight = 44

        dropDown.dataSource = [
            "COEX 별마당 도서관",
            "COEX 메가박스",
            "COEX 아쿠아리움",
            "COEX 전시장"
        ]

        // Full width under the menu view
        dropDown.width = routingMenuView.frame.width
        dropDown.bottomOffset = CGPoint(x: 0, y: 49)
//        dropDown.bottomOffset = CGPoint(x: 0, y:(dropDown.anchorView?.plainView.bounds.height)!)
        
        dropDown.customCellConfiguration = { [weak self] (index: Index, item: String, cell: DropDownCell) in
            cell.optionLabel.font = UIFont.systemFont(ofSize: 16, weight: .regular)
            cell.optionLabel.textColor = .black
            _ = self
        }

        dropDown.selectionAction = { [weak self] (index: Int, item: String) in
            guard let self = self else { return }
            self.routingMenuLabel.text = item
            self.routingMenuLabel.textColor = .black
            self.routingMenuChevronImageView.image = UIImage(systemName: "chevron.down")
        }

        dropDown.cancelAction = { [weak self] in
            self?.routingMenuChevronImageView.image = UIImage(systemName: "chevron.down")
        }
    }
    
    func bindActions() {
        let menuTap = UITapGestureRecognizer(target: self, action: #selector(didTapMenu))
        routingMenuView.addGestureRecognizer(menuTap)

        let routingTap = UITapGestureRecognizer(target: self, action: #selector(didTapRoutingStart))
        routingButton.addGestureRecognizer(routingTap)

        let safeTap = UITapGestureRecognizer(target: self, action: #selector(didTapSafeDrivingStart))
        safeDrivingButton.addGestureRecognizer(safeTap)
    }

    @objc private func didTapMenu() {
        // Ensure width is correct after layout
        dropDown.width = routingMenuView.bounds.width

        if dropDown.isHidden {
            routingMenuChevronImageView.image = UIImage(systemName: "chevron.up")
            dropDown.show()
        } else {
            routingMenuChevronImageView.image = UIImage(systemName: "chevron.down")
            dropDown.hide()
        }
    }

    @objc private func didTapRoutingStart() {
//        goToMapViewController(userId: userId)
        goToCardViewController(region: region, userId: userId)
    }

    @objc private func didTapSafeDrivingStart() {
        goToCardViewController(region: region, userId: userId)
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
}
