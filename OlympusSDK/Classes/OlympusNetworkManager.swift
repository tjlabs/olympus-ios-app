

public class OlympusNetworkManager {
    static let shared = OlympusNetworkManager()
    
    let rfdSession1: URLSession
    let rfdSession2: URLSession
    var rfdSessionCount: Int = 0
    
    let uvdSession1: URLSession
    let uvdSession2: URLSession
    var uvdSessionCount: Int = 0
    
    var rfdSessions = [URLSession]()
    var uvdSessions = [URLSession]()
    
    let fltSession: URLSession
    let osrSession: URLSession
    
    init() {
        let rfdConfig = URLSessionConfiguration.default
        rfdConfig.timeoutIntervalForResource = TIMEOUT_VALUE_PUT
        rfdConfig.timeoutIntervalForRequest = TIMEOUT_VALUE_PUT
        self.rfdSession1 = URLSession(configuration: rfdConfig)
        self.rfdSession2 = URLSession(configuration: rfdConfig)
        self.rfdSessions.append(self.rfdSession1)
        self.rfdSessions.append(self.rfdSession2)
        
        let uvdConfig = URLSessionConfiguration.default
        uvdConfig.timeoutIntervalForResource = TIMEOUT_VALUE_PUT
        uvdConfig.timeoutIntervalForRequest = TIMEOUT_VALUE_PUT
        self.uvdSession1 = URLSession(configuration: uvdConfig)
        self.uvdSession2 = URLSession(configuration: uvdConfig)
        self.uvdSessions.append(self.uvdSession1)
        self.uvdSessions.append(self.uvdSession2)
        
        let fltConfig = URLSessionConfiguration.default
        fltConfig.timeoutIntervalForResource = TIMEOUT_VALUE_POST
        fltConfig.timeoutIntervalForRequest = TIMEOUT_VALUE_POST
        self.fltSession = URLSession(configuration: fltConfig)
        
        let osrConfig = URLSessionConfiguration.default
        osrConfig.timeoutIntervalForResource = TIMEOUT_VALUE_POST
        osrConfig.timeoutIntervalForRequest = TIMEOUT_VALUE_POST
        self.osrSession = URLSession(configuration: osrConfig)
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
    
    func postReceivedForce(url: String, input: [ReceivedForce], completion: @escaping (Int, String, [ReceivedForce]) -> Void){
        // [http 비동기 방식을 사용해서 http 요청 수행 실시]
        let urlComponents = URLComponents(string: url)
        var requestURL = URLRequest(url: (urlComponents?.url)!)
        let inputRfd = input

        requestURL.httpMethod = "POST"
        let encodingData = JSONConverter.encodeJson(param: input)
        if (encodingData != nil) {
            requestURL.httpBody = encodingData
            requestURL.addValue("application/json", forHTTPHeaderField: "Content-Type")
            requestURL.setValue("\(encodingData)", forHTTPHeaderField: "Content-Length")
            
            // [http 요청 수행 실시]
//            print("")
//            print("====================================")
//            print("POST RF URL :: ", url)
//            print("POST RF 데이터 :: ", input)
//            print("====================================")
//            print("")

            let rfdSession = self.rfdSessions[self.rfdSessionCount%2]
            self.rfdSessionCount+=1
            let dataTask = rfdSession.dataTask(with: requestURL, completionHandler: { (data, response, error) in
                let code = (response as? HTTPURLResponse)?.statusCode ?? 500
                // [error가 존재하면 종료]
                guard error == nil else {
                    if let timeoutError = error as? URLError, timeoutError.code == .timedOut {
                        DispatchQueue.main.async {
                            completion(timeoutError.code.rawValue, error?.localizedDescription ?? "timed out", inputRfd)
                        }
                    } else {
                        DispatchQueue.main.async {
                            completion(code, error?.localizedDescription ?? "Fail to send bluetooth data", inputRfd)
                        }
                    }
                    return
                }

                // [status 코드 체크 실시]
                let successsRange = 200..<300
                guard let statusCode = (response as? HTTPURLResponse)?.statusCode, successsRange.contains(statusCode)
                else {
                    DispatchQueue.main.async {
                        completion(code, (response as? HTTPURLResponse)?.description ?? "Fail to send bluetooth data", inputRfd)
                    }
                    return
                }

                // [response 데이터 획득]
                let resultCode = (response as? HTTPURLResponse)?.statusCode ?? 500 // [상태 코드]
                guard let resultLen = data else {
                    DispatchQueue.main.async {
                        completion(code, (response as? HTTPURLResponse)?.description ?? "Fail to send bluetooth data", inputRfd)
                    }
                    return
                }

                // [콜백 반환]
                DispatchQueue.main.async {
//                    print("")
//                    print("====================================")
//                    print("RESPONSE RF 데이터 :: ", resultCode)
//                    print("====================================")
//                    print("")
                    completion(resultCode, "Fail to send bluetooth data", inputRfd)
                }
            })
            dataTask.resume()
        } else {
            DispatchQueue.main.async {
                completion(406, "Fail to encode RFD", inputRfd)
            }
        }
    }
    
    func postUserVelocity(url: String, input: [UserVelocity], completion: @escaping (Int, String, [UserVelocity]) -> Void) {
        // [http 비동기 방식을 사용해서 http 요청 수행 실시]
        let urlComponents = URLComponents(string: url)
        var requestURL = URLRequest(url: (urlComponents?.url)!)
        let inputUvd = input

        requestURL.httpMethod = "POST"
        let encodingData = JSONConverter.encodeJson(param: input)
        if (encodingData != nil) {
            requestURL.httpBody = encodingData
            requestURL.addValue("application/json", forHTTPHeaderField: "Content-Type")
            requestURL.setValue("\(encodingData)", forHTTPHeaderField: "Content-Length")
            
            // [http 요청 수행 실시]
    //        print("")
    //        print("====================================")
    //        print("PUT UV 데이터 :: ", input)
    //        print("====================================")
    //        print("")
            
            let uvdSession = self.uvdSessions[self.uvdSessionCount%2]
            self.uvdSessionCount+=1
            
            let dataTask = uvdSession.dataTask(with: requestURL, completionHandler: { (data, response, error) in
                let code = (response as? HTTPURLResponse)?.statusCode ?? 400
                guard error == nil else {
                    if let timeoutError = error as? URLError, timeoutError.code == .timedOut {
                        DispatchQueue.main.async {
                            completion(timeoutError.code.rawValue, error?.localizedDescription ?? "timed out", inputUvd)
                        }
                    } else {
                        DispatchQueue.main.async {
                            completion(code, error?.localizedDescription ?? "Fail to send sensor measurements", inputUvd)
                        }
                    }
                    return
                }

                let successsRange = 200..<300
                guard let statusCode = (response as? HTTPURLResponse)?.statusCode, successsRange.contains(statusCode)
                else {
                    DispatchQueue.main.async {
                        completion(code, (response as? HTTPURLResponse)?.description ?? "Fail to send sensor measurements", inputUvd)
                    }
                    return
                }

                let resultCode = (response as? HTTPURLResponse)?.statusCode ?? 500 // [상태 코드]
                guard let resultLen = data else {
                    DispatchQueue.main.async {
                        completion(code, (response as? HTTPURLResponse)?.description ?? "Fail to send sensor measurements", inputUvd)
                    }
                    return
                }

                DispatchQueue.main.async {
                    completion(resultCode, String(input[input.count-1].index), inputUvd)
                }
            })
            dataTask.resume()
        } else {
            DispatchQueue.main.async {
                completion(406, "Fail to encode UVD", inputUvd)
            }
        }
    }
    
    func postFLT(url: String, input: FineLocationTracking, userTraj: [TrajectoryInfo], searchInfo: SearchInfo, completion: @escaping (Int, String, Int, [TrajectoryInfo], SearchInfo) -> Void) {
        // [http 비동기 방식을 사용해서 http 요청 수행 실시]
        let urlComponents = URLComponents(string: url)
        var requestURL = URLRequest(url: (urlComponents?.url)!)
        let inputPhase: Int = input.phase
        let inputTraj: [TrajectoryInfo] = userTraj
        let inputSearchInfo: SearchInfo = searchInfo
        
        requestURL.httpMethod = "POST"
        let encodingData = JSONConverter.encodeJson(param: input)
        if (encodingData != nil) {
            requestURL.httpBody = encodingData
            requestURL.addValue("application/json", forHTTPHeaderField: "Content-Type")
            requestURL.setValue("\(encodingData)", forHTTPHeaderField: "Content-Length")
            
            print("")
            print("====================================")
            print("POST FLT URL :: ", url)
            print("POST FLT Sector :: ", input.sector_id)
            print("POST FLT ID :: ", input.user_id)
            print("POST FLT 데이터 :: ", input)
            print("====================================")
            print("")
            
            let dataTask = self.fltSession.dataTask(with: requestURL, completionHandler: { (data, response, error) in
                // [error가 존재하면 종료]
                guard error == nil else {
                    // [콜백 반환]
                    DispatchQueue.main.async {
                        completion(500, error?.localizedDescription ?? "Fail", inputPhase, inputTraj, inputSearchInfo)
                    }
                    return
                }

                // [status 코드 체크 실시]
                let successsRange = 200..<300
                guard let statusCode = (response as? HTTPURLResponse)?.statusCode, successsRange.contains(statusCode)
                else {
                    // [콜백 반환]
                    DispatchQueue.main.async {
                        completion(500, (response as? HTTPURLResponse)?.description ?? "Fail", inputPhase, inputTraj, inputSearchInfo)
                    }
                    return
                }

                // [response 데이터 획득]
                let resultCode = (response as? HTTPURLResponse)?.statusCode ?? 500 // [상태 코드]
                guard let resultLen = data else {
                    completion(resultCode, (response as? HTTPURLResponse)?.description ?? "Fail", inputPhase, inputTraj, inputSearchInfo)
                    return
                }
                let resultData = String(data: resultLen, encoding: .utf8) ?? "" // [데이터 확인]

                // [콜백 반환]
                DispatchQueue.main.async {
//                    print("")
//                    print("====================================")
//                    print("RESPONSE FLT 데이터 :: ", resultData)
//                    print("====================================")
//                    print("")
                    completion(resultCode, resultData, inputPhase, inputTraj, inputSearchInfo)
                }
            })

            // [network 통신 실행]
            dataTask.resume()
        } else {
            completion(500, "Fail to encode", inputPhase, inputTraj, inputSearchInfo)
        }
    }
    
    func postOSR(url: String, input: OnSpotRecognition, completion: @escaping (Int, String) -> Void) {
        // [http 비동기 방식을 사용해서 http 요청 수행 실시]
        let urlComponents = URLComponents(string: url)
        var requestURL = URLRequest(url: (urlComponents?.url)!)
        
        requestURL.httpMethod = "POST"
        let encodingData = JSONConverter.encodeJson(param: input)
        if (encodingData != nil) {
            requestURL.httpBody = encodingData
            requestURL.addValue("application/json", forHTTPHeaderField: "Content-Type")
            requestURL.setValue("\(encodingData)", forHTTPHeaderField: "Content-Length")
            
//            print("")
//            print("====================================")
//            print("POST OSR 데이터 :: ", input)
//            print("====================================")
//            print("")

            let dataTask = self.osrSession.dataTask(with: requestURL, completionHandler: { (data, response, error) in
                // [error가 존재하면 종료]
                guard error == nil else {
                    // [콜백 반환]
                    DispatchQueue.main.async {
                        completion(500, error?.localizedDescription ?? "Fail")
                    }
                    return
                }
                
                // [status 코드 체크 실시]
                let successsRange = 200..<300
                guard let statusCode = (response as? HTTPURLResponse)?.statusCode, successsRange.contains(statusCode)
                else {
                    // [콜백 반환]
                    DispatchQueue.main.async {
                        completion(500, (response as? HTTPURLResponse)?.description ?? "Fail")
                    }
                    return
                }
                
                // [response 데이터 획득]
                let resultCode = (response as? HTTPURLResponse)?.statusCode ?? 500 // [상태 코드]
                guard let resultLen = data else {
                    completion(500, (response as? HTTPURLResponse)?.description ?? "Fail")
                    return
                }
                let resultData = String(data: resultLen, encoding: .utf8) ?? "" // [데이터 확인]
                
                // [콜백 반환]
                DispatchQueue.main.async {
//                    print("")
//                    print("====================================")
//                    print("RESPONSE OSR 데이터 :: ", resultCode)
//                    print("                 :: ", resultData)
//                    print("====================================")
//                    print("")
                    completion(resultCode, resultData)
                }
            })
            
            // [network 통신 실행]
            dataTask.resume()
        } else {
            completion(500, "Fail to encode")
        }
    }
}
