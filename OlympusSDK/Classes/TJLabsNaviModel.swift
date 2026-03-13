
import TJLabsResource

struct NaviDestination: Codable {
    let building: String
    let level: String
    let category: TJLabsResource.Category
    let name: String
    let x: Float
    let y: Float
}
