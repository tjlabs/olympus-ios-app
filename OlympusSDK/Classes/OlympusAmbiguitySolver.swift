import Foundation

public class OlympusAmbiguitySolver {
    
    init() {
        
    }
    
    deinit {

    }
    
    public func initialize() {

    }
    
    public func selectBestResult(results: FineLocationTrackingFromServerList) -> FineLocationTrackingFromServer {
        let fltOutputs = results.flt_outputs
        var highestSCC: Double = 0
        
        let sccArray: [Double] = fltOutputs.map { $0.scc }
        print(getLocalTimeString() + " , (Olympus) selectBestResult : sccArray = \(sccArray)")
        var resultToReturn: FineLocationTrackingFromServer = fltOutputs[0]
        for result in fltOutputs {
            if result.scc > highestSCC {
                resultToReturn = result
                highestSCC = result.scc
            }
        }
        
        print(getLocalTimeString() + " , (Olympus) selectBestResult : \(resultToReturn)")
        return resultToReturn
    }
    
//    public func selectResult(results: FineLocationTrackingFromServerList) {
//        let fltOutputs = results.flt_outputs
//        
//        var indexArray = [Int](0..<fltOutputs.count)
//        if indexArray.count > 1 {
//            let sccArray: [Double] = fltOutputs.map { $0.scc }
//            let targetNum = 2
//            var ratioArray = [Double]()
//            let indexCombination = getCombination(inputArray: indexArray, targetNum: targetNum)
//            for indexes in indexCombination {
//                let ratio = fltOutputs[indexes[0]].scc/fltOutputs[indexes[1]].scc
//                ratioArray.append(ratio)
//            }
//            print(getLocalTimeString() + " , (Olympus) selectResult : sccArray = \(sccArray)")
//            print(getLocalTimeString() + " , (Olympus) selectResult : ratioArray = \(ratioArray)")
//        } else {
//            
//        }
//    }
    
    public func selectResult(results: FineLocationTrackingFromServerList) {
        let fltOutputs = results.flt_outputs.sorted { $0.scc > $1.scc }
        let sccArray: [Double] = fltOutputs.map { $0.scc }
        
        if fltOutputs.count > 1 {
            let ratio = fltOutputs[1].scc/fltOutputs[0].scc
            
            print(getLocalTimeString() + " , (Olympus) selectResult : sccArray = \(sccArray)")
            print(getLocalTimeString() + " , (Olympus) selectResult : ratio = \(ratio)")
            
            if ratio < OlympusConstants.OUTPUT_AMBIGUITY_RATIO {
                
            }
        } else {
            
        }
    }
    
}
