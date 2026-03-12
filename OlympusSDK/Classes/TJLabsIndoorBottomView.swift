
import UIKit
import TJLabsResource

class TJLabsIndoorBottomView: UIView {
    var buildingInfo: BuildingOutput?
    
    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.layer.cornerRadius = 12
        view.addShadow(offset: CGSize(width: 0, height: 1), color: .black, opacity: 0.2, radius: 4)
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
        guard let buildingInfo = self.buildingInfo else { return }
        
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
