import Foundation

public class OlympusAmbiguitySolver {
    var ambiguousFltInput = FineLocationTracking()
    var isAmbiguous = false

    func initialize() {
        isAmbiguous = false
        ambiguousFltInput = FineLocationTracking()
    }


    func selectResult(results: FineLocationTrackingFromServerList) -> (Bool, FineLocationTrackingFromServer) {
        let fltOutputs = results.flt_outputs
        if fltOutputs.count == 1 {
            return (true, fltOutputs[0])
        } else if (fltOUputs.count > 1) {
            let sortedFltOutputs = fltOutputs.sorted(by: { $0.scc > $1.scc })
            let firstFltOutput = sortedFltOutputs[0]
            let secondFltOutput = sortedFltOutputs[1]

            if firstFltOutput.scc != 0 {
                let ratio = secondFltOutput.scc / firstFltOutput.scc
                print("1st: \(firstFltOutput.scc) // 2nd: \(secondFltOutput.scc) // ratio: \(ratio)")
                if ratio < 0.85 {
                    return (true, firstFltOutput)
                } else {
                    return (false, FineLocationTrackingFromServer())
                }
            } else {
                return (false, FineLocationTrackingFromServer())
            }
        } else {
            return (false, FineLocationTrackingFromServer())
        }
    }
}