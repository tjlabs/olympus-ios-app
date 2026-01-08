
import TJLabsCommon

class StackManager {
    init() { }
    
    private let SAME_COORD_THRESHOLD: Int = 20
    
    private let DR_BUFFER_SIZE: Int = 60
    private let HEADING_BUFFER_SIZE: Int = 5
    private let BLE_LEVEL_BUFFER_SIZE: Int = 8
    private let CUR_RESULT_BUFFER_SIZE: Int = 100

    private var rfdBuffer = [[String: Float]]()
    var uvdBuffer = [UserVelocity]()
    var isNeedClearBuffer: Bool = false
    
    var curResultBuffer = [FineLocationTrackingOutput]()
    
    var userMaskBuffer = [UserMask]()
    var userUniqueMaskBuffer = [UserMask]()
    var recoveryIndex: Int = 0
    
    func stackUvd(uvd: UserVelocity) {
        uvdBuffer.append(uvd)
        if (uvdBuffer.count > DR_BUFFER_SIZE) {
            uvdBuffer.remove(at: 0)
        }
    }
    
    func getUvdBuffer() -> [UserVelocity] {
        return self.uvdBuffer
    }

    func stackUserMask(userMask: UserMask) {
        if (userMaskBuffer.count > 0) {
            let lastIndex = userMaskBuffer.last?.index
            let currentIndex = userMask.index
            if (lastIndex == currentIndex) {
                _ = userMaskBuffer.popLast()
            }
        }

        userMaskBuffer.append(userMask)
        if (userMaskBuffer.count > DR_BUFFER_SIZE) {
            userMaskBuffer.remove(at: 0)
        }
    }

    func stackUserUniqueMask(userMask: UserMask) {
        if (userUniqueMaskBuffer.count > 0) {
            let lastUserMask = userUniqueMaskBuffer.last
            let lastIndex = lastUserMask?.index
            let lastX = lastUserMask?.x
            let lastY = lastUserMask?.y
            let currentIndex = userMask.index
            let currentX = userMask.x
            let currentY = userMask.y
            if (lastIndex == currentIndex || (lastX == currentX && lastY == currentY)) {
                _ = userUniqueMaskBuffer.popLast()
            }
        }

        userUniqueMaskBuffer.append(userMask)
        if (userUniqueMaskBuffer.count > DR_BUFFER_SIZE) {
            userUniqueMaskBuffer.remove(at: 0)
        }
    }
    
    func stackCurResult(curResult: FineLocationTrackingOutput, reconCurResultBuffer: [FineLocationTrackingOutput]?) {
        curResultBuffer.append(curResult)
        if (curResultBuffer.count > CUR_RESULT_BUFFER_SIZE) {
            curResultBuffer.remove(at: 0)
        }

        guard let reconCurResultBuffer = reconCurResultBuffer, !reconCurResultBuffer.isEmpty else { return }

        var reconMap: [Int: FineLocationTrackingOutput] = [:]
        reconMap.reserveCapacity(reconCurResultBuffer.count)
        for r in reconCurResultBuffer {
            reconMap[r.index] = r
        }

        for i in 0..<curResultBuffer.count {
            let idx = curResultBuffer[i].index
            if let recon = reconMap[idx] {
                curResultBuffer[i] = recon
            }
        }
    }
    
    func getCurResultBuffer() -> [FineLocationTrackingOutput] {
        return self.curResultBuffer
    }
    
    func isDrBufferStraightCircularStd(numIndex: Int, condition: Double = 1) -> (Bool, Double) {
        let uvdBuffer = self.uvdBuffer
        if (uvdBuffer.count >= numIndex) {
            let firstIndex = uvdBuffer.count-numIndex
            var headingBuffer = [Double]()
            for i in firstIndex..<uvdBuffer.count-1 {
                let compensatedHeading = TJLabsUtilFunctions.shared.compensateDegree(uvdBuffer[i].heading)
                headingBuffer.append(compensatedHeading)
            }
            let headingStd = TJLabsUtilFunctions.shared.calculateCircularStd(for: headingBuffer)
            return (headingStd <= condition) ? (true, headingStd) : (false, headingStd)
        } else {
            return (false, 360)
        }
    }
    
    func checkIsBadCase() -> Bool {
        var isBadCase: Bool = false
        
        let inputUserMaskBuffer = userMaskBuffer
        let th = SAME_COORD_THRESHOLD
        if inputUserMaskBuffer.count >= th {
            var diffX: Int = 0
            var diffY: Int = 0
            var checkCount: Int = 0
            for i in inputUserMaskBuffer.count-(th-1)..<inputUserMaskBuffer.count {
                if (inputUserMaskBuffer[i].index) > recoveryIndex {
                    diffX += abs(inputUserMaskBuffer[i-1].x - inputUserMaskBuffer[i].x)
                    diffY += abs(inputUserMaskBuffer[i-1].y - inputUserMaskBuffer[i].y)
                    checkCount += 1
                }
            }
            if diffX == 0 && diffY == 0 && checkCount >= (th-1) {
                isBadCase = true
            }
        }
        return isBadCase
    }
    
    
    func isResultHeadingStraight(drBufferInput: [UserVelocity], fltResult: FineLocationTrackingOutput) -> Bool {
        var isStraight: Bool = false
        let resultIndex = fltResult.index
        
        var matchedIndex: Int = -1
        var headingBuffer = [Double]()

        for i in 0..<drBufferInput.count {
            guard i < drBufferInput.count else {
                matchedIndex = -1
                break
            }
            let drBufferIndex = drBufferInput[i].index
            if drBufferIndex == resultIndex {
                matchedIndex = i
            }
            
            if drBufferIndex >= resultIndex {
                headingBuffer.append(TJLabsUtilFunctions.shared.compensateDegree(drBufferInput[i].heading))
            }
        }

        if (matchedIndex != -1 && matchedIndex >= 4) {
            let headingStd = TJLabsUtilFunctions.shared.calculateCircularStd(for: headingBuffer)
            isStraight = headingStd <= 2 ? true : false
        }
        
        return isStraight
    }
    
