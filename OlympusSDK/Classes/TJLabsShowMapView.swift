import UIKit
import TJLabsResource

class TJLabsShowMapView: UIView {
    
    var onTapShowMap: (() -> Void)?
    private var isShowingMap = false
    
    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(hex: "#F5F5F5")
        view.layer.cornerRadius = 12
        view.addShadow(offset: CGSize(width: 0, height: 0.5), color: .black, opacity: 0.2, radius: 4)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let showMapView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let contentStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.alignment = .center
        stackView.distribution = .fill
        stackView.spacing = 4
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()
    
    private let showMapLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14, weight: .bold)
        label.textColor = .black
        label.text = "지도 보기"
        label.textAlignment = .center
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.8
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let pinImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = TJLabsAssets.image(named: "ic_show_map_pin")
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
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
    }
    
    private func setupLayout() {
        addSubview(containerView)
        containerView.addSubview(showMapView)
        showMapView.addSubview(contentStackView)
        contentStackView.addArrangedSubview(showMapLabel)
        contentStackView.addArrangedSubview(pinImageView)
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: topAnchor),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor),
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            
            showMapView.widthAnchor.constraint(equalTo: containerView.widthAnchor, multiplier: 0.3),
            showMapView.heightAnchor.constraint(equalTo: containerView.heightAnchor, multiplier: 0.7),
            showMapView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            showMapView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),

            contentStackView.centerXAnchor.constraint(equalTo: showMapView.centerXAnchor),
            contentStackView.centerYAnchor.constraint(equalTo: showMapView.centerYAnchor),
            contentStackView.leadingAnchor.constraint(greaterThanOrEqualTo: showMapView.leadingAnchor, constant: 8),
            contentStackView.trailingAnchor.constraint(lessThanOrEqualTo: showMapView.trailingAnchor, constant: -8),

            pinImageView.widthAnchor.constraint(equalTo: showMapView.widthAnchor, multiplier: 0.22),
            pinImageView.heightAnchor.constraint(equalTo: pinImageView.widthAnchor, multiplier: 1.45)
        ])
    }
    
    private func bindActions() {
        showMapView.isUserInteractionEnabled = true
        let showMapTap = UITapGestureRecognizer(target: self, action: #selector(didTapShowMapView))
        showMapView.addGestureRecognizer(showMapTap)
    }
    
    @objc private func didTapShowMapView() {
        guard !isShowingMap else { return }
        isShowingMap = true
        showMapView.isUserInteractionEnabled = false

        UIView.animate(withDuration: 0.08, animations: {
            self.showMapView.transform = CGAffineTransform(scaleX: 1.0, y: 1.0)
        }) { _ in
            UIView.animate(
                withDuration: 0.1,
                animations: {
                    self.showMapView.transform = .identity
                }
            ) { _ in
                self.showMapView.isUserInteractionEnabled = true
                self.isShowingMap = false
                self.onTapShowMap?()
            }
        }
    }
}
