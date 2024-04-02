import Foundation

final class JSONConverter {
    static func decodeJsonArray<T: Codable>(data: Data) -> [T]? {
        do {
            let result = try JSONDecoder().decode([T].self, from: data)
            return result
        } catch {
            guard let error = error as? DecodingError else { return nil }
            
            switch error {
            case .dataCorrupted(let context):
                return nil
            default:
                return nil
            }
        }
    }
    
    static func decodeJson<T: Codable>(data: Data) -> T? {
        do {
            let result = try JSONDecoder().decode(T.self, from: data)
            return result
        } catch {
            guard let error = error as? DecodingError else { return nil }
            
            switch error {
            case .dataCorrupted(let context):
                return nil
            default:
                return nil
            }
        }
    }
    
    static func encodeJson<T: Encodable>(param: T) -> Data? {
        do {
            let result = try JSONEncoder().encode(param)
            return result
        } catch let error as NSError {
            print("Error encoding JSON: \(error.localizedDescription)")
            return nil
        }
    }
}
