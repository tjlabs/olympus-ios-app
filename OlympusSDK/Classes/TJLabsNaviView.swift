
import Foundation
import TJLabsResource
import UIKit

public class TJLabsNaviView: UIView, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, UIScrollViewDelegate, TJLabsMapManagerDelegate {

    func onBuildingLevelData(_ manager: TJLabsMapManager, buildingLevelData: [String : [String]]) {
        self.updateBuildingData(Array(buildingLevelData.keys), levelData: buildingLevelData)
    }
    
    func onPathPixelData(_ manager: TJLabsMapManager, pathPixelKey: String, data: TJLabsResource.PathPixelData) {
        self.updatePathPixelIfNecessary(pathPixelKey: pathPixelKey)
    }
    
    func onBuildingLevelImageData(_ manager: TJLabsMapManager, imageKey: String, data: UIImage) {
        self.updateMapImageIfNecessary(imageKey: imageKey)
    }
    
    func onScaleOffsetData(_ manager: TJLabsMapManager, scaleKey: String, data: [Double]) {
        self.buildingLevelScale[scaleKey] = data
        updatePathPixel()
        updateMapImageView()
    }
    
    func onUnitData(_ manager: TJLabsMapManager, unitKey: String, data: [TJLabsResource.UnitData]) {
        print("(TJLabsNaviView) onUnitData : unitKey = \(unitKey) , data = \(data)")
    }
    
    
    private var region: ResourceRegion = .KOREA
    private var sectorId: Int = -1
    private let mapManager = TJLabsMapManager()

    
    private var mapImageView = UIImageView()
    private var buildingsCollectionView: UICollectionView!
    private var levelsCollectionView: UICollectionView!
    private let scrollView = UIScrollView()
    private var velocityLabel = TJLabsVelocityLabel()
    private let myLocationButton = TJLabsMyLocationButton()
    private let zoomButton = TJLabsZoomButton()
    
    private var imageMapMarker: UIImage?
    
    private var buildingData = [String]()
    private var levelData = [String]()
    private var buildingLevelScale = [String: [Double]]()
    private var selectedBuilding: String?
    private var selectedLevel: String?
    private let cellSize: CGSize = CGSize(width: 30, height: 30)
    private let cellSpacing: CGFloat = 0.1
    private var maxCollectionViewHeight: CGFloat = 0
    private var buildingsCollectionViewHeightConstraint: NSLayoutConstraint!
    private var levelsCollectionViewHeightConstraint: NSLayoutConstraint!
    private var levelsLeadingToSuperviewConstraint: NSLayoutConstraint!
    private var levelsLeadingToBuildingsConstraint: NSLayoutConstraint!
    
    private var currentScale: CGFloat = 1.0
    private var isPpHidden = true
    private var isUnitHidden = true
    
    private var preXyh = [Double]()
    private let userCoordTag = 999
    
    private var mode: MapMode = .MAP_ONLY
    private var mapModeChangedTime = 0

