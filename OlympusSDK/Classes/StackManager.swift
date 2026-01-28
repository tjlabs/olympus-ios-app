
import TJLabsCommon
import TJLabsResource

class StackManager {
    init() { }
    
    private let SAME_COORD_THRESHOLD: Int = 20
    
    private let DR_BUFFER_SIZE: Int = 200
    private let BLE_LEVEL_BUFFER_SIZE: Int = 8
    private let USER_PEAK_AND_LINK_BUFFER_SIZE: Int = 5
    private let CUR_RESULT_BUFFER_SIZE: Int = 200
    private let CUR_PM_RESULT_BUFFER_SIZE: Int = 200
    
    private var rfdBuffer = [[String: Float]]()
    var uvdBuffer = [UserVelocity]()
    
    var userPeakAndLinkBuffer = [(UserPeak, LinkData)]()
    var userPeakAndLinksBuffer = [(UserPeak, [LinkData])]()
    var curResultBuffer = [FineLocationTrackingOutput]()
    var curPmResultBuffer = [FineLocationTrackingOutput]()

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
    
    func getUvdBuffer(from: Int) -> [UserVelocity] {
        var buffer = [UserVelocity]()
        for uvd in uvdBuffer {
            if uvd.index >= from {
                buffer.append(uvd)
            }
        }
        return buffer
    }
    
    func getUvdBuffer(from: Int, to: Int) -> [UserVelocity] {
        var buffer = [UserVelocity]()
        for uvd in uvdBuffer {
            if uvd.index >= from && uvd.index <= to {
                buffer.append(uvd)
            }
        }
        return buffer
    }
    
    
    func stackUserPeakAndLinks(userPeakAndLinks: (UserPeak, [LinkData])) {
        userPeakAndLinksBuffer.append(userPeakAndLinks)
        if (userPeakAndLinksBuffer.count > USER_PEAK_AND_LINK_BUFFER_SIZE) {
            userPeakAndLinksBuffer.remove(at: 0)
        }
//        JupiterLogger.i(tag: "StackManager", message: "(stackUserPeakAndLink) userPeakAndLinkBuffer: \(userPeakAndLinkBuffer)")
    }
    
    func getUserPeakAndLinksBuffer() -> [(UserPeak, [LinkData])] {
        return self.userPeakAndLinksBuffer
    }
    
