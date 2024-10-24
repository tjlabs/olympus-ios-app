
import UIKit

public class OlympusMapManager {
    public static let shared = OlympusMapManager()
    
    var sector_id: Int = -1
    var sectorInfo = [Int: [String: [String]]]()
    var sectorImages = [String: [UIImage]]()
    
    init() {
        
    }
    
    private func setSectorID(value: Int) {
        self.sector_id = value
    }
    
    public func loadSectorInfo(sector_id: Int, completion: @escaping (Int, String) -> Void) {
        setSectorID(value: sector_id)
        let sectorInput = SectorInput(sector_id: sector_id, operating_system: OlympusConstants.OPERATING_SYSTEM)
        OlympusNetworkManager.shared.postUserSector(url: USER_SECTOR_URL, input: sectorInput, completion: { statusCode, returnedString in
            completion(statusCode, returnedString)
//            print(getLocalTimeString() + " , (Olympus) MapManager : loadSectorInfo // \(USER_SECTOR_URL) , \(returnedString)")
//            if statusCode == 200 {
//                let sectorInfoFromServer = jsonToSectorInfoFromServer(jsonString: returnedString)
//                if sectorInfoFromServer.0 {
//                    let infoBuildingLevel: [String: [String]] = makeBuildingLevelInfo(sectorInfoFromServer: sectorInfoFromServer.1)
//                    setSectorBuildingLevel(sector_id: sector_id, infoBuildingLevel: infoBuildingLevel)
//                }
//                completion(statusCode, returnedString)
//            } else {
//                completion(statusCode, returnedString)
//            }
        })
    }
    
    private func makeBuildingLevelInfo(sector_id: Int, sectorInfoFromServer: SectorInfoFromServer) -> [String: [String]] {
        let sectorLevelList = sectorInfoFromServer.level_list
        var infoBuildingLevel = [String: [String]]()
        
        for element in sectorLevelList {
            let buildingName = element.building_name
            let levelName = element.level_name
            let key = "\(sector_id)_\(buildingName)_\(levelName)"
            
            if !levelName.contains("_D") {
                if var levels = infoBuildingLevel[buildingName] {
                    levels.append(levelName)
                    infoBuildingLevel[buildingName] = levels.sorted(by: { lhs, rhs in
                        return compareFloorNames(lhs: lhs, rhs: rhs)
                    })
                } else {
                    let levels = [levelName]
                    infoBuildingLevel[buildingName] = levels
                }
                
                if (!element.path_pixel_version.isEmpty) {
                    OlympusPathMatchingCalculator.shared.PpVersion[key] = OlympusPathMatchingCalculator.shared.PpVersion[key] ?? element.path_pixel_version
                    print(getLocalTimeString() + " , (Olympus) MapManager : \(key) PP Version = \(element.path_pixel_version)")
                }
            }
        }
        OlympusPathMatchingCalculator.shared.loadPathPixel(sector_id: sector_id, PathPixelVersion: OlympusPathMatchingCalculator.shared.PpVersion)
        // 임시
        infoBuildingLevel["Test"] = ["1F", "2F", "3F"]
        
        return infoBuildingLevel
    }

    private func compareFloorNames(lhs: String, rhs: String) -> Bool {
        func floorValue(_ floor: String) -> Int {
            if floor.starts(with: "B"), let number = Int(floor.dropFirst()) {
                return -number
            } else if floor.hasSuffix("F"), let number = Int(floor.dropLast()) {
                return number
            }
            return 0
        }
        
        return floorValue(lhs) < floorValue(rhs)
    }
    
    private func setSectorBuildingLevel(sector_id: Int, infoBuildingLevel: [String: [String]]) {
        self.sectorInfo[sector_id] = self.sectorInfo[sector_id] ?? infoBuildingLevel
        print(getLocalTimeString() + " , (Olympus) MapManager : sectorInfo = \(self.sectorInfo)")
    }
    
