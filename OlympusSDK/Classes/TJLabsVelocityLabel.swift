
import UIKit

class TJLabsVelocityLabel: UILabel {
    
    init() {
        super.init(frame: .zero)
        
        self.text = "0"
        self.textAlignment = .center
        self.textColor = .black
        self.font = UIFont.boldSystemFont(ofSize: 50)
        self.translatesAutoresizingMaskIntoConstraints = false
        
        let attrString = NSAttributedString(
            string: "0",
            attributes: [
                NSAttributedString.Key.strokeColor: UIColor.white,
                NSAttributedString.Key.foregroundColor: UIColor.black,
                NSAttributedString.Key.strokeWidth: -3.0,
                NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: 53.0)
            ]
        )
        self.attributedText = attrString
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setText(text: String) {
        self.text = text
        let attrString = NSAttributedString(
            string: text,
            attributes: [
                NSAttributedString.Key.strokeColor: UIColor.white,
                NSAttributedString.Key.foregroundColor: UIColor.black,
                NSAttributedString.Key.strokeWidth: -3.0,
                NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: 53.0)
            ]
        )
        self.attributedText = attrString
    }
}
