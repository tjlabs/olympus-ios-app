import UIKit
import Foundation

public class OlympusMapView: UIView, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, UIScrollViewDelegate {
    
    enum MapMode {
        case MAP_ONLY
        case MAP_INTERACTION
        case UPDATE_USER
    }
    
    enum ZoomMode {
        case ZOOM_IN
        case ZOOM_OUT
    }
    
    enum PlotType {
        case NORMAL
        case FORCE
    }
    
    private var mapImageView = UIImageView()
    private var buildingsCollectionView: UICollectionView!
    private var levelsCollectionView: UICollectionView!
    private let scrollView = UIScrollView()
    private let velocityLabel = UILabel()
    private let myLocationButton = UIButton()
    private let zoomButton = UIButton()
    
    private var imageMapMarker: UIImage?
    private var imageZoomIn: UIImage?
    private var imageZoomOut: UIImage?
    private var imageMyLocation: UIImage?
    
    private var buildingData = [String]()
    private var levelData = [String]()
    private var selectedBuilding: String?
    private var selectedLevel: String?
    private let cellSize: CGSize = CGSize(width: 30, height: 30)
    private let cellSpacing: CGFloat = 0.1
    private var buildingsCollectionViewHeightConstraint: NSLayoutConstraint!
    private var levelsCollectionViewHeightConstraint: NSLayoutConstraint!
    private var levelsLeadingToSuperviewConstraint: NSLayoutConstraint!
    private var levelsLeadingToBuildingsConstraint: NSLayoutConstraint!
    
    private var mapScaleOffset = [String: [Double]]()
    private var sectorScales = [String: [Double]]()
    private var sectorUnits = [String: [Unit]]()
    private var currentScale: CGFloat = 1.0
    private var translationOffset: CGPoint = .zero
    private var isPpHidden = true
    private var isUnitHidden = true
    
    private var preXyh = [Double]()
    private var userHeadingBuffer = [Double]()
    private var mapHeading: Double = 0
    private let userCoordTag = 999
    
    private var mode: MapMode = .MAP_ONLY
    private var zoomMode: ZoomMode = .ZOOM_OUT
    
    private var mapModeChangedTime = 0
    private var zoomModeChangedTime = 0
    private let TIME_FOR_REST: Int = 3*1000
    private let USER_CENTER_OFFSET: CGFloat = 40 // 30 // 150
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupAssets()
        setupView()
        observeImageUpdates()
        observeScaleUpdates()
        observeUnitUpdates()
        observePathPixelUpdates()
//        addGestures()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupAssets()
        setupView()
        observeImageUpdates()
        observeScaleUpdates()
        observeUnitUpdates()
        observePathPixelUpdates()
//        addGestures()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    public func setIsPpHidden(flag: Bool) {
        self.isPpHidden = flag
    }
    
    private func addGestures() {
//        addPinchGesture()
//        addPanGesture()
    }
    
//    private func addPinchGesture() {
//        let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(handlePinchGesture(_:)))
//        self.addGestureRecognizer(pinchGesture)
//    }
//    
//    private func addPanGesture() {
//        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture(_:)))
//        self.addGestureRecognizer(panGesture)
//    }
//    
//    private func addTouchGesture() {
//        let touchGesture = UIPanGestureRecognizer(target: self, action: #selector(handleTouchGesture(_:)))
//        self.addGestureRecognizer(touchGesture)
//    }
//    
//    @objc private func handlePinchGesture(_ sender: UIPinchGestureRecognizer) {
//        if sender.state == .changed {
//            let scale = sender.scale
//            mapImageView.transform = mapImageView.transform.scaledBy(x: scale, y: scale)
//            currentScale = scale
//            sender.scale = 1.0
//            print(getLocalTimeString() + " , (Olympus) MapView : currentScale = \(currentScale)")
//        } else if sender.state == .ended {
//            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
//                self?.updatePathPixel()
//            }
//        }
//    }
//    
//    @objc private func handlePanGesture(_ sender: UIPanGestureRecognizer) {
//        let translation = sender.translation(in: self)
//        if sender.state == .changed {
//            mapImageView.transform = mapImageView.transform.translatedBy(x: translation.x, y: translation.y)
//            translationOffset.x = translation.x
//            translationOffset.y = translation.y
//            sender.setTranslation(.zero, in: self)
//        } else if sender.state == .ended {
//            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
//                self?.updatePathPixel()
//            }
//        }
//    }
//    
//    @objc private func handleTouchGesture(_ sender: UITapGestureRecognizer) {
//        let touchPoint = sender.location(in: self.mapImageView)
//        print(getLocalTimeString() + " , (Olympus) MapView : Touch \(touchPoint)")
//    }

    private func setupView() {
        setupMapImageView()
        setupCollectionViews()
        setupLabels()
        setupButtons()
        setupButtonActions()
    }
    
    private func setupLabels() {
        velocityLabel.text = "0"
        velocityLabel.textAlignment = .center
        velocityLabel.textColor = .black
        velocityLabel.font = UIFont.boldSystemFont(ofSize: 50)
        velocityLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let attrString = NSAttributedString(
            string: "0",
            attributes: [
                NSAttributedString.Key.strokeColor: UIColor.white,
                NSAttributedString.Key.foregroundColor: UIColor.black,
                NSAttributedString.Key.strokeWidth: -3.0,
                NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: 53.0)
            ]
        )
        velocityLabel.attributedText = attrString
        
        addSubview(velocityLabel)
        
        NSLayoutConstraint.activate([
            velocityLabel.topAnchor.constraint(equalTo: self.topAnchor, constant: 40),
            velocityLabel.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 40)
        ])
    }
    
    private func setupButtons() {
        func styleButton(_ button: UIButton) {
            button.backgroundColor = .white
            button.layer.cornerRadius = 8
            button.layer.shadowColor = UIColor.black.cgColor
            button.layer.shadowOpacity = 0.2
            button.layer.shadowOffset = CGSize(width: 0, height: 4)
            button.layer.shadowRadius = 4
            button.contentEdgeInsets = UIEdgeInsets(top: 6, left: 6, bottom: 6, right: 6)
        }
        
        zoomButton.isHidden = true
        zoomButton.setImage(imageZoomIn, for: .normal)
        zoomButton.translatesAutoresizingMaskIntoConstraints = false
        zoomButton.widthAnchor.constraint(equalToConstant: 40).isActive = true
        zoomButton.heightAnchor.constraint(equalToConstant: 40).isActive = true
        styleButton(zoomButton)
        addSubview(zoomButton)
        
        myLocationButton.isHidden = true
        myLocationButton.setImage(imageMyLocation, for: .normal)
        myLocationButton.translatesAutoresizingMaskIntoConstraints = false
        myLocationButton.widthAnchor.constraint(equalToConstant: 40).isActive = true
        myLocationButton.heightAnchor.constraint(equalToConstant: 40).isActive = true
        styleButton(myLocationButton)
        addSubview(myLocationButton)

        NSLayoutConstraint.activate([
            myLocationButton.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -20),
            myLocationButton.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: -20),

            zoomButton.trailingAnchor.constraint(equalTo: myLocationButton.trailingAnchor),
            zoomButton.bottomAnchor.constraint(equalTo: myLocationButton.topAnchor, constant: -10)
        ])
    }
    
