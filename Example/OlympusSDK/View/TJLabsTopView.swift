
import UIKit
import SnapKit

class TJLabsTopView: UIView {
    
    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(hex: "#ec008b")
        return view
    }()

    private let backButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(named: "ic_back"), for: .normal)
        button.tintColor = .white
        return button
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        label.textColor = .white
        label.text = "COEX"
        label.textAlignment = .center
        return label
    }()
    
    init() {
        super.init(frame: .zero)
        setupLayout()
        bindActions()
    }
    
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupLayout() {
        addSubview(containerView)
        containerView.addSubview(backButton)
        containerView.addSubview(titleLabel)
        containerView.snp.makeConstraints{ make in
            make.top.bottom.leading.trailing.equalToSuperview()
        }
//        backButton.snp.makeConstraints { make in
//            make.leading.equalToSuperview().offset(16)
//            make.centerY.equalToSuperview()
//            make.width.height.equalTo(24)
//        }
//        titleLabel.snp.makeConstraints { make in
//            make.center.equalToSuperview()
//        }
        
        backButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.top.equalTo(self.safeAreaLayoutGuide.snp.top).offset(6)   // ⬅️ safeArea 아래에 붙임
            make.width.height.equalTo(24)
        }

        titleLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(self.safeAreaLayoutGuide.snp.top).offset(6)   // ⬅️ safeArea 아래에 붙임
        }
    }
    
    private func bindActions() {
        
    }
    public func setTitle(_ text: String) {
        titleLabel.text = text
    }
}
