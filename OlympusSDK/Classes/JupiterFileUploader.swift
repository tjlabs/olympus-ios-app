
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
    
    public func getReplayFilesInExports() -> (rfdFiles: [(name: String, path: String)], uvdFiles: [(name: String, path: String)], eventFiles: [(name: String, path: String)]) {
        return JupiterFileManager.shared.getReplayFilesInExports()
    }
    
    func requestStorageFileURL(sectorId: Int, fileName: String, completion: @escaping (StorageOutput?) -> Void) {
        let successRange = 200..<300
        let input = StorageInput(sector_id: sectorId, operating_system: "iOS", file_name: fileName)
        JupiterNetworkManager.shared.postStorage(url: JupiterNetworkConstants.getUserFileUploadURL(), input: input, completion: { [self] statusCode, returnedString, storageInput in
            if successRange.contains(statusCode) {
                guard let StorageOutput = decodeStorageOutput(from: returnedString) else {
                    completion(nil)
                    return
                }
                completion(StorageOutput)
            } else {
                JupiterLogger.e(tag: "JupiterFileUploader", message: "(requestStorageFileURL) : \(statusCode), \(returnedString)")
                completion(nil)
            }
        })
    }
    
    func uploadFileToStorage(storagePath: String, filePath: String, completion: ((Bool) -> Void)? = nil) {
        guard let uploadURL = URL(string: storagePath) else {
            JupiterLogger.e(tag: "JupiterFileUploader", message: "uploadFileToStorage : invalid storagePath = \(storagePath)")
            completion?(false)
            return
        }
        
        let fileURL = URL(fileURLWithPath: filePath)
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            JupiterLogger.e(tag: "JupiterFileUploader", message: "uploadFileToStorage : file does not exist at \(fileURL.path)")
            completion?(false)
            return
        }
        
        let fileAttributes: [FileAttributeKey: Any]
        do {
            fileAttributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
        } catch {
            JupiterLogger.e(tag: "JupiterFileUploader", message: "uploadFileToStorage : failed to read file attributes \(error)")
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
        JupiterLogger.i(tag: "JupiterFileUploader", message: "uploadFileToStorage : background upload started for \(fileURL.lastPathComponent)")
        task.resume()
    }
    
    // MARK: - Decoding
    private func decodeStorageOutput(from jsonString: String) -> StorageOutput? {
        guard let data = jsonString.data(using: .utf8) else {
            JupiterLogger.e(tag: "JupiterFileUploader", message: "utf8 → data fail")
            return nil
        }

        let decoder = JSONDecoder()
        do {
            let result = try decoder.decode(StorageOutput.self, from: data)
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