//    private func setupButtonActions() {
//        myLocationButton.addTarget(self, action: #selector(myLocationButtonTapped), for: .touchUpInside)
//        myLocationButton.addTarget(self, action: #selector(myLocationButtonTappedOver), for: [.touchUpInside, .touchUpOutside])
//        
//        zoomButton.addTarget(self, action: #selector(zoomButtonTapped), for: .touchUpInside)
//        zoomButton.addTarget(self, action: #selector(zoomButtonTappedOver), for: [.touchUpInside, .touchUpOutside])
//    }
    
    private func setupButtonActions() {
        myLocationButton.addAction(UIAction { [weak self] _ in
            self?.myLocationButtonTapped()
        }, for: .touchUpInside)
        
        myLocationButton.addAction(UIAction { [weak self] _ in
            self?.myLocationButtonTappedOver()
        }, for: [.touchUpInside, .touchUpOutside])
        
        zoomButton.addAction(UIAction { [weak self] _ in
            self?.zoomButtonTapped()
        }, for: .touchUpInside)
        
        zoomButton.addAction(UIAction { [weak self] _ in
            self?.zoomButtonTappedOver()
        }, for: [.touchUpInside, .touchUpOutside])
    }

    
    private func myLocationButtonTapped() {
        self.zoomButton.isUserInteractionEnabled = false
        self.myLocationButton.isUserInteractionEnabled = false
        UIView.animate(withDuration: 0.1) {
            self.myLocationButton.transform = CGAffineTransform(scaleX: 0.98, y: 0.98)
        }
        self.mode = .UPDATE_USER
        forceToZoomInMode()
    }
    
    private func myLocationButtonTappedOver() {
        UIView.animate(withDuration: 0.1) {
            self.myLocationButton.transform = CGAffineTransform.identity // Reset scale
            self.zoomButton.isUserInteractionEnabled = true
            self.myLocationButton.isUserInteractionEnabled = true
        }
    }
    
    private func forceToMapInteractionMode() {
        DispatchQueue.main.async { [self] in
            self.mode = .MAP_INTERACTION
            self.mapModeChangedTime = getCurrentTimeInMilliseconds()
            self.toggleZoomMode(to: .ZOOM_OUT)
            
            mapImageView.transform = .identity
            if let existingPointView = mapImageView.viewWithTag(userCoordTag) {
                existingPointView.removeFromSuperview()
            }
        }
    }
    
    private func forceToZoomInMode() {
        if zoomMode == .ZOOM_OUT {
            toggleZoomMode(to: .ZOOM_IN)
            if !preXyh.isEmpty {
                plotUserCoordWithZoomAndRotation(building: selectedBuilding ?? "", level: selectedLevel ?? "",xyh: preXyh, type: .FORCE)
            }
        } else {
            if !preXyh.isEmpty {
                plotUserCoordWithZoomAndRotation(building: selectedBuilding ?? "", level: selectedLevel ?? "",xyh: preXyh, type: .FORCE)
            }
        }
    }
        
    private func zoomButtonTapped() {
        self.zoomButton.isUserInteractionEnabled = false
        self.myLocationButton.isUserInteractionEnabled = false
        UIView.animate(withDuration: 0.1) {
            self.zoomButton.transform = CGAffineTransform(scaleX: 0.98, y: 0.98)
        }
        toggleZoomMode()
    }
    
    private func zoomButtonTappedOver() {
        UIView.animate(withDuration: 0.1) {
            self.zoomButton.transform = CGAffineTransform.identity
            self.zoomButton.isUserInteractionEnabled = true
            self.myLocationButton.isUserInteractionEnabled = true
        }
    }
        
    private func toggleZoomMode(to mode: ZoomMode? = nil) {
        zoomMode = mode ?? (zoomMode == .ZOOM_IN ? .ZOOM_OUT : .ZOOM_IN)
        DispatchQueue.main.async { [self] in
            zoomButton.setImage(zoomMode == .ZOOM_IN ? imageZoomOut : imageZoomIn, for: .normal)
        }
        
        if zoomMode == .ZOOM_IN {
            // 현재 확대 모드
            if !preXyh.isEmpty {
                plotUserCoordWithZoomAndRotation(building: selectedBuilding ?? "", level: selectedLevel ?? "", xyh: preXyh, type: .FORCE)
            }
        } else {
            zoomModeChangedTime = getCurrentTimeInMilliseconds()
            // 현재 전체 모드
            if !preXyh.isEmpty && self.mode != .MAP_INTERACTION {
                plotUserCoord(building: selectedBuilding ?? "", level: selectedLevel ?? "", xyh: preXyh)
            }
        }
    }
    
    private func setupAssets() {
        if let bundleURL = Bundle(for: OlympusSDK.OlympusMapView.self).url(forResource: "OlympusSDK", withExtension: "bundle") {
            if let resourceBundle = Bundle(url: bundleURL) {
                if let mapMarker = UIImage(named: "icon_mapMarker", in: resourceBundle, compatibleWith: nil) {
                    self.imageMapMarker = mapMarker
                } else {
                    print(getLocalTimeString() + " , (Olympus) Error : Could not load icon_mapMarker.png from bundle.")
                }
                
                if let zoomIn = UIImage(named: "icon_zoomIn", in: resourceBundle, compatibleWith: nil) {
                    self.imageZoomIn = zoomIn
                } else {
                    print(getLocalTimeString() + " , (Olympus) Error : Could not load icon_zoomIn.png from bundle.")
                }
                
                if let zoomOut = UIImage(named: "icon_zoomOut", in: resourceBundle, compatibleWith: nil) {
                    self.imageZoomOut = zoomOut
                } else {
                    print(getLocalTimeString() + " , (Olympus) Error : Could not load icon_zoomOut.png from bundle.")
                }
                
                if let myLocation = UIImage(named: "icon_myLocation", in: resourceBundle, compatibleWith: nil) {
                    self.imageMyLocation = myLocation
                } else {
                    print(getLocalTimeString() + " , (Olympus) Error : Could not load icon_myLocation.png from bundle.")
                }
            } else {
                print(getLocalTimeString() + " , (Olympus) Error : Could not load resourceBundle")
            }
        } else {
            print(getLocalTimeString() + " , (Olympus) Error : Could not load bundleURL")
        }
    }
    
    private func setupMapImageView() {
        scrollView.frame = self.bounds
        scrollView.backgroundColor = .clear
        scrollView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 4.0
        scrollView.isScrollEnabled = false
        scrollView.delegate = self
        addSubview(scrollView)
        
        mapImageView.contentMode = .scaleAspectFit
        mapImageView.backgroundColor = .clear
        mapImageView.frame = scrollView.bounds
        mapImageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        scrollView.addSubview(mapImageView)
    }
    
    private func setupCollectionViews() {
        let buildingLayout = UICollectionViewFlowLayout()
        buildingLayout.scrollDirection = .vertical
        buildingLayout.minimumLineSpacing = cellSpacing
        
        buildingsCollectionView = UICollectionView(frame: .zero, collectionViewLayout: buildingLayout)
        buildingsCollectionView.backgroundColor = .clear
        buildingsCollectionView.layer.cornerRadius = 10
        buildingsCollectionView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "BuildingCell")
        buildingsCollectionView.delegate = self
        buildingsCollectionView.dataSource = self
        addSubview(buildingsCollectionView)
        
        let levelLayout = UICollectionViewFlowLayout()
        levelLayout.scrollDirection = .vertical
        levelLayout.minimumLineSpacing = cellSpacing
        
        levelsCollectionView = UICollectionView(frame: .zero, collectionViewLayout: levelLayout)
        levelsCollectionView.backgroundColor = .clear
        levelsCollectionView.layer.cornerRadius = 10
        levelsCollectionView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "LevelCell")
        levelsCollectionView.delegate = self
        levelsCollectionView.dataSource = self
        addSubview(levelsCollectionView)
        
        buildingsCollectionView.translatesAutoresizingMaskIntoConstraints = false
        levelsCollectionView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            buildingsCollectionView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            buildingsCollectionView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -20),
            buildingsCollectionView.widthAnchor.constraint(equalToConstant: cellSize.width),
            
            levelsCollectionView.leadingAnchor.constraint(equalTo: buildingsCollectionView.trailingAnchor, constant: 5),
            levelsCollectionView.bottomAnchor.constraint(equalTo: buildingsCollectionView.bottomAnchor),
            levelsCollectionView.widthAnchor.constraint(equalToConstant: cellSize.width)
        ])
        
        buildingsCollectionViewHeightConstraint = buildingsCollectionView.heightAnchor.constraint(equalToConstant: calculateCollectionViewHeight(for: buildingData.count))
        buildingsCollectionViewHeightConstraint.isActive = true
        
        levelsCollectionViewHeightConstraint = levelsCollectionView.heightAnchor.constraint(equalToConstant: calculateCollectionViewHeight(for: levelData.count))
        levelsCollectionViewHeightConstraint.isActive = true
        
        // MARK: - Control Building & Level CollectionView when building is 1
        buildingsCollectionView.translatesAutoresizingMaskIntoConstraints = false
        levelsCollectionView.translatesAutoresizingMaskIntoConstraints = false

        levelsLeadingToBuildingsConstraint = levelsCollectionView.leadingAnchor.constraint(equalTo: buildingsCollectionView.trailingAnchor, constant: 5)
        levelsLeadingToSuperviewConstraint = levelsCollectionView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20)
            
        NSLayoutConstraint.activate([
            buildingsCollectionView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            buildingsCollectionView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -20),
            buildingsCollectionView.widthAnchor.constraint(equalToConstant: cellSize.width),
                
            levelsCollectionView.bottomAnchor.constraint(equalTo: buildingsCollectionView.bottomAnchor),
            levelsCollectionView.widthAnchor.constraint(equalToConstant: cellSize.width)
        ])
            
        buildingsCollectionViewHeightConstraint = buildingsCollectionView.heightAnchor.constraint(equalToConstant: calculateCollectionViewHeight(for: buildingData.count))
        buildingsCollectionViewHeightConstraint.isActive = true
            
        levelsCollectionViewHeightConstraint = levelsCollectionView.heightAnchor.constraint(equalToConstant: calculateCollectionViewHeight(for: levelData.count))
        levelsCollectionViewHeightConstraint.isActive = true
            
        levelsLeadingToBuildingsConstraint.isActive = true
    }
    
    private func calculateCollectionViewHeight(for itemCount: Int) -> CGFloat {
        return CGFloat(itemCount) * (cellSize.height + cellSpacing) - cellSpacing
    }
    
    public func configureFrame(to matchView: UIView) {
        self.frame = matchView.bounds
        self.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    }

