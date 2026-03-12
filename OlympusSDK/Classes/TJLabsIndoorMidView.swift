import UIKit
import TJLabsResource

class TJLabsIndoorMidView: UIView {
    var onTapShowMap: (() -> Void)?
    
    var buildingInfo: BuildingOutput?
    var parkingStateView: TJLabsParkingStateView?
    var parkingInfoView: TJLabsParkingInfoView?
    var showMapView: TJLabsShowMapView?
    
    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.clear
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let contentsStackView: UIStackView = {
        let view = UIStackView()
        view.axis = .horizontal
        view.spacing = 0
        view.distribution = .fill
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    // MARK: - Left
    private let leftView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.clear
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    // MARK: - Right
    private let rightView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.clear
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let rightStackView: UIStackView = {
        let view = UIStackView()
        view.backgroundColor = UIColor.clear
        view.axis = .vertical
        view.spacing = 4
        view.distribution = .fill
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    init(buildingInfo: BuildingOutput) {
        super.init(frame: .zero)
        self.buildingInfo = buildingInfo
        commonInit()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func commonInit() {
        setupLayout()
        bindActions()
    }
    
    private func setupLayout() {
        guard let buildingInfo = buildingInfo else { return }
        
        addSubview(containerView)
        containerView.addSubview(contentsStackView)
        contentsStackView.addArrangedSubview(leftView)
        contentsStackView.addArrangedSubview(rightView)

        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: topAnchor),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor),
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            
            contentsStackView.topAnchor.constraint(equalTo: containerView.topAnchor),
            contentsStackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            contentsStackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            contentsStackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),

            leftView.widthAnchor.constraint(equalTo: contentsStackView.widthAnchor, multiplier: 1.2/3.0)
        ])
        
        self.parkingStateView = TJLabsParkingStateView(buildingInfo: buildingInfo)
        guard let parkingStateView = self.parkingStateView else { return }
        parkingStateView.translatesAutoresizingMaskIntoConstraints = false
        leftView.addSubview(parkingStateView)
        NSLayoutConstraint.activate([
            parkingStateView.topAnchor.constraint(equalTo: leftView.topAnchor, constant: 10),
            parkingStateView.bottomAnchor.constraint(equalTo: leftView.bottomAnchor, constant: -10),
            parkingStateView.leadingAnchor.constraint(equalTo: leftView.leadingAnchor, constant: 10),
            parkingStateView.trailingAnchor.constraint(equalTo: leftView.trailingAnchor, constant: -2.5)
        ])
        
        rightView.addSubview(rightStackView)
        NSLayoutConstraint.activate([
            rightStackView.topAnchor.constraint(equalTo: rightView.topAnchor, constant: 10),
            rightStackView.bottomAnchor.constraint(equalTo: rightView.bottomAnchor, constant: -10),
            rightStackView.leadingAnchor.constraint(equalTo: rightView.leadingAnchor, constant: 2.5),
            rightStackView.trailingAnchor.constraint(equalTo: rightView.trailingAnchor, constant: -10)
        ])
        
        self.parkingInfoView = TJLabsParkingInfoView(buildingInfo: buildingInfo)
        self.showMapView = TJLabsShowMapView()
        guard let parkingInfoView = self.parkingInfoView, let showMapView = self.showMapView else { return }
        parkingInfoView.translatesAutoresizingMaskIntoConstraints = false
        rightStackView.addArrangedSubview(parkingInfoView)
        rightStackView.addArrangedSubview(showMapView)
        NSLayoutConstraint.activate([
            parkingInfoView.heightAnchor.constraint(equalTo: rightStackView.heightAnchor, multiplier: 1.1/2.0)
        ])
        
        showMapView.onTapShowMap = { [weak self] in
            self?.onTapShowMap?()
        }
    }
    
    private func bindActions() {

    }
}
