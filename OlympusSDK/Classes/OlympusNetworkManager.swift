import Foundation

public class OlympusNetworkManager {
    static let shared = OlympusNetworkManager()
    
    let rfdSession1: URLSession
    let rfdSession2: URLSession
    let rfdSession3: URLSession
    var rfdSessionCount: Int = 0
    
    let uvdSession1: URLSession
    let uvdSession2: URLSession
    let uvdSession3: URLSession
    var uvdSessionCount: Int = 0
    
    let umSession1: URLSession
    let umSession2: URLSession
    let umSession3: URLSession
    var umSessionCount: Int = 0
    
    let mrSession1: URLSession
    let mrSession2: URLSession
    let mrSession3: URLSession
    var mrSessionCount: Int = 0
    
    var rfdSessions = [URLSession]()
    var uvdSessions = [URLSession]()
    var umSessions  = [URLSession]()
    var mrSessions  = [URLSession]()
    var fltSessions = [URLSession]()
    
    let fltSession1: URLSession
    let fltSession2: URLSession
    var fltSessionCount: Int = 0
    
    let osrSession: URLSession
    let reportSession: URLSession
    
    init() {
        let rfdConfig = URLSessionConfiguration.default
        rfdConfig.timeoutIntervalForResource = TIMEOUT_VALUE_POST
        rfdConfig.timeoutIntervalForRequest = TIMEOUT_VALUE_POST
        self.rfdSession1 = URLSession(configuration: rfdConfig)
        self.rfdSession2 = URLSession(configuration: rfdConfig)
        self.rfdSession3 = URLSession(configuration: rfdConfig)
        self.rfdSessions.append(self.rfdSession1)
        self.rfdSessions.append(self.rfdSession2)
        self.rfdSessions.append(self.rfdSession3)
        
        let uvdConfig = URLSessionConfiguration.default
        uvdConfig.timeoutIntervalForResource = TIMEOUT_VALUE_POST
        uvdConfig.timeoutIntervalForRequest = TIMEOUT_VALUE_POST
        self.uvdSession1 = URLSession(configuration: uvdConfig)
        self.uvdSession2 = URLSession(configuration: uvdConfig)
        self.uvdSession3 = URLSession(configuration: uvdConfig)
        self.uvdSessions.append(self.uvdSession1)
        self.uvdSessions.append(self.uvdSession2)
        self.uvdSessions.append(self.uvdSession3)
        
        let umConfig = URLSessionConfiguration.default
        umConfig.timeoutIntervalForResource = TIMEOUT_VALUE_POST
        umConfig.timeoutIntervalForRequest = TIMEOUT_VALUE_POST
        self.umSession1 = URLSession(configuration: umConfig)
        self.umSession2 = URLSession(configuration: umConfig)
        self.umSession3 = URLSession(configuration: umConfig)
        self.umSessions.append(self.umSession1)
        self.umSessions.append(self.umSession2)
        self.umSessions.append(self.umSession3)
        
        let mrConfig = URLSessionConfiguration.default
        mrConfig.timeoutIntervalForResource = TIMEOUT_VALUE_POST
        mrConfig.timeoutIntervalForRequest = TIMEOUT_VALUE_POST
        self.mrSession1 = URLSession(configuration: mrConfig)
        self.mrSession2 = URLSession(configuration: mrConfig)
        self.mrSession3 = URLSession(configuration: mrConfig)
        self.mrSessions.append(self.mrSession1)
        self.mrSessions.append(self.mrSession2)
        self.mrSessions.append(self.mrSession3)
        
//        let fltConfig = URLSessionConfiguration.default
//        fltConfig.timeoutIntervalForResource = TIMEOUT_VALUE_POST
//        fltConfig.timeoutIntervalForRequest = TIMEOUT_VALUE_POST
//        self.fltSession = URLSession(configuration: fltConfig)
        
        let fltConfig = URLSessionConfiguration.default
        fltConfig.timeoutIntervalForResource = TIMEOUT_VALUE_POST
        fltConfig.timeoutIntervalForRequest = TIMEOUT_VALUE_POST
        self.fltSession1 = URLSession(configuration: mrConfig)
        self.fltSession2 = URLSession(configuration: mrConfig)
        self.fltSessions.append(self.fltSession1)
        self.fltSessions.append(self.fltSession2)
        
        let osrConfig = URLSessionConfiguration.default
        osrConfig.timeoutIntervalForResource = TIMEOUT_VALUE_POST
        osrConfig.timeoutIntervalForRequest = TIMEOUT_VALUE_POST
        self.osrSession = URLSession(configuration: osrConfig)
        
        let reportConfig = URLSessionConfiguration.default
        reportConfig.timeoutIntervalForResource = TIMEOUT_VALUE_POST
        reportConfig.timeoutIntervalForRequest = TIMEOUT_VALUE_POST
        self.reportSession = URLSession(configuration: reportConfig)
    }
    