//    public func updateBuildingData(_ buildings: [String], levelData: [String: [String]]) {
//        self.buildingData = buildings.sorted()
//        if let firstBuilding = buildingData.first {
//            self.selectedBuilding = firstBuilding
//            self.levelData = levelData[firstBuilding] ?? []
//            self.selectedLevel = self.levelData.first
//        }
//        buildingsCollectionView.reloadData()
//        levelsCollectionView.reloadData()
//        adjustCollectionViewHeights()
//        updateMapImageView()
//        updatePathPixel()
//        updateUnit()
//        
//        // MARK: - Control Building & Level CollectionView when building is 1
//        if buildings.count < 2 {
//            buildingsCollectionView.isHidden = true
//            levelsLeadingToBuildingsConstraint.isActive = false
//            levelsLeadingToSuperviewConstraint.isActive = true
//        } else {
//            buildingsCollectionView.isHidden = false
//            levelsLeadingToSuperviewConstraint.isActive = false
//            levelsLeadingToBuildingsConstraint.isActive = true
//        }
//
//        UIView.animate(withDuration: 0.3) {
//            self.layoutIfNeeded()
//        }
//    }
    
    public func updateBuildingData(_ buildings: [String], levelData: [String: [String]]) {
        self.buildingData = buildings.sorted()
        if let firstBuilding = buildingData.first {
            self.selectedBuilding = firstBuilding
            self.levelData = levelData[firstBuilding] ?? []
            self.selectedLevel = self.levelData.first
        } else {
            self.selectedBuilding = nil
            self.levelData = []
            self.selectedLevel = nil
        }
        
        buildingsCollectionView.reloadData()
        levelsCollectionView.reloadData()
        adjustCollectionViewHeights()
        updateMapImageView()
        updatePathPixel()
        updateUnit()

        if buildings.isEmpty {
            buildingsCollectionView.isHidden = true
            levelsLeadingToBuildingsConstraint.isActive = false
            levelsLeadingToSuperviewConstraint.isActive = true
        } else {
            buildingsCollectionView.isHidden = false
            levelsLeadingToSuperviewConstraint.isActive = false
            levelsLeadingToBuildingsConstraint.isActive = true
        }

        UIView.animate(withDuration: 0.3) {
            self.layoutIfNeeded()
        }
    }

    
    private func adjustCollectionViewHeights() {
        let buildingHeight = calculateCollectionViewHeight(for: buildingData.count)
        let levelHeight = calculateCollectionViewHeight(for: levelData.count)
            
        print(getLocalTimeString() + " , (Olympus) MapView : Building Height = \(buildingHeight), Level Height = \(levelHeight)")
            
        buildingsCollectionViewHeightConstraint.constant = max(buildingHeight, 0)
        levelsCollectionViewHeightConstraint.constant = max(levelHeight, 0)

        UIView.animate(withDuration: 0.3) {
            self.layoutIfNeeded()
        }
    }
    
    private func updateMapImageView() {
        guard let selectedBuilding = selectedBuilding, let selectedLevel = selectedLevel else { return }
        
        let pathPixelKey = "\(OlympusMapManager.shared.sector_id)_\(selectedBuilding)_\(selectedLevel)"
        let imageKey = "image_" + pathPixelKey

        if let images = OlympusMapManager.shared.sectorImages[imageKey], let image = images.first {
            mapImageView.image = image
            mapScaleOffset[pathPixelKey].map { _ in } ?? updatePathPixel()
        } else {
            mapImageView.image = nil
        }
    }

    private func updatePathPixel() {
        guard let selectedBuilding = selectedBuilding, let selectedLevel = selectedLevel else { return }
        let pathPixelKey = "\(OlympusMapManager.shared.sector_id)_\(selectedBuilding)_\(selectedLevel)"
        if let ppCoord = OlympusPathMatchingCalculator.shared.PpCoord[pathPixelKey] {
            calMapScaleOffset(building: selectedBuilding, level: selectedLevel, ppCoord: ppCoord)
            if !self.isPpHidden {
                plotPathPixels(building: selectedBuilding, level: selectedLevel, ppCoord: ppCoord)
            }
        }
    }
    
    private func updateUnit() {
        guard let selectedBuilding = selectedBuilding, let selectedLevel = selectedLevel else { return }
        let pathPixelKey = "\(OlympusMapManager.shared.sector_id)_\(selectedBuilding)_\(selectedLevel)"
        let unitKey = "unit_" + pathPixelKey
        
        if let ppCoord = OlympusPathMatchingCalculator.shared.PpCoord[pathPixelKey] {
            guard let scaleOffsetValues = mapScaleOffset[pathPixelKey], scaleOffsetValues.count == 6 else {
                print(getLocalTimeString() + " , (Olympus) MapView : Scale Empty in Unit")
                calMapScaleOffset(building: selectedBuilding, level: selectedLevel, ppCoord: ppCoord)
                return
            }
            if !self.isUnitHidden {
                guard let units = self.sectorUnits[unitKey] else {
                    print(getLocalTimeString() + " , (Olympus) MapView : Unit Empty \(unitKey)")
                    DispatchQueue.main.async { [self] in
                        mapImageView.subviews.forEach { $0.removeFromSuperview() }
                    }
                    return
                }
                plotUnit(building: selectedBuilding, level: selectedLevel, units: units, ppCoord: ppCoord)
            }
        }
    }
    
    private func calMapScaleOffset(building: String, level: String, ppCoord: [[Double]]) {
        DispatchQueue.main.async { [self] in
            guard let image = mapImageView.image else { return }
            
            let key = "\(OlympusMapManager.shared.sector_id)_\(building)_\(level)"
            let scaledSize = calculateAspectFitImageSize(for: image, in: mapImageView)
            
            let scaleKey = "scale_" + key
            var sectorScale: [Double] = sectorScales[scaleKey] ?? []
            if key == "2_S3_7F" {
                sectorScale = []
            }
            
            let xCoords = ppCoord[0]
            let yCoords = ppCoord[1]
            
            guard let ppMinX = xCoords.min(),
                  let ppMaxX = xCoords.max(),
                  let ppMinY = yCoords.min(),
                  let ppMaxY = yCoords.max() else { return }
            
            // COEX PP Min Max : 6, 294, 3, 469
//            let minX: Double = -48
//            let maxX: Double = 286
//            let minY: Double = -10
//            let maxY: Double = 530
            
//            let minX: Double = -50.5
//            let maxX: Double = 282
//            let minY: Double = -8
//            let maxY: Double = 530
            
            print(getLocalTimeString() + " , (Olympus) MapView : calMapScaleOffset // xyMinMax = [\(ppMinX),\(ppMaxX),\(ppMinY),\(ppMaxY)]")
            print(getLocalTimeString() + " , (Olympus) MapView : calMapScaleOffset // key = \(scaleKey) // value = \(sectorScale)")
            
            // -54.5, 277.8, -8, 530
            let minX: Double = !sectorScale.isEmpty ? sectorScale[0] : ppMinX
            let maxX: Double = !sectorScale.isEmpty ? sectorScale[1] : ppMaxX
            let minY: Double = !sectorScale.isEmpty ? sectorScale[2] : ppMinY
            let maxY: Double = !sectorScale.isEmpty ? sectorScale[3] : ppMaxY
            
            let ppWidth: Double = maxX - minX // 11
            let ppHeight: Double = maxY - minY // 10

            let scaleX = scaledSize.width / ppWidth
            let scaleY = scaledSize.height / ppHeight

            let offsetX = minX
            let offsetY = minY
           
            mapScaleOffset[key] = [scaleX, scaleY, offsetX, offsetY, scaledSize.width, scaledSize.height]
        }
    }

    private func plotPathPixels(building: String, level: String, ppCoord: [[Double]]) {
        DispatchQueue.main.async { [self] in
            mapImageView.subviews.forEach { $0.removeFromSuperview() }
            let key = "\(OlympusMapManager.shared.sector_id)_\(building)_\(level)"
            guard let scaleOffsetValues = mapScaleOffset[key], scaleOffsetValues.count == 6 else {
                calMapScaleOffset(building: building, level: level, ppCoord: ppCoord)
                return
            }
            print(getLocalTimeString() + " , (Olympus) MapView : calMapScaleOffset // key = \(key) // scaleOffsetValues = \(scaleOffsetValues)")
            let scaleX = scaleOffsetValues[0]
            let scaleY = scaleOffsetValues[1]
            let offsetX = scaleOffsetValues[2]
            let offsetY = scaleOffsetValues[3]
            
            let tempOffsetX = abs(mapImageView.bounds.width - (scaleX*mapImageView.bounds.width))
            let offsetXByScale = scaleX < 1.0 ? (tempOffsetX/2) : -(tempOffsetX/2)
            let markerSize: Double = scaleX < 20.0 ? 3 : 20
            print(getLocalTimeString() + " , (Olympus) MapView : tempOffsetX = \(tempOffsetX) // offsetXByScale = \(offsetXByScale)")
            var scaledXY = [[Double]]()
            for i in 0..<ppCoord[0].count {
                let x = ppCoord[0][i]
                let y = ppCoord[1][i]

                let transformedX = ((x - offsetX)*scaleX) + offsetXByScale
                let transformedY = ((y - offsetY)*scaleY)
                
                let rotatedX = transformedX
                let rotatedY = scaleOffsetValues[5] - transformedY
                print(getLocalTimeString() + " , (Olympus) MapView : \(x),\(y) -> \(rotatedX),\(rotatedY)")
                scaledXY.append([transformedX, transformedY])
                
                let pointView = UIView(frame: CGRect(x: rotatedX - markerSize/2, y: rotatedY - markerSize/2, width: markerSize, height: markerSize))
                pointView.backgroundColor = .systemYellow
                pointView.layer.cornerRadius = markerSize/2
                mapImageView.addSubview(pointView)
            }
        }
    }
    
