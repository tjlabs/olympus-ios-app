public func jsonToSectorInfoFromServer(jsonString: String) -> (Bool, SectorInfoFromServer) {
    let result = SectorInfoFromServer(parameter: SectorInfoParam(trajectory_length: 0, trajectory_diagonal: 0, debug: false, standard_rss: []),
                                      level_list: [])
    
    if let jsonData = jsonString.data(using: .utf8) {
        do {
            let decodedData: SectorInfoFromServer = try JSONDecoder().decode(SectorInfoFromServer.self, from: jsonData)
            return (true, decodedData)
        } catch {
            print("Error decoding JSON: \(error)")
            return (false, result)
        }
    } else {
        return (false, result)
    }
}

public func jsonToRcInfoFromServer(jsonString: String) -> (Bool, RcInfoFromServer) {
    let result = RcInfoFromServer(rss_compensations: [])
    
    if let jsonData = jsonString.data(using: .utf8) {
        do {
            let decodedData: RcInfoFromServer = try JSONDecoder().decode(RcInfoFromServer.self, from: jsonData)
            return (true, decodedData)
        } catch {
            print("Error decoding JSON: \(error)")
            return (false, result)
        }
    } else {
        return (false, result)
    }
}

public func jsonToFineLocatoinTrackingResultFromServer(jsonString: String) -> (Bool, FineLocationTrackingFromServer) {
    let result = FineLocationTrackingFromServer.init()
    
    if let jsonData = jsonString.data(using: .utf8) {
        do {
            let decodedData: FineLocationTrackingFromServer = try JSONDecoder().decode(FineLocationTrackingFromServer.self, from: jsonData)
            
            return (true, decodedData)
        } catch {
            print("Error decoding JSON: \(error)")
            
            return (false, result)
        }
    } else {
        return (false, result)
    }
    
}

public func jsonToFineLocatoinTrackingResultFromServerList(jsonString: String) -> (Bool, FineLocationTrackingFromServerList) {
    let result = FineLocationTrackingFromServerList(flt_outputs: [])
    
    if let jsonData = jsonString.data(using: .utf8) {
        do {
            let decodedData: FineLocationTrackingFromServerList = try JSONDecoder().decode(FineLocationTrackingFromServerList.self, from: jsonData)
            
            return (true, decodedData)
        } catch {
            print("Error decoding JSON: \(error)")
            
            return (false, result)
        }
    } else {
        return (false, result)
    }
}

public func jsonToOnSpotRecognitionResult(jsonString: String) -> (Bool, OnSpotRecognitionResult) {
    let result = OnSpotRecognitionResult.init()
    
    if let jsonData = jsonString.data(using: .utf8) {
        do {
            let decodedData: OnSpotRecognitionResult = try JSONDecoder().decode(OnSpotRecognitionResult.self, from: jsonData)
            
            return (true, decodedData)
        } catch {
            print("Error decoding JSON: \(error)")
            
            return (false, result)
        }
    } else {
        return (false, result)
    }
    
}

public func jsonToBlackListDevices(from jsonString: String) -> BlackListDevices? {
    let jsonData = jsonString.data(using: .utf8)!
    
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    
    do {
        let blackListDevices = try decoder.decode(BlackListDevices.self, from: jsonData)
        return blackListDevices
    } catch {
        print("Error decoding JSON: \(error)")
        return nil
    }
}
