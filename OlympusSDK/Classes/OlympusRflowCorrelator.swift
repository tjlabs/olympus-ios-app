import Foundation

public class OlympusRflowCorrelator {
    let D = 10*2 // 10s
    let T = 10*2 // 10s
    
    var rfdBufferLength = 40
    var rfdBuffer = [[String: Double]]()
    
    let D_V = 15*2
    let T_V = 3*2
    
    let D_AUTO = 5*2
    let T_AUTO = 10*2
    
    var rfdVelocityBufferLength = 36
    var rfdVelocityBuffer = [[String: Double]]()
    var rflowQueue = [Double]()
    var preSmoothedRflowForVelocity: Double = 0
    
    var rfdAutoModeBufferLength = 30
    var rfdAutoModeBuffer = [[String: Double]]()
    var rflowForAutoModeQueue = [Double]()
    var preSmoothedRflowForAutoMode: Double = 0
    
    init() {
        self.rfdBufferLength = (self.D + self.T)
        self.rfdVelocityBufferLength = (self.D_V + self.T_V)
        self.rfdAutoModeBufferLength = (self.D_AUTO + self.T_AUTO)
    }
    
    public func initialize() {
        self.rfdVelocityBuffer = [[String: Double]]()
        self.rflowQueue = [Double]()
        self.rfdAutoModeBuffer = [[String: Double]]()
        self.rflowForAutoModeQueue = [Double]()
    }
    
    public func accumulateRfdBuffer(bleData: [String: Double]) -> Bool {
        var isSufficient: Bool = false
        if (self.rfdBuffer.count < self.rfdBufferLength) {
            if (self.rfdBuffer.isEmpty) {
                self.rfdBuffer.append(["empty": -100.0])
            } else {
                self.rfdBuffer.append(bleData)
            }
        } else {
            isSufficient = true
            self.rfdBuffer.remove(at: 0)
            if (self.rfdBuffer.isEmpty) {
                self.rfdBuffer.append(["empty": -100.0])
            } else {
                self.rfdBuffer.append(bleData)
            }
        }
        
        return isSufficient
    }
    
    public func getRflow() -> Double {
        var result: Double = 0
        
        if (self.rfdBuffer.count >= self.rfdBufferLength) {
            let preRfdBuffer = sliceDictionaryArray(self.rfdBuffer, startIndex: self.rfdBufferLength-T-D, endIndex: self.rfdBufferLength-T-1)
            let curRfdBuffer = sliceDictionaryArray(self.rfdBuffer, startIndex: self.rfdBufferLength-D, endIndex: self.rfdBufferLength-1)
            
            var sumDiffRssi: Double = 0
            var validKeyCount: Int = 0
            
            for i in 0..<D {
                let preRfd = preRfdBuffer[i]
                let curRfd = curRfdBuffer[i]
                
                for (key, value) in curRfd {
                    if (key != "empty" && value > -100.0) {
                        let curRssi = value
                        let preRssi = preRfd[key] ?? -100.0
                        sumDiffRssi += abs(curRssi - preRssi)
                        
                        validKeyCount += 1
                    }
                }
            }
            
            if (validKeyCount != 0) {
                let avgValue: Double = sumDiffRssi/Double(validKeyCount)
                if (avgValue != 0) {
                    result = calcScc(value: avgValue)
                }
            }
        }
        
        return result
    }
    
    public func accumulateRfdVelocityBuffer(bleData: [String: Double]) -> Bool {
        var isSufficient: Bool = false
        if (self.rfdVelocityBuffer.count < self.rfdVelocityBufferLength) {
            if (self.rfdVelocityBuffer.isEmpty) {
                self.rfdVelocityBuffer.append(["empty": -100.0])
            } else {
                self.rfdVelocityBuffer.append(bleData)
            }
        } else {
            isSufficient = true
            self.rfdVelocityBuffer.remove(at: 0)
            if (self.rfdVelocityBuffer.isEmpty) {
                self.rfdVelocityBuffer.append(["empty": -100.0])
            } else {
                self.rfdVelocityBuffer.append(bleData)
            }
        }
        
        return isSufficient
    }
    
    public func getRflowForVelocityScale() -> Double {
        var result: Double = 0
        
        if (self.rfdVelocityBuffer.count >= self.rfdVelocityBufferLength) {
            let preRfdBuffer = sliceDictionaryArray(self.rfdVelocityBuffer, startIndex: self.rfdVelocityBufferLength-T_V-D_V, endIndex: self.rfdVelocityBufferLength-T_V-1)
            let curRfdBuffer = sliceDictionaryArray(self.rfdVelocityBuffer, startIndex: self.rfdVelocityBufferLength-D_V, endIndex: self.rfdVelocityBufferLength-1)
            
            var sumDiffRssi: Double = 0
            var validKeyCount: Int = 0
            
            for i in 0..<D_V {
                let preRfd = preRfdBuffer[i]
                let curRfd = curRfdBuffer[i]
                
                for (key, value) in curRfd {
                    if (key != "empty" && value > -100.0) {
                        let curRssi = value
                        let preRssi = preRfd[key] ?? -100.0
                        sumDiffRssi += abs(curRssi - preRssi)
                        
                        validKeyCount += 1
                    }
                }
            }
            
            if (validKeyCount != 0) {
                let avgValue: Double = sumDiffRssi/Double(validKeyCount)
                if (avgValue != 0) {
                    result = calcScc(value: avgValue)
                }
            }
        }
        
        return result
    }
    
