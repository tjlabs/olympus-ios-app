

public class OlympusNetworkManager {
    static let shared = OlympusNetworkManager()
    
    init() {
        let uvdConfig = URLSessionConfiguration.default
        uvdConfig.timeoutIntervalForResource = TIMEOUT_VALUE_PUT
        uvdConfig.timeoutIntervalForRequest = TIMEOUT_VALUE_PUT
//        self.uvdSession1 = URLSession(configuration: uvdConfig)
//        self.uvdSession2 = URLSession(configuration: uvdConfig)
//        self.uvdSessions.append(self.uvdSession1)
//        self.uvdSessions.append(self.uvdSession2)
        
        let fltConfig = URLSessionConfiguration.default
        fltConfig.timeoutIntervalForResource = TIMEOUT_VALUE_POST
        fltConfig.timeoutIntervalForRequest = TIMEOUT_VALUE_POST
//        self.fltSession = URLSession(configuration: fltConfig)
    }
    
    func postUserLogin(url: String, input: LoginInput, completion: @escaping (Int, String) -> Void) {
        // [http 비동기 방식을 사용해서 http 요청 수행 실시]
        let urlComponents = URLComponents(string: url)
        var requestURL = URLRequest(url: (urlComponents?.url)!)

        requestURL.httpMethod = "POST"
        let encodingData = JSONConverter.encodeJson(param: input)
        requestURL.httpBody = encodingData
        requestURL.addValue("application/json", forHTTPHeaderField: "Content-Type")
        requestURL.setValue("\(String(describing: encodingData))", forHTTPHeaderField: "Content-Length")
        
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForResource = TIMEOUT_VALUE_POST
        sessionConfig.timeoutIntervalForRequest = TIMEOUT_VALUE_POST
        let session = URLSession(configuration: sessionConfig)
        let dataTask = session.dataTask(with: requestURL, completionHandler: { (data, response, error) in
            
            // [error가 존재하면 종료]
            guard error == nil else {
                // [콜백 반환]
                completion(500, error?.localizedDescription ?? "Fail")
                return
            }
            
            let resultCode = (response as? HTTPURLResponse)?.statusCode ?? 500 // [상태 코드]
            // [status 코드 체크 실시]
            let successsRange = 200..<300
            guard let statusCode = (response as? HTTPURLResponse)?.statusCode, successsRange.contains(statusCode)
            else {
                // [콜백 반환]
                completion(resultCode, (response as? HTTPURLResponse)?.description ?? "Fail")
                return
            }
            
            // [response 데이터 획득]
            let resultLen = data! // [데이터 길이]
            let resultData = String(data: resultLen, encoding: .utf8) ?? "" // [데이터 확인]
            
            // [콜백 반환]
            DispatchQueue.main.async {
                completion(resultCode, resultData)
            }
        })
        
        // [network 통신 실행]
        dataTask.resume()
    }
    
    func postUserSector(url: String, input: SectorInput, completion: @escaping (Int, String) -> Void) {
        // [http 비동기 방식을 사용해서 http 요청 수행 실시]
        let urlComponents = URLComponents(string: url)
        var requestURL = URLRequest(url: (urlComponents?.url)!)

        requestURL.httpMethod = "POST"
        let encodingData = JSONConverter.encodeJson(param: input)
        requestURL.httpBody = encodingData
        requestURL.addValue("application/json", forHTTPHeaderField: "Content-Type")
        requestURL.setValue("\(String(describing: encodingData))", forHTTPHeaderField: "Content-Length")
        
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForResource = TIMEOUT_VALUE_POST
        sessionConfig.timeoutIntervalForRequest = TIMEOUT_VALUE_POST
        let session = URLSession(configuration: sessionConfig)
        let dataTask = session.dataTask(with: requestURL, completionHandler: { (data, response, error) in
            
            // [error가 존재하면 종료]
            guard error == nil else {
                // [콜백 반환]
                completion(500, error?.localizedDescription ?? "Fail")
                return
            }
            
            let resultCode = (response as? HTTPURLResponse)?.statusCode ?? 500 // [상태 코드]
            // [status 코드 체크 실시]
            let successsRange = 200..<300
            guard let statusCode = (response as? HTTPURLResponse)?.statusCode, successsRange.contains(statusCode)
            else {
                // [콜백 반환]
                completion(resultCode, (response as? HTTPURLResponse)?.description ?? "Fail")
                return
            }
            
            // [response 데이터 획득]
            let resultLen = data! // [데이터 길이]
            let resultData = String(data: resultLen, encoding: .utf8) ?? "" // [데이터 확인]
            
            // [콜백 반환]
            DispatchQueue.main.async {
                completion(resultCode, resultData)
            }
        })
        
        // [network 통신 실행]
        dataTask.resume()
    }
    
    func getUserRssCompensation(url: String, input: Any, isDeviceOs: Bool, completion: @escaping (Int, String) -> Void) {
        // [http 비동기 방식을 사용해서 http 요청 수행 실시]
        var urlComponents = URLComponents(string: url)
        if (isDeviceOs) {
            let rcDeviceOs: RcInputDeviceOs = input as! RcInputDeviceOs
            urlComponents?.queryItems = [URLQueryItem(name: "device_model", value: rcDeviceOs.device_model),
                                         URLQueryItem(name: "os_version", value: String(rcDeviceOs.os_version)),
                                         URLQueryItem(name: "sector_id", value: String(rcDeviceOs.sector_id))]
        } else {
            let rcDevice: RcInputDevice = input as! RcInputDevice
            urlComponents?.queryItems = [URLQueryItem(name: "device_model", value: rcDevice.device_model),
                                         URLQueryItem(name: "sector_id", value: String(rcDevice.sector_id))]
        }
        
        print(urlComponents)
        var requestURL = URLRequest(url: (urlComponents?.url)!)
        requestURL.httpMethod = "GET"
        
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForResource = TIMEOUT_VALUE_POST
        sessionConfig.timeoutIntervalForRequest = TIMEOUT_VALUE_POST
        let session = URLSession(configuration: sessionConfig)
        let dataTask = session.dataTask(with: requestURL, completionHandler: { (data, response, error) in
            
            // [error가 존재하면 종료]
            guard error == nil else {
                // [콜백 반환]
                completion(500, error?.localizedDescription ?? "Fail")
                return
            }
            
            let resultCode = (response as? HTTPURLResponse)?.statusCode ?? 500 // [상태 코드]
            let successsRange = 200..<300
            guard let statusCode = (response as? HTTPURLResponse)?.statusCode, successsRange.contains(statusCode)
            else {
                // [콜백 반환]
                completion(resultCode, (response as? HTTPURLResponse)?.description ?? "Fail")
                return
            }
            
            let resultLen = data! // [데이터 길이]
            let resultData = String(data: resultLen, encoding: .utf8) ?? "" // [데이터 확인]
            
            // [콜백 반환]
            DispatchQueue.main.async {
                completion(resultCode, resultData)
            }
        })
        
        // [network 통신 실행]
        dataTask.resume()
    }
}
