import Foundation

public class OlympusAmbiguitySolver {
    public var isAmbiguous = false
    public var isAmbiguousInDRMode = false
    public var retryFltInput = FineLocationTracking(user_id: "", mobile_time: 0, sector_id: 0, operating_system: "", building_name: "", level_name_list: [], phase: 0, search_range: [], search_direction_list: [], normalization_scale: 0, device_min_rss: 0, sc_compensation_list: [], tail_index: -1, head_section_number: 0, node_number_list: [], node_index: 0, retry: false)

    public func initialize() {
        isAmbiguous = false
        isAmbiguousInDRMode = false
        retryFltInput = FineLocationTracking(user_id: "", mobile_time: 0, sector_id: 0, operating_system: "", building_name: "", level_name_list: [], phase: 0, search_range: [], search_direction_list: [], normalization_scale: 0, device_min_rss: 0, sc_compensation_list: [], tail_index: -1, head_section_number: 0, node_number_list: [], node_index: 0, retry: false)
    }

    public func setIsAmbiguous(value: Bool) {
        self.isAmbiguous = value
    }
    
    public func setIsAmbiguousInDRMode(value: Bool) {
        self.isAmbiguousInDRMode = value
    }
    
    public func setRetryInput(input: FineLocationTracking) {
        self.retryFltInput = input
    }
    
    public func getIsAmbiguous() -> Bool {
        return self.isAmbiguous
    }
    
    public func getRetryInput() -> FineLocationTracking {
        self.retryFltInput.mobile_time = getCurrentTimeInMilliseconds()
        return self.retryFltInput
    }
    
    public func selectResult(results: FineLocationTrackingFromServerList, nodeCandidatesInfo: NodeCandidateInfo) -> (Bool, FineLocationTrackingFromServer) {
        let fltOutputs = results.flt_outputs
        if fltOutputs.count == 1 {
            return (true, fltOutputs[0])
        } else if (fltOutputs.count > 1) {
            let sortedFltOutputs = fltOutputs.sorted(by: { $0.scc > $1.scc })
            let firstFltOutput = sortedFltOutputs[0]
            let secondFltOutput = sortedFltOutputs[1]

            if firstFltOutput.scc != 0 {
                let ratio = secondFltOutput.scc / firstFltOutput.scc
                if ratio < OlympusConstants.OUTPUT_AMBIGUITY_RATIO {
//                    print(getLocalTimeString() + " , (Olympus) selectResult (Clear) : index = \(firstFltOutput.index) // 1st = \(firstFltOutput.scc) // 2nd = \(secondFltOutput.scc) // ratio = \(ratio)")
                    return (true, firstFltOutput)
                } else {
                    if nodeCandidatesInfo.nodeCandidatesInfo.isEmpty {
//                        print(getLocalTimeString() + " , (Olympus) selectResult (Ambiguous) nodeCandidatesInfo Empty : index = \(firstFltOutput.index) // 1st = \(firstFltOutput.scc) // 2nd = \(secondFltOutput.scc) // ratio = \(ratio)")
                        return (false, FineLocationTrackingFromServer())
                    } else {
//                        print(getLocalTimeString() + " , (Olympus) selectResult (Ambiguous) : index = \(firstFltOutput.index) // 1st = \(firstFltOutput.scc) // 2nd = \(secondFltOutput.scc) // ratio = \(ratio)")
                        let inputNodeNumber = nodeCandidatesInfo.nodeCandidatesInfo[0].nodeNumber
                        for output in fltOutputs {
                            if inputNodeNumber == output.node_number {
//                                print(getLocalTimeString() + " , (Olympus) selectResult (Ambiguous & Select) : index = \(firstFltOutput.index) // output = \(output)")
                                return (false, output)
                            }
                        }
                        return (false, FineLocationTrackingFromServer())
                    }
                }
            } else {
                return (false, FineLocationTrackingFromServer())
            }
        } else {
            return (false, FineLocationTrackingFromServer())
        }
    }
    


    public func selectBestResult(results: FineLocationTrackingFromServerList) -> FineLocationTrackingFromServer {
        let fltOutputs = results.flt_outputs
        var highestSCC: Double = 0
        let sccArray: [Double] = fltOutputs.map { $0.scc }
//        print(getLocalTimeString() + " , (Olympus) selectBestResult : sccArray = \(sccArray)")
        
        var resultToReturn: FineLocationTrackingFromServer = fltOutputs[0]
        for result in fltOutputs {
            if result.scc > highestSCC {
                resultToReturn = result
                highestSCC = result.scc
            }
        }
//        print(getLocalTimeString() + " , (Olympus) selectBestResult : \(resultToReturn)")
        return resultToReturn
    }
}
