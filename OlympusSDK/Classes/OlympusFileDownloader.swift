import Foundation

public class OlympusFileDownloader {
    static let shared = OlympusFileDownloader()
    
    public func downloadCSVFile(from url: URL, fname: String, completion: @escaping (URL?, Error?) -> Void) {
        print(getLocalTimeString() + " , (Olympus) Path-Pixel : \(url)")
        let task = URLSession.shared.downloadTask(with: url) { (tempLocalURL, response, error) in
            guard let tempLocalURL = tempLocalURL, error == nil else {
                completion(nil, error)
                return
            }
            
            do {
                let documentsURL = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
                let savedURL = documentsURL.appendingPathComponent("\(fname).csv")
                
                if FileManager.default.fileExists(atPath: savedURL.path) { try FileManager.default.removeItem(at: savedURL) }
                try FileManager.default.moveItem(at: tempLocalURL, to: savedURL)
                
                completion(savedURL, nil)
            } catch {
                completion(nil, error)
            }
        }
        task.resume()
    }
}
