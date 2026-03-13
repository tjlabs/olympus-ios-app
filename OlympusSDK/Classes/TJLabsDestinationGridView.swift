
import UIKit
import TJLabsResource

class TJLabsDestinationGridView: UIView, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    var onSelectDestination: ((NaviDestination) -> Void)?
    var destinations: [NaviDestination] = []
    
    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumLineSpacing = 8
        layout.minimumInteritemSpacing = 0
        layout.sectionInset = UIEdgeInsets(top: 10, left: 0, bottom: 10, right: 0)
        
        let view = UICollectionView(frame: .zero, collectionViewLayout: layout)
        view.backgroundColor = .clear
        view.showsVerticalScrollIndicator = false
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    init() {
        super.init(frame: .zero)
        commonInit()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func commonInit() {
        setupLayout()
        bindActions()
        configureCollectionView()
    }
    
    private func setupLayout() {
        addSubview(containerView)
        containerView.addSubview(collectionView)
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: topAnchor),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor),
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            collectionView.topAnchor.constraint(equalTo: containerView.topAnchor),
            collectionView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            collectionView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
        ])
    }
    
    private func bindActions() {

    }

    private func configureCollectionView() {
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(DestinationCardCell.self, forCellWithReuseIdentifier: DestinationCardCell.reuseIdentifier)
    }
    
    func configure(destinations: [NaviDestination]) {
        self.destinations = destinations
        collectionView.reloadData()
    }
    
    func configure() {
        collectionView.reloadData()
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return destinations.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: DestinationCardCell.reuseIdentifier, for: indexPath) as? DestinationCardCell else {
            return UICollectionViewCell()
        }
        
        cell.configure(with: destinations[indexPath.item])
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: collectionView.bounds.width, height: 50)
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard indexPath.item < destinations.count else { return }
        onSelectDestination?(destinations[indexPath.item])
    }
    private final class DestinationCardCell: UICollectionViewCell {
        static let reuseIdentifier = "DestinationCardCell"
        
        private let cardView: UIView = {
            let view = UIView()
            view.backgroundColor = .white
            view.layer.cornerRadius = 18
            view.layer.borderWidth = 1
            view.layer.borderColor = UIColor.systemGray6.cgColor
            view.translatesAutoresizingMaskIntoConstraints = false
            return view
        }()
        
        private let titleLabel: UILabel = {
            let label = UILabel()
            label.font = UIFont.systemFont(ofSize: 14, weight: .bold)
            label.textColor = .black
            label.textAlignment = .left
            label.adjustsFontSizeToFitWidth = true
            label.numberOfLines = 1
            label.translatesAutoresizingMaskIntoConstraints = false
            return label
        }()
        
        private let subtitleLabel: UILabel = {
            let label = UILabel()
            label.font = UIFont.systemFont(ofSize: 12, weight: .regular)
            label.textColor = UIColor.systemGray3
            label.textAlignment = .left
            label.adjustsFontSizeToFitWidth = true
            label.numberOfLines = 1
            label.translatesAutoresizingMaskIntoConstraints = false
            return label
        }()
        
        private let statusLabel: UILabel = {
            let label = UILabel()
            label.font = UIFont.systemFont(ofSize: 12, weight: .semibold)
            label.textAlignment = .center
            label.adjustsFontSizeToFitWidth = true
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
            cardView.addSubview(subtitleLabel)
            cardView.addSubview(statusLabel)
            
            NSLayoutConstraint.activate([
                cardView.topAnchor.constraint(equalTo: contentView.topAnchor),
                cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
                cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 10),
                cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10),
                
                titleLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 15),
                titleLabel.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),
                titleLabel.widthAnchor.constraint(equalTo: cardView.widthAnchor, multiplier: 1/2.5),
                
                statusLabel.widthAnchor.constraint(equalToConstant: 34),
                statusLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -18),
                statusLabel.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),
                
                subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.trailingAnchor, constant: 10),
                subtitleLabel.trailingAnchor.constraint(equalTo: statusLabel.leadingAnchor, constant: -10),
                subtitleLabel.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),
            ])
        }
        
        func configure(with destination: NaviDestination) {
            let values = Self.values(from: destination)
            titleLabel.text = values.title
            subtitleLabel.text = values.subtitle
            statusLabel.text = values.status
            
            switch values.status {
            case "원활":
                statusLabel.textColor = UIColor(red: 0.60, green: 0.94, blue: 0.14, alpha: 1.0)
            case "혼잡":
                statusLabel.textColor = .red
            default:
                statusLabel.textColor = UIColor.systemGray3
            }
        }
        
        private static func values(from destination: NaviDestination) -> (title: String, subtitle: String, status: String) {
            let mirror = Mirror(reflecting: destination)
            var dictionary: [String: Any] = [:]
            for child in mirror.children {
                if let label = child.label {
                    dictionary[label] = child.value
                }
            }
            
            func stringValue(for keys: [String], default defaultValue: String) -> String {
                for key in keys {
                    if let value = dictionary[key] as? String, !value.isEmpty {
                        return value
                    }
                    if let value = dictionary[key] {
                        let string = String(describing: value)
                        if !string.isEmpty, string != "nil" {
                            return string
                        }
                    }
                }
                return defaultValue
            }
            
            let title = stringValue(for: ["name", "title", "displayName"], default: "목적지")
            let subtitle = stringValue(for: ["subtitle", "direction", "location", "detail", "descriptionText"], default: "코엑스 어딘가")
            let status = stringValue(for: ["status", "traffic", "crowd", "congestion"], default: "원활")
            
            return (title, subtitle, status)
        }
    }
}
