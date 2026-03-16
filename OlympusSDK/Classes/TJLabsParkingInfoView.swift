
import UIKit
import TJLabsResource

class TJLabsParkingInfoView: UIView, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, UIScrollViewDelegate {
    var buildingInfo: BuildingOutput?
    var levelsInBuilding = [LevelOutput]()
    
    private struct ParkingContentItem {
        let title: String
        let countText: String
        let imageName: String
    }
    
    private var currentPage: Int = 0 {
        didSet {
            updatePagingInfo()
        }
    }
    
    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.white
        view.layer.cornerRadius = 12
        view.addShadow(offset: CGSize(width: 0, height: 1), color: .black, opacity: 0.2, radius: 4)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        label.textColor = .black
        label.text = "주차 정보 현황"
        label.textAlignment = .left
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.5
        label.translatesAutoresizingMaskIntoConstraints = false
        label.backgroundColor = .clear
        return label
    }()
    
    //MARK: - Level Collection View
    private let levelCollectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0
        layout.sectionInset = .zero
        
        let view = UICollectionView(frame: .zero, collectionViewLayout: layout)
        view.backgroundColor = .clear
        view.showsHorizontalScrollIndicator = false
        view.isPagingEnabled = true
        view.decelerationRate = .fast
        view.isScrollEnabled = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let pagingView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(hex: "#D9D9D9")
        view.cornerRadius = 6
        view.translatesAutoresizingMaskIntoConstraints = false
        
        return view
    }()
    
    private let pagingInfoLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        label.textColor = .black.withAlphaComponent(0.24)
        label.text = "0 / 3 >"
        label.textAlignment = .center
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.5
        label.translatesAutoresizingMaskIntoConstraints = false
        label.backgroundColor = .clear
        return label
    }()
    
    
    // images : ic_parking, ic_parking_family, ic_parking_electric_car, ic_parking_disabled_person
    
    init() {
        super.init(frame: .zero)
        commonInit()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    var selectedLevel: LevelOutput? {
        didSet {
            guard let selectedLevel = selectedLevel else { return }
            DispatchQueue.main.async { [weak self] in
                self?.setupViewsIfNeeded()
                self?.updateLevelContents(levelInfo: selectedLevel)
            }
        }
    }
    
    func update(buildingInfo: BuildingOutput) {
        self.buildingInfo = buildingInfo
        self.levelsInBuilding = []
        
        let levels = buildingInfo.levels
        for l in levels {
            let levelName = l.name
            if !levelName.contains("_D") && !levelName.contains("B0") {
                levelsInBuilding.append(l)
            }
        }
        
        currentPage = 0
        levelCollectionView.reloadData()
        updatePagingInfo()
        
        if selectedLevel == nil && !levelsInBuilding.isEmpty {
            selectedLevel = levelsInBuilding[0]
        } else if let selectedLevel = selectedLevel,
                  let index = levelsInBuilding.firstIndex(where: { $0.name == selectedLevel.name }) {
            titleLabel.text = "\(selectedLevel.name) 주차 정보 현황"
            let indexPath = IndexPath(item: index, section: 0)
            DispatchQueue.main.async { [weak self] in
                self?.levelCollectionView.scrollToItem(at: indexPath, at: .centeredHorizontally, animated: false)
            }
        } else if let firstLevel = levelsInBuilding.first {
            titleLabel.text = "\(firstLevel.name) 주차 정보 현황"
        }
    }
    
    private func commonInit() {
        setupLayout()
        bindActions()
        configureCollectionViews()
    }
    
    private func setupLayout() {
        addSubview(containerView)
        containerView.addSubview(titleLabel)
        containerView.addSubview(pagingView)
        containerView.addSubview(levelCollectionView)
        pagingView.addSubview(pagingInfoLabel)
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: topAnchor),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor),
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 10),
            titleLabel.heightAnchor.constraint(equalTo: containerView.heightAnchor, multiplier: 0.12),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 15),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -15),
            
            pagingView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -10),
            pagingView.heightAnchor.constraint(equalTo: containerView.heightAnchor, multiplier: 0.14),
            pagingView.widthAnchor.constraint(equalTo: containerView.widthAnchor, multiplier: 0.2),
            pagingView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -15),

            pagingInfoLabel.topAnchor.constraint(equalTo: pagingView.topAnchor, constant: 1),
            pagingInfoLabel.bottomAnchor.constraint(equalTo: pagingView.bottomAnchor, constant: -1),
            pagingInfoLabel.leadingAnchor.constraint(equalTo: pagingView.leadingAnchor, constant: 1),
            pagingInfoLabel.trailingAnchor.constraint(equalTo: pagingView.trailingAnchor, constant: -1),
            
            levelCollectionView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor),
            levelCollectionView.bottomAnchor.constraint(equalTo: pagingView.topAnchor),
            levelCollectionView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            levelCollectionView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
        ])
    }
    
    private func bindActions() {
        
    }
    
    private func configureCollectionViews() {
        levelCollectionView.dataSource = self
        levelCollectionView.delegate = self
        levelCollectionView.register(ParkingLevelCell.self, forCellWithReuseIdentifier: ParkingLevelCell.reuseIdentifier)
    }
    
    private func setupViewsIfNeeded() {
        
    }
    
    private func updatePagingInfo() {
        let totalCount = levelsInBuilding.count
        if totalCount <= 0 {
            pagingInfoLabel.text = "0 / 0 >"
            pagingView.isHidden = true
        } else {
            pagingView.isHidden = false
            pagingInfoLabel.text = "\(currentPage + 1) / \(totalCount) >"
        }
    }
    
    private func makeParkingItems(from levelInfo: LevelOutput) -> [ParkingContentItem] {
        let mirror = Mirror(reflecting: levelInfo)
        var values: [String: Any] = [:]
        for child in mirror.children {
            if let label = child.label {
                values[label] = child.value
            }
        }
        
        func countText(for keys: [String]) -> String {
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
            return "0대"
        }
        
        return [
            ParkingContentItem(title: "일반 주차", countText: countText(for: ["available_count", "parking_count", "count", "availableParkingCount", "availableCount", "normalParkingCount"]), imageName: "ic_parking"),
            ParkingContentItem(title: "여성 배려", countText: countText(for: ["women_count", "female_count", "womenParkingCount", "femaleParkingCount"]), imageName: "ic_parking_family"),
            ParkingContentItem(title: "전기차", countText: countText(for: ["ev_count", "electric_count", "electricVehicleCount", "evParkingCount"]), imageName: "ic_parking_electric_car"),
            ParkingContentItem(title: "장애인", countText: countText(for: ["disabled_count", "handicap_count", "disabledParkingCount", "handicapParkingCount"]), imageName: "ic_parking_disabled_person")
        ]
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return levelsInBuilding.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard indexPath.item < levelsInBuilding.count,
              let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ParkingLevelCell.reuseIdentifier, for: indexPath) as? ParkingLevelCell else {
            return UICollectionViewCell()
        }
        
        let levelInfo = levelsInBuilding[indexPath.item]
        cell.configure(items: makeParkingItems(from: levelInfo))
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: collectionView.bounds.width, height: collectionView.bounds.height)
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        guard scrollView === levelCollectionView, scrollView.bounds.width > 0 else { return }
        let page = Int(round(scrollView.contentOffset.x / scrollView.bounds.width))
        let clampedPage = max(0, min(page, max(levelsInBuilding.count - 1, 0)))
        currentPage = clampedPage
        if clampedPage < levelsInBuilding.count {
            selectedLevel = levelsInBuilding[clampedPage]
        }
    }
    
    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        guard scrollView === levelCollectionView, scrollView.bounds.width > 0 else { return }
        let page = Int(round(scrollView.contentOffset.x / scrollView.bounds.width))
        let clampedPage = max(0, min(page, max(levelsInBuilding.count - 1, 0)))
        currentPage = clampedPage
    }
    
    private func updateLevelContents(levelInfo: LevelOutput) {
        titleLabel.text = "\(levelInfo.name) 주차 정보 현황"
        if let index = levelsInBuilding.firstIndex(where: { $0.name == levelInfo.name }) {
            currentPage = index
            let indexPath = IndexPath(item: index, section: 0)
            DispatchQueue.main.async { [weak self] in
                self?.levelCollectionView.scrollToItem(at: indexPath, at: .centeredHorizontally, animated: false)
            }
        }
    }
    
    private final class ParkingLevelCell: UICollectionViewCell {
        static let reuseIdentifier = "ParkingLevelCell"
        
        private struct ContentItem {
            let title: String
            let countText: String
            let imageName: String
        }
        
        private var items: [ContentItem] = []
        
        private let contentStackView: UIStackView = {
            let view = UIStackView()
            view.axis = .horizontal
            view.alignment = .fill
            view.distribution = .fillEqually
            view.spacing = 0
            view.translatesAutoresizingMaskIntoConstraints = false
            return view
        }()
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            setupLayout()
            configureStackView()
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func configure(items: [ParkingContentItem]) {
            self.items = items.map { ContentItem(title: $0.title, countText: $0.countText, imageName: $0.imageName) }
            updateStackContents()
        }
        
        private func setupLayout() {
            contentView.backgroundColor = .clear
            contentView.addSubview(contentStackView)
            
            NSLayoutConstraint.activate([
                contentStackView.topAnchor.constraint(equalTo: contentView.topAnchor),
                contentStackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
                contentStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                contentStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor)
            ])
        }

        private func configureStackView() {
            updateStackContents()
        }
        
        private func updateStackContents() {
            contentStackView.arrangedSubviews.forEach { arranged in
                contentStackView.removeArrangedSubview(arranged)
                arranged.removeFromSuperview()
            }
            
            for item in items.prefix(4) {
                let itemView = ParkingContentItemView()
                itemView.configure(title: item.title, countText: item.countText, imageName: item.imageName)
                contentStackView.addArrangedSubview(itemView)
            }
            
            let missingCount = max(0, 4 - items.count)
            if missingCount > 0 {
                for _ in 0..<missingCount {
                    let spacerView = UIView()
                    spacerView.translatesAutoresizingMaskIntoConstraints = false
                    contentStackView.addArrangedSubview(spacerView)
                }
            }
        }
    }

    private final class ParkingContentItemView: UIView {
        private let iconAndTitleStackView: UIStackView = {
            let view = UIStackView()
            view.axis = .horizontal
            view.alignment = .center
            view.distribution = .fill
            view.spacing = 2
            view.translatesAutoresizingMaskIntoConstraints = false
            return view
        }()
        
        private let contentItemStackView: UIStackView = {
            let view = UIStackView()
            view.axis = .vertical
            view.alignment = .fill
            view.distribution = .fill
            view.spacing = 5
            view.translatesAutoresizingMaskIntoConstraints = false
            return view
        }()
        
        private let iconImageView: UIImageView = {
            let view = UIImageView()
            view.contentMode = .scaleAspectFit
            view.translatesAutoresizingMaskIntoConstraints = false
            view.setContentHuggingPriority(.required, for: .horizontal)
            view.setContentCompressionResistancePriority(.required, for: .horizontal)
            return view
        }()
        
        private let titleLabel: UILabel = {
            let label = UILabel()
            label.font = UIFont.systemFont(ofSize: 16, weight: .regular)
            label.textColor = .black
            label.textAlignment = .left
            label.numberOfLines = 1
            label.adjustsFontSizeToFitWidth = true
            label.minimumScaleFactor = 0.5
            label.translatesAutoresizingMaskIntoConstraints = false
            label.setContentHuggingPriority(.defaultLow, for: .horizontal)
            label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            return label
        }()
        
        private let countLabel: UILabel = {
            let label = UILabel()
            label.font = UIFont.systemFont(ofSize: 24, weight: .bold)
            label.textColor = .black
            label.textAlignment = .center
            label.adjustsFontSizeToFitWidth = true
            label.minimumScaleFactor = 0.6
            label.translatesAutoresizingMaskIntoConstraints = false
            label.setContentHuggingPriority(.required, for: .vertical)
            label.setContentCompressionResistancePriority(.required, for: .vertical)
            return label
        }()
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            setupLayout()
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func configure(title: String, countText: String, imageName: String) {
            titleLabel.text = title
            countLabel.text = countText
            iconImageView.image = TJLabsAssets.image(named: imageName)
        }
        
        private func setupLayout() {
            backgroundColor = .clear
            translatesAutoresizingMaskIntoConstraints = false
            addSubview(contentItemStackView)
            contentItemStackView.addArrangedSubview(iconAndTitleStackView)
            iconAndTitleStackView.addArrangedSubview(iconImageView)
            iconAndTitleStackView.addArrangedSubview(titleLabel)
            contentItemStackView.addArrangedSubview(countLabel)
            
            NSLayoutConstraint.activate([
                contentItemStackView.topAnchor.constraint(equalTo: topAnchor, constant: 6),
                contentItemStackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6),
                contentItemStackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
                contentItemStackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
                
                iconImageView.widthAnchor.constraint(equalTo: contentItemStackView.widthAnchor, multiplier: 0.22),
                iconImageView.heightAnchor.constraint(equalTo: iconImageView.widthAnchor),
                
                iconAndTitleStackView.heightAnchor.constraint(greaterThanOrEqualTo: iconImageView.heightAnchor),
                countLabel.heightAnchor.constraint(greaterThanOrEqualTo: contentItemStackView.heightAnchor, multiplier: 0.34)
            ])
        }
    }
}
