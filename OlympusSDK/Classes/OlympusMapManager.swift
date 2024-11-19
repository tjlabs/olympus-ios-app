import UIKit
import Foundation

public class OlympusMapManager {
    public static let shared = OlympusMapManager()
    
    var sector_id: Int = -1
    var sectorInfo = [Int: [String: [String]]]()
    var sectorImages = [String: [UIImage]]()
    var sectorScales = [String: [Double]]()
    var sectorUnits = [String: [Unit]]()
    
    init() {
        
    }
    
    private func setSectorID(value: Int) {
        self.sector_id = value
    }
    
    public func loadUserLevel(sector_id: Int, completion: @escaping (Int, String) -> Void) {
        setSectorID(value: sector_id)
        let input = InputSectorID(sector_id: sector_id)
        OlympusNetworkManager.shared.postSectorID(url: USER_LEVEL_URL, input: input, completion: { statusCode, returnedString in
            completion(statusCode, returnedString)
        })
    }
    
    private func loadUserPath(sector_id: Int, completion: @escaping (Bool, String) -> Void) {
        let input = InputSectorIDnOS(sector_id: sector_id, operating_system: OlympusConstants.OPERATING_SYSTEM)
        OlympusNetworkManager.shared.postSectorIDnOS(url: USER_PATH_URL, input: input, completion: { statusCode, returnedString in
            if statusCode == 200 {
                let outputPath = jsonToPathFromServer(jsonString: returnedString)
                if outputPath.0 {
                    //MARK: - Path
                    let pathInfo = outputPath.1
                    for element in pathInfo.path_pixel_list {
                        let buildingName = element.building_name
                        let levelName = element.level_name
                        let key = "\(input.sector_id)_\(buildingName)_\(levelName)"
                        let ppURL = element.url
                        // Path-Pixel URL 확인
                        OlympusPathMatchingCalculator.shared.PpURL[key] = ppURL
//                        print(getLocalTimeString() + " , (Olympus) Sector Info : \(key) PP URL = \(ppURL)")
                    }
                    OlympusPathMatchingCalculator.shared.loadPathPixel(sector_id: sector_id, PathPixelURL: OlympusPathMatchingCalculator.shared.PpURL)
                    let msg = getLocalTimeString() + " , (Olympus) Success : Load Sector Info // Path"
                    completion(true, msg)
                } else {
                    let msg = getLocalTimeString() + " , (Olympus) Error : Load Sector Info // Path \(statusCode)"
                    completion(false, msg)
                }
            } else {
                let msg = getLocalTimeString() + " , (Olympus) Error : Load Sector Info // Path \(statusCode)"
                completion(false, msg)
            }
        })
    }
    
    public func loadSectorBuildingLevel(sector_id: Int, completion: @escaping (Int, String) -> Void) {
        setSectorID(value: sector_id)
    }
    
    private func loadSectorScale(sector_id: Int) {
        let scaleInput = ScaleInput(sector_id: sector_id, operating_system: OlympusConstants.OPERATING_SYSTEM)
        OlympusNetworkManager.shared.postUserScale(url: USER_SCALE_URL, input: scaleInput, completion: { [self] statusCode, returnedString in
            let result = jsonToScaleFromServer(jsonString: returnedString)
            if result.0 {
                let scaleFromServer = result.1
                updateSectorScales(sector_id: sector_id, scaleFromServer: scaleFromServer)
            } else {
                print(getLocalTimeString() + " , (Olympus) MapManager : Error deocoding Sector Scale")
            }
        })
    }
    
    private func updateSectorScales(sector_id: Int, scaleFromServer: ScaleFromServer) {
        let scaleList = scaleFromServer.scale_list
        for element in scaleList {
            let buildingName = element.building_name
            let levelName = element.level_name
            
            let scaleKey = "scale_\(sector_id)_\(buildingName)_\(levelName)"
            sectorScales[scaleKey] = element.image_scale
//            print(getLocalTimeString() + " , (Olympus) MapManager : key = \(scaleKey) // scale = \(sectorScales[scaleKey])")
            NotificationCenter.default.post(name: .sectorScalesUpdated, object: nil, userInfo: ["scaleKey": scaleKey])
        }
    }
    
