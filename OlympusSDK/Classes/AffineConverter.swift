
import Foundation
import TJLabsResource

class AffineConverter {
    static let shared = AffineConverter()
    
    var affineParam = [Int: AffineTransParamOutput]()
    
    init () { }
    
    func initialize() { }
    
    func setAffineParam(sectorId: Int, data: AffineTransParamOutput) {
        self.affineParam[sectorId] = data
    }
    
    func getAffineParam(sectorId: Int) -> AffineTransParamOutput? {
        return self.affineParam[sectorId]
    }
    
    func convertPpToLLH(x: Double, y: Double, heading: Double, param: AffineTransParamOutput) -> LLH {
        let lon = param.xx_scale * x + param.xy_shear * y + param.x_translation
        let lat = param.yx_shear * x + param.yy_scale * y + param.y_translation
        
        let headingOffsetDeg = param.heading_offset // songdo : 36.92
        let correctedHeading = fmod(-heading + headingOffsetDeg + 360.0, 360.0)
        
        return LLH(lat: lat, lon: lon, heading: correctedHeading)
    }
}