//    private func plotPathPixels(building: String, level: String, ppCoord: [[Double]]) {
//        DispatchQueue.main.async { [self] in
//            mapImageView.subviews.forEach { $0.removeFromSuperview() }
//            let key = "\(OlympusMapManager.shared.sector_id)_\(building)_\(level)"
//            guard let scaleOffsetValues = mapScaleOffset[key], scaleOffsetValues.count == 6 else {
//                calMapScaleOffset(building: building, level: level, ppCoord: ppCoord)
//                return
//            }
//            print(getLocalTimeString() + " , (Olympus) MapView : calMapScaleOffset // key = \(key) // scaleOffsetValues = \(scaleOffsetValues)")
//            let scaleX = scaleOffsetValues[0]
//            let scaleY = scaleOffsetValues[1]
//            let offsetX = scaleOffsetValues[2]
//            let offsetY = scaleOffsetValues[3]
//            
//            let tempOffsetX = abs(mapImageView.bounds.width - (scaleX*mapImageView.bounds.width))
//            let offsetXByScale = scaleX < 1.0 ? (tempOffsetX/2) : -(tempOffsetX/2)
//            let markerSize: Double = scaleX < 20.0 ? 3 : 10
//            print(getLocalTimeString() + " , (Olympus) MapView : tempOffsetX = \(tempOffsetX) // offsetXByScale = \(offsetXByScale)")
//            
//            
//            let checkers: [Double] = [14, 13, 5, -2]
//            let centerX: Double = mapImageView.bounds.width/2
//            let centerY: Double = mapImageView.bounds.height/2
//            print(getLocalTimeString() + " , (Olympus) MapView : centerX = \(centerX) , centerY = \(centerY)")
//            var scaledXY = [[Double]]()
//            for i in 0..<ppCoord[0].count {
//                let x = ppCoord[0][i]
//                let y = ppCoord[1][i]
//
////                let transformedX = ((x - offsetX)*scaleX)
////                let transformedY = ((y - offsetY)*scaleY)
////                
////                let rotatedX = transformedX
////                let rotatedY = scaleOffsetValues[5] - transformedY
//            
//                let transformedX = (x + checkers[2])*checkers[0]
//                let transformedY = (y + checkers[3])*checkers[1]
//                
//                let rotatedX = transformedX
//                let rotatedY = transformedY
//                
//                print(getLocalTimeString() + " , (Olympus) MapView : \(x),\(y) -> \(rotatedX),\(rotatedY)")
//                scaledXY.append([transformedX, transformedY])
//                
//                let pointView = UIView(frame: CGRect(x: rotatedX - markerSize/2, y: rotatedY - markerSize/2, width: markerSize, height: markerSize))
//                pointView.backgroundColor = .systemYellow
//                pointView.layer.cornerRadius = markerSize/2
//                mapImageView.addSubview(pointView)
//            }
//        }
//    }

    private func plotUserCoord(building: String, level: String, xyh: [Double]) {
        DispatchQueue.main.async { [self] in
            if preXyh == xyh {
                return
            }
            
            let key = "\(OlympusMapManager.shared.sector_id)_\(building)_\(level)"
            guard let scaleOffsetValues = mapScaleOffset[key], scaleOffsetValues.count == 6 else {
                if let ppCoord = OlympusPathMatchingCalculator.shared.PpCoord[key] {
                    calMapScaleOffset(building: building, level: level, ppCoord: ppCoord)
                }
                return
            }

            let scaleX = scaleOffsetValues[0]
            let scaleY = scaleOffsetValues[1]
            let offsetX = scaleOffsetValues[2]
            let offsetY = scaleOffsetValues[3]
            
            let tempOffsetX = abs(mapImageView.bounds.width - (scaleX*mapImageView.bounds.width))
            let offsetXByScale = scaleX < 1.0 ? (tempOffsetX/2) : -(tempOffsetX/2)
            
            let x = xyh[0]
            let y = xyh[1]
            let heading = xyh[2]
            
            let transformedX = ((x - offsetX)*scaleX) + offsetXByScale
            let transformedY = ((y - offsetY)*scaleY)
            
            let rotatedX = transformedX
            let rotatedY = scaleOffsetValues[5] - transformedY
            
            mapImageView.transform = .identity
            if let existingPointView = mapImageView.viewWithTag(userCoordTag) {
                existingPointView.removeFromSuperview()
            }
            
            let marker = self.imageMapMarker
            let coordSize: CGFloat = 30
            let pointView = UIImageView(image: marker)
            pointView.frame = CGRect(x: rotatedX - coordSize / 2, y: rotatedY - coordSize / 2, width: coordSize, height: coordSize)
            pointView.tag = userCoordTag
            pointView.layer.shadowColor = UIColor.black.cgColor
            pointView.layer.shadowOpacity = 0.25
            pointView.layer.shadowOffset = CGSize(width: 0, height: 2)
            pointView.layer.shadowRadius = 2
            
            let rotationAngle = CGFloat(-(heading - 90) * .pi / 180)
            pointView.transform = CGAffineTransform(rotationAngle: rotationAngle)
            
            UIView.animate(withDuration: 0.55, delay: 0, options: .curveEaseInOut, animations: {
                self.mapImageView.addSubview(pointView)
            }, completion: nil)
            
            self.preXyh = xyh
        }
    }
    
    private func plotUnit(building: String, level: String, units: [Unit], ppCoord: [[Double]]) {
        DispatchQueue.main.async { [self] in
            mapImageView.subviews.forEach { $0.removeFromSuperview() }
            let key = "\(OlympusMapManager.shared.sector_id)_\(building)_\(level)"
            guard let scaleOffsetValues = mapScaleOffset[key], scaleOffsetValues.count == 6 else {
                calMapScaleOffset(building: building, level: level, ppCoord: ppCoord)
                return
            }
            
            let scaleX = scaleOffsetValues[0]
            let scaleY = scaleOffsetValues[1]
            let offsetX = scaleOffsetValues[2]
            let offsetY = scaleOffsetValues[3]
            
            let tempOffsetX = abs(mapImageView.bounds.width - (scaleX*mapImageView.bounds.width))
            let offsetXByScale = scaleX < 1.0 ? (tempOffsetX/2) : -(tempOffsetX/2)

            var scaledXY = [[Double]]()
            for unit in units {
                let x = unit.x
                let y = unit.y
                
                let transformedX = ((x - offsetX)*scaleX) + offsetXByScale
                let transformedY = ((y - offsetY)*scaleY)
                
                let rotatedX = transformedX
                let rotatedY = scaleOffsetValues[5] - transformedY
                scaledXY.append([transformedX, transformedY])
                
                let pointView = UIView(frame: CGRect(x: rotatedX - 2.5, y: rotatedY - 2.5, width: 20, height: 20))
                pointView.alpha = 0.5
                pointView.backgroundColor = .systemGreen
                pointView.layer.cornerRadius = 2.5
                mapImageView.addSubview(pointView)
            }
        }
    }
    
    private func determineUnitProperty(unit: Unit) {
        // Color
        // Size
        
    }
    
    // MARK: - Plot without Scale Up
