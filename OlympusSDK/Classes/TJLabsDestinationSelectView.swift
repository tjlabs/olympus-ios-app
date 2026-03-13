import UIKit

enum RoutingOption {
    case NORMAL
    case SHORTEST
    case PARX
}

final class TJLabsDestinationSelectView: UIView, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    var onTapStart: ((RoutingOption) -> Void)?
    
    var destination: NaviDestination?
    
    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = .black.withAlphaComponent(0.44)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let bottomSheetView: UIView = {
        let view = UIView()
        view.backgroundColor = .white
        view.layer.cornerRadius = 24
        view.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        view.clipsToBounds = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private var bottomSheetBottomConstraint: NSLayoutConstraint?
    
    // MARK: - Bottom Sheet Contents
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14, weight: .bold)
        label.textColor = .black
        label.text = "UNKNOWN"
        label.textAlignment = .center
        label.adjustsFontSizeToFitWidth = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let optionCollectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumLineSpacing = 4
        layout.minimumInteritemSpacing = 0
        layout.sectionInset = .zero

        let view = UICollectionView(frame: .zero, collectionViewLayout: layout)
        view.backgroundColor = .clear
        view.showsVerticalScrollIndicator = false
        view.isScrollEnabled = false
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private var startButton: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(hex: "#3fb1e5")
        view.isUserInteractionEnabled = true
        view.isHidden = false
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let startButtonTitleLabel: UILabel = {
        let label = UILabel()
        label.backgroundColor = .clear
        label.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        label.textColor = .white
        label.textAlignment = .center
        label.text = "안내 시작"
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let routingOptions: [RoutingOptionItem] = [
        RoutingOptionItem(
            option: .NORMAL,
            title: "일반 주행",
            description: "경로 제공 없이 현재 위치만 제공합니다.",
            isEnabled: true
        ),
        RoutingOptionItem(
            option: .SHORTEST,
            title: "최단 경로 안내",
            description: "최단 경로로 안내합니다.",
            isEnabled: true
        ),
        RoutingOptionItem(
            option: .PARX,
            title: "주차 우선 안내",
            description: "출구 안내에서는 제공되지 않습니다.",
            isEnabled: true
        )
    ]
    
    private var selectedOption: RoutingOption = .SHORTEST
    private var lastTappedOption: RoutingOption?
    private var lastTappedAt: CFTimeInterval = 0
    
    init(destination: NaviDestination) {
        super.init(frame: .zero)
        self.destination = destination
        setupLayout(title: destination.name)
        bindActions()
        configureCollectionView()
        DispatchQueue.main.async { [weak self] in
            self?.showBottomSheet(animated: true)
        }
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    private func setupLayout(title: String) {
        titleLabel.text = title
        
        addSubview(containerView)
        addSubview(bottomSheetView)
        bottomSheetBottomConstraint = bottomSheetView.topAnchor.constraint(equalTo: bottomAnchor)
        bottomSheetView.addSubview(titleLabel)
        bottomSheetView.addSubview(optionCollectionView)
        bottomSheetView.addSubview(startButton)
        startButton.addSubview(startButtonTitleLabel)
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: topAnchor),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor),
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            
            bottomSheetView.leadingAnchor.constraint(equalTo: leadingAnchor),
            bottomSheetView.trailingAnchor.constraint(equalTo: trailingAnchor),
            bottomSheetView.heightAnchor.constraint(equalToConstant: 255),
            bottomSheetBottomConstraint!,
            
            titleLabel.leadingAnchor.constraint(equalTo: bottomSheetView.leadingAnchor, constant: 10),
            titleLabel.trailingAnchor.constraint(equalTo: bottomSheetView.trailingAnchor, constant: -10),
            titleLabel.heightAnchor.constraint(equalToConstant: 40),
            titleLabel.topAnchor.constraint(equalTo: bottomSheetView.topAnchor, constant: 2),
            
            optionCollectionView.leadingAnchor.constraint(equalTo: bottomSheetView.leadingAnchor, constant: 4),
            optionCollectionView.trailingAnchor.constraint(equalTo: bottomSheetView.trailingAnchor, constant: -4),
            optionCollectionView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            optionCollectionView.heightAnchor.constraint(equalToConstant: 140),
            
            startButton.leadingAnchor.constraint(equalTo: bottomSheetView.leadingAnchor),
            startButton.trailingAnchor.constraint(equalTo: bottomSheetView.trailingAnchor),
            startButton.topAnchor.constraint(equalTo: optionCollectionView.bottomAnchor, constant: 8),
            startButton.bottomAnchor.constraint(equalTo: bottomSheetView.bottomAnchor),
            
            startButtonTitleLabel.centerXAnchor.constraint(equalTo: startButton.centerXAnchor),
            startButtonTitleLabel.centerYAnchor.constraint(equalTo: startButton.centerYAnchor)
        ])
    }
    
    private func bindActions() {
        containerView.isUserInteractionEnabled = true
        let backgroundTap = UITapGestureRecognizer(target: self, action: #selector(didTapBackground))
        containerView.addGestureRecognizer(backgroundTap)
        optionCollectionView.delegate = self
        
        let startTap = UITapGestureRecognizer(target: self, action: #selector(didTapStart))
        startButton.addGestureRecognizer(startTap)
    }

    private func configureCollectionView() {
        optionCollectionView.dataSource = self
        optionCollectionView.delegate = self
        optionCollectionView.register(RoutingOptionCell.self, forCellWithReuseIdentifier: RoutingOptionCell.reuseIdentifier)
        optionCollectionView.allowsSelection = true
    }

    private func indexPath(for option: RoutingOption) -> IndexPath? {
        guard let index = routingOptions.firstIndex(where: { $0.option == option }) else { return nil }
        return IndexPath(item: index, section: 0)
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return routingOptions.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard indexPath.item < routingOptions.count,
              let cell = collectionView.dequeueReusableCell(withReuseIdentifier: RoutingOptionCell.reuseIdentifier, for: indexPath) as? RoutingOptionCell else {
            return UICollectionViewCell()
        }
        
        let item = routingOptions[indexPath.item]
        let isSelected = item.option == selectedOption
        cell.configure(with: item, isSelected: isSelected)
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: collectionView.bounds.width, height: 44)
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        defer {
            collectionView.deselectItem(at: indexPath, animated: false)
        }
        
        guard indexPath.item < routingOptions.count else { return }
        let item = routingOptions[indexPath.item]
        guard item.isEnabled else { return }

        let now = CACurrentMediaTime()
        let wasAlreadySelected = (selectedOption == item.option)
        let isDoubleTapOnSelectedOption =
            wasAlreadySelected &&
            lastTappedOption == item.option &&
            (now - lastTappedAt) < 0.35

        lastTappedOption = item.option
        lastTappedAt = now

        if isDoubleTapOnSelectedOption {
            didTapStart()
            return
        }

        guard !wasAlreadySelected else { return }

        let previousOption = selectedOption
        selectedOption = item.option
        var indexPathsToReload: [IndexPath] = [indexPath]
        if let previousIndexPath = self.indexPath(for: previousOption), previousIndexPath != indexPath {
            indexPathsToReload.append(previousIndexPath)
        }

        collectionView.reloadItems(at: indexPathsToReload)
    }
    
    @objc func didTapBackground() {
        hideBottomSheet()
    }

    private func showBottomSheet(animated: Bool) {
        layoutIfNeeded()
        bottomSheetBottomConstraint?.isActive = false
        bottomSheetBottomConstraint = bottomSheetView.bottomAnchor.constraint(equalTo: bottomAnchor)
        bottomSheetBottomConstraint?.isActive = true
        
        if animated {
            bottomSheetView.transform = CGAffineTransform(translationX: 0, y: 40)
            bottomSheetView.alpha = 0.95
            UIView.animate(
                withDuration: 0.32,
                delay: 0,
                usingSpringWithDamping: 0.9,
                initialSpringVelocity: 0.8,
                options: [.curveEaseOut, .beginFromCurrentState],
                animations: {
                    self.bottomSheetView.transform = .identity
                    self.bottomSheetView.alpha = 1.0
                    self.layoutIfNeeded()
                }
            )
        } else {
            alpha = 0
            UIView.animate(withDuration: 0.22, animations: {
                self.alpha = 1
                self.layoutIfNeeded()
            })
        }
    }
    
    private func hideBottomSheet() {
        bottomSheetBottomConstraint?.isActive = false
        bottomSheetBottomConstraint = bottomSheetView.topAnchor.constraint(equalTo: bottomAnchor)
        bottomSheetBottomConstraint?.isActive = true
        
        UIView.animate(withDuration: 0.22, delay: 0, options: [.curveEaseIn], animations: {
            self.bottomSheetView.transform = CGAffineTransform(translationX: 0, y: 20)
            self.bottomSheetView.alpha = 0.98
            self.alpha = 0
            self.layoutIfNeeded()
        }) { _ in
            self.removeFromSuperview()
        }
    }
    
    @objc func didTapStart() {
        self.onTapStart?(self.selectedOption)
    }
    
    private struct RoutingOptionItem {
        let option: RoutingOption
        let title: String
        let description: String
        let isEnabled: Bool
    }
    
    private final class RoutingOptionCell: UICollectionViewCell {
        static let reuseIdentifier = "RoutingOptionCell"
        
        private let cardView: UIView = {
            let view = UIView()
            view.layer.cornerRadius = 14
            view.layer.borderWidth = 1
            view.translatesAutoresizingMaskIntoConstraints = false
            return view
        }()
        
        private let titleLabel: UILabel = {
            let label = UILabel()
            label.font = UIFont.systemFont(ofSize: 14, weight: .bold)
            label.translatesAutoresizingMaskIntoConstraints = false
            return label
        }()
        
        private let descriptionLabel: UILabel = {
            let label = UILabel()
            label.font = UIFont.systemFont(ofSize: 12, weight: .medium)
            label.textAlignment = .right
            label.adjustsFontSizeToFitWidth = true
            label.minimumScaleFactor = 0.85
            label.translatesAutoresizingMaskIntoConstraints = false
            return label
        }()
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            setupLayout()
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        private func setupLayout() {
            contentView.backgroundColor = .clear
            contentView.addSubview(cardView)
            cardView.addSubview(titleLabel)
            cardView.addSubview(descriptionLabel)
            
            NSLayoutConstraint.activate([
                cardView.topAnchor.constraint(equalTo: contentView.topAnchor),
                cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
                cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
                
                titleLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 16),
                titleLabel.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),
                
                descriptionLabel.leadingAnchor.constraint(greaterThanOrEqualTo: titleLabel.trailingAnchor, constant: 12),
                descriptionLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),
                descriptionLabel.centerYAnchor.constraint(equalTo: cardView.centerYAnchor)
            ])
        }
        
        func configure(with item: RoutingOptionItem, isSelected: Bool) {
            titleLabel.text = item.title
            descriptionLabel.text = item.description
            
            if isSelected && item.isEnabled {
                cardView.backgroundColor = UIColor(red: 0.40, green: 0.69, blue: 0.92, alpha: 1.0)
                cardView.layer.borderColor = UIColor(red: 0.31, green: 0.55, blue: 0.77, alpha: 1.0).cgColor
                titleLabel.textColor = .white
                descriptionLabel.textColor = UIColor.white.withAlphaComponent(0.9)
            } else {
                cardView.backgroundColor = .white
                cardView.layer.borderColor = UIColor.systemGray3.cgColor
                titleLabel.textColor = UIColor.systemGray3
                descriptionLabel.textColor = UIColor.systemGray3
            }
        }
    }
}