    private func loadSectorUnits(sector_id: Int) {
        let input = InputSectorID(sector_id: sector_id)
        OlympusNetworkManager.shared.postSectorID(url: USER_UNIT_URL, input: input, completion: { [self] statusCode, returnedString in
            let result = jsonToUnitFromServer(jsonString: returnedString)
            if result.0 {
                let unitFromServer = result.1
                updateSectorUnits(sector_id: sector_id, unitFromServer: unitFromServer)
            } else {
                print(getLocalTimeString() + " , (Olympus) MapManager : Error deocoding Sector Unit")
            }
        })
    }
    
    private func updateSectorUnits(sector_id: Int, unitFromServer: OutputUnit) {
        let unitList = unitFromServer.unit_list
        for element in unitList {
            let buildingName = element.building_name
            let levelName = element.level_name
            let unitKey = "unit_\(sector_id)_\(buildingName)_\(levelName)"
            sectorUnits[unitKey] = element.units
//            print(getLocalTimeString() + " , (Olympus) MapManager : key = \(unitKey) // unit = \(sectorUnits[unitKey])")
            NotificationCenter.default.post(name: .sectorUnitsUpdated, object: nil, userInfo: ["unitKey": unitKey])
        }
    }
    
    private func makeBuildingLevelInfo(sector_id: Int, outputLevel: OutputLevel) -> [String: [String]] {
        //MARK: - Level
        var infoBuildingLevel = [String:[String]]()
        for element in outputLevel.level_list {
            let buildingName = element.building_name
            let levelName = element.level_name
            
            if !levelName.contains("_D") {
//                if let value = infoBuildingLevel[buildingName] {
//                    var levels:[String] = value
//                    levels.append(levelName)
//                    infoBuildingLevel[buildingName] = levels
//                } else {
//                    let levels:[String] = [levelName]
//                    infoBuildingLevel[buildingName] = levels
//                }
                
                if var levels = infoBuildingLevel[buildingName] {
                    levels.append(levelName)
                    infoBuildingLevel[buildingName] = levels.sorted(by: { lhs, rhs in
                        return compareFloorNames(lhs: lhs, rhs: rhs)
                    })
                } else {
                    let levels = [levelName]
                    infoBuildingLevel[buildingName] = levels
                }
            }
        }
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
        
        return floorValue(lhs) > floorValue(rhs)
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
            
        loadSectorScale(sector_id: sector_id)
        loadSectorUnits(sector_id: sector_id)
        if let value = self.sectorInfo[sector_id] {
            mapView.updateBuildingData(Array(value.keys), levelData: value)
            loadSectorImages(sector_id: sector_id, infoBuildingLevel: value)
        } else {
            loadUserLevel(sector_id: sector_id) { [weak self] statusCode, returnedString in
                guard let self = self else { return }
                if statusCode == 200 {
                    let levelInfo = jsonToLevelFromServer(jsonString: returnedString)
                    if levelInfo.0 {
                        let infoBuildingLevel = self.makeBuildingLevelInfo(sector_id: sector_id, outputLevel: levelInfo.1)
                        self.setSectorBuildingLevel(sector_id: sector_id, infoBuildingLevel: infoBuildingLevel)
                        DispatchQueue.main.async {
                            mapView.updateBuildingData(Array(infoBuildingLevel.keys), levelData: infoBuildingLevel)
                        }
                        self.loadSectorImages(sector_id: sector_id, infoBuildingLevel: infoBuildingLevel)
                    }
                    
                    loadUserPath(sector_id: sector_id, completion: { isSuccess, message in
                        if isSuccess {
                        }
                    })
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
