
import UIKit
import SnapKit
import Lottie

class ProgressingView: UIView {

    init() {
        super.init(frame: .zero)
        setupLayout()
        bindActions()
    }
    
    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = .black
        view.alpha = 0.6
        return view
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        label.textColor = UIColor.white
        label.textAlignment = .center
        label.text = "데이터를 처리하고 있습니다."
        return label
    }()
    
    private let messageLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        label.textColor = UIColor.white
        label.textAlignment = .center
        label.text = "처리가 완료된 후 사라집니다."
        label.numberOfLines = 0
        label.adjustsFontSizeToFitWidth = true
        return label
    }()
    
    private let animationView = LottieAnimationView(name: "circle_loader")
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupLayout() {
        addSubview(containerView)
        containerView.snp.makeConstraints { make in
            make.leading.trailing.top.bottom.equalToSuperview()
        }
        
        containerView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints{ make in
            make.leading.trailing.equalToSuperview().inset(10)
            make.top.equalToSuperview().inset(200)
        }
        
        containerView.addSubview(messageLabel)
        messageLabel.snp.makeConstraints{ make in
            make.leading.trailing.equalToSuperview().inset(10)
            make.top.equalTo(titleLabel.snp.bottom).offset(30)
        }
        
        addSubview(animationView)
        animationView.contentMode = .scaleAspectFit
//        animationView.transform = CGAffineTransform(scaleX: 2.5, y: 2.5)
        animationView.loopMode = .loop
        animationView.play()
        animationView.animationSpeed = 1.0
        animationView.snp.makeConstraints { make in
            make.width.height.equalTo(200)
            make.centerX.equalToSuperview()
            make.top.equalTo(messageLabel.snp.bottom).offset(30)
        }
    }
    
    private func bindActions() {
    }
}
