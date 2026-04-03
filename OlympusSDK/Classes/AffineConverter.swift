
import Foundation
import TJLabsResource

class AffineConverter {
    static let shared = AffineConverter()
    
    var affineParam = [Int: WGS84Transform]()
    
    init () { }
    
    func initialize() { }
    
    func setAffineParam(sectorId: Int, data: WGS84Transform) {
        self.affineParam[sectorId] = data
    }
    
    func getAffineParam(sectorId: Int) -> WGS84Transform? {
        return self.affineParam[sectorId]
    }
    
    func convertPpToLLH(x: Double, y: Double, heading: Double, param: WGS84Transform) -> LLH {
        let lon = param.xxScale * x + param.xyShear * y + param.xTranslation
        let lat = param.yxShear * x + param.yyScale * y + param.yTranslation
        
        let headingOffsetDeg = param.headingOffset // songdo : 36.92
        let correctedHeading = fmod(-heading + headingOffsetDeg + 360.0, 360.0)
        
        return LLH(lat: lat, lon: lon, heading: correctedHeading)
    }
}
