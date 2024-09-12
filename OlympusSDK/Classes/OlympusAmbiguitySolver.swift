import Foundation

public class OlympusAmbiguitySolver {
    
    init() {
        
    }
    
    deinit {

    }
    
    public func initialize() {

    }
    
    public func selectResult(results: FineLocationTrackingFromServerList) {
        let fltOutputs = results.flt_outputs
        
        var indexArray = [Int](0...fltOutputs.count)
        if indexArray.count > 1 {
            let sccArray: [Double] = fltOutputs.map { $0.scc }
            let targetNum = 2
            var ratioArray = [Double]()
            let indexCombination = getCombination(inputArray: indexArray, targetNum: targetNum)
            for indexes in indexCombination {
                let ratio = fltOutputs[indexes[0]].scc/fltOutputs[indexes[1]].scc
                ratioArray.append(ratio)
            }
            print(getLocalTimeString() + " , (Olympus) selectResult : sccArray = \(sccArray)")
            print(getLocalTimeString() + " , (Olympus) selectResult : ratioArray = \(ratioArray)")
        } else {
            
        }
    }
    
}
