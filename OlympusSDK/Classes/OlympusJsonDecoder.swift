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

