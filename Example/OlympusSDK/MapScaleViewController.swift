import UIKit
import OlympusSDK

class MapScaleViewController: UIViewController, Observer {
    
    func update(result: OlympusSDK.FineLocationTrackingResult) { }
    func report(flag: Int) { }
    
    @IBOutlet weak var topView: UIView!
    @IBOutlet weak var mainView: UIView!
    @IBOutlet weak var bottomView: UIView!
    
    let mapView = OlympusMapViewForScale()
    var scales: [Double] = [0, 0, 0, 0]
    let SCALE_MIN_MAX: [Float] = [0, 25]
    let OFFSET_MIN_MAX: [Float] = [0, 25]
    
    var serviceManager = OlympusServiceManager()
    var sector_id: Int = 2
    var mode: String = "pdr"
    var userId: String = ""
    
    var timer: Timer?
    let TIMER_INTERVAL: TimeInterval = 1 / 10
    
    private var foregroundObserver: Any!
    private var backgroundObserver: Any!
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(false)
        navigationController?.isNavigationBarHidden = true
        self.notificationCenterAddObserver()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupLayout()
        setupBottomView()
        startOlympus()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        self.notificationCenterRemoveObserver()
        stopTimer()
        serviceManager.stopService()
        serviceManager.removeObserver(self)
    }
    
    private func startOlympus() {
        let uniqueId = makeUniqueId(uuid: self.userId)
        OlympusMapManager.shared.loadMapForScale(region: "Korea", sector_id: sector_id, mapView: mapView)
    }
    
    func startTimer() {
        if timer == nil {
            timer = Timer.scheduledTimer(timeInterval: TIMER_INTERVAL, target: self, selector: #selector(self.timerUpdate), userInfo: nil, repeats: true)
            RunLoop.current.add(self.timer!, forMode: .common)
        }
    }
    
    func stopTimer() {
        if timer != nil {
            self.timer!.invalidate()
            self.timer = nil
        }
    }
    
    @objc func timerUpdate() { }
    
    private func makeUniqueId(uuid: String) -> String {
        let currentTime: Int = getCurrentTimeInMilliseconds()
        let unique_id: String = "\(uuid)_\(currentTime)"
        return unique_id
    }
    
    @IBAction func tapBackButton(_ sender: UIButton) {
        serviceManager.removeObserver(self)
        self.navigationController?.popViewController(animated: true)
    }
    
    func notificationCenterAddObserver() {
        self.backgroundObserver = NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { _ in
            self.serviceManager.setBackgroundMode(flag: true)
        }
        
        self.foregroundObserver = NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { _ in
            self.serviceManager.setBackgroundMode(flag: false)
        }
    }
    
    func notificationCenterRemoveObserver() {
        NotificationCenter.default.removeObserver(self.backgroundObserver)
        NotificationCenter.default.removeObserver(self.foregroundObserver)
    }
}

extension MapScaleViewController {
    func setupLayout() {
        mapView.configureFrame(to: mainView)
        mainView.addSubview(mapView)
    }
    
    func setupBottomView() {
        let verticalStackView = UIStackView()
        verticalStackView.axis = .vertical
        verticalStackView.distribution = .fillEqually
        verticalStackView.spacing = 10
        verticalStackView.translatesAutoresizingMaskIntoConstraints = false
        bottomView.addSubview(verticalStackView)

        NSLayoutConstraint.activate([
            verticalStackView.leadingAnchor.constraint(equalTo: bottomView.leadingAnchor, constant: 10),
            verticalStackView.trailingAnchor.constraint(equalTo: bottomView.trailingAnchor, constant: -10),
            verticalStackView.topAnchor.constraint(equalTo: bottomView.topAnchor, constant: 10),
            verticalStackView.bottomAnchor.constraint(equalTo: bottomView.bottomAnchor, constant: -10)
        ])

        let labels = ["x scale: ", "y scale: ", "x offset: ", "y offset: "]

        for (index, labelText) in labels.enumerated() {
            let horizontalStackView = UIStackView()
            horizontalStackView.axis = .horizontal
            horizontalStackView.distribution = .fill
            horizontalStackView.spacing = 10
            horizontalStackView.translatesAutoresizingMaskIntoConstraints = false
            
            let label = UILabel()
            label.text = labelText
            label.textAlignment = .left
            label.setContentHuggingPriority(.defaultHigh, for: .horizontal)
            
            let slider = UISlider()
            if index < 2 {
                slider.minimumValue = SCALE_MIN_MAX[0]
                slider.maximumValue = SCALE_MIN_MAX[1]
            } else {
                slider.minimumValue = OFFSET_MIN_MAX[0]
                slider.maximumValue = OFFSET_MIN_MAX[1]
            }
            
            slider.value = Float(scales[index])
            slider.tag = index
            
            slider.addTarget(self, action: #selector(sliderValueChanged(_:)), for: .valueChanged)
            
            let valueLabel = UILabel()
            valueLabel.text = String(format: "%.2f", scales[index])
            valueLabel.textAlignment = .right
            valueLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)
            valueLabel.tag = 1000 + index
            
            horizontalStackView.addArrangedSubview(label)
            horizontalStackView.addArrangedSubview(slider)
            horizontalStackView.addArrangedSubview(valueLabel)
            
            verticalStackView.addArrangedSubview(horizontalStackView)
        }
    }

    @objc private func sliderValueChanged(_ sender: UISlider) {
        let index = sender.tag
        let sliderValue = Double(sender.value)
        scales[index] = Double(sender.value)
        if let valueLabel = bottomView.viewWithTag(1000 + index) as? UILabel {
            valueLabel.text = String(format: "%.2f", scales[index])
        }
        
        mapView.updateMapAndPpScaleValues(index: index, value: sliderValue)
    }
}
