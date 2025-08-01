
import Foundation

class OlympusAffineConverter {
    static let shared = OlympusAffineConverter()
    
    private var sector_id: Int = -1
    var AffineParam = [Int: AffineTransParamOutput]()
    
    init () { }
    
    func initialize() { }
    
    func setSectorID(sector_id: Int) {
        self.sector_id = sector_id
    }
}