    public func accumulateRfdAutoModeBuffer(bleData: [String: Double]) -> Bool {
        var isSufficient: Bool = false
        if (self.rfdAutoModeBuffer.count < self.rfdAutoModeBufferLength) {
            if (self.rfdAutoModeBuffer.isEmpty) {
                self.rfdAutoModeBuffer.append(["empty": -100.0])
            } else {
                self.rfdAutoModeBuffer.append(bleData)
            }
        } else {
            isSufficient = true
            self.rfdAutoModeBuffer.remove(at: 0)
            if (self.rfdAutoModeBuffer.isEmpty) {
                self.rfdAutoModeBuffer.append(["empty": -100.0])
            } else {
                self.rfdAutoModeBuffer.append(bleData)
            }
        }
        
        return isSufficient
    }
    
    public func getRflowForAutoMode() -> Double {
        var result: Double = 0
        
        if (self.rfdAutoModeBuffer.count >= self.rfdAutoModeBufferLength) {
            let preRfdBuffer = sliceDictionaryArray(self.rfdAutoModeBuffer, startIndex: self.rfdAutoModeBufferLength-T_AUTO-D_AUTO, endIndex: self.rfdAutoModeBufferLength-T-1)
            let curRfdBuffer = sliceDictionaryArray(self.rfdAutoModeBuffer, startIndex: self.rfdAutoModeBufferLength-D_AUTO, endIndex: self.rfdAutoModeBufferLength-1)
            
            var maxPreValues = [String: Double]()
            var maxCurValues = [String: Double]()

            for i in 0..<preRfdBuffer.count {
                for (key, value) in preRfdBuffer[i] {
                    if maxPreValues.keys.contains(key) {
                        if let previousValue = maxPreValues[key] {
                            if (value > previousValue) {
                                maxPreValues[key] = value
                            }
                        }
                    } else {
                        maxPreValues[key] = value
                    }
                }
            }
            
            for i in 0..<curRfdBuffer.count {
                for (key, value) in curRfdBuffer[i] {
                    if maxCurValues.keys.contains(key) {
                        if let previousValue = maxCurValues[key] {
                            if (value > previousValue) {
                                maxCurValues[key] = value
                            }
                        }
                    } else {
                        maxCurValues[key] = value
                    }
                }
            }
            
            let curSortedKeys = maxCurValues.keys.sorted { maxCurValues[$0]! > maxCurValues[$1]! }
            let preSortedKeys = maxPreValues.keys.sorted { maxPreValues[$0]! > maxPreValues[$1]! }

            var topRatioCount = Int(Double(curSortedKeys.count) * 0.7)

            if topRatioCount == 0 {
                topRatioCount = 1
            }

            let curTopKeys = Array(curSortedKeys.prefix(topRatioCount))
            let preTopKeys = Array(preSortedKeys.prefix(topRatioCount))

            let curNewMap = Dictionary(uniqueKeysWithValues: curTopKeys.map { key in
                (key, maxCurValues[key]!)
            })

            let preNewMap = Dictionary(uniqueKeysWithValues: preTopKeys.map { key in
                (key, maxPreValues[key]!)
            })

            
            var sumDiffRssi: Double = 0
            var validKeyCount: Int = 0
            
            for (key, value) in curNewMap {
                let curRssi = value
                let preRssi = preNewMap[key] ?? -130.0
                sumDiffRssi += (curRssi - preRssi)*(curRssi - preRssi)
                validKeyCount += 1
            }
            
            if (validKeyCount != 0) {
                let avgValue: Double = sqrt(sumDiffRssi/Double(validKeyCount))
                if (avgValue != 0) {
                    let rflowScc = calcScc(value: avgValue)
                    result = smoothRflowForAutoMode(rflow: rflowScc)
                }
            }
        }
        
        return result
    }
    
    func calcScc(value: Double) -> Double {
        return exp(-value/10)
    }
    
    func sliceDictionaryArray(_ array: [[String: Double]], startIndex: Int, endIndex: Int) -> [[String: Double]] {
        let arrayCount = array.count
        
        guard startIndex >= 0 && startIndex < arrayCount && endIndex >= 0 && endIndex < arrayCount else {
            return []
        }
        
        var slicedArray: [[String: Double]] = []
        for index in startIndex...endIndex {
            slicedArray.append(array[index])
        }
        
        return slicedArray
    }
    
    func updateRflowQueue(data: Double) {
        if (self.rflowQueue.count >= 6) {
            self.rflowQueue.remove(at: 0)
        }
        self.rflowQueue.append(data)
    }
    
    func smoothRflowForVelocity(rflow: Double) -> Double {
        var smoothedRflow: Double = 1.0
        if (self.rflowQueue.count == 1) {
            smoothedRflow = rflow
        } else {
            smoothedRflow = movingAverage(preMvalue: self.preSmoothedRflowForVelocity, curValue: rflow, windowSize: self.rflowQueue.count)
        }
        preSmoothedRflowForVelocity = smoothedRflow
        return smoothedRflow
    }
    
    func updateRflowForAutoModeQueue(data: Double) {
        if (self.rflowForAutoModeQueue.count >= 20) {
            self.rflowForAutoModeQueue.remove(at: 0)
        }
        self.rflowForAutoModeQueue.append(data)
    }
    
    func smoothRflowForAutoMode(rflow: Double) -> Double {
        var smoothedRflow: Double = 1.0
        if (self.rflowForAutoModeQueue.count == 1) {
            smoothedRflow = rflow
        } else {
            smoothedRflow = movingAverage(preMvalue: self.preSmoothedRflowForAutoMode, curValue: rflow, windowSize: self.rflowForAutoModeQueue.count)
        }
        updateRflowForAutoModeQueue(data: smoothedRflow)
        preSmoothedRflowForAutoMode = smoothedRflow
        return smoothedRflow
    }
}
