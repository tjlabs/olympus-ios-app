
import UIKit
import TJLabsResource
import TJLabsMap

class TJLabsIndoorMapView: UIView, TJLabsMapViewDelegate {
    
    func didSelectUnit(_ view: TJLabsMap.TJLabsMapView, data: TJLabsResource.UnitData) {
        JupiterLogger.i(tag: "TJLabsIndoorMapView", message: "didSelect Unit: \(data)")
    }
    
    private var didSetupLayout = false
    
    var cloud: String?
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
        setupLayoutIfNeeded()
    }

    private func setupLayoutIfNeeded() {
        guard !didSetupLayout else { return }
        didSetupLayout = true
        setupLayout()
        bindActions()
    }

    public func configureFrame(to matchView: UIView) {
        setupLayoutIfNeeded()

        if self.superview !== matchView {
            matchView.addSubview(self)
        }

        self.translatesAutoresizingMaskIntoConstraints = true
        self.frame = matchView.bounds
        self.autoresizingMask = [.flexibleWidth, .flexibleHeight]
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
        guard let cloud = self.cloud, let region = self.region, let sectorId = self.sectorId else { return }
        mapView.initialize(cloud: cloud, region: region, sectorId: sectorId, showUnits: true)
        mapView.configureFrame(to: self.containerView)
        mapView.setZoomScale(zoom: 2.0)
        mapView.delegate = self
        addSubview(mapView)
    }
}
