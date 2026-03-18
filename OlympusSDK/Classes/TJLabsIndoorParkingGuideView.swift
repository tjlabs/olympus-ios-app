import UIKit

class TJLabsIndoorParkingGuideView: UIView {

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
    
    private let animationContainerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let spinnerTrackLayer: CAShapeLayer = {
        let layer = CAShapeLayer()
        layer.fillColor = UIColor.clear.cgColor
        layer.strokeColor = UIColor(red: 0.286, green: 0.572, blue: 1.0, alpha: 1.0).cgColor
        layer.lineWidth = 36
        layer.lineCap = .round
        layer.strokeStart = 0.0
        layer.strokeEnd = 0.1
        return layer
    }()
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupLayout() {
        containerView.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(containerView)
        NSLayoutConstraint.activate([
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            containerView.topAnchor.constraint(equalTo: topAnchor),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        
        containerView.addSubview(titleLabel)
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 10),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -10),
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 200)
        ])
        
        containerView.addSubview(messageLabel)
        NSLayoutConstraint.activate([
            messageLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 10),
            messageLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -10),
            messageLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 30)
        ])
        
        addSubview(animationContainerView)
        NSLayoutConstraint.activate([
            animationContainerView.centerXAnchor.constraint(equalTo: centerXAnchor),
            animationContainerView.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: 50),
            animationContainerView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 50),
            animationContainerView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -50),
            animationContainerView.heightAnchor.constraint(equalToConstant: 200)
        ])
    }
    
    private func bindActions() {
        animationContainerView.layer.addSublayer(spinnerTrackLayer)
        startSpinnerAnimation()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let inset: CGFloat = 18
        let side = min(animationContainerView.bounds.width, animationContainerView.bounds.height) - inset * 2
        let arcRect = CGRect(
            x: (animationContainerView.bounds.width - side) / 2,
            y: (animationContainerView.bounds.height - side) / 2,
            width: side,
            height: side
        )
        
        spinnerTrackLayer.frame = animationContainerView.bounds
        spinnerTrackLayer.path = UIBezierPath(ovalIn: arcRect).cgPath
    }
    
    private func startSpinnerAnimation() {
        spinnerTrackLayer.removeAllAnimations()
        
        let headAnimation = CABasicAnimation(keyPath: "strokeEnd")
        headAnimation.fromValue = 0.1
        headAnimation.toValue = 1.0
        headAnimation.duration = 1.2
        headAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        
        let tailAnimation = CABasicAnimation(keyPath: "strokeStart")
        tailAnimation.fromValue = 0.0
        tailAnimation.toValue = 0.9
        tailAnimation.duration = 1.2
        tailAnimation.beginTime = 0.2
        tailAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        
        let rotationAnimation = CABasicAnimation(keyPath: "transform.rotation")
        rotationAnimation.fromValue = 0
        rotationAnimation.toValue = CGFloat.pi * 2
        rotationAnimation.duration = 1.2
        rotationAnimation.timingFunction = CAMediaTimingFunction(name: .linear)
        
        let animationGroup = CAAnimationGroup()
        animationGroup.animations = [headAnimation, tailAnimation, rotationAnimation]
        animationGroup.duration = 1.4
        animationGroup.repeatCount = .infinity
        animationGroup.isRemovedOnCompletion = false
        animationGroup.fillMode = .forwards
        
        spinnerTrackLayer.add(animationGroup, forKey: "circle_loader_spinner")
    }
}
