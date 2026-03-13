import UIKit
import TJLabsResource

class TJLabsFinderView: UIView {
    var onSelectDestination: ((NaviDestination) -> Void)?
    var destinations: [NaviDestination] = [] {
        didSet {
            JupiterLogger.i(tag: "TJLabsFinderView", message: "destinations= \(destinations)")
            destinationGridView.configure(destinations: destinations)
        }
    }
    
    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let menuView: TJLabsFinderMenuView = {
        let view = TJLabsFinderMenuView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let contentContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let exitListView = TJLabsExitListView()
    private let destinationGridView = TJLabsDestinationGridView()
    
    init() {
        super.init(frame: .zero)
        commonInit()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func updateDestinations(destinations: [NaviDestination]) {
        self.destinations = destinations
    }
    
    private func commonInit() {
        setupLayout()
        bindActions()
        switchTab(to: .destination)
    }
    
    private func setupLayout() {
        addSubview(containerView)
        containerView.addSubview(menuView)
        containerView.addSubview(contentContainerView)
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: topAnchor),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor),
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            
            menuView.topAnchor.constraint(equalTo: containerView.topAnchor),
            menuView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            menuView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            menuView.heightAnchor.constraint(equalToConstant: 48),
            
            contentContainerView.topAnchor.constraint(equalTo: menuView.bottomAnchor),
            contentContainerView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            contentContainerView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            contentContainerView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
        ])
    }
    
    private func bindActions() {
        menuView.onTapMenu = { [weak self] menu in
            self?.switchTab(to: menu)
        }
        
        destinationGridView.onSelectDestination = { [weak self] destination in
            self?.onSelectDestination?(destination)
        }
    }
    
    private func switchTab(to tab: FinderMenu) {
        menuView.setSelectedMenu(tab, animated: true, shouldNotify: false)
        exitListView.removeFromSuperview()
        destinationGridView.removeFromSuperview()

        let targetView: UIView
        switch tab {
        case .exit:
            targetView = exitListView
        case .destination:
            targetView = destinationGridView
        }

        contentContainerView.addSubview(targetView)
        targetView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            targetView.topAnchor.constraint(equalTo: contentContainerView.topAnchor),
            targetView.bottomAnchor.constraint(equalTo: contentContainerView.bottomAnchor),
            targetView.leadingAnchor.constraint(equalTo: contentContainerView.leadingAnchor),
            targetView.trailingAnchor.constraint(equalTo: contentContainerView.trailingAnchor)
        ])
    }
}