//    private func plotUserCoord(xyh: [Double]) {
//        DispatchQueue.main.async { [self] in
//            if preXyh == xyh {
//                return
//            }
//
//            let key = "\(OlympusMapManager.shared.sector_id)_\(selectedBuilding ?? "")_\(selectedLevel ?? "")"
//            guard let scaleOffsetValues = mapScaleOffset[key], scaleOffsetValues.count == 6 else {
//                return
//            }
//
//            let scaleX = scaleOffsetValues[0]
//            let scaleY = scaleOffsetValues[1]
//            let offsetX = scaleOffsetValues[2]
//            let offsetY = scaleOffsetValues[3]
//            
//            let tempOffsetX = abs(mapImageView.bounds.width - (scaleX * mapImageView.bounds.width))
//            let offsetXByScale = scaleX < 1.0 ? (tempOffsetX / 2) : -(tempOffsetX / 2)
//            
//            let x = xyh[0]
//            let y = xyh[1]
//            let heading = xyh[2]
//
//            // Reset the transform to ensure consistent rotation and translation
//            mapImageView.transform = .identity
//
//            // Calculate transformed coordinates within the unrotated `mapImageView`
//            let transformedX = ((x - offsetX) * scaleX) + offsetXByScale
//            let transformedY = ((y - offsetY) * scaleY)
//            let rotatedX = transformedX
//            let rotatedY = scaleOffsetValues[5] - transformedY
//
//            // Apply rotation to `mapImageView`
//            let rotationAngle = CGFloat((heading - 90) * .pi / 180)
//            mapImageView.transform = CGAffineTransform(rotationAngle: rotationAngle)
//
//            // Create or update `pointView`
//            if let existingPointView = mapImageView.viewWithTag(userCoordTag) {
//                existingPointView.removeFromSuperview()
//            }
//            let coordSize: CGFloat = 14
//            let radius = coordSize / 2
//            let pointView = CircleView(frame: CGRect(x: rotatedX - radius, y: rotatedY - radius, width: coordSize, height: coordSize), radius: radius)
//            pointView.tag = userCoordTag
//            mapImageView.addSubview(pointView)
//            
//            let mapCenterX = bounds.midX
//            let mapCenterY = bounds.midY
//            let pointViewCenterInSelf = scrollView.convert(pointView.center, to: self)
//            
//            let translationX = mapCenterX - pointViewCenterInSelf.x
//            let translationY = mapCenterY - pointViewCenterInSelf.y
//            mapImageView.transform = mapImageView.transform.translatedBy(x: translationX, y: translationY)
//
//            // Store the previous coordinates
//            self.preXyh = xyh
//        }
//    }
    
    // MARK: - Plot Rotation & Scale Up