    public func getSectorBuildingLevel(sector_id: Int) -> [String: [String]] {
        if let value = self.sectorInfo[sector_id] {
            return value
        } else {
            return [String: [String]]()
        }
    }
    
    public func loadMap(region: String, sector_id: Int, mapView: OlympusMapView) {
        setServerURL(region: region)
        setSectorID(value: sector_id)
            
        if let value = self.sectorInfo[sector_id] {
            mapView.updateBuildingData(Array(value.keys), levelData: value)
            loadSectorImages(sector_id: sector_id, infoBuildingLevel: value)
        } else {
            loadSectorInfo(sector_id: sector_id) { [weak self] statusCode, returnedString in
                guard let self = self else { return }
                if statusCode == 200 {
                    let sectorInfoFromServer = jsonToSectorInfoFromServer(jsonString: returnedString)
                    if sectorInfoFromServer.0 {
                        let infoBuildingLevel = self.makeBuildingLevelInfo(sector_id: sector_id, sectorInfoFromServer: sectorInfoFromServer.1)
                        self.setSectorBuildingLevel(sector_id: sector_id, infoBuildingLevel: infoBuildingLevel)
                        DispatchQueue.main.async {
                            mapView.updateBuildingData(Array(infoBuildingLevel.keys), levelData: infoBuildingLevel)
                        }
                        self.loadSectorImages(sector_id: sector_id, infoBuildingLevel: infoBuildingLevel)
                    }
                }
            }
        }
    }
    
    private func loadSectorImages(sector_id: Int, infoBuildingLevel: [String: [String]]) {
        print(getLocalTimeString() + " , (Olympus) MapManager : loadSectorImages // infoBuildingLevel = \(infoBuildingLevel)")
        for (key, value) in infoBuildingLevel {
            let buildingName = key
            let levelNameList: [String] = value
            for levelName in levelNameList {
                let imageKey = "image_\(sector_id)_\(buildingName)_\(levelName)"
                self.loadBuildingLevelImage(sector_id: sector_id, building: buildingName, level: levelName, completion: { [self] data, error in
                    updateSectorImages(imageKey: imageKey, data: data)
                })
            }
        }
    }
    
    private func updateSectorImages(imageKey: String, data: UIImage?) {
        if let imageData = data {
            if var images = self.sectorImages[imageKey] {
                images.append(imageData)
                self.sectorImages[imageKey] = images
            } else {
                self.sectorImages[imageKey] = [imageData]
            }
            NotificationCenter.default.post(name: .sectorImagesUpdated, object: nil, userInfo: ["imageKey": imageKey])
        }
    }

    
    private func loadBuildingLevelImage(sector_id: Int, building: String, level: String, completion: @escaping (UIImage?, Error?) -> Void) {
        let urlString: String = "\(IMAGE_URL)/map/\(sector_id)/\(building)/\(level).png"
        print(getLocalTimeString() + " , (Olympus) MapManager : Image URL = \(urlString)")
        if let urlLevel = URL(string: urlString) {
            let cacheKey = NSString(string: urlString)
            
            if let cachedImage = OlympusImageCacheManager.shared.object(forKey: cacheKey) {
                completion(cachedImage, nil)
            } else {
                let task = URLSession.shared.dataTask(with: urlLevel) { (data, response, error) in
                    if let error = error {
                        completion(nil, error)
                    }
                    
                    if let data = data, let httpResponse = response as? HTTPURLResponse,
                       httpResponse.statusCode == 200 {
                        DispatchQueue.main.async {
                            if let imageData = UIImage(data: data) {
                                OlympusImageCacheManager.shared.setObject(imageData, forKey: cacheKey)
                                completion(UIImage(data: data), nil)
                            } else {
                                completion(nil, error)
                            }
                        }
                    } else {
                        completion(nil, error)
                    }
                }
                task.resume()
            }
        } else {
            completion(nil, nil)
        }
    }
}