    func getOlderPeakIndex() -> Int {
        if self.userPeakAndLinkBuffer.count < 2 {
            return 0
        } else {
            let olderPeakAndLink = self.userPeakAndLinkBuffer[0]
            return olderPeakAndLink.0.peak_index
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
    
    func editCurResultBuffer(
        sectorId: Int,
        mode: UserMode,
        from: Int,
        shifteTraj: [RecoveryTrajectory],
        paddings: [Float]
    ) {
        let trajByIndex = Dictionary(uniqueKeysWithValues: shifteTraj.map { ($0.index, $0) })

        curResultBuffer = curResultBuffer.map { result in
            guard result.index >= from else { return result }

            guard let traj = trajByIndex[result.index] else { return result }

            guard let pm = PathMatcher.shared.pathMatching(
                sectorId: sectorId,
                building: result.building_name,
                level: result.level_name,
                x: traj.x, y: traj.y, heading: traj.heading,
                isUseHeading: true,
                mode: mode,
                paddingValues: paddings
            ) else { return result }

            var newResult = result
            newResult.x = pm.x
            newResult.y = pm.y
            newResult.absolute_heading = pm.heading

            JupiterLogger.i(
                tag: "StackManager",
                message: "(editCurResultBuffer) index:\(result.index) edited // [\(result.x),\(result.y),\(result.absolute_heading)] -> [\(newResult.x),\(newResult.y),\(newResult.absolute_heading)]"
            )

            return newResult
        }
    }
    
    func stackCurPmResultBuffer(curPmResult: FineLocationTrackingOutput) {
        curPmResultBuffer.append(curPmResult)
        if (curPmResultBuffer.count > CUR_PM_RESULT_BUFFER_SIZE) {
            curPmResultBuffer.remove(at: 0)
        }
    }
    
    func getCurPmResultBuffer(from: Int) -> [FineLocationTrackingOutput] {
        var buffer = [FineLocationTrackingOutput]()
        for result in curPmResultBuffer {
            if result.index >= from {
                buffer.append(result)
            }
        }
        return buffer
    }
    
    func editCurPmResultBuffer(
        sectorId: Int,
        mode: UserMode,
        from: Int,
        shifteTraj: [RecoveryTrajectory],
        paddings: [Float]
    ) {
        let trajByIndex = Dictionary(uniqueKeysWithValues: shifteTraj.map { ($0.index, $0) })

        curPmResultBuffer = curPmResultBuffer.map { result in
            guard result.index >= from else { return result }

            guard let traj = trajByIndex[result.index] else { return result }

            guard let pm = PathMatcher.shared.pathMatching(
                sectorId: sectorId,
                building: result.building_name,
                level: result.level_name,
                x: traj.x, y: traj.y, heading: traj.heading,
                isUseHeading: true,
                mode: mode,
                paddingValues: paddings
            ) else { return result }

            var newResult = result
            newResult.x = pm.x
            newResult.y = pm.y
            newResult.absolute_heading = pm.heading

            JupiterLogger.i(
                tag: "StackManager",
                message: "(editCurPmResultBuffer) index:\(result.index) edited // [\(result.x),\(result.y),\(result.absolute_heading)] -> [\(newResult.x),\(newResult.y),\(newResult.absolute_heading)]"
            )

            return newResult
        }
    }
    
    func makeHeadingSet(resultBuffer: [FineLocationTrackingOutput]) -> [Float] {
        var headingSet: Set<Float> = []
        for result in resultBuffer {
            let heading = result.absolute_heading
            headingSet.insert(heading)
        }
    
        return headingSet.map{$0}
    }
    
    func checkIsBadCase(jupiterPhase: JupiterPhase, uvdIndexWhenCorrection: Int) -> Bool {
        if jupiterPhase == .ENTERING { return false }
        guard curPmResultBuffer.count >= SAME_COORD_THRESHOLD else { return false }
        let last = curPmResultBuffer[curPmResultBuffer.count-1]
        let lastIndex: Int = last.index
        
        if lastIndex - uvdIndexWhenCorrection < SAME_COORD_THRESHOLD { return false }
        
        let lastX: Float = last.x
        let lastY: Float = last.y
        var sameCount = 0

        for result in curPmResultBuffer.reversed() {
            let x = result.x
            let y = result.y
            
            if x == lastX && y == lastY {
                sameCount += 1
            } else {
                break
            }
//            JupiterLogger.i(tag: "StackManager", message: "(checkIsBadCase) sameCount: \(sameCount)")
            if sameCount >= SAME_COORD_THRESHOLD {
                return true
            }
        }

        return false
    }
    
//    func checkIsBadCase() -> Bool {
//        guard curPmResultBuffer.count >= 40 else { return false }
//        
//        let curIndex = curPmResultBuffer[curPmResultBuffer.count-1].index
//        if curIndex - recoveryIndex > 40 {
//            recoveryIndex = curIndex
//            return true
//        }
//
//        return false
//    }
    
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
    
    func isDrBufferStraightCircularStd(uvdBuffer: [UserVelocity], condition: Double = 5) -> (Bool, Double) {
        var headingBuffer = [Double]()
        for uvd in uvdBuffer {
            let compensatedHeading = TJLabsUtilFunctions.shared.compensateDegree(uvd.heading)
            headingBuffer.append(compensatedHeading)
        }
        let headingStd = TJLabsUtilFunctions.shared.calculateCircularStd(for: headingBuffer)
        JupiterLogger.i(tag: "StackManager", message: "(isDrBufferStraightCircularStd) headingBuffer: \(headingBuffer)")
        JupiterLogger.i(tag: "StackManager", message: "(isDrBufferStraightCircularStd) headingStd: \(headingStd)")
        return (headingStd <= condition) ? (true, headingStd) : (false, headingStd)
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
    
    func checkHasMajorDirection(uvdBuffer: [UserVelocity], requiredSize: Int = 7) -> Bool {
        var uvdRawHeading = [Float]()
        for value in uvdBuffer {
            uvdRawHeading.append(Float(value.heading))
        }
        let headingLeastChangeSection = extractSectionWithLeastChange(inputArray: uvdRawHeading, requiredSize: requiredSize)
        return headingLeastChangeSection.isEmpty ? false : true
    }
    
    func extractSectionWithLeastChange(inputArray: [Float], requiredSize: Int = 7) -> [Float] {
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