//    private func plotUserCoord(xyh: [Double]) {
//        DispatchQueue.main.async { [self] in
//            if preXyh == xyh {
//                return
//            }
//
//            let key = "\(OlympusMapManager.shared.sector_id)_\(selectedBuilding ?? "")_\(selectedLevel ?? "")"
//            guard let scaleOffsetValues = mapScaleOffset[key], scaleOffsetValues.count == 6 else {
//                return
//            }
//
//            let scaleX = scaleOffsetValues[0]
//            let scaleY = scaleOffsetValues[1]
//            let offsetX = scaleOffsetValues[2]
//            let offsetY = scaleOffsetValues[3]
//                
//            let tempOffsetX = abs(mapImageView.bounds.width - (scaleX * mapImageView.bounds.width))
//            let offsetXByScale = scaleX < 1.0 ? (tempOffsetX / 2) : -(tempOffsetX / 2)
//                
//            let x = xyh[0]
//            let y = xyh[1]
//            let heading = xyh[2]
//
//            let transformedX = ((x - offsetX) * scaleX) + offsetXByScale
//            let transformedY = ((y - offsetY) * scaleY)
//            let rotatedX = transformedX
//            let rotatedY = scaleOffsetValues[5] - transformedY
//
//            if let existingPointView = mapImageView.viewWithTag(userCoordTag) {
//                existingPointView.removeFromSuperview()
//            }
//
//            let coordSize: CGFloat = 14
//            let radius = coordSize / 2
//            let pointView = CircleView(frame: CGRect(x: rotatedX - radius, y: rotatedY - radius, width: coordSize, height: coordSize), radius: radius)
//            pointView.tag = userCoordTag
//            mapImageView.addSubview(pointView)
//
//            let rotationAngle = CGFloat((heading - 90) * .pi / 180)
//            let scaleFactor: CGFloat = 6.0
//            let mapCenterX = bounds.midX
//            let mapCenterY = bounds.midY
//            let pointViewCenterInSelf = scrollView.convert(pointView.center, to: self)
//                
//            let dx = -USER_CENTER_OFFSET * cos(heading * (.pi / 180))
//            let dy = USER_CENTER_OFFSET * sin(heading * (.pi / 180))
//                
//            let translationX = mapCenterX - pointViewCenterInSelf.x + dx
//            let translationY = mapCenterY - pointViewCenterInSelf.y + dy
//            
//            // Smooth Animation
//            UIView.animate(withDuration: 0.55, delay: 0, options: .curveEaseInOut, animations: {
//                self.mapImageView.transform = CGAffineTransform(rotationAngle: rotationAngle)
//                    .scaledBy(x: scaleFactor, y: scaleFactor)
//                    .translatedBy(x: translationX, y: translationY)
//            }, completion: nil)
//            
//            // without Animation
////            mapImageView.transform = mapImageView.transform.translatedBy(x: translationX, y: translationY)
//            self.preXyh = xyh
//        }
//    }
    
    private func plotUserCoordWithZoomAndRotation(building: String, level: String,xyh: [Double], type: PlotType) {
        DispatchQueue.main.async { [self] in
            if preXyh == xyh && type == .NORMAL {
                return
            }

            let key = "\(OlympusMapManager.shared.sector_id)_\(selectedBuilding ?? "")_\(selectedLevel ?? "")"
            guard let scaleOffsetValues = mapScaleOffset[key], scaleOffsetValues.count == 6 else {
                if let ppCoord = OlympusPathMatchingCalculator.shared.PpCoord[key] {
                    calMapScaleOffset(building: building, level: level, ppCoord: ppCoord)
                }
                return
            }

            let scaleX = scaleOffsetValues[0]
            let scaleY = scaleOffsetValues[1]
            let offsetX = scaleOffsetValues[2]
            let offsetY = scaleOffsetValues[3]
                
            let tempOffsetX = abs(mapImageView.bounds.width - (scaleX * mapImageView.bounds.width))
            let offsetXByScale = scaleX < 1.0 ? (tempOffsetX / 2) : -(tempOffsetX / 2)
                
            let x = xyh[0]
            let y = xyh[1]
            let heading = xyh[2]

            let transformedX = ((x - offsetX) * scaleX) + offsetXByScale
            let transformedY = ((y - offsetY) * scaleY)
            let rotatedX = transformedX
            let rotatedY = scaleOffsetValues[5] - transformedY

            if let existingPointView = mapImageView.viewWithTag(userCoordTag) {
                existingPointView.removeFromSuperview()
            }
            
            let marker = self.imageMapMarker
            let coordSize: CGFloat = 14
            let pointView = UIImageView(image: marker)
            pointView.frame = CGRect(x: rotatedX - coordSize / 2, y: rotatedY - coordSize / 2, width: coordSize, height: coordSize)
            pointView.tag = userCoordTag
            
            // Adding shadow effect to pointView
            pointView.layer.shadowColor = UIColor.black.cgColor
            pointView.layer.shadowOpacity = 0.25
            pointView.layer.shadowOffset = CGSize(width: 0, height: 2)
            pointView.layer.shadowRadius = 2
            
            UIView.animate(withDuration: 0.55, delay: 0, options: .curveEaseInOut, animations: {
                self.mapImageView.addSubview(pointView)
            }, completion: nil)
            

            let rotationAngle = CGFloat((heading - 90) * .pi / 180)
            let scaleFactor: CGFloat = 4.0
            let mapCenterX = bounds.midX
            let mapCenterY = bounds.midY
            let pointViewCenterInSelf = scrollView.convert(pointView.center, to: self)
                
            let dx = -USER_CENTER_OFFSET * cos(heading * (.pi / 180))
            let dy = USER_CENTER_OFFSET * sin(heading * (.pi / 180))
                
            let translationX = mapCenterX - pointViewCenterInSelf.x + dx
            let translationY = mapCenterY - pointViewCenterInSelf.y + dy
            
            UIView.animate(withDuration: 0.55, delay: 0, options: .curveEaseInOut, animations: {
                self.mapImageView.transform = CGAffineTransform(rotationAngle: rotationAngle)
                    .scaledBy(x: scaleFactor, y: scaleFactor)
                    .translatedBy(x: translationX, y: translationY)
            }, completion: nil)
            pointView.transform = CGAffineTransform(rotationAngle: -rotationAngle)

            self.preXyh = xyh
        }
    }
    
    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if collectionView == buildingsCollectionView {
            return buildingData.count
        } else if collectionView == levelsCollectionView {
            return levelData.count
        }
        return 0
    }
    
    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if collectionView == buildingsCollectionView {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "BuildingCell", for: indexPath)
            
            let buildingName = buildingData[indexPath.row]
            cell.contentView.subviews.forEach { $0.removeFromSuperview() }
            
            let label = UILabel(frame: cell.contentView.bounds)
            label.text = buildingName
            label.textAlignment = .center
            label.font = .systemFont(ofSize: 12, weight: .semibold)

            if buildingName == selectedBuilding {
                label.textColor = .white
                cell.backgroundColor = .systemBlue
                cell.layer.borderWidth = 0
            } else {
                label.textColor = .black
                cell.backgroundColor = .systemGray6
                cell.layer.borderWidth = 0
                cell.layer.borderColor = UIColor.black.cgColor
            }
            
            cell.contentView.addSubview(label)
            return cell
        } else if collectionView == levelsCollectionView {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "LevelCell", for: indexPath)
            
            let levelName = levelData[indexPath.row]
            cell.contentView.subviews.forEach { $0.removeFromSuperview() }
            
            let label = UILabel(frame: cell.contentView.bounds)
            label.text = levelName
            label.textAlignment = .center
            label.font = .systemFont(ofSize: 12, weight: .semibold)

            if levelName == selectedLevel {
                label.textColor = .white
                cell.backgroundColor = .systemBlue
                cell.layer.borderWidth = 0
            } else {
                label.textColor = .black
                cell.backgroundColor = .systemGray6
                cell.layer.borderWidth = 0
                cell.layer.borderColor = UIColor.black.cgColor
            }
            cell.contentView.addSubview(label)
            
            return cell
        }
        return UICollectionViewCell()
    }
    
    public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return cellSize
    }
    
    public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if collectionView == buildingsCollectionView {
            let selectedBuildingName = buildingData[indexPath.row]
            self.selectedBuilding = selectedBuildingName
            self.forceToMapInteractionMode()
            if let levels = OlympusMapManager.shared.getSectorBuildingLevel(sector_id: OlympusMapManager.shared.sector_id)[selectedBuildingName] {
                self.levelData = levels
                self.selectedLevel = self.levelData.first
            } else {
                self.levelData = []
                self.selectedLevel = nil
            }
            buildingsCollectionView.reloadData()
            levelsCollectionView.reloadData()
            adjustCollectionViewHeights()
            updateMapImageView()
            updatePathPixel()
            updateUnit()
        } else if collectionView == levelsCollectionView {
            let selectedLevelName = levelData[indexPath.row]
            self.selectedLevel = selectedLevelName
            self.forceToMapInteractionMode()
            levelsCollectionView.reloadData()
            updateMapImageView()
            updatePathPixel()
            updateUnit()
        }
    }
    
    // MARK: - Building & Level Images
    private func observeImageUpdates() {
        NotificationCenter.default.addObserver(forName: .sectorImagesUpdated, object: nil, queue: .main) { [weak self] notification in
            guard let userInfo = notification.userInfo, let imageKey = userInfo["imageKey"] as? String else { return }
            self?.updateImageIfNecessary(imageKey: imageKey)
        }
    }

    private func updateImageIfNecessary(imageKey: String) {
        guard let selectedBuilding = selectedBuilding, let selectedLevel = selectedLevel else { return }
        let expectedImageKey = "image_\(OlympusMapManager.shared.sector_id)_\(selectedBuilding)_\(selectedLevel)"
        if imageKey == expectedImageKey {
            updateMapImageView()
        }
    }
    
    // MARK: - Building & Level Scales
    private func observeScaleUpdates() {
        NotificationCenter.default.addObserver(forName: .sectorScalesUpdated, object: nil, queue: .main) { [weak self] notification in
            guard let userInfo = notification.userInfo, let scaleKey = userInfo["scaleKey"] as? String else { return }
            self?.sectorScales[scaleKey] = OlympusMapManager.shared.sectorScales[scaleKey]
        }
    }
    
    private func scaleUpdated(_ notification: Notification) {
        guard let userInfo = notification.userInfo, let scaleKey = userInfo["scaleKey"] as? String else { return }
        self.sectorScales[scaleKey] = OlympusMapManager.shared.sectorScales[scaleKey]
    }
    
    private func observeUnitUpdates() {
        NotificationCenter.default.addObserver(forName: .sectorUnitsUpdated, object: nil, queue: .main) { [weak self] notification in
            guard let userInfo = notification.userInfo, let unitKey = userInfo["unitKey"] as? String else { return }
            print(getLocalTimeString() + " , (Olympus) MapView : observe \(unitKey)")
            self?.sectorUnits[unitKey] = OlympusMapManager.shared.sectorUnits[unitKey]
            self?.updateUnitIfNecessary(unitKey: unitKey)
        }
    }
    
    private func unitUpdated(_ notification: Notification) {
        guard let userInfo = notification.userInfo, let unitKey = userInfo["unitKey"] as? String else { return }
        self.sectorUnits[unitKey] = OlympusMapManager.shared.sectorUnits[unitKey]
    }
    
    private func updateUnitIfNecessary(unitKey: String) {
        guard let selectedBuilding = selectedBuilding, let selectedLevel = selectedLevel else { return }
        let expectedUnitKey = "unit_\(OlympusMapManager.shared.sector_id)_\(selectedBuilding)_\(selectedLevel)"
        print(getLocalTimeString() + " , (Olympus) MapView : expectedUnitKey = \(expectedUnitKey) // unitKey = \(unitKey)")
        if unitKey == expectedUnitKey {
            updateUnit()
        }
    }
    
    // MARK: - Building & Level Path-Pixels
    private func observePathPixelUpdates() {
        NotificationCenter.default.addObserver(forName: .sectorPathPixelUpdated, object: nil, queue: .main) { [weak self] notification in
            guard let userInfo = notification.userInfo, let pathPixelKey = userInfo["pathPixelKey"] as? String else { return }
            self?.updatePathPixelIfNecessary(pathPixelKey: pathPixelKey)
        }
    }

    private func updatePathPixelIfNecessary(pathPixelKey: String) {
        guard let selectedBuilding = selectedBuilding, let selectedLevel = selectedLevel else { return }
        let expectedPpKey = "\(OlympusMapManager.shared.sector_id)_\(selectedBuilding)_\(selectedLevel)"
        if pathPixelKey == expectedPpKey {
            updatePathPixel()
        }
    }
    
    func calculateAspectFitImageSize(for image: UIImage, in imageView: UIImageView) -> CGSize {
        let imageSize = image.size
        let imageViewSize = imageView.bounds.size
        let widthRatio = imageViewSize.width / imageSize.width
        let heightRatio = imageViewSize.height / imageSize.height
        
        let scaleFactor = min(widthRatio, heightRatio)
        
        let scaledWidth = imageSize.width * scaleFactor
        let scaledHeight = imageSize.height * scaleFactor
        
        print(getLocalTimeString() + " , (Olympus) MapView : image // w = \(imageSize.width) , h = \(imageSize.height)")
        print(getLocalTimeString() + " , (Olympus) MapView : imageView // w = \(imageViewSize.width) , h = \(imageViewSize.height)")
        print(getLocalTimeString() + " , (Olympus) MapView : imageView // scaleFactor = \(scaleFactor)")
        return CGSize(width: scaledWidth, height: scaledHeight)
    }
    
    public func updateResultInMap(result: FineLocationTrackingResult) {
        if mode == .MAP_ONLY {
            mode = .UPDATE_USER
            toggleZoomMode(to: .ZOOM_IN)
            DispatchQueue.main.async { [self] in
                zoomButton.isHidden = false
                myLocationButton.isHidden = false
            }
        } else if mode == .MAP_INTERACTION {
            DispatchQueue.main.async { [self] in
                if zoomButton.isHidden {
                    zoomButton.isHidden = false
                    myLocationButton.isHidden = false
                }
            }
            if (getCurrentTimeInMilliseconds() - mapModeChangedTime) > TIME_FOR_REST && mapModeChangedTime != 0 {
                mode = .UPDATE_USER
            }
        }
        
        if mode == .MAP_INTERACTION {
            let newBuilding = result.building_name
            let newLevel = result.level_name
            
            let buildingChanged = selectedBuilding != newBuilding
            let levelChanged = selectedLevel != newLevel
            
            if !buildingChanged && !levelChanged {
                plotUserCoord(building: newBuilding, level: newLevel, xyh: [result.x, result.y, result.absolute_heading])
            }
        } else if mode == .UPDATE_USER {
            let newBuilding = result.building_name
            let newLevel = result.level_name
            
            let buildingChanged = selectedBuilding != newBuilding
            let levelChanged = selectedLevel != newLevel
            
            DispatchQueue.main.async { [self] in
                let velocityString = String(Int(round(result.velocity)))
                self.velocityLabel.text = velocityString
                let attrString = NSAttributedString(
                    string: velocityString,
                    attributes: [
                        NSAttributedString.Key.strokeColor: UIColor.white,
                        NSAttributedString.Key.foregroundColor: UIColor.black,
                        NSAttributedString.Key.strokeWidth: -3.0,
                        NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: 53.0)
                    ]
                )
                self.velocityLabel.attributedText = attrString
                
                if buildingChanged || levelChanged {
                    selectedBuilding = newBuilding
                    selectedLevel = newLevel
                    
                    buildingsCollectionView.reloadData()
                    levelsCollectionView.reloadData()
                    adjustCollectionViewHeights()
                    
                    updateMapImageView()
                    updatePathPixel()
                    updateUnit()
                }
                
                if zoomMode == .ZOOM_IN {
                    plotUserCoordWithZoomAndRotation(building: selectedBuilding ?? "", level: selectedLevel ?? "", xyh: [result.x, result.y, result.absolute_heading], type: .NORMAL)
                } else {
                    // 모드 전환 시기 확인
                    if (getCurrentTimeInMilliseconds() - zoomModeChangedTime) > TIME_FOR_REST && zoomModeChangedTime != 0 {
                        toggleZoomMode()
                        plotUserCoordWithZoomAndRotation(building: selectedBuilding ?? "", level: selectedLevel ?? "", xyh: [result.x, result.y, result.absolute_heading], type: .FORCE)
                    } else {
                        plotUserCoord(building: selectedBuilding ?? "", level: selectedLevel ?? "", xyh: [result.x, result.y, result.absolute_heading])
                    }
                }
            }
        }
        
