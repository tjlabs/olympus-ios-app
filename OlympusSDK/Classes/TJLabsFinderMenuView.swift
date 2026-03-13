import UIKit

enum FinderMenu {
    case EXIT
    case DESTINATION
}

final class TJLabsFinderMenuView: UIView {
    private var selectedMenu: FinderMenu = .DESTINATION
    
    var onTapMenu: ((FinderMenu) -> Void)?
    
    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let destinationButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("목적지 찾기", for: .normal)
        button.setTitleColor(.black, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let exitButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("출구 찾기", for: .normal)
        button.setTitleColor(UIColor.systemGray3, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let bottomLineView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.systemGray4
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let indicatorView: UIView = {
        let view = UIView()
        view.backgroundColor = .black
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private var indicatorLeadingToExitConstraint: NSLayoutConstraint?
    private var indicatorLeadingToDestinationConstraint: NSLayoutConstraint?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayout()
        bindActions()
        updateMenuUI(animated: false)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLayout()
        bindActions()
        updateMenuUI(animated: false)
    }
    
    private func setupLayout() {
        addSubview(containerView)
        containerView.addSubview(destinationButton)
        containerView.addSubview(exitButton)
        containerView.addSubview(bottomLineView)
        containerView.addSubview(indicatorView)
        
        indicatorLeadingToDestinationConstraint = indicatorView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor)
        indicatorLeadingToExitConstraint = indicatorView.leadingAnchor.constraint(equalTo: containerView.centerXAnchor)
        indicatorLeadingToDestinationConstraint?.isActive = true
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: topAnchor),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor),
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            
            destinationButton.topAnchor.constraint(equalTo: containerView.topAnchor),
            destinationButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            destinationButton.widthAnchor.constraint(equalTo: containerView.widthAnchor, multiplier: 0.5),
            destinationButton.heightAnchor.constraint(equalToConstant: 48),
            
            exitButton.topAnchor.constraint(equalTo: containerView.topAnchor),
            exitButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            exitButton.widthAnchor.constraint(equalTo: containerView.widthAnchor, multiplier: 0.5),
            exitButton.heightAnchor.constraint(equalToConstant: 48),
            
            bottomLineView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            bottomLineView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            bottomLineView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            bottomLineView.heightAnchor.constraint(equalToConstant: 1),
            
            indicatorView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            indicatorView.widthAnchor.constraint(equalTo: containerView.widthAnchor, multiplier: 0.5),
            indicatorView.heightAnchor.constraint(equalToConstant: 2)
        ])
    }
    
    private func bindActions() {
        destinationButton.addTarget(self, action: #selector(didTapDestinationButton), for: .touchUpInside)
        exitButton.addTarget(self, action: #selector(didTapExitButton), for: .touchUpInside)
    }
    
    @objc private func didTapExitButton() {
        setSelectedMenu(.EXIT, animated: true, shouldNotify: true)
    }
    
    @objc private func didTapDestinationButton() {
        setSelectedMenu(.DESTINATION, animated: true, shouldNotify: true)
    }
    
    func setSelectedMenu(_ menu: FinderMenu, animated: Bool = true, shouldNotify: Bool = false) {
        guard selectedMenu != menu else {
            if shouldNotify { onTapMenu?(menu) }
            return
        }
        selectedMenu = menu
        updateMenuUI(animated: animated)
        if shouldNotify {
            onTapMenu?(menu)
        }
    }
    
    private func updateMenuUI(animated: Bool) {
        let updates = {
            switch self.selectedMenu {
            case .EXIT:
                self.exitButton.setTitleColor(.black, for: .normal)
                self.destinationButton.setTitleColor(UIColor.systemGray3, for: .normal)
                self.indicatorLeadingToDestinationConstraint?.isActive = false
                self.indicatorLeadingToExitConstraint?.isActive = true
            case .DESTINATION:
                self.exitButton.setTitleColor(UIColor.systemGray3, for: .normal)
                self.destinationButton.setTitleColor(.black, for: .normal)
                self.indicatorLeadingToExitConstraint?.isActive = false
                self.indicatorLeadingToDestinationConstraint?.isActive = true
            }
            self.layoutIfNeeded()
        }
        
        if animated {
            UIView.animate(withDuration: 0.2, delay: 0, options: [.curveEaseInOut]) {
                updates()
            }
        } else {
            updates()
        }
    }
}
