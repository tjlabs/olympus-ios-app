import UIKit

class TJLabsIndoorTopView: UIView {
    
    var onTapBack: (() -> Void)?
    var onTapRefresh: (() -> Void)?
    
    private var isBackAnimating = false
    private var isRefreshAnimating = false
    
    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.clear
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let backView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let backImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = TJLabsAssets.image(named: "ic_back_arrow")
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private let refreshView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let refreshImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = TJLabsAssets.image(named: "ic_refresh")
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        label.textColor = .black
        label.text = "UNKNOWN"
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let lineView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(hex: "#F5F5F5")
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    init(title: String) {
        super.init(frame: .zero)
        commonInit()
        setTitle(title)
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
        containerView.addSubview(titleLabel)
        containerView.addSubview(backView)
        containerView.addSubview(refreshView)
        backView.addSubview(backImageView)
        refreshView.addSubview(refreshImageView)
        containerView.addSubview(lineView)
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: topAnchor),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor),
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor),

            titleLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            
            backView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            backView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 10),
            backView.widthAnchor.constraint(equalToConstant: 48),
            backView.heightAnchor.constraint(equalToConstant: 48),
            
            backImageView.centerXAnchor.constraint(equalTo: backView.centerXAnchor),
            backImageView.centerYAnchor.constraint(equalTo: backView.centerYAnchor),
            backImageView.widthAnchor.constraint(equalToConstant: 33),
            backImageView.heightAnchor.constraint(equalToConstant: 33),
            
            refreshView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            refreshView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -10),
            refreshView.widthAnchor.constraint(equalToConstant: 48),
            refreshView.heightAnchor.constraint(equalToConstant: 48),
            
            refreshImageView.centerXAnchor.constraint(equalTo: refreshView.centerXAnchor),
            refreshImageView.centerYAnchor.constraint(equalTo: refreshView.centerYAnchor),
            refreshImageView.widthAnchor.constraint(equalToConstant: 33),
            refreshImageView.heightAnchor.constraint(equalToConstant: 33),
            
            lineView.leadingAnchor.constraint(equalTo: leadingAnchor),
            lineView.trailingAnchor.constraint(equalTo: trailingAnchor),
            lineView.heightAnchor.constraint(equalToConstant: 1),
            lineView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
    }
    
    private func bindActions() {
        backView.isUserInteractionEnabled = true
        let backTap = UITapGestureRecognizer(target: self, action: #selector(didTapBackView))
        backView.addGestureRecognizer(backTap)
        
        refreshView.isUserInteractionEnabled = true
        let refreshTap = UITapGestureRecognizer(target: self, action: #selector(didTapRefreshView))
        refreshView.addGestureRecognizer(refreshTap)
    }
    
    @objc private func didTapBackView() {
        guard !isBackAnimating else { return }
        isBackAnimating = true
        backView.isUserInteractionEnabled = false
        
        UIView.animate(withDuration: 0.08, animations: {
            self.backView.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        }) { _ in
            UIView.animate(
                withDuration: 0.4,
                delay: 0,
                usingSpringWithDamping: 0.55,
                initialSpringVelocity: 3.0,
                options: [.beginFromCurrentState],
                animations: {
                    self.backView.transform = .identity
                }
            ) { _ in
                self.backView.isUserInteractionEnabled = true
                self.isBackAnimating = false
                self.onTapBack?()
            }
        }
    }
    
    @objc private func didTapRefreshView() {
        guard !isRefreshAnimating else { return }
        isRefreshAnimating = true
        refreshView.isUserInteractionEnabled = false
        
        UIView.animate(withDuration: 0.08, animations: {
            self.refreshView.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        }) { _ in
            UIView.animate(
                withDuration: 0.4,
                delay: 0,
                usingSpringWithDamping: 0.55,
                initialSpringVelocity: 3.0,
                options: [.beginFromCurrentState],
                animations: {
                    self.refreshView.transform = .identity
                }
            ) { _ in
                self.refreshView.isUserInteractionEnabled = true
                self.isRefreshAnimating = false
                self.onTapRefresh?()
            }
        }
    }
    
    private func setTitle(_ text: String) {
        titleLabel.text = text
    }
}
