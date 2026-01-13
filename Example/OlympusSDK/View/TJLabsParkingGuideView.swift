
import UIKit
import SnapKit
import Lottie

class TJLabsParkingGuideView: UIView {

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
        label.text = "주차장에 진입하고 있습니다."
        return label
    }()
    
    private let messageLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        label.textColor = UIColor.white
        label.textAlignment = .center
        label.text = "진입 후 주차장 상황에 맞춰 추천 경로로 안내합니다.\n주차 빈자리를 경유하는 경로를 생성합니다."
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
