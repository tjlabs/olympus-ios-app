import UIKit
import Foundation

public protocol MapViewForScaleDelegate: AnyObject {
    func mapScaleUpdated()
}

public class OlympusMapViewForScale: UIView, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, UIScrollViewDelegate {
    public var delegate: MapViewForScaleDelegate?
    
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
    
    private var plotUserCoordWorkItem: DispatchWorkItem?
    
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
    
    private var isInit: Bool = true
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
    private var isPpHidden = false
    private var isUnitHidden = true
    
    private var preXyh = [Double]()
    private var preIndex = -1
    private var userHeadingBuffer = [Double]()
    private var mapHeading: Double = 0
    private let userCoordTag = 999
    
    private var mode: MapMode = .MAP_ONLY
    private var isZoomMode: Bool = false
    
    public var isDefaultScale: Bool = true
    public var mapAndPpScaleValues: [Double] = [0, 0, 0, 0]
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupAssets()
        setupView()
        setupButtons()
        setupButtonActions()
        observeImageUpdates()
        observeUnitUpdates()
        observePathPixelUpdates()
        observeScaleUpdates()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupAssets()
        setupView()
        setupButtons()
        setupButtonActions()
        observeImageUpdates()
        observeUnitUpdates()
        observePathPixelUpdates()
        observeScaleUpdates()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    public func setIsPpHidden(flag: Bool) {
        self.isPpHidden = flag
        if flag {
            self.mapImageView.subviews.forEach { $0.removeFromSuperview() }
            self.delegate?.mapScaleUpdated()
        } else {
            updatePathPixel()
        }
    }
    
    public func setBuildingLevelIsHidden(flag: Bool) {
        self.buildingsCollectionView.isHidden = flag
    }
    
    public func setIsDefaultScale(flag: Bool) {
        self.isDefaultScale = flag
        if self.isPpHidden {
            self.mapImageView.subviews.forEach { $0.removeFromSuperview() }
        }
        updatePathPixel()
    }
    
    public func getMapAndPpScaleValues() -> [Double] {
        return self.mapAndPpScaleValues
    }

