
import Foundation
import TJLabsResource
import UIKit

public class TJLabsIndoorView: UIView, TJLabsResourceManagerDelegate {
    public func onSectorData(_ manager: TJLabsResource.TJLabsResourceManager, data: TJLabsResource.SectorOutput) {
        self.sectorInfo = data
        let buildings = data.buildings
        if !buildings.isEmpty {
            selectedBuilding = buildings[0]
        }
    }
    
    public func onSectorError(_ manager: TJLabsResource.TJLabsResourceManager, error: TJLabsResource.ResourceError) {
        // TODO
    }
    
    public func onBuildingsData(_ manager: TJLabsResource.TJLabsResourceManager, data: [TJLabsResource.BuildingOutput]) {
        // TODO
    }
    
    public func onScaleOffsetData(_ manager: TJLabsResource.TJLabsResourceManager, key: String, data: [Float]) {
        // TODO
    }
    
    public func onPathPixelData(_ manager: TJLabsResource.TJLabsResourceManager, key: String, data: TJLabsResource.PathPixelData) {
        // TODO
    }
    
    public func onNodeLinkData(_ manager: TJLabsResource.TJLabsResourceManager, key: String, type: TJLabsResource.NodeLinkType, data: Any) {
        // TODO
    }
    
    public func onLevelUnitsData(_ manager: TJLabsResource.TJLabsResourceManager, key: String, data: [TJLabsResource.UnitData]) {
        // TODO
    }
    
    public func onGeofenceData(_ manager: TJLabsResource.TJLabsResourceManager, key: String, data: TJLabsResource.GeofenceData) {
        // TODO
    }
    
    public func onEntranceData(_ manager: TJLabsResource.TJLabsResourceManager, key: String, data: TJLabsResource.EntranceData) {
        // TODO
    }
    
    public func onEntranceRouteData(_ manager: TJLabsResource.TJLabsResourceManager, key: String, data: TJLabsResource.EntranceRouteData) {
        // TODO
    }
    
    public func onImageData(_ manager: TJLabsResource.TJLabsResourceManager, key: String, data: UIImage?) {
        // TODO
    }
    
    public func onLevelWardsData(_ manager: TJLabsResource.TJLabsResourceManager, key: String, data: [TJLabsResource.LevelWard]) {
        // TODO
    }
    
    public func onAffineParam(_ manager: TJLabsResource.TJLabsResourceManager, data: TJLabsResource.AffineTransParamOutput) {
        // TODO
    }
    
    public func onSpotsData(_ manager: TJLabsResource.TJLabsResourceManager, key: Int, type: TJLabsResource.SpotType, data: Any) {
        // TODO
    }
    
    public func onLandmarkData(_ manager: TJLabsResource.TJLabsResourceManager, key: String, data: [String : TJLabsResource.LandmarkData]) {
        // TODO
    }
    
    public func onError(_ manager: TJLabsResource.TJLabsResourceManager, error: TJLabsResource.ResourceError, key: String) {
        // TODO
    }
    
    
    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    deinit {

    }
    
    // MARK: - variables
    var region: String?
    var sectorId: Int?
    
    var sectorInfo: SectorOutput?
    var selectedBuilding: BuildingOutput? {
        didSet {
            guard let selectedBuilding = selectedBuilding else { return }
            DispatchQueue.main.async { [weak self] in
                self?.setupTopView(buildingInfo: selectedBuilding)
                self?.setupMidView(buildingInfo: selectedBuilding)
            }
        }
    }
    
    
    // MARK: - View
    var topView: TJLabsIndoorTopView?
    var midView: TJLabsIndoorMidView?
    var bottomView: TJLabsIndoorBottomView?
    
    public func initialize(region: String, sectorId: Int) {
        self.region = region
        self.sectorId = sectorId
        TJLabsResourceManager.shared.delegate = self
        TJLabsResourceManager.shared.loadMapResource(region: region, sectorId: sectorId, completion: { isSuccess in
            let msg = isSuccess ? "success" : "fail"
            JupiterLogger.i(tag: "TJLabsIndoorView", message: "initialize " + msg)
        })
    }
    
    public func configureFrame(to matchView: UIView) {
        guard let _ = self.region, let _ = self.sectorId else { return }
        self.frame = matchView.bounds
        self.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    }
    
    func setupLayout() {
        
    }
    
    private func setupTopView(buildingInfo: BuildingOutput) {
        self.topView = TJLabsIndoorTopView(buildingInfo: buildingInfo)
        guard let topView = topView else { return }
        
        topView.onTapBack = { [weak self] in
            self?.handleTapBack()
        }

        topView.onTapRefresh = { [weak self] in
            self?.handleTapRefresh()
        }
        
        addSubview(topView)
        topView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            topView.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor),
            topView.leadingAnchor.constraint(equalTo: leadingAnchor),
            topView.trailingAnchor.constraint(equalTo: trailingAnchor),
            topView.heightAnchor.constraint(equalToConstant: 50)
        ])
    }
    
    private func setupMidView(buildingInfo: BuildingOutput) {
        self.midView = TJLabsIndoorMidView(buildingInfo: buildingInfo)
        guard let midView = midView, let topView = topView else { return }
 
        let ratio: CGFloat = 2.2
        let midWidth = self.frame.width
        let midHeight = midWidth / ratio
        addSubview(midView)
        midView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            midView.topAnchor.constraint(equalTo: topView.bottomAnchor),
            midView.leadingAnchor.constraint(equalTo: leadingAnchor),
            midView.trailingAnchor.constraint(equalTo: trailingAnchor),
            midView.heightAnchor.constraint(equalToConstant: midHeight)
        ])
        midView.onTapShowMap = { [weak self] in
            self?.handleTapShowMap()
        }
    }
    
    func bindActions() {
        
    }
    
    private func handleTapBack() {
        print("IndoorView received back tap")
    }

    private func handleTapRefresh() {
        print("IndoorView received refresh tap")
    }
    
    private func handleTapShowMap() {
        print("IndoorView received show map tap")
    }
}
