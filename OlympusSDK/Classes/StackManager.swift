
import TJLabsCommon
import TJLabsResource

class StackManager {
    init() { }
    
    private let SAME_COORD_THRESHOLD: Int = 10
    
    private let DR_BUFFER_SIZE: Int = 200
    private let PEAK_BUILDING_LEVEL_BUFFER_SIZE: Int = 5
    private let BLE_LEVEL_BUFFER_SIZE: Int = 8
    private let USER_PEAK_BUFFER_SIZE: Int = 5
    private let USER_PEAK_AND_LINK_BUFFER_SIZE: Int = 5
    private let CUR_RESULT_BUFFER_SIZE: Int = 200
    private let CUR_PM_RESULT_BUFFER_SIZE: Int = 200
    private let SEARCH_RESULT_BUFFER_SIZE: Int = 5
    private let NAVI_ROUTE_RESULT_BUFFER_SIZE: Int = 10
    
    private var rfdBuffer = [[String: Float]]()
    var uvdBuffer = [UserVelocity]()
    
    var buildingLevelByPeakBuffer = [(String, String)]()
    var userPeakBuffer = [UserPeak]()
    var userPeakAndLinksBuffer = [(UserPeak, [LinkData])]()
    var curResultBuffer = [FineLocationTrackingOutput]()
    var curPmResultBuffer = [FineLocationTrackingOutput]()
    var searchResultBuffer = [FineLocationTrackingOutput]()
    var naviRouteResultBuffer = [NavigationRoute]()
    
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
    
    func stackBuildingLevelByPeak(buildingLevel: (String, String)) {
        buildingLevelByPeakBuffer.append(buildingLevel)
        if (buildingLevelByPeakBuffer.count > PEAK_BUILDING_LEVEL_BUFFER_SIZE) {
            buildingLevelByPeakBuffer.remove(at: 0)
        }
    }
    
    func getBuildingLevelByPeakBuffer(size: Int) -> [(String, String)] {
        guard size > 0 else { return [] }
        if buildingLevelByPeakBuffer.count <= size {
            return buildingLevelByPeakBuffer
        } else {
            return Array(buildingLevelByPeakBuffer.suffix(size))
        }
    }
    
    func stackUserPeak(userPeak: UserPeak) {
        userPeakBuffer.append(userPeak)
        if (userPeakBuffer.count > USER_PEAK_BUFFER_SIZE) {
            userPeakBuffer.remove(at: 0)
        }
    }
    
    func getUserPeakBuffer() -> [UserPeak] {
        return self.userPeakBuffer
    }
    
    func stackUserPeakAndLinks(userPeakAndLinks: (UserPeak, [LinkData])) {
        userPeakAndLinksBuffer.append(userPeakAndLinks)
        if (userPeakAndLinksBuffer.count > USER_PEAK_AND_LINK_BUFFER_SIZE) {
            userPeakAndLinksBuffer.remove(at: 0)
        }
    }
    
