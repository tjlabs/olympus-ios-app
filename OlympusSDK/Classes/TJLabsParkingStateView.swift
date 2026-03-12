
import UIKit
import TJLabsResource

class TJLabsParkingStateView: UIView {
    var sectorInfo: SectorOutput?
    
    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(hex: "#C0D6FF")
        view.layer.cornerRadius = 12
        view.addShadow(offset: CGSize(width: 0, height: 1), color: .black, opacity: 0.2, radius: 4)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14, weight: .bold)
        label.textColor = .white
        label.text = "주차가능대수"
        label.textAlignment = .left
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.5
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let descLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 10, weight: .medium)
        label.textColor = .white
        label.text = "층별현황"
        label.textAlignment = .left
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.5
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    init(sectorInfo: SectorOutput) {
        super.init(frame: .zero)
        self.sectorInfo = sectorInfo
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
        guard let sectorInfo = self.sectorInfo else { return }
        
        let buildings = sectorInfo.buildings
        
        addSubview(containerView)
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: topAnchor),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor),
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
    }
    
    private func bindActions() {

    }
}
