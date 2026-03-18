
import UIKit

extension UIView {
    enum VerticalLocation {
        case bottom
        case top
        case left
        case right
        case rightBottom
    }
    
     var className: String {
        NSStringFromClass(self.classForCoder).components(separatedBy: ".").last!
    }
    
    @IBInspectable var borderWidth: CGFloat {
        set {
            layer.borderWidth = newValue
        }
        get {
            return layer.borderWidth
        }
    }
    
    @IBInspectable var cornerRadius: CGFloat {
        set {
            layer.cornerRadius = newValue
        }
        get {
            return layer.cornerRadius
        }
    }
    
    @IBInspectable var borderColor: UIColor? {
        set {
            guard let uiColor = newValue else { return }
            layer.borderColor = uiColor.cgColor
        }
        get {
            guard let color = layer.borderColor else { return nil }
            return UIColor(cgColor: color)
        }
    }
    
    @IBInspectable var shadowOpacity : Float {
        //그림자의 투명도 0 - 1 사이의 값을 가짐
        get{
            return self.layer.shadowOpacity
        }
        
        set{
            self.layer.shadowOpacity = newValue
        }
        
    }
    
    @IBInspectable var shadowColor : UIColor {
        //그림자의 색
        get{
            if let shadowColor = self.layer.shadowColor {
                return UIColor(cgColor: shadowColor)
            }
            return UIColor.clear
        }
        set{
            //그림자의 색이 지정됬을 경우
            self.layer.shadowOffset = CGSize(width: 0, height: 0)
            //shadowOffset은 빛의 위치를 지정해준다. 북쪽에 있으면 남쪽으로 그림지가 생기는 것
            self.layer.shadowColor = newValue.cgColor
            //그림자의 색을 지정
        }
        
    }
    
    @IBInspectable var maskToBound : Bool{
        
        get{
            return self.layer.masksToBounds
        }
        
        set{
            self.layer.masksToBounds = newValue
        }
        
    }
    
    public func makeVibrate(degree : UIImpactFeedbackGenerator.FeedbackStyle = .medium)
    {
        let generator = UIImpactFeedbackGenerator(style: degree)
        generator.impactOccurred()
    }
    
    func addShadow(location: VerticalLocation, color: UIColor = .black, opacity: Float = 0.4, radius: CGFloat = 2.0) {
        switch location {
        case .bottom:
                addShadow(offset: CGSize(width: 0, height: 10), color: color, opacity: opacity, radius: radius)
        case .top:
            addShadow(offset: CGSize(width: 0, height: -10), color: color, opacity: opacity, radius: radius)
        case .left:
            addShadow(offset: CGSize(width: -10, height: 0), color: color, opacity: opacity, radius: radius)
        case .right:
            addShadow(offset: CGSize(width: 10, height: 0), color: color, opacity: opacity, radius: radius)
        case .rightBottom:
            addShadow(offset: CGSize(width: 4, height: 4), color: color, opacity: opacity, radius: radius)
        }
    }
    
    func addShadow(offset: CGSize, color: UIColor = .black, opacity: Float = 0.1, radius: CGFloat = 3.0) {
        self.layer.masksToBounds = false
        self.layer.shadowColor = color.cgColor
        self.layer.shadowOffset = offset
        self.layer.shadowOpacity = opacity
        self.layer.shadowRadius = radius
    }
    
    func parentViewController() -> UIViewController? {
        var parentResponder: UIResponder? = self
        while let next = parentResponder?.next {
            if let vc = next as? UIViewController {
                return vc
            }
            parentResponder = next
        }
        return nil
    }
    
    func hideKeyboardWhenTappedAround() {
        let tap: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(UIView.dismissKeyboard))
        tap.cancelsTouchesInView = false
        addGestureRecognizer(tap)
    }
    
    @objc func dismissKeyboard() {
        endEditing(true)
    }
    
    func showToastWithIcon(image: UIImage?, message: String, duration: TimeInterval = 2.0) {
        let toastView = UIView()
        toastView.backgroundColor = UIColor.black.withAlphaComponent(0.8)
        toastView.layer.cornerRadius = 20
        toastView.clipsToBounds = true
        toastView.alpha = 0.0

        // 앱 아이콘 (또는 원하는 이미지)
        let iconImageView = UIImageView()
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconImageView.image = image
        
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.tintColor = .white
        iconImageView.cornerRadius = 20

        // 라벨
        let messageLabel = PaddingLabel()
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        messageLabel.text = message
        messageLabel.textColor = .white
        messageLabel.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        messageLabel.adjustsFontSizeToFitWidth = true
        messageLabel.minimumScaleFactor = 0.5
        messageLabel.lineBreakMode = .byTruncatingTail
        messageLabel.numberOfLines = 0
        messageLabel.textAlignment = .left

        // StackView
        let stackView = UIStackView(arrangedSubviews: [iconImageView, messageLabel])
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .horizontal
        stackView.spacing = 5
        stackView.alignment = .center

        toastView.translatesAutoresizingMaskIntoConstraints = false
        toastView.addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: toastView.topAnchor, constant: 10),
            stackView.bottomAnchor.constraint(equalTo: toastView.bottomAnchor, constant: -10),
            stackView.leadingAnchor.constraint(equalTo: toastView.leadingAnchor, constant: 10),
            stackView.trailingAnchor.constraint(equalTo: toastView.trailingAnchor, constant: -10),
            iconImageView.widthAnchor.constraint(equalToConstant: 36),
            iconImageView.heightAnchor.constraint(equalToConstant: 36)
        ])

        addSubview(toastView)
        NSLayoutConstraint.activate([
            toastView.centerXAnchor.constraint(equalTo: centerXAnchor),
            toastView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -180),
            toastView.widthAnchor.constraint(lessThanOrEqualTo: widthAnchor, multiplier: 0.9)
        ])

        // 애니메이션
        UIView.animate(withDuration: 0.3, animations: {
            toastView.alpha = 1.0
        }) { _ in
            UIView.animate(withDuration: 0.3, delay: duration, options: .curveEaseOut, animations: {
                toastView.alpha = 0.0
            }) { _ in
                toastView.removeFromSuperview()
            }
        }
    }
}

class PaddingLabel: UILabel {
    var inset = UIEdgeInsets(top: 6, left: 12, bottom: 6, right: 12)

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: inset))
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(width: size.width + inset.left + inset.right,
                      height: size.height + inset.top + inset.bottom)
    }
}