    private func setupView() {
        setupMapImageView()
        setupCollectionViews()
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
        
        zoomButton.isHidden = false
        zoomButton.isUserInteractionEnabled = true
        zoomButton.setImage(imageZoomIn, for: .normal)
        zoomButton.translatesAutoresizingMaskIntoConstraints = false
        zoomButton.widthAnchor.constraint(equalToConstant: 40).isActive = true
        zoomButton.heightAnchor.constraint(equalToConstant: 40).isActive = true
        styleButton(zoomButton)
        addSubview(zoomButton)

        NSLayoutConstraint.activate([
            zoomButton.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -20),
            zoomButton.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: -20),
        ])
    }
    
    private func setupButtonActions() {
        zoomButton.addAction(UIAction { [weak self] _ in
            self?.zoomButtonTapped()
        }, for: .touchUpInside)
        
        zoomButton.addAction(UIAction { [weak self] _ in
            self?.zoomButtonTappedOver()
        }, for: [.touchUpInside, .touchUpOutside])
    }
    
    private func zoomButtonTapped() {
        print(getLocalTimeString() + " , (OlympusMapViewForScale) zoomButtonTapped")
        self.zoomButton.isUserInteractionEnabled = false
        UIView.animate(withDuration: 0.1) {
            self.zoomButton.transform = CGAffineTransform(scaleX: 0.98, y: 0.98)
        }
        
        if self.isZoomMode {
            isZoomMode = false
        } else {
            isZoomMode = true
        }
    }
    
    private func zoomButtonTappedOver() {
        UIView.animate(withDuration: 0.1) {
            self.zoomButton.transform = CGAffineTransform.identity
            self.zoomButton.isUserInteractionEnabled = true
        }
    }
    
    public func updateMapAndPpScaleValues(index: Int, value: Double) {
        isDefaultScale = false
        mapAndPpScaleValues[index] = value
        print(getLocalTimeString() + " , (OlympusMapViewForScale) : mapAndPpScaleValues updated to: \(mapAndPpScaleValues)")
        updatePathPixel()
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
//        guard let selectedBuilding = selectedBuilding, let selectedLevel = selectedLevel else { return }
//        let pathPixelKey = "\(OlympusMapManager.shared.sector_id)_\(selectedBuilding)_\(selectedLevel)"
//        let unitKey = "unit_" + pathPixelKey
//
//        if let ppCoord = OlympusPathMatchingCalculator.shared.PpCoord[pathPixelKey] {
//            guard let scaleOffsetValues = mapScaleOffset[pathPixelKey], scaleOffsetValues.count == 6 else {
//                print(getLocalTimeString() + " , (Olympus) MapView : Scale Empty in Unit")
//                calMapScaleOffset(building: selectedBuilding, level: selectedLevel, ppCoord: ppCoord)
//                return
//            }
//            if !self.isUnitHidden {
//                guard let units = self.sectorUnits[unitKey] else {
//                    print(getLocalTimeString() + " , (Olympus) MapView : Unit Empty \(unitKey)")
//                    DispatchQueue.main.async { [self] in
//                        mapImageView.subviews.forEach { $0.removeFromSuperview() }
//                    }
//                    return
//                }
//                plotUnit(building: selectedBuilding, level: selectedLevel, units: units, ppCoord: ppCoord)
//            }
//        }
    }
    
    private func calMapScaleOffset(building: String, level: String, ppCoord: [[Double]]) {
        DispatchQueue.main.async { [self] in
            guard let image = mapImageView.image else { return }
            
            let key = "\(OlympusMapManager.shared.sector_id)_\(building)_\(level)"
            let scaledSize = calculateAspectFitImageSize(for: image, in: mapImageView)
            
            let xCoords = ppCoord[0]
            let yCoords = ppCoord[1]
            
            guard let ppMinX = xCoords.min(),
                  let ppMaxX = xCoords.max(),
                  let ppMinY = yCoords.min(),
                  let ppMaxY = yCoords.max() else { return }
            
            print(getLocalTimeString() + " , (Olympus) MapView : calMapScaleOffset // xyMinMax = [\(ppMinX),\(ppMaxX),\(ppMinY),\(ppMaxY)]")
            
            let minX: Double = ppMinX
            let maxX: Double = ppMaxX
            let minY: Double = ppMinY
            let maxY: Double = ppMaxY
            
            let ppWidth: Double = maxX - minX
            let ppHeight: Double = maxY - minY

            let scaleX = scaledSize.width / ppWidth
            let scaleY = scaledSize.height / ppHeight

            let offsetX = minX
            let offsetY =  -maxY
            
            let scaleKey = "scale_" + key
            let sectorScale: [Double] = sectorScales[scaleKey] ?? []
            
            print(getLocalTimeString() + " , (Olympus) MapView : isDefaultScale \(isDefaultScale) // sectorScale = \(sectorScale)")
            if self.isDefaultScale {
                if sectorScale.isEmpty {
                    mapAndPpScaleValues = [scaleX, scaleY, offsetX, offsetY]
                    mapScaleOffset[key] = [scaleX, scaleY, offsetX, offsetY]
                } else {
                    mapAndPpScaleValues = sectorScale
                    mapScaleOffset[key] = sectorScale
                }
            }
            print(getLocalTimeString() + " , (Olympus) MapView : mapAndPpScaleValues = \(mapAndPpScaleValues)")
            self.delegate?.mapScaleUpdated()
        }
    }
    
    private func plotPathPixels(building: String, level: String, ppCoord: [[Double]]) {
        DispatchQueue.main.async { [self] in
            mapImageView.subviews.forEach { $0.removeFromSuperview() }
            let key = "\(OlympusMapManager.shared.sector_id)_\(building)_\(level)"
            guard let scaleOffsetValues = mapScaleOffset[key], scaleOffsetValues.count == 4 else {
                calMapScaleOffset(building: building, level: level, ppCoord: ppCoord)
                return
            }
            let markerSize: Double = 10
            let scales: [Double] = isDefaultScale ? scaleOffsetValues : self.mapAndPpScaleValues
            print(getLocalTimeString() + " , (Olympus) MapView : \(key) // isDefaultScale = \(isDefaultScale) // scales = \(scales)")
            let offsetValue = scaleOffsetValues[3]
            var scaledXY = [[Double]]()
            for i in 0..<ppCoord[0].count {
                let x = ppCoord[0][i]
                let y = -ppCoord[1][i]
                
                let transformedX = (x - scales[2])*scales[0]
                let transformedY = (y - scales[3])*scales[1]
                
                let rotatedX = transformedX
                let rotatedY = transformedY
                
//                print(getLocalTimeString() + " , (Olympus) MapView : \(x),\(y) -> \(rotatedX),\(rotatedY)")
                scaledXY.append([transformedX, transformedY])
                
                let pointView = UIView(frame: CGRect(x: rotatedX - markerSize/2, y: rotatedY - markerSize/2, width: markerSize, height: markerSize))
                pointView.backgroundColor = .systemYellow
                pointView.layer.cornerRadius = markerSize/2
                mapImageView.addSubview(pointView)
            }
        }
    }
    
    public func plotUnitUsingCoord(unitView: UIView) {
        DispatchQueue.main.async { [self] in
            mapImageView.addSubview(unitView)
        }
    }
    
    private func plotUnit(building: String, level: String, units: [Unit], ppCoord: [[Double]]) {
        DispatchQueue.main.async { [self] in
            mapImageView.subviews.forEach { $0.removeFromSuperview() }
            let key = "\(OlympusMapManager.shared.sector_id)_\(building)_\(level)"
            guard let scaleOffsetValues = mapScaleOffset[key], scaleOffsetValues.count == 4 else {
                calMapScaleOffset(building: building, level: level, ppCoord: ppCoord)
                return
            }
            let markerSize: Double = 20
            let scales: [Double] = isDefaultScale ? scaleOffsetValues : self.mapAndPpScaleValues
            print(getLocalTimeString() + " , (Olympus) MapView : \(key) // isDefaultScale = \(isDefaultScale) // scales = \(scales)")
            let offsetValue = scaleOffsetValues[3]
            var scaledXY = [[Double]]()
            for unit in units {
                let x = unit.x
                let y = -unit.y
                
                let transformedX = (x - scales[2])*scales[0]
                let transformedY = (y - scales[3])*scales[1]
                
                let rotatedX = transformedX
                let rotatedY = transformedY
                scaledXY.append([transformedX, transformedY])
                
                let pointView = UIView(frame: CGRect(x: rotatedX - 2.5, y: rotatedY - 2.5, width: 20, height: 20))
                pointView.alpha = 0.5
                pointView.backgroundColor = .systemGreen
                pointView.layer.cornerRadius = 2.5
                mapImageView.addSubview(pointView)
            }
        }
    }

    private func plotUserCoord(building: String, level: String, xyh: [Double]) {
        // Cancel any existing work item
        plotUserCoordWorkItem?.cancel()

        // Create a new work item
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }

            if self.preXyh == xyh {
                return
            }

            let key = "\(OlympusMapManager.shared.sector_id)_\(building)_\(level)"
            guard let scaleOffsetValues = self.mapScaleOffset[key], scaleOffsetValues.count == 4 else {
                if let ppCoord = OlympusPathMatchingCalculator.shared.PpCoord[key] {
                    self.calMapScaleOffset(building: building, level: level, ppCoord: ppCoord)
                }
                return
            }
            let scales: [Double] = self.isDefaultScale ? scaleOffsetValues : self.mapAndPpScaleValues

            let x = xyh[0]
            let y = -xyh[1]
            let heading = xyh[2]

            let transformedX = (x - scales[2]) * scales[0]
            let transformedY = (y - scales[3]) * scales[1]

            let rotatedX = transformedX
            let rotatedY = transformedY

            DispatchQueue.main.async {
                self.mapImageView.transform = .identity
                if let existingPointView = self.mapImageView.viewWithTag(self.userCoordTag) {
                    existingPointView.removeFromSuperview()
                }

                let marker = self.imageMapMarker
                let coordSize: CGFloat = 30
                let pointView = UIImageView(image: marker)
                pointView.frame = CGRect(x: rotatedX - coordSize / 2, y: rotatedY - coordSize / 2, width: coordSize, height: coordSize)
                pointView.tag = self.userCoordTag
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

        // Assign and execute the new work item
        plotUserCoordWorkItem = workItem
        DispatchQueue.global(qos: .userInteractive).async(execute: workItem)
    }
    
    private func plotUserCoordWithZoomAndRotation(building: String, level: String,xyh: [Double]) {
        plotUserCoordWorkItem?.cancel()
        
        // Create a new work item
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }

            if self.preXyh == xyh {
                return
            }

            let key = "\(OlympusMapManager.shared.sector_id)_\(building)_\(level)"
            guard let scaleOffsetValues = self.mapScaleOffset[key], scaleOffsetValues.count == 4 else {
                if let ppCoord = OlympusPathMatchingCalculator.shared.PpCoord[key] {
                    self.calMapScaleOffset(building: building, level: level, ppCoord: ppCoord)
                }
                return
            }
            let scales: [Double] = self.isDefaultScale ? scaleOffsetValues : self.mapAndPpScaleValues

            let x = xyh[0]
            let y = -xyh[1]
            let heading = xyh[2]

            let transformedX = (x - scales[2]) * scales[0]
            let transformedY = (y - scales[3]) * scales[1]

            let rotatedX = transformedX
            let rotatedY = transformedY

            DispatchQueue.main.async { [self] in
//                self.mapImageView.transform = .identity
                if let existingPointView = self.mapImageView.viewWithTag(self.userCoordTag) {
                    existingPointView.removeFromSuperview()
                }

                let marker = self.imageMapMarker
                let coordSize: CGFloat = 30
                let pointView = UIImageView(image: marker)
                pointView.frame = CGRect(x: rotatedX - coordSize / 2, y: rotatedY - coordSize / 2, width: coordSize, height: coordSize)
                pointView.tag = self.userCoordTag
                
                // Adding shadow effect to pointView
                pointView.layer.shadowColor = UIColor.black.cgColor
                pointView.layer.shadowOpacity = 0.25
                pointView.layer.shadowOffset = CGSize(width: 0, height: 2)
                pointView.layer.shadowRadius = 2
                
                UIView.animate(withDuration: 0.55, delay: 0, options: .curveEaseInOut, animations: {
                    self.mapImageView.addSubview(pointView)
                }, completion: nil)
                

                let rotationAngle = CGFloat((heading - 90) * .pi / 180)
                let scaleFactor: CGFloat = 2.0
                let mapCenterX = self.bounds.midX
                let mapCenterY = self.bounds.midY
                let pointViewCenterInSelf = self.scrollView.convert(pointView.center, to: self)
                
                let USER_CENTER_OFFSET: CGFloat = 40
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

        // Assign and execute the new work item
        plotUserCoordWorkItem = workItem
        DispatchQueue.global(qos: .userInteractive).async(execute: workItem)
    }

    
