
import UIKit

class TJLabsZoomButton: UIButton {
    
    private var imageZoomIn: UIImage?
    private var imageZoomOut: UIImage?
    
    static var zoomMode: ZoomMode = .ZOOM_OUT
    static var zoomModeChangedTime = 0
    
    init() {
        super.init(frame: .zero)
        self.setupAssets()
        
        self.setImage(self.imageZoomIn, for: .normal)
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
        if let bundleURL = Bundle(for: OlympusSDK.TJLabsZoomButton.self).url(forResource: "OlympusSDK", withExtension: "bundle") {
            if let resourceBundle = Bundle(url: bundleURL) {
                if let zoomIn = UIImage(named: "icon_zoomIn", in: resourceBundle, compatibleWith: nil) {
                    self.imageZoomIn = zoomIn
                } else {
                    print(getLocalTimeString() + " , (Olympus) Error : Could not load icon_zoomIn.png from bundle.")
                }
                if let zoomOut = UIImage(named: "icon_zoomOut", in: resourceBundle, compatibleWith: nil) {
                    self.imageZoomOut = zoomOut
                } else {
                    print(getLocalTimeString() + " , (Olympus) Error : Could not load icon_zoomOut.png from bundle.")
                }
            } else {
                print(getLocalTimeString() + " , (Olympus) Error : Could not load resourceBundle")
            }
        } else {
            print(getLocalTimeString() + " , (Olympus) Error : Could not load bundleURL")
        }
    }
    
    func setButtonImage(to mode: ZoomMode? = nil) {
        TJLabsZoomButton.zoomMode = mode ?? (TJLabsZoomButton.zoomMode == .ZOOM_IN ? .ZOOM_OUT : .ZOOM_IN)
        DispatchQueue.main.async { [self] in
            self.setImage(TJLabsZoomButton.zoomMode == .ZOOM_IN ? imageZoomOut : imageZoomIn, for: .normal)
        }
    }
    
    func updateZoomModeChangedTime(time: Int) {
        TJLabsZoomButton.zoomModeChangedTime = time
    }
}