    func getUserPeakAndLinksBuffer() -> [(UserPeak, [LinkData])] {
        return self.userPeakAndLinksBuffer
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
        
        var preResult = curResultBuffer[curResultBuffer.count-1]
        curResultBuffer = curResultBuffer.map { result in
            guard result.index >= from else { return result }
            guard let traj = trajByIndex[result.index] else { return result }
            
            var newResult = result
            if result.index == from {
                guard let pm = PathMatcher.shared.pathMatching(
                    sectorId: sectorId,
                    building: result.building_name,
                    level: result.level_name,
                    x: traj.x, y: traj.y, heading: traj.heading,
                    isUseHeading: true,
                    mode: mode,
                    paddingValues: paddings
                ) else { return result }
                
                newResult.x = pm.x
                newResult.y = pm.y
                newResult.absolute_heading = pm.heading
            } else {
                let preIndex = result.index - 1
                guard let preTraj = trajByIndex[preIndex] else { return result }
                let dx = traj.x - preTraj.x
                let dy = traj.y - preTraj.y
                
                let newX = preResult.x + dx
                let newY = preResult.y + dy
                
                guard let pm = PathMatcher.shared.pathMatching(
                    sectorId: sectorId,
                    building: result.building_name,
                    level: result.level_name,
                    x: newX, y: newY, heading: traj.heading,
                    isUseHeading: true,
                    mode: mode,
                    paddingValues: paddings
                ) else { return result }
                
                newResult.x = pm.x
                newResult.y = pm.y
                newResult.absolute_heading = pm.heading
            }
            preResult = newResult
            
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
    
    func getCurPmResultBuffer(size: Int) -> [FineLocationTrackingOutput] {
        guard size > 0 else { return [] }
        if curPmResultBuffer.count <= size {
            return curPmResultBuffer
        } else {
            return Array(curPmResultBuffer.suffix(size))
        }
    }
    
    func editCurPmResultBuffer(
        sectorId: Int,
        mode: UserMode,
        from: Int,
        shifteTraj: [RecoveryTrajectory],
        paddings: [Float]
    ) -> FineLocationTrackingOutput {
        let trajByIndex = Dictionary(uniqueKeysWithValues: shifteTraj.map { ($0.index, $0) })
        
        var preResult = curPmResultBuffer[curPmResultBuffer.count-1]
        curPmResultBuffer = curPmResultBuffer.map { result in
            guard result.index >= from else { return result }
            guard let traj = trajByIndex[result.index] else { return result }
            
            var newResult = result
            if result.index == from {
                guard let pm = PathMatcher.shared.pathMatching(
                    sectorId: sectorId,
                    building: result.building_name,
                    level: result.level_name,
                    x: traj.x, y: traj.y, heading: traj.heading,
                    isUseHeading: true,
                    mode: mode,
                    paddingValues: paddings
                ) else { return result }
                
                newResult.x = pm.x
                newResult.y = pm.y
                newResult.absolute_heading = pm.heading
            } else {
                let preIndex = result.index - 1
                guard let preTraj = trajByIndex[preIndex] else { return result }
                let dx = traj.x - preTraj.x
                let dy = traj.y - preTraj.y
                
                let newX = preResult.x + dx
                let newY = preResult.y + dy
                
                guard let pm = PathMatcher.shared.pathMatching(
                    sectorId: sectorId,
                    building: result.building_name,
                    level: result.level_name,
                    x: newX, y: newY, heading: traj.heading,
                    isUseHeading: true,
                    mode: mode,
                    paddingValues: paddings
                ) else { return result }
                
                newResult.x = pm.x
                newResult.y = pm.y
                newResult.absolute_heading = pm.heading
                JupiterLogger.i(
                    tag: "StackManager",
                    message: "(editCurPmResultBuffer) index:\(result.index) do pm // [\(newX),\(newY),\(traj.heading)] -> pm [\(pm.x),\(pm.y),\(pm.heading)]"
                )
            }
            preResult = newResult
            
            JupiterLogger.i(
                tag: "StackManager",
                message: "(editCurPmResultBuffer) index:\(result.index) edited // [\(result.x),\(result.y),\(result.absolute_heading)] -> [\(newResult.x),\(newResult.y),\(newResult.absolute_heading)]"
            )

            return newResult
        }
        
        return curPmResultBuffer[curPmResultBuffer.count-1]
    }
    
    func stackSearchResult(searchResult: FineLocationTrackingOutput) {
        searchResultBuffer.append(searchResult)
        if (searchResultBuffer.count > SEARCH_RESULT_BUFFER_SIZE) {
            searchResultBuffer.remove(at: 0)
        }
    }
    
    func getSearchResultBuffer(size: Int) -> [FineLocationTrackingOutput] {
        guard size > 0 else { return [] }
        if searchResultBuffer.count <= size {
            return searchResultBuffer
        } else {
            return Array(searchResultBuffer.suffix(size))
        }
    }
    
    func stackNaviRouteResult(naviRouteResult: NavigationRoute) {
        naviRouteResultBuffer.append(naviRouteResult)
        if (naviRouteResultBuffer.count > NAVI_ROUTE_RESULT_BUFFER_SIZE) {
            naviRouteResultBuffer.remove(at: 0)
        }
    }
    
    func getNaviRouteResultBuffer(size: Int) -> [NavigationRoute] {
        guard size > 0 else { return [] }
        if naviRouteResultBuffer.count <= size {
            return naviRouteResultBuffer
        } else {
            return Array(naviRouteResultBuffer.suffix(size))
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
    
    func checkIsBadCase(jupiterPhase: JupiterPhase, uvdIndexWhenCorrection: Int, travelingLinkDist: Float) -> Bool {
        if jupiterPhase == .ENTERING { return false }
        
        let adaptive_th = max(Int(travelingLinkDist*0.3), SAME_COORD_THRESHOLD)
        JupiterLogger.i(tag: "StackManager", message: "(checkIsBadCase) travelingLinkDist: \(travelingLinkDist), adaptive_th: \(adaptive_th)")
        guard curPmResultBuffer.count >= adaptive_th else { return false }
        let last = curPmResultBuffer[curPmResultBuffer.count-1]
        let lastIndex: Int = last.index
        
        if lastIndex - uvdIndexWhenCorrection < adaptive_th { return false }
        
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
            
            if sameCount >= adaptive_th {
                JupiterLogger.i(tag: "StackManager", message: "(checkIsBadCase) sameCount: \(sameCount)")
                return true
            }
        }

        return false
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
