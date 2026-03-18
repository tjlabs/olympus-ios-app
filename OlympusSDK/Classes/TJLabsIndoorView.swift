
import Foundation
import TJLabsMap
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
        let SBL = key.split(separator: "_")
        if SBL.count != 3 { return }
        let building: String = String(SBL[1])
        let level: String = String(SBL[2])
        
        var destinations = [NaviDestination]()
        for unit in data {
            if unit.category == .PARKING_SPACE { continue }
            let dest = NaviDestination(building: building, level: level, level_id: unit.level_id, category: unit.category, name: unit.name, x: Float(unit.x), y: Float(unit.y))
            destinations.append(dest)
        }
        
        if destinations.isEmpty { return }
        if let preValue = self.destinationsMap[building] {
            let newValue = preValue + destinations
            self.destinationsMap[building] = newValue
        } else {
            self.destinationsMap[building] = destinations
        }
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
    var userId: String?
    
    var isResourceLoaded: Bool? {
        didSet {
            guard let isResourceLoaded = isResourceLoaded else { return }
            JupiterLogger.i(tag: "TJLabsIndoorView", message: "isResourceLoaded= \(isResourceLoaded)")
            if isResourceLoaded {
                self.updateDestinations()
            }
        }
    }
    
    var sectorInfo: SectorOutput?
    var selectedBuilding: BuildingOutput? {
        didSet {
            guard let selectedBuilding = selectedBuilding else { return }
            DispatchQueue.main.async { [weak self] in
                self?.setupViewsIfNeeded()
                self?.updateBuildingContents(buildingInfo: selectedBuilding)
            }
        }
    }
    
    var destinationsMap = [String: [NaviDestination]]()
    
    // MARK: - View
    private var hasSetupViews = false
    var topView: TJLabsIndoorTopView?
    var midView: TJLabsIndoorMidView?
    var bottomView: TJLabsIndoorBottomView?
    var indoorMapView: TJLabsIndoorMapView?
    var indoorNaviView: TJLabsIndoorNaviView?
    
    var parkingGuideView: TJLabsIndoorParkingGuideView?
    
    public func initialize(region: String, sectorId: Int, userId: String) {
        self.region = region
        self.sectorId = sectorId
        self.userId = userId
        TJLabsResourceManager.shared.delegate = self
        TJLabsResourceManager.shared.loadMapResource(region: region, sectorId: sectorId, completion: { isSuccess in
            let msg = isSuccess ? "success" : "fail"
            JupiterLogger.i(tag: "TJLabsIndoorView", message: "initialize " + msg)
            self.isResourceLoaded = isSuccess
        })
    }
    
    public func configureFrame(to matchView: UIView) {
        guard let _ = self.region, let _ = self.sectorId else { return }
        self.frame = matchView.bounds
        self.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    }
    
    private func setupViewsIfNeeded() {
        JupiterLogger.i(tag: "TJLabsIndoorView", message: "setupViewsIfNeededinitialize")
        guard !hasSetupViews else { return }
        hasSetupViews = true

        setupTopView()
        setupMidView()
        setupBottomView()
        bindActions()
    }
    
    private func updateBuildingContents(buildingInfo: BuildingOutput) {
        JupiterLogger.i(tag: "TJLabsIndoorView", message: "updateBuildingContents")
        updateTopView(buildingInfo: buildingInfo)
        updateMidView(buildingInfo: buildingInfo)
        updateBottomView(buildingInfo: buildingInfo)
    }
    
    // MARK: - Top View
    private func setupTopView() {
        guard topView == nil else { return }
        
        let topView = TJLabsIndoorTopView()
        self.topView = topView
        JupiterLogger.i(tag: "TJLabsIndoorView", message: "setupTopView")
        addSubview(topView)
        topView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            topView.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor),
            topView.leadingAnchor.constraint(equalTo: leadingAnchor),
            topView.trailingAnchor.constraint(equalTo: trailingAnchor),
            topView.heightAnchor.constraint(equalToConstant: 50)
        ])
    }
    
    private func updateTopView(buildingInfo: BuildingOutput) {
        topView?.update(buildingInfo: buildingInfo)
        JupiterLogger.i(tag: "TJLabsIndoorView", message: "updateTopView")
    }
    
    // MARK: - Mid View
    private func setupMidView() {
        guard midView == nil, let topView = self.topView else { return }

        let midView = TJLabsIndoorMidView()
        self.midView = midView
        JupiterLogger.i(tag: "TJLabsIndoorView", message: "setupMidView")
        addSubview(midView)
        midView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            midView.topAnchor.constraint(equalTo: topView.bottomAnchor),
            midView.leadingAnchor.constraint(equalTo: leadingAnchor),
            midView.trailingAnchor.constraint(equalTo: trailingAnchor),
            midView.heightAnchor.constraint(equalTo: widthAnchor, multiplier: 1.0 / 2.2)
        ])
    }
    
    private func updateMidView(buildingInfo: BuildingOutput) {
        midView?.update(buildingInfo: buildingInfo)
        JupiterLogger.i(tag: "TJLabsIndoorView", message: "updateMidView")
    }
    
    // MARK: - Bottom View
    private func setupBottomView() {
        guard bottomView == nil, let midView = self.midView else { return }
        
        let bottomView = TJLabsIndoorBottomView()
        self.bottomView = bottomView
        JupiterLogger.i(tag: "TJLabsIndoorView", message: "setupBottomView")
        addSubview(bottomView)
        bottomView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            bottomView.topAnchor.constraint(equalTo: midView.bottomAnchor),
            bottomView.leadingAnchor.constraint(equalTo: leadingAnchor),
            bottomView.trailingAnchor.constraint(equalTo: trailingAnchor),
            bottomView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
    
    private func updateBottomView(buildingInfo: BuildingOutput) {
        bottomView?.update(buildingInfo: buildingInfo)
        JupiterLogger.i(tag: "TJLabsIndoorView", message: "updateBottomView")
    }
    
    private func updateDestinations() {
        guard let selectedBuilding = self.selectedBuilding else { return }
        guard let matchedDestinations = self.destinationsMap[selectedBuilding.name] else { return }
        bottomView?.updateDestinations(destinations: matchedDestinations)
    }
    
    func bindActions() {
        topView?.onTapBack = { [weak self] in
            self?.handleTapBack()
        }
        
        topView?.onTapRefresh = { [weak self] in
            self?.handleTapRefresh()
        }
        
        midView?.onTapShowMap = { [weak self] in
            self?.handleTapShowMap()
        }
        
        bottomView?.onSelectDestination = { [weak self] destination in
            JupiterLogger.i(tag: "TJLabsIndoorView", message: "destination \(destination) selected")
            DispatchQueue.main.async { [weak self] in
                self?.showSelectView(destination: destination)
            }
        }
    }
    
    private func showSelectView(destination: NaviDestination) {
        let selectView = TJLabsDestinationSelectView(destination: destination)
        selectView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(selectView)
        NSLayoutConstraint.activate([
            selectView.topAnchor.constraint(equalTo: topAnchor),
            selectView.bottomAnchor.constraint(equalTo: bottomAnchor),
            selectView.leadingAnchor.constraint(equalTo: leadingAnchor),
            selectView.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
        
        selectView.onTapStart = { [weak self] routingOption in
            if routingOption == .SHORTEST {
                JupiterLogger.i(tag: "TJLabsIndoorView", message: "destination \(destination) with \(routingOption) routing start")
                DispatchQueue.main.async { [weak self] in
                    selectView.removeFromSuperview()
                    self?.setupNaviView(destination: destination, routingOption: routingOption)
                }
            } else {
                JupiterLogger.i(tag: "TJLabsIndoorView", message: "destination \(destination) with \(routingOption) cannot start")
                DispatchQueue.main.async { [weak self] in
                    selectView.removeFromSuperview()
                }
            }
        }
    }
    
    private func handleTapBack() {
        JupiterLogger.i(tag: "TJLabsIndoorView", message: "received back tap")
        if let indoorMapView = self.indoorMapView {
            DispatchQueue.main.async { [weak self] in
                UIView.animate(withDuration: 0.22, delay: 0, options: [.curveEaseInOut], animations: {
                    indoorMapView.alpha = 0
                    indoorMapView.transform = CGAffineTransform(translationX: 0, y: 12)
                }) { _ in
                    indoorMapView.removeFromSuperview()
                    indoorMapView.alpha = 1
                    indoorMapView.transform = .identity
                    self?.indoorMapView = nil
                }
            }
        } else if let indoorNaviView = self.indoorNaviView {
            DispatchQueue.main.async { [weak self] in
                UIView.animate(withDuration: 0.22, delay: 0, options: [.curveEaseInOut], animations: {
                    indoorNaviView.alpha = 0
                    indoorNaviView.transform = CGAffineTransform(translationX: 0, y: 12)
                }) { _ in
                    indoorNaviView.removeFromSuperview()
                    indoorNaviView.alpha = 1
                    indoorNaviView.transform = .identity
                    self?.indoorNaviView = nil
                }
            }
        } else {
            DispatchQueue.main.async { [weak self] in
                UIView.animate(withDuration: 0.22, delay: 0, options: [.curveEaseInOut], animations: {
                    self?.alpha = 0
                }) { _ in
                    self?.alpha = 1
                    self?.removeFromSuperview()
                }
            }
        }
    }

    private func handleTapRefresh() {
        JupiterLogger.i(tag: "TJLabsIndoorView", message: "received refresh tap")
    }
    
    private func handleTapShowMap() {
        JupiterLogger.i(tag: "TJLabsIndoorView", message: "received show map tap")
        DispatchQueue.main.async { [weak self] in
            self?.setupMapView()
        }
        
    }
    
    private func setupMapView() {
        guard let region = self.region, let sectorId = self.sectorId else { return }
        
        if let indoorMapView = self.indoorMapView {
            bringSubviewToFront(indoorMapView)
            return
        }
        
        let indoorMapView = TJLabsIndoorMapView(region: region, sectorId: sectorId)
        self.indoorMapView = indoorMapView
        guard let topView = self.topView else { return }
        
        self.indoorMapView?.translatesAutoresizingMaskIntoConstraints = false
        self.indoorMapView?.alpha = 0
        self.indoorMapView?.transform = CGAffineTransform(translationX: 0, y: 12)
        addSubview(self.indoorMapView!)
        NSLayoutConstraint.activate([
            self.indoorMapView!.topAnchor.constraint(equalTo: topView.bottomAnchor),
            self.indoorMapView!.bottomAnchor.constraint(equalTo: bottomAnchor),
            self.indoorMapView!.leadingAnchor.constraint(equalTo: leadingAnchor),
            self.indoorMapView!.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
        
        layoutIfNeeded()
        UIView.animate(withDuration: 0.25, delay: 0, options: [.curveEaseInOut], animations: {
            self.indoorMapView!.alpha = 1
            self.indoorMapView!.transform = .identity
        })
    }
    
    private func setupNaviView(destination: NaviDestination, routingOption: RoutingOption) {
        guard let region = self.region, let sectorId = self.sectorId, let userId = self.userId else { return }
        let indoorNaviView = TJLabsIndoorNaviView(region: region, sectorId: sectorId, userId: userId)
        self.indoorNaviView = indoorNaviView
        let dest = RoutingPoint(level_id: destination.level_id, x: Int(destination.x), y: Int(destination.y), absolute_heading: 0)
        self.indoorNaviView?.setNavigationDestination(dest: dest)
        
        guard let topView = self.topView else { return }
        self.indoorNaviView?.translatesAutoresizingMaskIntoConstraints = false
        self.indoorNaviView?.alpha = 0
        self.indoorNaviView?.transform = CGAffineTransform(translationX: 0, y: 12)
        addSubview(self.indoorNaviView!)
        NSLayoutConstraint.activate([
            self.indoorNaviView!.topAnchor.constraint(equalTo: topView.bottomAnchor),
            self.indoorNaviView!.bottomAnchor.constraint(equalTo: bottomAnchor),
            self.indoorNaviView!.leadingAnchor.constraint(equalTo: leadingAnchor),
            self.indoorNaviView!.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
        
        layoutIfNeeded()
        UIView.animate(withDuration: 0.25, delay: 0, options: [.curveEaseInOut], animations: {
            self.indoorNaviView?.alpha = 1
            self.indoorNaviView?.transform = .identity
        })
        
        self.indoorNaviView?.parkingGuideStart = { [weak self] in
            DispatchQueue.main.async { [self] in
                UIView.animate(withDuration: 0.2, animations: { [weak self] in
                    self?.parkingGuideView = TJLabsIndoorParkingGuideView()
                    self?.parkingGuideView!.translatesAutoresizingMaskIntoConstraints = false
                    self?.addSubview((self?.parkingGuideView)!)
                    NSLayoutConstraint.activate([
                        self!.parkingGuideView!.topAnchor.constraint(equalTo: self!.topAnchor),
                        self!.parkingGuideView!.bottomAnchor.constraint(equalTo: self!.bottomAnchor),
                        self!.parkingGuideView!.leadingAnchor.constraint(equalTo: self!.leadingAnchor),
                        self!.parkingGuideView!.trailingAnchor.constraint(equalTo: self!.trailingAnchor),
                    ])
                })
            }
        }

        self.indoorNaviView?.parkingGuideFinish = { [weak self] in
            DispatchQueue.main.async {
                self?.parkingGuideView?.removeFromSuperview()
            }
        }
    }
}