//    private func plotUserCoord(building: String, level: String, xyh: [Double]) {
//        DispatchQueue.main.async { [self] in
//            if preXyh == xyh {
//                return
//            }
//            
//            let key = "\(OlympusMapManager.shared.sector_id)_\(building)_\(level)"
//            guard let scaleOffsetValues = mapScaleOffset[key], scaleOffsetValues.count == 4 else {
//                if let ppCoord = OlympusPathMatchingCalculator.shared.PpCoord[key] {
//                    calMapScaleOffset(building: building, level: level, ppCoord: ppCoord)
//                }
//                return
//            }
//            let scales: [Double] = isDefaultScale ? scaleOffsetValues : self.mapAndPpScaleValues
////            print(getLocalTimeString() + " , (PlotUserCoord) display = \(xyh)")
//            let x = xyh[0]
//            let y = -xyh[1]
//            let heading = xyh[2]
//            
//            let transformedX = (x - scales[2])*scales[0]
//            let transformedY = (y - scales[3])*scales[1]
//            
//            let rotatedX = transformedX
//            let rotatedY = transformedY
//            
//            mapImageView.transform = .identity
//            if let existingPointView = mapImageView.viewWithTag(userCoordTag) {
//                existingPointView.removeFromSuperview()
//            }
//            
//            let marker = self.imageMapMarker
//            let coordSize: CGFloat = 30
//            let pointView = UIImageView(image: marker)
//            pointView.frame = CGRect(x: rotatedX - coordSize / 2, y: rotatedY - coordSize / 2, width: coordSize, height: coordSize)
//            pointView.tag = userCoordTag
//            pointView.layer.shadowColor = UIColor.black.cgColor
//            pointView.layer.shadowOpacity = 0.25
//            pointView.layer.shadowOffset = CGSize(width: 0, height: 2)
//            pointView.layer.shadowRadius = 2
//            
//            let rotationAngle = CGFloat(-(heading - 90) * .pi / 180)
//            pointView.transform = CGAffineTransform(rotationAngle: rotationAngle)
//            
//            UIView.animate(withDuration: 0.55, delay: 0, options: .curveEaseInOut, animations: {
//                self.mapImageView.addSubview(pointView)
//            }, completion: nil)
//            
//            self.preXyh = xyh
//        }
//    }
    
    public func updateResultInMap(result: FineLocationTrackingResult) {
        let newBuilding = result.building_name
        let newLevel = result.level_name
        
        let buildingChanged = isInit ? true : selectedBuilding != newBuilding
        let levelChanged = isInit ? true : selectedLevel != newLevel
//        print(getLocalTimeString() + " , (PlotUserCoord) result = \(result.x),\(result.y),\(result.absolute_heading)")
        DispatchQueue.main.async { [self] in
            if buildingChanged || levelChanged {
                isInit = false
                selectedBuilding = newBuilding
                selectedLevel = newLevel
                
                buildingsCollectionView.reloadData()
                levelsCollectionView.reloadData()
                adjustCollectionViewHeights()
                
                updateMapImageView()
                updatePathPixel()
                updateUnit()
            }
            
            if self.isZoomMode {
                plotUserCoordWithZoomAndRotation(building: selectedBuilding ?? "", level: selectedLevel ?? "", xyh: [result.x, result.y, result.absolute_heading])
            } else {
                plotUserCoord(building: selectedBuilding ?? "", level: selectedLevel ?? "", xyh: [result.x, result.y, result.absolute_heading])
            }
//            plotUserCoord(building: selectedBuilding ?? "", level: selectedLevel ?? "", xyh: [result.x, result.y, result.absolute_heading])
//            plotUserCoordWithZoomAndRotation(building: selectedBuilding ?? "", level: selectedLevel ?? "", xyh: [result.x, result.y, result.absolute_heading])
        }
        preIndex = result.index
    }
    
    private func determineUnitProperty(unit: Unit) {
        // Color
        // Size
        
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
            levelsCollectionView.reloadData()
            updateMapImageView()
            updatePathPixel()
            updateUnit()
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
    
    public func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return mapImageView
    }
}
