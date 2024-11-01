import UIKit

public class OlympusMapView: UIView, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
    private var mapImageView = UIImageView()
    private var buildingsCollectionView: UICollectionView!
    private var levelsCollectionView: UICollectionView!
    private var buildingData = [String]()
    private var levelData = [String]()
    private var selectedBuilding: String?
    private var selectedLevel: String?
    private let cellSize: CGSize = CGSize(width: 50, height: 50)
    private let cellSpacing: CGFloat = 1.0
    private var buildingsCollectionViewHeightConstraint: NSLayoutConstraint!
    private var levelsCollectionViewHeightConstraint: NSLayoutConstraint!
    
    private var mapScaleOffset = [String: [Double]]()
    
    private var isPpHidden = false
    
    private var preXyh = [Double]()
    private let userCoordTag = 999
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
        observeImageUpdates()
        observePathPixelUpdates()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
        observeImageUpdates()
        observePathPixelUpdates()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func setupView() {
//        backgroundColor = .blue
        setupMapImageView()
        setupCollectionViews()
    }
    
    private func setupMapImageView() {
        mapImageView.contentMode = .scaleAspectFit
        mapImageView.backgroundColor = .clear
        mapImageView.frame = self.bounds
        mapImageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(mapImageView)
    }
    
    private func setupCollectionViews() {
        let buildingLayout = UICollectionViewFlowLayout()
        buildingLayout.scrollDirection = .vertical
        buildingLayout.minimumLineSpacing = cellSpacing
        
        buildingsCollectionView = UICollectionView(frame: .zero, collectionViewLayout: buildingLayout)
        buildingsCollectionView.backgroundColor = .clear
        buildingsCollectionView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "BuildingCell")
        buildingsCollectionView.delegate = self
        buildingsCollectionView.dataSource = self
        addSubview(buildingsCollectionView)
        
        let levelLayout = UICollectionViewFlowLayout()
        levelLayout.scrollDirection = .vertical
        levelLayout.minimumLineSpacing = cellSpacing
        
        levelsCollectionView = UICollectionView(frame: .zero, collectionViewLayout: levelLayout)
        levelsCollectionView.backgroundColor = .clear
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
    }
    
    private func calculateCollectionViewHeight(for itemCount: Int) -> CGFloat {
        return CGFloat(itemCount) * (cellSize.height + cellSpacing) - cellSpacing
    }
    
    public func configureFrame(to matchView: UIView) {
        self.frame = matchView.bounds
        self.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    }

    public func updateBuildingData(_ buildings: [String], levelData: [String: [String]]) {
        self.buildingData = buildings
        if let firstBuilding = buildings.first {
            self.selectedBuilding = firstBuilding
            self.levelData = levelData[firstBuilding] ?? []
            self.selectedLevel = self.levelData.first
        }
        buildingsCollectionView.reloadData()
        levelsCollectionView.reloadData()
        adjustCollectionViewHeights()
        updateMapImageView()
        updatePathPixel()
    }
    
    private func adjustCollectionViewHeights() {
        let buildingHeight = calculateCollectionViewHeight(for: buildingData.count)
        let levelHeight = calculateCollectionViewHeight(for: levelData.count)
        
        buildingsCollectionViewHeightConstraint.constant = buildingHeight
        levelsCollectionViewHeightConstraint.constant = levelHeight

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
            calMapScaleOffset(ppCoord: ppCoord)
            if !self.isPpHidden {
                plotPathPixels(ppCoord: ppCoord)
            }
        }
    }
    
    private func calMapScaleOffset(ppCoord: [[Double]]) {
        DispatchQueue.main.async { [self] in
            guard let image = mapImageView.image else {
//                print(getLocalTimeString() + " , (Olympus) MapView : image is not loaded")
                return
            }
            
            let imageSize = image.size
            let imageViewSize = mapImageView.bounds.size
            let scaledSize = calculateAspectFitImageSize(for: image, in: mapImageView)
            
            let xCoords = ppCoord[0]
            let yCoords = ppCoord[1]
            
//            guard let minX = xCoords.min(),
//                  let maxX = xCoords.max(),
//                  let minY = yCoords.min(),
//                  let maxY = yCoords.max() else { return }
            
            // COEX PP Min Max : 6, 294, 3, 469
            let minX: Double = -48
            let maxX: Double = 286
            let minY: Double = -10
            let maxY: Double = 530
            
            let ppWidth: Double = maxX - minX
            let ppHeight: Double = maxY - minY

            let scaleX = scaledSize.width / ppWidth
            let scaleY = scaledSize.height / ppHeight
            
//            let offsetX = (scaledSize.width - ppWidth * scaleX) / 2.0
//            let offsetY = (scaledSize.height - ppHeight * scaleY) / 2.0
            let offsetX = minX
            let offsetY = minY
            
            let key = "\(OlympusMapManager.shared.sector_id)_\(selectedBuilding ?? "")_\(selectedLevel ?? "")"
            mapScaleOffset[key] = [scaleX, scaleY, offsetX, offsetY, scaledSize.width, scaledSize.height]
            
            print(getLocalTimeString() + " , (Olympus) MapView : \(key) // Path-Pixel Min and Max = [\(minX), \(maxX), \(minY), \(maxY)]")
            print(getLocalTimeString() + " , (Olympus) MapView : \(key) // Calculated Scale and Offset = [\(scaleX), \(scaleY), \(offsetX), \(offsetY)]")
        }
    }

    private func plotPathPixels(ppCoord: [[Double]]) {
        DispatchQueue.main.async { [self] in
            mapImageView.subviews.forEach { $0.removeFromSuperview() }
            let key = "\(OlympusMapManager.shared.sector_id)_\(selectedBuilding ?? "")_\(selectedLevel ?? "")"
            guard let scaleOffsetValues = mapScaleOffset[key], scaleOffsetValues.count == 6 else {
//                print(getLocalTimeString() + " , (Olympus) MapView : Scale and Offset not found for key \(key)")
                return
            }
            
            let scaleX = scaleOffsetValues[0]
            let scaleY = scaleOffsetValues[1]
            let offsetX = scaleOffsetValues[2]
            let offsetY = scaleOffsetValues[3]
            
            var scaledXY = [[Double]]()
            for i in 0..<ppCoord[0].count {
                let x = ppCoord[0][i]
                let y = ppCoord[1][i]
                
                let transformedX = (x-offsetX)*scaleX
                let transformedY = (y-offsetY)*scaleY
                
                let rotatedX = transformedX
                let rotatedY = scaleOffsetValues[5] - transformedY
                scaledXY.append([transformedX, transformedY])
                
                let pointView = UIView(frame: CGRect(x: rotatedX - 2.5, y: rotatedY - 2.5, width: 3, height: 3))
                pointView.backgroundColor = .systemYellow
                pointView.layer.cornerRadius = 2.5
                mapImageView.addSubview(pointView)
            }
        }
    }

    private func plotUserCoord(xyh: [Double]) {
        DispatchQueue.main.async { [self] in
            if preXyh == xyh {
//                print(getLocalTimeString() + " , (Olympus) plotUserCoord : sameCoord [\(preXyh) == \(xyh)]")
                return
            }
//            print(getLocalTimeString() + " , (Olympus) plotUserCoord : updateCoord [\(xyh)]")
            
            let key = "\(OlympusMapManager.shared.sector_id)_\(selectedBuilding ?? "")_\(selectedLevel ?? "")"
            guard let scaleOffsetValues = mapScaleOffset[key], scaleOffsetValues.count == 6 else {
                return
            }

            let scaleX = scaleOffsetValues[0]
            let scaleY = scaleOffsetValues[1]
            let offsetX = scaleOffsetValues[2]
            let offsetY = scaleOffsetValues[3]

            let x = xyh[0]
            let y = xyh[1]
            
            let transformedX = (x - offsetX) * scaleX
            let transformedY = (y - offsetY) * scaleY
            
            let rotatedX = transformedX
            let rotatedY = scaleOffsetValues[5] - transformedY
            
            if let existingPointView = mapImageView.viewWithTag(userCoordTag) {
                existingPointView.removeFromSuperview()
            }
            
            let coordWidthHeight: [Double] = [14, 14]
            let pointView = UIView(frame: CGRect(x: rotatedX - coordWidthHeight[0]/2, y: rotatedY - coordWidthHeight[1]/2, width: coordWidthHeight[0], height: coordWidthHeight[1]))
            pointView.backgroundColor = .systemRed
            pointView.layer.cornerRadius = 8
            pointView.tag = userCoordTag
            mapImageView.addSubview(pointView)

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
                cell.layer.borderWidth = 1
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
                cell.layer.borderWidth = 1
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
        } else if collectionView == levelsCollectionView {
            let selectedLevelName = levelData[indexPath.row]
            self.selectedLevel = selectedLevelName
            
            levelsCollectionView.reloadData()
            updateMapImageView()
            updatePathPixel()
        }
    }
    
    private func observeImageUpdates() {
        NotificationCenter.default.addObserver(self, selector: #selector(imageUpdated(_:)), name: .sectorImagesUpdated, object: nil)
    }

    @objc private func imageUpdated(_ notification: Notification) {
        guard let userInfo = notification.userInfo, let imageKey = userInfo["imageKey"] as? String else { return }
        if let selectedBuilding = selectedBuilding, let selectedLevel = selectedLevel {
            let expectedImageKey = "image_\(OlympusMapManager.shared.sector_id)_\(selectedBuilding)_\(selectedLevel)"
            if imageKey == expectedImageKey {
                updateMapImageView()
            }
        }
    }
    
    private func observePathPixelUpdates() {
        NotificationCenter.default.addObserver(self, selector: #selector(pathPixelUpdated(_:)), name: .sectorPathPixelUpdated, object: nil)
    }

    @objc private func pathPixelUpdated(_ notification: Notification) {
        guard let userInfo = notification.userInfo, let pathPixelKey = userInfo["pathPixelKey"] as? String else { return }
        if let selectedBuilding = selectedBuilding, let selectedLevel = selectedLevel {
            let expectedPpKey = "\(OlympusMapManager.shared.sector_id)_\(selectedBuilding)_\(selectedLevel)"
//            print(getLocalTimeString() + " , (Olympus) MapView : pathPixelUpdated // expectedPpKey = \(expectedPpKey) , pathPixelKey = \(pathPixelKey)")
            if pathPixelKey == expectedPpKey {
                updatePathPixel()
            }
        }
    }
    
    func calculateAspectFitImageSize(for image: UIImage, in imageView: UIImageView) -> CGSize {
        let imageSize = image.size
        let imageViewSize = imageView.bounds.size
//        print(getLocalTimeString() + " , (Olympus) MapView : imageView width = \(imageViewSize.width), imageView height = \(imageViewSize.height)")
        let widthRatio = imageViewSize.width / imageSize.width
        let heightRatio = imageViewSize.height / imageSize.height
        
        let scaleFactor = min(widthRatio, heightRatio)
        
        let scaledWidth = imageSize.width * scaleFactor
        let scaledHeight = imageSize.height * scaleFactor
        
        return CGSize(width: scaledWidth, height: scaledHeight)
    }
    
    public func updateResultInMap(result: FineLocationTrackingResult) {
        let newBuilding = result.building_name
        let newLevel = result.level_name
        
        let buildingChanged = selectedBuilding != newBuilding
        let levelChanged = selectedLevel != newLevel
        
        DispatchQueue.main.async { [self] in
            if buildingChanged || levelChanged {
                selectedBuilding = newBuilding
                selectedLevel = newLevel
                
                buildingsCollectionView.reloadData()
                levelsCollectionView.reloadData()
                adjustCollectionViewHeights()
                
                updateMapImageView()
                updatePathPixel()
            }
            self.plotUserCoord(xyh: [result.x, result.y, result.absolute_heading])
        }
    }
}
