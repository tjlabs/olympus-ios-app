import UIKit
import TJLabsResource

class TJLabsParkingStateView: UIView, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    var buildingInfo: BuildingOutput?
    
    private struct ParkingLevelItem {
        let level: String
        let countText: String
    }
    
    private var parkingLevelItems: [ParkingLevelItem] = []
    
    private let parkingCollectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumLineSpacing = 10
        layout.minimumInteritemSpacing = 0
        layout.sectionInset = .zero
        
        let view = UICollectionView(frame: .zero, collectionViewLayout: layout)
        view.backgroundColor = .clear
        view.showsVerticalScrollIndicator = false
        view.isScrollEnabled = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
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
    
    private let moreContentsCountLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 10, weight: .bold)
        label.textColor = .white
        label.text = "1 / N"
        label.textAlignment = .center
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.5
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let moreContentsLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 10, weight: .medium)
        label.textColor = .white
        label.text = "아래로 더 보기"
        label.textAlignment = .left
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.5
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    init() {
        super.init(frame: .zero)
        commonInit()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func update(buildingInfo: BuildingOutput) {
        self.buildingInfo = buildingInfo
        parkingLevelItems = makeParkingLevelItems(from: buildingInfo.levels)
        updateVisibleCountLabel()
        parkingCollectionView.reloadData()
        DispatchQueue.main.async { [weak self] in
            self?.updateVisibleCountLabel()
        }
    }
    
    private func commonInit() {
        setupLayout()
        bindActions()
        configureCollectionView()
    }
    
    private func setupLayout() {
        addSubview(containerView)
        containerView.addSubview(titleLabel)
        containerView.addSubview(descLabel)
        containerView.addSubview(parkingCollectionView)
        
        containerView.addSubview(moreContentsCountLabel)
        containerView.addSubview(moreContentsLabel)
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: topAnchor),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor),
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 8),
            titleLabel.heightAnchor.constraint(equalTo: containerView.heightAnchor, multiplier: 0.1),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -5),
            
            descLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor),
            descLabel.heightAnchor.constraint(equalTo: containerView.heightAnchor, multiplier: 0.1),
            descLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            descLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -5),
            
            parkingCollectionView.topAnchor.constraint(equalTo: descLabel.bottomAnchor, constant: 4),
            parkingCollectionView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 2),
            parkingCollectionView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -2),
            parkingCollectionView.bottomAnchor.constraint(equalTo: moreContentsCountLabel.topAnchor, constant: -4),
            
            moreContentsCountLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -8),
            moreContentsCountLabel.heightAnchor.constraint(equalTo: containerView.heightAnchor, multiplier: 0.12),
            moreContentsCountLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            
            moreContentsLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -8),
            moreContentsLabel.heightAnchor.constraint(equalTo: containerView.heightAnchor, multiplier: 0.12),
            moreContentsLabel.leadingAnchor.constraint(equalTo: moreContentsCountLabel.trailingAnchor, constant: 8),
        ])
    }
    
    private func bindActions() {
        parkingCollectionView.alwaysBounceVertical = true
    }
    
    private func configureCollectionView() {
        parkingCollectionView.dataSource = self
        parkingCollectionView.delegate = self
        parkingCollectionView.register(ParkingLevelCell.self, forCellWithReuseIdentifier: ParkingLevelCell.reuseIdentifier)
    }
    
    private func updateVisibleCountLabel() {
        let totalCount = max(parkingLevelItems.count, 1)
        guard !parkingLevelItems.isEmpty else {
            moreContentsCountLabel.text = "3 / \(totalCount)"
            return
        }
        
        let visibleIndexPaths = parkingCollectionView.indexPathsForVisibleItems
        let maxVisibleIndex = visibleIndexPaths.map(\ .item).max() ?? -1
        let remainingCount = max(parkingLevelItems.count - (maxVisibleIndex + 1), 0)
        
        if remainingCount > 0 {
            moreContentsCountLabel.text = "\(maxVisibleIndex+1) / \(totalCount)"
        } else {
            moreContentsCountLabel.text = "\(totalCount) / \(totalCount)"
        }
    }
    
    private func makeParkingLevelItems(from levels: Any) -> [ParkingLevelItem] {
        guard let array = levels as? [Any] else { return [] }
        
        return array.compactMap { level in
            let mirror = Mirror(reflecting: level)
            var values: [String: Any] = [:]
            for child in mirror.children {
                if let label = child.label {
                    values[label] = child.value
                }
            }
            
            func firstString(for keys: [String]) -> String? {
                for key in keys {
                    if let value = values[key] as? String, !value.isEmpty {
                        return value
                    }
                    if let value = values[key] {
                        let text = String(describing: value)
                        if !text.isEmpty, text != "nil" {
                            return text
                        }
                    }
                }
                return nil
            }
            
            func firstIntLikeString(for keys: [String]) -> String? {
                for key in keys {
                    if let value = values[key] as? Int {
                        return "\(value)대"
                    }
                    if let value = values[key] as? Double {
                        return "\(Int(value))대"
                    }
                    if let value = values[key] as? Float {
                        return "\(Int(value))대"
                    }
                    if let value = values[key] as? String, !value.isEmpty {
                        return value.hasSuffix("대") ? value : "\(value)대"
                    }
                }
                return nil
            }
            
            guard let levelName = firstString(for: ["name"]), !levelName.contains("_D"), !levelName.contains("B0") else {
                return nil
            }
            let countText = firstIntLikeString(for: ["available_count", "parking_count", "count", "availableParkingCount", "availableCount"]) ?? "100대"
            return ParkingLevelItem(level: levelName, countText: countText)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return parkingLevelItems.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard indexPath.item < parkingLevelItems.count,
              let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ParkingLevelCell.reuseIdentifier, for: indexPath) as? ParkingLevelCell else {
            return UICollectionViewCell()
        }
        
        cell.configure(with: parkingLevelItems[indexPath.item])
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let lineSpacing: CGFloat
        if let layout = collectionViewLayout as? UICollectionViewFlowLayout {
            lineSpacing = layout.minimumLineSpacing
        } else {
            lineSpacing = 0
        }
        
        let totalSpacing = lineSpacing * 2
        let availableHeight = max(collectionView.bounds.height - totalSpacing, 0)
        let itemHeight = floor(availableHeight / 3)
        return CGSize(width: collectionView.bounds.width, height: itemHeight)
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard scrollView === parkingCollectionView else { return }
        updateVisibleCountLabel()
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        guard scrollView === parkingCollectionView else { return }
        updateVisibleCountLabel()
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        guard scrollView === parkingCollectionView else { return }
        if !decelerate {
            updateVisibleCountLabel()
        }
    }
    
    private final class ParkingLevelCell: UICollectionViewCell {
        static let reuseIdentifier = "ParkingLevelCell"
        
        private let levelLabel: UILabel = {
            let label = UILabel()
            label.font = UIFont.systemFont(ofSize: 40, weight: .bold)
            label.textColor = .white
            label.textAlignment = .left
            label.adjustsFontSizeToFitWidth = true
            label.minimumScaleFactor = 0.7
            label.translatesAutoresizingMaskIntoConstraints = false
            return label
        }()
        
        private let countLabel: UILabel = {
            let label = UILabel()
            label.font = UIFont.systemFont(ofSize: 40, weight: .bold)
            label.textColor = .black
            label.textAlignment = .left
            label.adjustsFontSizeToFitWidth = true
            label.minimumScaleFactor = 0.7
            label.translatesAutoresizingMaskIntoConstraints = false
            return label
        }()
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            contentView.backgroundColor = .clear
            contentView.addSubview(levelLabel)
            contentView.addSubview(countLabel)
            
            NSLayoutConstraint.activate([
                levelLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 9),
                levelLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
                levelLabel.widthAnchor.constraint(equalTo: contentView.widthAnchor, multiplier: 0.36),
                
                countLabel.leadingAnchor.constraint(equalTo: levelLabel.trailingAnchor, constant: 8),
                countLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -4),
                countLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
            ])
        }
        
        override func layoutSubviews() {
            super.layoutSubviews()
            updateFonts()
        }
        
        private func updateFonts() {
            let baseSize = max(24, min(54, contentView.bounds.height * 0.72))
            levelLabel.font = UIFont.systemFont(ofSize: baseSize, weight: .bold)
            countLabel.font = UIFont.systemFont(ofSize: baseSize, weight: .bold)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func configure(with item: ParkingLevelItem) {
            levelLabel.text = item.level
            countLabel.text = item.countText
        }
    }
}