//        if mode != .UPDATE_USER {
//            mode = .UPDATE_USER
//            toggleZoomMode(to: .ZOOM_IN)
//            DispatchQueue.main.async { [self] in
//                zoomButton.isHidden = false
//                myLocationButton.isHidden = false
//            }
//        }
        
//        let newBuilding = result.building_name
//        let newLevel = result.level_name
//        
//        let buildingChanged = selectedBuilding != newBuilding
//        let levelChanged = selectedLevel != newLevel
//        
//        DispatchQueue.main.async { [self] in
//            let velocityString = String(Int(round(result.velocity)))
//            self.velocityLabel.text = velocityString
//            let attrString = NSAttributedString(
//                string: velocityString,
//                attributes: [
//                    NSAttributedString.Key.strokeColor: UIColor.white,
//                    NSAttributedString.Key.foregroundColor: UIColor.black,
//                    NSAttributedString.Key.strokeWidth: -3.0,
//                    NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: 53.0)
//                ]
//            )
//            self.velocityLabel.attributedText = attrString
//            
//            if buildingChanged || levelChanged {
//                selectedBuilding = newBuilding
//                selectedLevel = newLevel
//                
//                buildingsCollectionView.reloadData()
//                levelsCollectionView.reloadData()
//                adjustCollectionViewHeights()
//                
//                updateMapImageView()
//                updatePathPixel()
//            }
//            
//            if zoomMode == .ZOOM_IN {
//                plotUserCoordWithZoomAndRotation(xyh: [result.x, result.y, result.absolute_heading], type: .NORMAL)
//            } else {
//                // 모드 전환 시기 확인
//                if (getCurrentTimeInMilliseconds() - zoomModeChangedTime) > TIME_FOR_REST && zoomModeChangedTime != 0 {
//                    toggleZoomMode()
//                    plotUserCoordWithZoomAndRotation(xyh: [result.x, result.y, result.absolute_heading], type: .FORCE)
//                } else {
//                    plotUserCoord(xyh: [result.x, result.y, result.absolute_heading])
//                }
//            }
//        }
    }
    
    public func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return mapImageView
    }
    
    private func controlMapDirection(heading: Double) {
        if userHeadingBuffer.count > 5 {
            userHeadingBuffer.remove(at: 0)
        }
        userHeadingBuffer.append(heading)
        
        let majorHeading = heading
        
        // 회전 방향 정하기
        let diffHeading = majorHeading - mapHeading
    }
}

class CircleView: UIView {
    private var radius: CGFloat = 0.0
    
    init(frame: CGRect, radius: CGFloat) {
        super.init(frame: frame)
        self.radius = radius
        self.backgroundColor = .clear
        drawCircle()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        drawCircle()
    }
    
    private func drawCircle() {
        let circleLayer = CAShapeLayer()

        let circlePath = UIBezierPath(
            arcCenter: CGPoint(x: bounds.midX, y: bounds.midY),
            radius: radius,
            startAngle: 0,
            endAngle: CGFloat.pi * 2,
            clockwise: true
        )
        
        circleLayer.path = circlePath.cgPath
        circleLayer.fillColor = UIColor.systemGray6.cgColor
        circleLayer.strokeColor = UIColor.clear.cgColor
        circleLayer.lineWidth = 0
        
        layer.addSublayer(circleLayer)
    }
}