    private let TIME_FOR_REST: Int = 31000
    private let USER_CENTER_OFFSET: CGFloat = 40
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupAssets()
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupAssets()
        setupView()
    }
    
    public func initialze(region: ResourceRegion, sectorId: Int) {
        self.region = region
        self.sectorId = sectorId
        mapManager.delegate = self
        mapManager.loadMap(region: region, sectorId: sectorId)
    }
    
    public func setIsPpHidden(flag: Bool) {
        self.isPpHidden = flag
    }

    private func setupView() {
        setupMapImageView()
        setupCollectionViews()
        setupLabels()
        setupButtons()
        setupButtonActions()
    }
    
    private func setupLabels() {
        addSubview(velocityLabel)
        NSLayoutConstraint.activate([
            velocityLabel.topAnchor.constraint(equalTo: self.topAnchor, constant: 40),
            velocityLabel.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 40)
        ])
    }
    
    private func setupButtons() {
        [zoomButton, myLocationButton].forEach {
            $0.widthAnchor.constraint(equalToConstant: 40).isActive = true
            $0.heightAnchor.constraint(equalToConstant: 40).isActive = true
            addSubview($0)
        }

        NSLayoutConstraint.activate([
            myLocationButton.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -20),
            myLocationButton.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: -20),
            zoomButton.trailingAnchor.constraint(equalTo: myLocationButton.trailingAnchor),
            zoomButton.bottomAnchor.constraint(equalTo: myLocationButton.topAnchor, constant: -10)
        ])
    }
    
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
            self.mapModeChangedTime = mapManager.getCurrentTimeInMilliseconds()
            self.toggleZoomMode(to: .ZOOM_OUT)
            
            mapImageView.transform = .identity
            if let existingPointView = mapImageView.viewWithTag(userCoordTag) {
                existingPointView.removeFromSuperview()
            }
        }
    }
    
    private func forceToZoomInMode() {
        if TJLabsZoomButton.zoomMode == .ZOOM_OUT {
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
        zoomButton.setButtonImage(to: mode)
        if TJLabsZoomButton.zoomMode == .ZOOM_IN {
            // 현재 확대 모드
            if !preXyh.isEmpty {
                plotUserCoordWithZoomAndRotation(building: selectedBuilding ?? "", level: selectedLevel ?? "", xyh: preXyh, type: .FORCE)
            }
        } else {
            zoomButton.updateZoomModeChangedTime(time: mapManager.getCurrentTimeInMilliseconds())
            // 현재 전체 모드
            if !preXyh.isEmpty && self.mode != .MAP_INTERACTION {
                plotUserCoord(building: selectedBuilding ?? "", level: selectedLevel ?? "", xyh: preXyh)
            }
        }
    }
    
    private func setupAssets() {
        if let bundleURL = Bundle(for: OlympusSDK.TJLabsNaviView.self).url(forResource: "OlympusSDK", withExtension: "bundle") {
            if let resourceBundle = Bundle(url: bundleURL) {
                if let mapMarker = UIImage(named: "icon_mapMarker", in: resourceBundle, compatibleWith: nil) {
                    self.imageMapMarker = mapMarker
                } else {
                    print(getLocalTimeString() + " , (Olympus) Error : Could not load icon_mapMarker.png from bundle.")
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
        self.maxCollectionViewHeight = 5 * (cellSize.height + cellSpacing) - cellSpacing
        
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
        
        buildingsCollectionView.showsVerticalScrollIndicator = false
        buildingsCollectionView.bounces = false
        levelsCollectionView.showsVerticalScrollIndicator = false
        levelsCollectionView.bounces = false
    }
    
    private func calculateCollectionViewHeight(for itemCount: Int) -> CGFloat {
        let computedHeight = CGFloat(itemCount) * (cellSize.height + cellSpacing) - cellSpacing
        return min(computedHeight, maxCollectionViewHeight)
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

        buildingsCollectionViewHeightConstraint.constant = buildingHeight
        levelsCollectionViewHeightConstraint.constant = levelHeight

        buildingsCollectionView.isScrollEnabled = buildingData.count > 5
        levelsCollectionView.isScrollEnabled = levelData.count > 5

        UIView.animate(withDuration: 0.3) {
            self.layoutIfNeeded()
        }
    }

    
    private func updateMapImageView() {
        guard let selectedBuilding = selectedBuilding, let selectedLevel = selectedLevel else { return }
        
        let pathPixelKey = "\(self.sectorId)_\(selectedBuilding)_\(selectedLevel)"
        let imageKey = "image_" + pathPixelKey
        
        if let image = mapManager.buildingLevelImages[imageKey] {
            mapImageView.image = image
            updatePathPixel()
        } else {
            mapImageView.image = nil
        }
    }

    private func updatePathPixel() {
        guard let selectedBuilding = selectedBuilding, let selectedLevel = selectedLevel else { return }
        let pathPixelKey = "\(self.sectorId)_\(selectedBuilding)_\(selectedLevel)"
        if let ppCoord = mapManager.buildingLevelPathPixel[pathPixelKey]?.road {
            if !self.isPpHidden {
                plotPathPixels(building: selectedBuilding, level: selectedLevel, ppCoord: ppCoord)
            }
        }
    }
    
    private func plotPathPixels(building: String, level: String, ppCoord: [[Double]]) {
        DispatchQueue.main.async { [self] in
            mapImageView.subviews.forEach { $0.removeFromSuperview() }

            guard let image = mapImageView.image else { return }
            let scaleKey = "scale_\(self.sectorId)_\(building)_\(level)"
            let scaleOffset: [Double] = buildingLevelScale[scaleKey] ?? []
            if scaleOffset.isEmpty { return }
            
            let imageViewSize = mapImageView.bounds.size
            let imageSize = image.size

            let scaleX = imageViewSize.width / imageSize.width
            let scaleY = imageViewSize.height / imageSize.height
            
            let scale = min(scaleX, scaleY)
            
            let imageViewCenterX = imageViewSize.width / 2
            let imageViewCenterY = imageViewSize.height / 2
            
            let imageCenterX = (imageSize.width / 2)
            let imageCenterY = (imageSize.height / 2)
            
            let offsetX = imageCenterX - imageViewCenterX / scale
            let offsetY = imageCenterY - imageViewCenterY / scale

            let newScaleX = scaleOffset[0]
            let newScaleY = scaleOffset[1]
            let newOffsetX = scaleOffset[2]
            let newOffsetY = scaleOffset[3]
            
            let markerSize: CGFloat = scaleX < 20.0 ? 3 : 20

            for i in 0..<ppCoord[0].count {
                let x = ppCoord[0][i]
                let y = ppCoord[1][i]
                
                let imageX = newScaleX*x + newOffsetX
                let imageY = newScaleY*y + newOffsetY

                let transformedX = ((imageX - offsetX) * scale)
                let transformedY = ((imageY - offsetY) * scale)

                let adjustedY = transformedY
                
                let pointView = UIView(frame: CGRect(x: transformedX - markerSize / 2, y: adjustedY - markerSize / 2, width: markerSize, height: markerSize))
                pointView.backgroundColor = .systemYellow
                pointView.layer.cornerRadius = markerSize / 2
                mapImageView.addSubview(pointView)
            }
        }
    }

    private func plotUserCoord(building: String, level: String, xyh: [Double]) {
        DispatchQueue.main.async { [self] in
            if preXyh == xyh {
                return
            }
            
            guard let image = mapImageView.image else { return }
            let scaleKey = "scale_\(self.sectorId)_\(building)_\(level)"
            let scaleOffset: [Double] = buildingLevelScale[scaleKey] ?? []
            if scaleOffset.isEmpty { return }
            
            let imageViewSize = mapImageView.bounds.size
            let imageSize = image.size

            let scaleX = imageViewSize.width / imageSize.width
            let scaleY = imageViewSize.height / imageSize.height
            let scale = min(scaleX, scaleY)
            
            let imageViewCenterX = imageViewSize.width / 2
            let imageViewCenterY = imageViewSize.height / 2
            
            let imageCenterX = (imageSize.width / 2)
            let imageCenterY = (imageSize.height / 2)
            
            let offsetX = imageCenterX - imageViewCenterX / scale
            let offsetY = imageCenterY - imageViewCenterY / scale

            let newScaleX = scaleOffset[0]
            let newScaleY = scaleOffset[1]
            let newOffsetX = scaleOffset[2]
            let newOffsetY = scaleOffset[3]
            
            let x = xyh[0]
            let y = xyh[1]
            let heading = xyh[2]
            
            let imageX = newScaleX*x + newOffsetX
            let imageY = newScaleY*y + newOffsetY

            let transformedX = ((imageX - offsetX) * scale)
            let transformedY = ((imageY - offsetY) * scale)
            
            let adjustedY = transformedY
            
            mapImageView.transform = .identity
            if let existingPointView = mapImageView.viewWithTag(userCoordTag) {
                existingPointView.removeFromSuperview()
            }
            
            let marker = self.imageMapMarker
            let coordSize: CGFloat = 30
            let pointView = UIImageView(image: marker)
            pointView.frame = CGRect(x: transformedX - coordSize / 2, y: adjustedY - coordSize / 2, width: coordSize, height: coordSize)
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
    
    // MARK: - Plot without Scale Up
    private func plotUserCoordWithZoomAndRotation(building: String, level: String,xyh: [Double], type: PlotType) {
        DispatchQueue.main.async { [self] in
            if preXyh == xyh && type == .NORMAL {
                return
            }

            guard let image = mapImageView.image else { return }
            let scaleKey = "scale_\(self.sectorId)_\(building)_\(level)"
            let scaleOffset: [Double] = buildingLevelScale[scaleKey] ?? []
            if scaleOffset.isEmpty { return }
            
            let imageViewSize = mapImageView.bounds.size
            let imageSize = image.size

            let scaleX = imageViewSize.width / imageSize.width
            let scaleY = imageViewSize.height / imageSize.height
            
            let scale = min(scaleX, scaleY)

            let imageViewCenterX = imageViewSize.width / 2
            let imageViewCenterY = imageViewSize.height / 2
            
            let imageCenterX = (imageSize.width / 2)
            let imageCenterY = (imageSize.height / 2)
            
            let offsetX = imageCenterX - imageViewCenterX / scale
            let offsetY = imageCenterY - imageViewCenterY / scale

            let newScaleX = scaleOffset[0]
            let newScaleY = scaleOffset[1]
            let newOffsetX = scaleOffset[2]
            let newOffsetY = scaleOffset[3]
            
            let x = xyh[0]
            let y = xyh[1]
            let heading = xyh[2]
            
            let imageX = newScaleX*x + newOffsetX
            let imageY = newScaleY*y + newOffsetY

            let transformedX = ((imageX - offsetX) * scale)
            let transformedY = ((imageY - offsetY) * scale)
            
            let adjustedY = transformedY

            if let existingPointView = mapImageView.viewWithTag(userCoordTag) {
                existingPointView.removeFromSuperview()
            }
            
            let marker = self.imageMapMarker
            let coordSize: CGFloat = 14
            let pointView = UIImageView(image: marker)
            pointView.frame = CGRect(x: transformedX - coordSize / 2, y: adjustedY - coordSize / 2, width: coordSize, height: coordSize)
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
            buildingsCollectionView.isScrollEnabled = buildingData.count > 5
            return buildingData.count
        } else if collectionView == levelsCollectionView {
            levelsCollectionView.isScrollEnabled = levelData.count > 5
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
            label.adjustsFontSizeToFitWidth = true

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
            if let levels = mapManager.getBuildingLevelInfo(sector_id: self.sectorId)[selectedBuildingName] {
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
        } else if collectionView == levelsCollectionView {
            let selectedLevelName = levelData[indexPath.row]
            self.selectedLevel = selectedLevelName
            self.forceToMapInteractionMode()
            levelsCollectionView.reloadData()
            updateMapImageView()
            updatePathPixel()
        }
    }
    
    // MARK: - Building & Level Image
    private func updateMapImageIfNecessary(imageKey: String) {
        guard let selectedBuilding = selectedBuilding, let selectedLevel = selectedLevel else { return }
        let expectedImageKey = "image_\(self.sectorId)_\(selectedBuilding)_\(selectedLevel)"
        if imageKey == expectedImageKey {
            updateMapImageView()
        }
    }
    
    // MARK: - Building & Level Path-Pixels
    private func updatePathPixelIfNecessary(pathPixelKey: String) {
        guard let selectedBuilding = selectedBuilding, let selectedLevel = selectedLevel else { return }
        let expectedPpKey = "\(self.sectorId)_\(selectedBuilding)_\(selectedLevel)"
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
        
        return CGSize(width: scaledWidth, height: scaledHeight)
    }
    
    public func updateResultInMap(result: TJLabsUserCoordinate) {
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
            if (mapManager.getCurrentTimeInMilliseconds() - mapModeChangedTime) > TIME_FOR_REST && mapModeChangedTime != 0 {
                mode = .UPDATE_USER
            }
        }
        
        if mode == .MAP_INTERACTION {
            let newBuilding = result.building
            let newLevel = result.level
            
            let buildingChanged = selectedBuilding != newBuilding
            let levelChanged = selectedLevel != newLevel
            
            if !buildingChanged && !levelChanged {
                plotUserCoord(building: newBuilding, level: newLevel, xyh: [result.x, result.y, result.heading])
            }
        } else if mode == .UPDATE_USER {
            let newBuilding = result.building
            let newLevel = result.level
            
            let buildingChanged = selectedBuilding != newBuilding
            let levelChanged = selectedLevel != newLevel
            
            DispatchQueue.main.async { [self] in
                let velocityString = String(Int(round(result.velocity)))
                self.velocityLabel.setText(text: velocityString)
                
                if buildingChanged || levelChanged {
                    selectedBuilding = newBuilding
                    selectedLevel = newLevel
                    
                    buildingsCollectionView.reloadData()
                    levelsCollectionView.reloadData()
                    adjustCollectionViewHeights()
                    
                    updateMapImageView()
                    updatePathPixel()
                }
                
                if TJLabsZoomButton.zoomMode == .ZOOM_IN {
                    plotUserCoordWithZoomAndRotation(building: selectedBuilding ?? "", level: selectedLevel ?? "", xyh: [result.x, result.y, result.heading], type: .NORMAL)
                } else {
                    // 모드 전환 시기 확인
                    if (mapManager.getCurrentTimeInMilliseconds() - TJLabsZoomButton.zoomModeChangedTime) > TIME_FOR_REST && TJLabsZoomButton.zoomModeChangedTime != 0 {
                        toggleZoomMode()
                        plotUserCoordWithZoomAndRotation(building: selectedBuilding ?? "", level: selectedLevel ?? "", xyh: [result.x, result.y, result.heading], type: .FORCE)
                    } else {
                        plotUserCoord(building: selectedBuilding ?? "", level: selectedLevel ?? "", xyh: [result.x, result.y, result.heading])
                    }
                }
            }
        }
    }
    
    public func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return mapImageView
    }
}
