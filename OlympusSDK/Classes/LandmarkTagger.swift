
import Foundation
import TJLabsCommon
import TJLabsResource

class LandmarkTagger {
    init(sectorId: Int) {
        self.sectorId = sectorId
    }
    
    var sectorId: Int
    var landmarkData = [String: [String: LandmarkData]]()
    
    func setLandmarkData(key: String, data: [String: LandmarkData]) {
        self.landmarkData[key] = data
    }
    
    func findMatchedLandmarkWithUserPeak(userPeak: UserPeak, curResult: FineLocationTrackingOutput?) -> LandmarkData? {
        guard let curResult = curResult else { return nil }
        let key = "\(sectorId)_\(curResult.building_name)_\(curResult.level_name)"
        guard let landmarkData = self.landmarkData[key] else { return nil }
        guard let matchedLandmark = landmarkData[userPeak.id] else { return nil }
        
        JupiterLogger.i(tag: "LandmarkTagger", message: "(findMatchedLandmarkWithUserPeak) matchedLandmark: \(matchedLandmark)")
        
        return matchedLandmark
    }
}
