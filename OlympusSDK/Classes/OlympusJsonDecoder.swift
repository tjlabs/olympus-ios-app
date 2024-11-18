import Foundation

public func jsonToLevelFromServer(jsonString: String) -> (Bool, OutputLevel) {
    let result = OutputLevel(level_list: [])
    
    if let jsonData = jsonString.data(using: .utf8) {
        do {
            let decodedData: OutputLevel = try JSONDecoder().decode(OutputLevel.self, from: jsonData)
            return (true, decodedData)
        } catch {
            print("Error decoding JSON: \(error)")
            return (false, result)
        }
    } else {
        return (false, result)
    }
}

public func jsonToUnitFromServer(jsonString: String) -> (Bool, OutputUnit) {
    let result = OutputUnit(unit_list: [])
    
    if let jsonData = jsonString.data(using: .utf8) {
        do {
            let decodedData: OutputUnit = try JSONDecoder().decode(OutputUnit.self, from: jsonData)
            return (true, decodedData)
        } catch {
            print("Error decoding JSON: \(error)")
            return (false, result)
        }
    } else {
        return (false, result)
    }
}

public func jsonToParamFromServer(jsonString: String) -> (Bool, OutputParameter) {
    let result = OutputParameter(trajectory_length: 0, trajectory_diagonal: 0, debug: false, standard_rss: [])
    
    if let jsonData = jsonString.data(using: .utf8) {
        do {
            let decodedData: OutputParameter = try JSONDecoder().decode(OutputParameter.self, from: jsonData)
            return (true, decodedData)
        } catch {
            print("Error decoding JSON: \(error)")
            return (false, result)
        }
    } else {
        return (false, result)
    }
}

public func jsonToPathFromServer(jsonString: String) -> (Bool, OutputPathPixel) {
    let result = OutputPathPixel(path_pixel_list: [])
    
    if let jsonData = jsonString.data(using: .utf8) {
        do {
            let decodedData: OutputPathPixel = try JSONDecoder().decode(OutputPathPixel.self, from: jsonData)
            return (true, decodedData)
        } catch {
            print("Error decoding JSON: \(error)")
            return (false, result)
        }
    } else {
        return (false, result)
    }
}

public func jsonToGeofenceFromServer(jsonString: String) -> (Bool, OutputGeofence) {
    let result = OutputGeofence(geofence_list: [])
    
    if let jsonData = jsonString.data(using: .utf8) {
        do {
            let decodedData: OutputGeofence = try JSONDecoder().decode(OutputGeofence.self, from: jsonData)
            return (true, decodedData)
        } catch {
            print("Error decoding JSON: \(error)")
            return (false, result)
        }
    } else {
        return (false, result)
    }
}

public func jsonToEntranceFromServer(jsonString: String) -> (Bool, OutputEntrance) {
    let result = OutputEntrance(entrance_list: [])
    
    if let jsonData = jsonString.data(using: .utf8) {
        do {
            let decodedData: OutputEntrance = try JSONDecoder().decode(OutputEntrance.self, from: jsonData)
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

public func jsonToScaleFromServer(jsonString: String) -> (Bool, ScaleFromServer) {
    let result = ScaleFromServer(scale_list: [])
    
    if let jsonData = jsonString.data(using: .utf8) {
        do {
            let decodedData: ScaleFromServer = try JSONDecoder().decode(ScaleFromServer.self, from: jsonData)
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
