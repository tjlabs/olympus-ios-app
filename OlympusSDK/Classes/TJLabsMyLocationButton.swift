
import UIKit

class TJLabsMyLocationButton: UIButton {
    
    private var imageMyLocation: UIImage?
    
    init() {
        super.init(frame: .zero)
        self.setupAssets()
        
        self.setImage(self.imageMyLocation, for: .normal)
        self.backgroundColor = .white
        self.layer.cornerRadius = 8
        self.layer.shadowColor = UIColor.black.cgColor
        self.layer.shadowOpacity = 0.2
        self.layer.shadowOffset = CGSize(width: 0, height: 4)
        self.layer.shadowRadius = 4
        self.contentEdgeInsets = UIEdgeInsets(top: 6, left: 6, bottom: 6, right: 6)
        self.translatesAutoresizingMaskIntoConstraints = false
        self.isHidden = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupAssets() {
        if let bundleURL = Bundle(for: OlympusSDK.TJLabsNaviView.self).url(forResource: "OlympusSDK", withExtension: "bundle") {
            if let resourceBundle = Bundle(url: bundleURL) {
                if let myLocation = UIImage(named: "icon_myLocation", in: resourceBundle, compatibleWith: nil) {
                    self.imageMyLocation = myLocation
                } else {
                    print(getLocalTimeString() + " , (Olympus) Error : Could not load icon_myLocation.png from bundle.")
                }
            } else {
                print(getLocalTimeString() + " , (Olympus) Error : Could not load resourceBundle")
            }
        } else {
            print(getLocalTimeString() + " , (Olympus) Error : Could not load bundleURL")
        }
    }
}
