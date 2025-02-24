
import UIKit
import Foundation
import TJLabsResource

class TJLabsMapManager: TJLabsResourceManagerDelegate {
    func onBuildingLevelData(_ manager: TJLabsResource.TJLabsResourceManager, isOn: Bool, buildingLevelData: [String : [String]]) {
        if isOn {
            self.buildingLevelInfo[self.sectorId] = buildingLevelData
            delegate?.onBuildingLevelData(self, buildingLevelData: buildingLevelData)
//            let testData = ["COEX": ["B0", "B2", "B3", "B4", "B5", "B6"],
//                            "BOEX": ["B0", "B2", "B3", "B4", "B5", "B6"],
//                            "DOEX": ["B0", "B2", "B3", "B4", "B5", "B6"],
//                            "EOEX": ["B0", "B2", "B3", "B4", "B5", "B6"],
//                            "FOEX": ["B0", "B2", "B3", "B4", "B5", "B6"],
//                            "GOEX": ["B0", "B2", "B3", "B4", "B5", "B6"]]
//            self.buildingLevelInfo[self.sectorId] = testData
//            delegate?.onBuildingLevelData(self, buildingLevelData: testData)
        } else {
            
        }
    }
    
    func onPathPixelData(_ manager: TJLabsResource.TJLabsResourceManager, isOn: Bool, pathPixelKey: String, data: TJLabsResource.PathPixelData?) {
        if let ppData = data, isOn {
            self.buildingLevelPathPixel[pathPixelKey] = ppData
            delegate?.onPathPixelData(self, pathPixelKey: pathPixelKey, data: ppData)
        } else {
            
        }
    }
    
    func onBuildingLevelImageData(_ manager: TJLabsResource.TJLabsResourceManager, isOn: Bool, imageKey: String, data: UIImage?) {
        if let imageData = data, isOn {
            self.buildingLevelImages[imageKey] = imageData
            delegate?.onBuildingLevelImageData(self, imageKey: imageKey, data: imageData)
        } else {
            
        }
    }
    
    func onScaleOffsetData(_ manager: TJLabsResource.TJLabsResourceManager, isOn: Bool, scaleKey: String, data: [Double]?) {
        if let scaleOffsetData = data, isOn {
            self.buildingLevelScaleOffset[scaleKey] = scaleOffsetData
            delegate?.onScaleOffsetData(self, scaleKey: scaleKey, data: scaleOffsetData)
        } else {
            
        }
    }
    
    func onEntranceData(_ manager: TJLabsResource.TJLabsResourceManager, isOn: Bool, entranceKey: String, data: TJLabsResource.EntranceRouteData?) {
        // Do not use in Map SDK
    }
    
    func onError(_ manager: TJLabsResource.TJLabsResourceManager, error: TJLabsResource.ResourceError) {
        print("(TJLabsMap) Error : \(error)")
    }
    
    static let shared = TJLabsMapManager()
    
    var buildingLevelInfo = [Int: [String: [String]]]()
    var buildingLevelPathPixel = [String: PathPixelData]()
    var buildingLevelImages = [String: UIImage]()
    var buildingLevelScaleOffset = [String: [Double]]()
    var buildingLevelUnits = [String: [Unit]]()
    
    init() {
        resourceManager.delegate = self
    }
    
    let resourceManager = TJLabsResourceManager()
    weak var delegate: TJLabsMapManagerDelegate?
    
    var sectorId: Int = 0
    var region: ResourceRegion = .KOREA
    
    public func loadMap(region: ResourceRegion, sectorId: Int) {
        self.sectorId = sectorId
        resourceManager.loadMapResource(region: region, sectorId: sectorId)
    }
    
    func getBuildingLevelInfo(sector_id: Int) -> [String: [String]] {
        print("(TJLabsMapManager) : buildingLevelInfo = \(buildingLevelInfo)")
        if let value = self.buildingLevelInfo[sector_id] {
            return value
        } else {
            return [String: [String]]()
        }
    }
    
    func getCurrentTimeInMilliseconds() -> Int {
        return Int(Date().timeIntervalSince1970 * 1000)
    }
}
