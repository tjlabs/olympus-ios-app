
import Foundation
import UIKit
import TJLabsResource

public struct TJLabsUserCoordinate {
    public let building: String
    public let level: String
    public let x: Double
    public let y: Double
    public let heading: Double
    public let velocity: Double
    
    public init(building: String, level: String, x: Double, y: Double, heading: Double, velocity: Double) {
        self.building = building
        self.level = level
        self.x = x
        self.y = y
        self.heading = heading
        self.velocity = velocity
    }
}

protocol TJLabsMapManagerDelegate: AnyObject {
    func onBuildingLevelData(_ manager: TJLabsMapManager, buildingLevelData: [String: [String]])
    func onPathPixelData(_ manager: TJLabsMapManager, pathPixelKey: String, data: PathPixelData)
    func onBuildingLevelImageData(_ manager: TJLabsMapManager, imageKey: String, data: UIImage)
    func onScaleOffsetData(_ manager: TJLabsMapManager, scaleKey: String, data: [Double])
    func onUnitData(_ manager: TJLabsMapManager, unitKey: String, data: [UnitData])
}

enum ZoomMode {
    case ZOOM_IN
    case ZOOM_OUT
}

enum MapMode {
    case MAP_ONLY
    case MAP_INTERACTION
    case UPDATE_USER
}

enum PlotType {
    case NORMAL
    case FORCE
}
