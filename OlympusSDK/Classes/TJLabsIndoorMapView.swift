
import UIKit
import TJLabsResource
import TJLabsMap

class TJLabsIndoorMapView: UIView {
    var region: String?
    var sectorId: Int?
    
    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = .white
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    let mapView = TJLabsMapView()
    
    init(region: String, sectorId: Int) {
        super.init(frame: .zero)
        self.region = region
        self.sectorId = sectorId
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
        addSubview(containerView)
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: topAnchor),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor),
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
        self.setupMapView()
    }
    
    private func bindActions() {

    }
    
    private func setupMapView() {
        guard let region = self.region, let sectorId = self.sectorId else { return }
        mapView.initialize(region: region, sectorId: sectorId)
        mapView.configureFrame(to: self.containerView)
        mapView.setZoomScale(zoom: 2.0)
        addSubview(mapView)
    }
}