    func extractTop3BleInWindow(currentTime: Int, ble: [String: Float]) ->  (Int, [(String, Float)])? {
        var result: (Int, [(String, Float)])?
        var mergedBLE: [String: Float] = [:]
        
        rfdBuffer.append(ble)
        if (rfdBuffer.count >= BLE_LEVEL_BUFFER_SIZE) {
            for data in rfdBuffer {
                let bleDict = data
                for (deviceId, rssi) in bleDict {
                    if let existingRSSI = mergedBLE[deviceId] {
                        if rssi > existingRSSI {
                            mergedBLE[deviceId] = rssi
                        }
                    } else {
                        mergedBLE[deviceId] = rssi
                    }
                }
            }
            
            let top3 = mergedBLE.sorted(by: { $0.value > $1.value }).prefix(3).map { ($0.key, $0.value) }
            result = ((currentTime, top3))
            
            rfdBuffer = []
        }
        
        return result
    }
    
    func propagateUsingUvd(uvdBuffer: [UserVelocity], fltResult: FineLocationTrackingOutput) -> ixyhs? {
        var propagationValues: ixyhs?
        
        let resultIndex = fltResult.index
        var matchedIndex: Int = -1
        
        for i in 0..<uvdBuffer.count {
            let drBufferIndex = uvdBuffer[i].index
            if (drBufferIndex == resultIndex) {
                matchedIndex = i
            }
        }
        
        var dx: Float = 0
        var dy: Float = 0
        var dh: Float = 0
        
        if (matchedIndex != -1) {
            let drBuffrerFromIndex = TJLabsUtilFunctions.shared.sliceArrayFrom(uvdBuffer, startingFrom: matchedIndex)
            let headingCompensation: Double = Double(fltResult.absolute_heading) - drBuffrerFromIndex[0].heading
            var headingBuffer = [Double]()
            for i in 0..<drBuffrerFromIndex.count {
                let compensatedHeading = TJLabsUtilFunctions.shared.compensateDegree(drBuffrerFromIndex[i].heading + headingCompensation)
                let headAngle = TJLabsUtilFunctions.shared.degree2radian(degree: compensatedHeading)
                headingBuffer.append(compensatedHeading)
                
                dx += Float(drBuffrerFromIndex[i].length * cos(headAngle))
                dy += Float(drBuffrerFromIndex[i].length * sin(headAngle))
            }
            dh = Float(headingBuffer[headingBuffer.count-1] - headingBuffer[0])
            
            propagationValues = ixyhs(x: dx, y: dy, heading: dh, scale: 1.0)
        }
        
        return propagationValues
    }
    
    func checkHasMajorDirection(uvdBuffer: [UserVelocity]) -> Bool {
        var uvdRawHeading = [Float]()
        for value in uvdBuffer {
            uvdRawHeading.append(Float(value.heading))
        }
        let headingLeastChangeSection = extractSectionWithLeastChange(inputArray: uvdRawHeading, requiredSize: 7)
        return headingLeastChangeSection.isEmpty ? false : true
    }
    
    func extractSectionWithLeastChange(inputArray: [Float], requiredSize: Int) -> [Float] {
        var resultArray = [Float]()
        guard inputArray.count > requiredSize else {
            return []
        }
        
        var compensatedArray = [Double] (repeating: 0, count: inputArray.count)
        for i in 0..<inputArray.count {
            compensatedArray[i] = TJLabsUtilFunctions.shared.compensateDegree(Double(inputArray[i]))
        }
        
        var bestSliceStartIndex = 0
        var bestSliceEndIndex = 0

        for startIndex in 0..<(inputArray.count-(requiredSize-1)) {
            for endIndex in (startIndex+requiredSize)..<inputArray.count {
                let slice = Array(compensatedArray[startIndex...endIndex])
                let circularStd = TJLabsUtilFunctions.shared.calculateCircularStd(for: slice)
                if circularStd < 5 && slice.count > bestSliceEndIndex - bestSliceStartIndex {
                    bestSliceStartIndex = startIndex
                    bestSliceEndIndex = endIndex
                }
            }
        }
        
        resultArray = Array(inputArray[bestSliceStartIndex...bestSliceEndIndex])
        if resultArray.count > requiredSize {
            return resultArray
        } else {
            return []
        }
    }
}
