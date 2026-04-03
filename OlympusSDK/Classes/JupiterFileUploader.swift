
import Foundation
import TJLabsCommon

public class JupiterFileUploader: NSObject, URLSessionTaskDelegate {
    public static let shared = JupiterFileUploader()
    
    private var completionHandlers: [Int: (Bool) -> Void] = [:]
    
    private let backgroundSessionIdentifier = "com.tjlabs.jupiter.fileuploader.background"
    private lazy var backgroundSession: URLSession = {
        let config = URLSessionConfiguration.background(withIdentifier: backgroundSessionIdentifier)
        config.isDiscretionary = false
        config.sessionSendsLaunchEvents = true
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()
    
    override init() { }
    
    public func getSimulationFilesInExports() -> (rfdFiles: [(name: String, path: String)], uvdFiles: [(name: String, path: String)], eventFiles: [(name: String, path: String)]) {
        return JupiterFileManager.shared.getSimulationFilesInExports()
    }
    
    func requestS3FileURL(fileName: String, completion: @escaping (S3Output?) -> Void) {
        let successRange = 200..<300
        let input = S3Input(file_name: fileName, content_type: "application/json")
        JupiterNetworkManager.shared.postS3(url: JupiterNetworkConstants.getRecS3URL(), input: input, completion: { [self] statusCode, returnedString, s3Input in
            if successRange.contains(statusCode) {
                guard let s3Output = decodeS3Output(from: returnedString) else {
                    completion(nil)
                    return
                }
                completion(s3Output)
            } else {
                JupiterLogger.e(tag: "JupiterFileUploader", message: "\(statusCode) fail")
                completion(nil)
            }
        })
    }
    
    func uploadFileToS3(s3Path: String, filePath: String, completion: ((Bool) -> Void)? = nil) {
        guard let uploadURL = URL(string: s3Path) else {
            JupiterLogger.e(tag: "JupiterFileUploader", message: "uploadFileToS3 : invalid s3Path = \(s3Path)")
            completion?(false)
            return
        }
        
        let fileURL = URL(fileURLWithPath: filePath)
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            JupiterLogger.e(tag: "JupiterFileUploader", message: "uploadFileToS3 : file does not exist at \(fileURL.path)")
            completion?(false)
            return
        }
        
        let fileAttributes: [FileAttributeKey: Any]
        do {
            fileAttributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
        } catch {
            JupiterLogger.e(tag: "JupiterFileUploader", message: "uploadFileToS3 : failed to read file attributes \(error)")
            completion?(false)
            return
        }
        
        let fileSize = (fileAttributes[.size] as? NSNumber)?.int64Value ?? 0
        
        var request = URLRequest(url: uploadURL)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("\(fileSize)", forHTTPHeaderField: "Content-Length")
        
        let task = backgroundSession.uploadTask(with: request, fromFile: fileURL)
        if let completion = completion {
            completionHandlers[task.taskIdentifier] = completion
        }
        JupiterLogger.i(tag: "JupiterFileUploader", message: "uploadFileToS3 : background upload started for \(fileURL.lastPathComponent)")
        task.resume()
    }
    
    // MARK: - Decoding
    private func decodeS3Output(from jsonString: String) -> S3Output? {
        guard let data = jsonString.data(using: .utf8) else {
            JupiterLogger.e(tag: "JupiterFileUploader", message: "utf8 → data fail")
            return nil
        }

        let decoder = JSONDecoder()
        do {
            let result = try decoder.decode(S3Output.self, from: data)
            return result
        } catch {
            JupiterLogger.e(tag: "JupiterFileUploader", message: "decode S3Output fail: \(error)")
            return nil
        }
    }

    // MARK: - URLSessionTaskDelegate
    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        let completion = completionHandlers[task.taskIdentifier]
        completionHandlers.removeValue(forKey: task.taskIdentifier)
        
        if let error = error {
            JupiterLogger.e(tag: "JupiterFileUploader", message: "uploadFileToS3 : failed with error \(error)")
            completion?(false)
            return
        }
        
        if let httpResponse = task.response as? HTTPURLResponse,
           (200..<300).contains(httpResponse.statusCode) {
            JupiterLogger.i(tag: "JupiterFileUploader", message: "uploadFileToS3 : success statusCode = \(httpResponse.statusCode)")
            completion?(true)
        } else {
            let status = (task.response as? HTTPURLResponse)?.statusCode ?? -1
            JupiterLogger.e(tag: "JupiterFileUploader", message: "uploadFileToS3 : failed statusCode = \(status)")
            completion?(false)
        }
    }

}