    func initailze() {
        self.rfdSessionCount = 0
        self.uvdSessionCount = 0
        self.umSessionCount = 0
        self.mrSessionCount = 0
        
        self.rfdSessions = [URLSession]()
        self.uvdSessions = [URLSession]()
        self.umSessions  = [URLSession]()
        self.mrSessions  = [URLSession]()
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
    
    func postSectorID(url: String, input: InputSectorID, completion: @escaping (Int, String) -> Void) {
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
        
//        print("")
//        print("====================================")
//        print("POST SECTOR ID URL :: ", url)
//        print("POST SECTOR ID 데이터 :: ", input)
//        print("====================================")
//        print("")
        
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
    
    func postSectorIDnOS(url: String, input: InputSectorIDnOS, completion: @escaping (Int, String) -> Void) {
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
        
//        print("")
//        print("====================================")
//        print("POST SECTOR ID & OS URL :: ", url)
//        print("POST SECTOR ID & OS 데이터 :: ", input)
//        print("====================================")
//        print("")
        
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
    
    func postUserScale(url: String, input: ScaleInput, completion: @escaping (Int, String) -> Void) {
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
        
//        print("")
//        print("====================================")
//        print("POST USER SCALE URL :: ", url)
//        print("POST USER SCALE 데이터 :: ", input)
//        print("====================================")
//        print("")
        
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

            let rfdSession = self.rfdSessions[self.rfdSessionCount%3]
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
    //        print("POST UV 데이터 :: ", input)
    //        print("====================================")
    //        print("")
            
            let uvdSession = self.uvdSessions[self.uvdSessionCount%3]
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
    
    func postUserMask(url: String, input: [UserMask], completion: @escaping (Int, String, [UserMask]) -> Void) {
        // [http 비동기 방식을 사용해서 http 요청 수행 실시]
        let urlComponents = URLComponents(string: url)
        var requestURL = URLRequest(url: (urlComponents?.url)!)
        let inputUserMask = input

        requestURL.httpMethod = "POST"
        let encodingData = JSONConverter.encodeJson(param: input)
        if (encodingData != nil) {
            requestURL.httpBody = encodingData
            requestURL.addValue("application/json", forHTTPHeaderField: "Content-Type")
            requestURL.setValue("\(encodingData)", forHTTPHeaderField: "Content-Length")
            
            // [http 요청 수행 실시]
//            print("")
//            print("====================================")
//            print("POST User Mask URL :: ", url)
//            print("POST User Mask 데이터 :: ", input)
//            print("====================================")
//            print("")
            
            let umSession = self.umSessions[self.umSessionCount%3]
            self.umSessionCount+=1
            
            let dataTask = umSession.dataTask(with: requestURL, completionHandler: { (data, response, error) in
                let code = (response as? HTTPURLResponse)?.statusCode ?? 400
                guard error == nil else {
                    if let timeoutError = error as? URLError, timeoutError.code == .timedOut {
                        DispatchQueue.main.async {
                            completion(timeoutError.code.rawValue, error?.localizedDescription ?? "timed out", inputUserMask)
                        }
                    } else {
                        DispatchQueue.main.async {
                            completion(code, error?.localizedDescription ?? "Fail to send sensor measurements", inputUserMask)
                        }
                    }
                    return
                }

                let successsRange = 200..<300
                guard let statusCode = (response as? HTTPURLResponse)?.statusCode, successsRange.contains(statusCode)
                else {
                    DispatchQueue.main.async {
                        completion(code, (response as? HTTPURLResponse)?.description ?? "Fail to send sensor measurements", inputUserMask)
                    }
                    return
                }

                let resultCode = (response as? HTTPURLResponse)?.statusCode ?? 500 // [상태 코드]
                guard let resultLen = data else {
                    DispatchQueue.main.async {
                        completion(code, (response as? HTTPURLResponse)?.description ?? "Fail to send sensor measurements", inputUserMask)
                    }
                    return
                }

                DispatchQueue.main.async {
                    completion(resultCode, String(input[input.count-1].index), inputUserMask)
                }
            })
            dataTask.resume()
        } else {
            DispatchQueue.main.async {
                completion(406, "Fail to encode UserMask", inputUserMask)
            }
        }
    }
    
    func postFLT(url: String, input: FineLocationTracking, userTraj: [TrajectoryInfo], searchInfo: SearchInfo, completion: @escaping (Int, String, FineLocationTracking, [TrajectoryInfo], SearchInfo) -> Void) {
        // [http 비동기 방식을 사용해서 http 요청 수행 실시]
        let urlComponents = URLComponents(string: url)
        var requestURL = URLRequest(url: (urlComponents?.url)!)
        let fltInput = input
        let inputTraj: [TrajectoryInfo] = userTraj
        let inputSearchInfo: SearchInfo = searchInfo
        
        requestURL.httpMethod = "POST"
        let encodingData = JSONConverter.encodeJson(param: input)
        if (encodingData != nil) {
//            print("")
//            print("====================================")
//            print("POST FLT Phase 3 :: ", url)
//            print("POST FLT Phase 3 :: ", input)
//            print("====================================")
//            print("")
            
            requestURL.httpBody = encodingData
            requestURL.addValue("application/json", forHTTPHeaderField: "Content-Type")
            requestURL.setValue("\(encodingData)", forHTTPHeaderField: "Content-Length")
            
            let fltSession = self.fltSessions[self.rfdSessionCount%2]
            self.rfdSessionCount+=1
            
            let dataTask = fltSession.dataTask(with: requestURL, completionHandler: { (data, response, error) in
                // [error가 존재하면 종료]
                guard error == nil else {
                    // [콜백 반환]
                    DispatchQueue.main.async {
                        completion(500, error?.localizedDescription ?? "Fail", fltInput, inputTraj, inputSearchInfo)
                    }
                    return
                }

                // [status 코드 체크 실시]
                let successsRange = 200..<300
                guard let statusCode = (response as? HTTPURLResponse)?.statusCode, successsRange.contains(statusCode)
                else {
                    // [콜백 반환]
                    DispatchQueue.main.async {
                        completion(500, (response as? HTTPURLResponse)?.description ?? "Fail", fltInput, inputTraj, inputSearchInfo)
                    }
                    return
                }

                // [response 데이터 획득]
                let resultCode = (response as? HTTPURLResponse)?.statusCode ?? 500 // [상태 코드]
                guard let resultLen = data else {
                    completion(resultCode, (response as? HTTPURLResponse)?.description ?? "Fail", fltInput, inputTraj, inputSearchInfo)
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
                    completion(resultCode, resultData, fltInput, inputTraj, inputSearchInfo)
                }
            })

            // [network 통신 실행]
            dataTask.resume()
        } else {
            completion(500, "Fail to encode", fltInput, inputTraj, inputSearchInfo)
        }
    }
    
    func postStableFLT(url: String, input: FineLocationTracking, userTraj: [TrajectoryInfo], nodeCandidateInfo: NodeCandidateInfo, completion: @escaping (Int, String, FineLocationTracking, [TrajectoryInfo], NodeCandidateInfo) -> Void) {
        // [http 비동기 방식을 사용해서 http 요청 수행 실시]
        let urlComponents = URLComponents(string: url)
        var requestURL = URLRequest(url: (urlComponents?.url)!)
        let fltInput = input
        let inputTraj: [TrajectoryInfo] = userTraj
        let inputNodeCandidateInfo: NodeCandidateInfo = nodeCandidateInfo
        
        requestURL.httpMethod = "POST"
        let encodingData = JSONConverter.encodeJson(param: input)
        if (encodingData != nil) {
            requestURL.httpBody = encodingData
            requestURL.addValue("application/json", forHTTPHeaderField: "Content-Type")
            requestURL.setValue("\(encodingData)", forHTTPHeaderField: "Content-Length")
            
            let fltSession = self.fltSessions[self.rfdSessionCount%2]
            self.rfdSessionCount+=1
            let dataTask = fltSession.dataTask(with: requestURL, completionHandler: { (data, response, error) in
                // [error가 존재하면 종료]
                guard error == nil else {
                    // [콜백 반환]
                    DispatchQueue.main.async {
                        completion(500, error?.localizedDescription ?? "Fail", fltInput, inputTraj, inputNodeCandidateInfo)
                    }
                    return
                }

                // [status 코드 체크 실시]
                let successsRange = 200..<300
                guard let statusCode = (response as? HTTPURLResponse)?.statusCode, successsRange.contains(statusCode)
                else {
                    // [콜백 반환]
                    DispatchQueue.main.async {
                        completion(500, (response as? HTTPURLResponse)?.description ?? "Fail", fltInput, inputTraj, inputNodeCandidateInfo)
                    }
                    return
                }

                // [response 데이터 획득]
                let resultCode = (response as? HTTPURLResponse)?.statusCode ?? 500 // [상태 코드]
                guard let resultLen = data else {
                    completion(resultCode, (response as? HTTPURLResponse)?.description ?? "Fail", fltInput, inputTraj, inputNodeCandidateInfo)
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
                    completion(resultCode, resultData, fltInput, inputTraj, inputNodeCandidateInfo)
                }
            })

            // [network 통신 실행]
            dataTask.resume()
        } else {
            completion(500, "Fail to encode", fltInput, inputTraj, inputNodeCandidateInfo)
        }
    }
    
    func postRecoveryFLT(url: String, input: FineLocationTracking, userTraj: [TrajectoryInfo], nodeCandidateInfo: NodeCandidateInfo, preFltResult: FineLocationTrackingFromServer, completion: @escaping (Int, String, FineLocationTracking, [TrajectoryInfo], NodeCandidateInfo, FineLocationTrackingFromServer) -> Void) {
        // [http 비동기 방식을 사용해서 http 요청 수행 실시]
        let urlComponents = URLComponents(string: url)
        var requestURL = URLRequest(url: (urlComponents?.url)!)
        let fltInput = input
        let inputTraj: [TrajectoryInfo] = userTraj
        let inputNodeCandidateInfo: NodeCandidateInfo = nodeCandidateInfo
        
        requestURL.httpMethod = "POST"
        let encodingData = JSONConverter.encodeJson(param: input)
        if (encodingData != nil) {
            requestURL.httpBody = encodingData
            requestURL.addValue("application/json", forHTTPHeaderField: "Content-Type")
            requestURL.setValue("\(encodingData)", forHTTPHeaderField: "Content-Length")
            
//            print("")
//            print("====================================")
//            print("POST FLT Phase 3 :: ", url)
//            print("POST FLT Phase 3 :: ", input)
//            print("====================================")
//            print("")
            
            let fltSession = self.fltSessions[self.rfdSessionCount%2]
            self.rfdSessionCount+=1
            let dataTask = fltSession.dataTask(with: requestURL, completionHandler: { (data, response, error) in
                // [error가 존재하면 종료]
                guard error == nil else {
                    // [콜백 반환]
                    DispatchQueue.main.async {
                        completion(500, error?.localizedDescription ?? "Fail", fltInput, inputTraj, inputNodeCandidateInfo, preFltResult)
                    }
                    return
                }

                // [status 코드 체크 실시]
                let successsRange = 200..<300
                guard let statusCode = (response as? HTTPURLResponse)?.statusCode, successsRange.contains(statusCode)
                else {
                    // [콜백 반환]
                    DispatchQueue.main.async {
                        completion(500, (response as? HTTPURLResponse)?.description ?? "Fail", fltInput, inputTraj, inputNodeCandidateInfo, preFltResult)
                    }
                    return
                }

                // [response 데이터 획득]
                let resultCode = (response as? HTTPURLResponse)?.statusCode ?? 500 // [상태 코드]
                guard let resultLen = data else {
                    completion(resultCode, (response as? HTTPURLResponse)?.description ?? "Fail", fltInput, inputTraj, inputNodeCandidateInfo, preFltResult)
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
                    completion(resultCode, resultData, fltInput, inputTraj, inputNodeCandidateInfo, preFltResult)
                }
            })

            // [network 통신 실행]
            dataTask.resume()
        } else {
            completion(500, "Fail to encode", fltInput, inputTraj, inputNodeCandidateInfo, preFltResult)
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
    
    func postMobileResult(url: String, input: [MobileResult], completion: @escaping (Int, String) -> Void) {
        // [http 비동기 방식을 사용해서 http 요청 수행 실시]
        let urlComponents = URLComponents(string: url)
        var requestURL = URLRequest(url: (urlComponents?.url)!)
        
        requestURL.httpMethod = "POST"
        let encodingData = JSONConverter.encodeJson(param: input)
        if (encodingData != nil) {
            requestURL.httpBody = encodingData
            requestURL.addValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
            
//            print("")
//            print("====================================")
//            print("POST Mobile Result URL :: ", url)
//            print("POST Mobile Result 데이터 :: ", input)
//            print("====================================")
//            print("")
            
            let mrSession = self.mrSessions[self.mrSessionCount%3]
            self.mrSessionCount+=1
            let dataTask = mrSession.dataTask(with: requestURL, completionHandler: { (data, response, error) in
                
                // [error가 존재하면 종료]
                guard error == nil else {
                    if let timeoutError = error as? URLError, timeoutError.code == .timedOut {
                        DispatchQueue.main.async {
                            completion(timeoutError.code.rawValue, error?.localizedDescription ?? "timed out")
                        }
                    } else {
                        DispatchQueue.main.async {
                            completion(500, error?.localizedDescription ?? "Fail")
                        }
                    }
                    return
                }
                
                // [status 코드 체크 실시]
                let successsRange = 200..<300
                guard let statusCode = (response as? HTTPURLResponse)?.statusCode, successsRange.contains(statusCode)
                else {
                    DispatchQueue.main.async {
                        completion(500, (response as? HTTPURLResponse)?.description ?? "Fail")
                    }
                    return
                }
                
                // [response 데이터 획득]
                let resultCode = (response as? HTTPURLResponse)?.statusCode ?? 500 // [상태 코드]
                guard let resultLen = data else {
                    DispatchQueue.main.async {
                        completion(500, (response as? HTTPURLResponse)?.description ?? "Fail")
                    }
                    return
                }
                let resultData = String(data: resultLen, encoding: .utf8) ?? "" // [데이터 확인]
                
                // [콜백 반환]
                DispatchQueue.main.async {
                    completion(resultCode, resultData)
                }
            })
            
            // [network 통신 실행]
            dataTask.resume()
        } else {
            DispatchQueue.main.async {
                completion(500, "Fail to encode")
            }
        }
    }
    
    func postMobileReport(url: String, input: MobileReport, completion: @escaping (Int, String) -> Void) {
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
//            print("POST Mobile Report URL :: ", url)
//            print("POST Mobile Report 데이터 :: ", input)
//            print("====================================")
//            print("")
            
            let dataTask = self.reportSession.dataTask(with: requestURL, completionHandler: { (data, response, error) in
                // [error가 존재하면 종료]
                guard error == nil else {
                    // [콜백 반환]
                    completion(500, error?.localizedDescription ?? "Fail")
                    return
                }
                
                // [status 코드 체크 실시]
                let successsRange = 200..<300
                guard let statusCode = (response as? HTTPURLResponse)?.statusCode, successsRange.contains(statusCode)
                else {
                    // [콜백 반환]
                    completion(500, (response as? HTTPURLResponse)?.description ?? "Fail")
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
//                    print("RESPONSE Mobile Report 데이터 :: ", resultCode)
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
    
    func getBlackList(url: String, completion: @escaping (Int, String) -> Void) {
        var urlComponents = URLComponents(string: url)
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
                completion(resultCode, resultData)
            }
        })
        
        // [network 통신 실행]
        dataTask.resume()
    }
    
    func postParam(url: String, input: RcInfoSave, completion: @escaping (Int, String) -> Void) {
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
//            print("POST Param URL :: ", url)
//            print("POST Param 데이터 :: ", input)
//            print("====================================")
//            print("")
            
            let dataTask = self.reportSession.dataTask(with: requestURL, completionHandler: { (data, response, error) in
                // [error가 존재하면 종료]
                guard error == nil else {
                    // [콜백 반환]
                    completion(500, error?.localizedDescription ?? "Fail")
                    return
                }
                
                // [status 코드 체크 실시]
                let successsRange = 200..<300
                guard let statusCode = (response as? HTTPURLResponse)?.statusCode, successsRange.contains(statusCode)
                else {
                    // [콜백 반환]
                    completion(500, (response as? HTTPURLResponse)?.description ?? "Fail")
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
//                    print("RESPONSE Param 데이터 :: ", resultCode)
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
