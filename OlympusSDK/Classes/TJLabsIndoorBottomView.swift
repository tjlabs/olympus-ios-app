import UIKit
import TJLabsResource

class TJLabsIndoorBottomView: UIView {
    var onSelectDestination: ((NaviDestination) -> Void)?
    var buildingInfo: BuildingOutput?
    
    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let searchView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.cornerRadius = 10
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor.black.withAlphaComponent(0.37).cgColor
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let searchImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = TJLabsAssets.image(named: "ic_search")
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false

        return imageView
    }()
    
    private let searchTextField: UITextField = {
        let textField = UITextField()
        textField.translatesAutoresizingMaskIntoConstraints = false
        return textField
    }()
    
    private let lineView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(hex: "#F5F5F5")
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    var finderView: TJLabsFinderView?
    
    init() {
        super.init(frame: .zero)
        commonInit()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func update(buildingInfo: BuildingOutput) {
        self.buildingInfo = buildingInfo
    }
    
    func updateDestinations(destinations: [NaviDestination]) {
        self.finderView?.updateDestinations(destinations: destinations)
    }
    
    private func commonInit() {
        setupLayout()
        bindActions()
    }
    
    private func setupLayout() {
        self.finderView = TJLabsFinderView()
        guard let finderView = self.finderView else { return }
        finderView.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(containerView)
        containerView.addSubview(searchView)
        searchView.addSubview(searchImageView)
        searchView.addSubview(searchTextField)
        containerView.addSubview(lineView)
        containerView.addSubview(finderView)
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: topAnchor),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor),
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            
            searchView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 5),
            searchView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 10),
            searchView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -10),
            searchView.heightAnchor.constraint(equalToConstant: 40),
            searchImageView.leadingAnchor.constraint(equalTo: searchView.leadingAnchor, constant: 6),
            searchImageView.centerYAnchor.constraint(equalTo: searchView.centerYAnchor),
            searchImageView.widthAnchor.constraint(equalToConstant: 30),
            searchImageView.heightAnchor.constraint(equalToConstant: 30),

            searchTextField.leadingAnchor.constraint(equalTo: searchImageView.trailingAnchor, constant: 10),
            searchTextField.trailingAnchor.constraint(equalTo: searchView.trailingAnchor, constant: -10),
            searchTextField.centerYAnchor.constraint(equalTo: searchView.centerYAnchor),
            
            lineView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            lineView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            lineView.heightAnchor.constraint(equalToConstant: 1),
            lineView.topAnchor.constraint(equalTo: searchView.bottomAnchor, constant: 15),
            
            finderView.topAnchor.constraint(equalTo: lineView.bottomAnchor, constant: 10),
            finderView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            finderView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            finderView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
        ])
    }
    
    private func bindActions() {
        self.finderView?.onSelectDestination = { [weak self] destination in
            self?.onSelectDestination?(destination)
        }
        
        searchTextField.addTarget(self, action: #selector(searchTextDidChange(_:)), for: .editingChanged)
    }
    
    @objc private func searchTextDidChange(_ textField: UITextField) {
        finderView?.updateSearchText(textField.text ?? "")
    }
}
