import Foundation
import UIKit

class OlympusImageCacheManager {
    
    static let shared = NSCache<NSString, UIImage>()
    
    private init() {}
}
