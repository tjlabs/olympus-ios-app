import Foundation

public func getLocalTimeString() -> String {
    struct StaticFormatter {
        static let formatter: DateFormatter = {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"
            formatter.locale = Locale(identifier: "ko_KR")
            return formatter
        }()
    }
    return StaticFormatter.formatter.string(from: Date())
}

public func getCurrentTimeInMilliseconds() -> Int
{
    return Int(Date().timeIntervalSince1970 * 1000)
}

public func getCurrentTimeInMillisecondsDouble() -> Double
{
    return Double(Date().timeIntervalSince1970 * 1000)
}

public func removeLevelDirectionString(levelName: String) -> String {
    var levelToReturn: String = levelName
    if (levelToReturn.contains("_D")) {
        levelToReturn = levelName.replacingOccurrences(of: "_D", with: "")
    }
    return levelToReturn
}

public func movingAverage(preMvalue: Double, curValue: Double, windowSize: Int) -> Double {
    let windowSizeDouble: Double = Double(windowSize)
    return preMvalue*((windowSizeDouble - 1)/windowSizeDouble) + (curValue/windowSizeDouble)
}

public func compensateHeading(heading: Double) -> Double {
    var headingToReturn: Double = heading
    
    if (headingToReturn < 0) {
        headingToReturn = headingToReturn + 360
    }
    headingToReturn = headingToReturn - floor(headingToReturn/360)*360

    return headingToReturn
}

public func isResultHeadingStraight(unitDRInfoBuffer: [UnitDRInfo], fltResult: FineLocationTrackingFromServer) -> Bool {
    var isStraight: Bool = false
    let resultIndex = fltResult.index
    
    var matchedIndex: Int = -1
    var headingBuffer = [Double]()
//    
//    for i in 0..<unitDRInfoBuffer.count {
//        let drBufferIndex = unitDRInfoBuffer[i].index
//        if (drBufferIndex == resultIndex) {
//            matchedIndex = i
//        }
//        
//        if drBufferIndex >= resultIndex {
//            headingBuffer.append(compensateHeading(heading: unitDRInfoBuffer[i].heading))
//        }
//    }
    
    for i in 0..<unitDRInfoBuffer.count {
        guard i < unitDRInfoBuffer.count else {
            matchedIndex = -1
            break
        }
        let drBufferIndex = unitDRInfoBuffer[i].index
        if drBufferIndex == resultIndex {
            matchedIndex = i
        }
        
        if drBufferIndex >= resultIndex {
            headingBuffer.append(compensateHeading(heading: unitDRInfoBuffer[i].heading))
        }
    }

    if (matchedIndex != -1 && matchedIndex >= 4) {
//        var startHeading: Double = 0
//        var endHeading: Double = 0
//        if (unitDRInfoBuffer.count < OlympusConstants.HEADING_BUFFER_SIZE) {
//            startHeading = unitDRInfoBuffer[0].heading
//            endHeading = unitDRInfoBuffer[matchedIndex].heading
//        } else {
//            startHeading = unitDRInfoBuffer[matchedIndex-4].heading
//            endHeading = unitDRInfoBuffer[matchedIndex].heading
//        }
        let headingStd = circularStandardDeviation(for: headingBuffer)
//        print(getLocalTimeString() + " , (Olympus) Heading Std : headingStd = \(headingStd) count = \(headingBuffer.count) , diffHeading = \(abs(endHeading - startHeading))")
        isStraight = headingStd <= 2 ? true : false
    }
    
    return isStraight
}

public func checkHeadingCorrection(buffer: [Double]) -> Bool {
    if (buffer.count >= OlympusConstants.HEADING_BUFFER_SIZE) {
        let firstHeading: Double = buffer.first ?? 0.0
        let lastHeading: Double = buffer.last ?? 10.0

        let diffHeadingLastFirst: Double = abs(lastHeading - firstHeading)
        if (diffHeadingLastFirst < 5.0) {
            return true
        } else {
            return false
        }
    } else {
        return false
    }
}

public func propagateUsingUvd(unitDRInfoBuffer: [UnitDRInfo], fltResult: FineLocationTrackingFromServer) -> (Bool, [Double]) {
    var isSuccess: Bool = false
    var propagationValues: [Double] = [0, 0, 0]
    let resultIndex = fltResult.index
    var matchedIndex: Int = -1
    
    for i in 0..<unitDRInfoBuffer.count {
        let drBufferIndex = unitDRInfoBuffer[i].index
        if (drBufferIndex == resultIndex) {
            matchedIndex = i
        }
    }
    
    var dx: Double = 0
    var dy: Double = 0
    var dh: Double = 0
    
    if (matchedIndex != -1) {
        let drBuffrerFromIndex = sliceArray(unitDRInfoBuffer, startingFrom: matchedIndex)
        let headingCompensation: Double = fltResult.absolute_heading - drBuffrerFromIndex[0].heading
        var headingBuffer = [Double]()
        for i in 0..<drBuffrerFromIndex.count {
            let compensatedHeading = compensateHeading(heading: drBuffrerFromIndex[i].heading + headingCompensation)
            headingBuffer.append(compensatedHeading)
            
            dx += drBuffrerFromIndex[i].length * cos(compensatedHeading*OlympusConstants.D2R)
            dy += drBuffrerFromIndex[i].length * sin(compensatedHeading*OlympusConstants.D2R)
        }
        dh = headingBuffer[headingBuffer.count-1] - headingBuffer[0]
        
        isSuccess = true
        propagationValues = [dx, dy, dh]
    }
    
    return (isSuccess, propagationValues)
}

public func isDrBufferStraightCircularStd(unitDRInfoBuffer: [UnitDRInfo], numIndex: Int, condition: Double) -> (Bool, Double) {
    if (unitDRInfoBuffer.count >= numIndex) {
        let firstIndex = unitDRInfoBuffer.count-numIndex
        var headingBuffer = [Double]()
        for i in firstIndex..<unitDRInfoBuffer.count {
            headingBuffer.append(compensateHeading(heading: unitDRInfoBuffer[i].heading))
        }
        let firstHeading: Double = unitDRInfoBuffer[firstIndex].heading
        let lastHeading: Double = unitDRInfoBuffer[unitDRInfoBuffer.count-1].heading
        var diffHeading: Double = abs(lastHeading - firstHeading)
        if (diffHeading >= 270 && diffHeading < 360) {
            diffHeading = 360 - diffHeading
        }
        let headingStd = circularStandardDeviation(for: headingBuffer)
        
//        print(getLocalTimeString() + " , (Olympus) isDrBufferStraight : diffHeading = \(diffHeading) // headingStd = \(headingStd)")
        if headingStd <= 1 {
            return (true, headingStd)
        } else {
            return (false, headingStd)
        }
    } else {
        return (false, 360)
    }
}

public func isDrBufferStraight(unitDRInfoBuffer: [UnitDRInfo], numIndex: Int, condition: Double) -> (Bool, Double) {
    if (unitDRInfoBuffer.count >= numIndex) {
        let firstIndex = unitDRInfoBuffer.count-numIndex
        let firstHeading: Double = unitDRInfoBuffer[firstIndex].heading
        let lastHeading: Double = unitDRInfoBuffer[unitDRInfoBuffer.count-1].heading
        var diffHeading: Double = abs(lastHeading - firstHeading)
        if (diffHeading >= 270 && diffHeading < 360) {
            diffHeading = 360 - diffHeading
        }

        if diffHeading <= condition {
            return (true, diffHeading)
        } else {
            return (false, diffHeading)
        }
    } else {
        return (false, 360)
    }
}

public func flattenAndUniquify(_ array2D: [[Double]]) -> [Double] {
    var uniqueElements: Set<Double> = Set()
    
    for subArray in array2D {
        uniqueElements.formUnion(subArray)
    }
    
    return Array(uniqueElements)
}

func normalizeAngle(_ angle: Double) -> Double {
    let normalizedAngle = fmod(angle, 360)
    return normalizedAngle < 0 ? normalizedAngle + 360 : normalizedAngle
}

public func weightedAverageHeading(A: Double, B: Double, weightA: Double, weightB: Double) -> Double {
    let A_rad = normalizeAngle(A)*OlympusConstants.D2R
    let B_rad = normalizeAngle(B)*OlympusConstants.D2R
    
    // Compute the weighted components
    let x = weightA * cos(A_rad) + weightB * cos(B_rad)
    let y = weightA * sin(A_rad) + weightB * sin(B_rad)
    
    let result_rad = atan2(y, x)

    var result_deg = result_rad*OlympusConstants.R2D

    if result_deg < 0 {
        result_deg += 360
    }
    
    return result_deg
}

public func getCombination(inputArray: [Int], targetNum: Int) -> [[Int]] {
    var result = [[Int]]()
    
    func comb(index: Int, curComb: [Int]) {
        if targetNum == curComb.count {
            result.append(curComb)
            return
        } else {
            for i in index..<inputArray.count {
                comb(index: i+1, curComb: curComb + [inputArray[i]])
            }
        }
    }
    comb(index: 0, curComb: [])
    
    return result
}

func determineClosestDirection(for angles: (Double, Double)) -> String? {
    let normalizedAngles = (
        angles.0.truncatingRemainder(dividingBy: 360),
        angles.1.truncatingRemainder(dividingBy: 360)
    )

    let directions: [String: [Double]] = [
        "hor": [0.0, 180.0],
        "ver": [90.0, 270.0]
    ]

    func angularDifference(from angle1: Double, to angle2: Double) -> Double {
        let diff = abs(angle1 - angle2)
        return min(diff, 360 - diff)
    }

    for (directionName, referenceAngles) in directions {
            let isBothClose = referenceAngles.contains { refAngle1 in
                angularDifference(from: normalizedAngles.0, to: refAngle1) <= 40
            } && referenceAngles.contains { refAngle2 in
                angularDifference(from: normalizedAngles.1, to: refAngle2) <= 40
            }

            if isBothClose {
                return directionName
            }
        }

    return nil
}

func isStraightTrajectoryFromCumulativeHeading(_ list: [UnitDRInfo], thresholdRMSE: Double = 5.0) -> (Bool, Double) {
    guard list.count >= 2 else { return (true, 0) }

    let n = Double(list.count)
    let x = list.map { Double($0.index) }
    let y = list.map { $0.heading }

    let sumX = x.reduce(0, +)
    let sumY = y.reduce(0, +)
    let sumXY = zip(x, y).map(*).reduce(0, +)
    let sumX2 = x.map { $0 * $0 }.reduce(0, +)

    let denominator = n * sumX2 - sumX * sumX
    guard denominator != 0 else { return (false, -1) }

    let slope = (n * sumXY - sumX * sumY) / denominator
    let intercept = (sumY - slope * sumX) / n

    // 예측값과 실제값 사이의 RMSE (Root Mean Square Error)
    let rmse = sqrt(zip(x, y).map { xi, yi in
        let pred = slope * xi + intercept
        return (yi - pred) * (yi - pred)
    }.reduce(0, +) / n)
    
    return (rmse < thresholdRMSE, rmse)
}

func convertPpToLLH(x: Double, y: Double, heading: Double, param: AffineTransParamOutput) -> LLH {
    let lon = param.xx_scale * x + param.xy_shear * y + param.x_translation
    let lat = param.yx_shear * x + param.yy_scale * y + param.y_translation
    
    let headingOffsetDeg = param.heading_offset // songdo : 36.92
    let correctedHeading = fmod(-heading + headingOffsetDeg + 360.0, 360.0)
    
    return LLH(lat: lat, lon: lon, heading: correctedHeading)
}

enum BadCaseType {
    case STRAIGHT, TURN
}

func checkForTrajMatching(index: Int,
                          ambiguitySolvedIndex: Int,
                          fltResult: FineLocationTrackingFromServer,
                          userMaskBuffer: [UserMask],
                          unitDRInfoBuffer: [UnitDRInfo],
                          linkCoord: [Double],
                          linkDirections: [Double],
                          mode: String) -> (BadCaseType, [[Double]])? {
    
    let indexStandard: Int = mode == OlympusConstants.MODE_DR ? 20 : 8
    let pathType: Int = mode == OlympusConstants.MODE_DR ? 1 : 0
    // 같은 좌표에 최근 User Mask가 N개 존재하는지 확인
    let indexForSameCount: Int = indexStandard
    let cutIndex = max(max(0, index - indexForSameCount), ambiguitySolvedIndex)
    let buffer = userMaskBuffer.filter { $0.index >= cutIndex && $0.index < index }
    
    var sameCount: Int = 0
    for index in stride(from: buffer.count - 1, through: 1, by: -1) {
        guard index < buffer.count, index - 1 >= 0, index - 1 < buffer.count else {
            continue
        }
        let current = buffer[index]
        let previous = buffer[index - 1]
        
        let dx = current.x - previous.x
        let dy = current.y - previous.y
        let norm = sqrt(Double(dx*dx + dy*dy))

        if norm < 0.1 {
            sameCount += 1
        }
    }
    
    if sameCount < indexStandard-1 {
        return nil
    }
    
    print(getLocalTimeString() + " , (OlympusServiceManager) checkForTrajMatching : index = \(index)")
    // 최근 30개의 UserMask와 UserVelocity를 비교
    let indexCount = Int(round(Double(indexStandard)*1.5))
    let tailIndex = max(max(0, index - indexCount), ambiguitySolvedIndex)
    
    let userMaskList = userMaskBuffer.filter { $0.index >= tailIndex && $0.index < index }
    let unitDRInfoList = unitDRInfoBuffer.filter { $0.index >= tailIndex && $0.index < index }
    
    guard userMaskList.count == indexCount,
          unitDRInfoList.count == indexCount,
          userMaskList.count > 0,
          unitDRInfoList.count > 0 else {
        print(getLocalTimeString() + " , (OlympusServiceManager) checkForTrajMatching : insufficient data - userMask: \(userMaskList.count), unitDR: \(unitDRInfoList.count), required: \(indexCount)")
        return nil
    }
    
    // heading 변화 구간 추출
    var changeIndices = [0]
    for i in 1..<userMaskList.count {
        guard i < userMaskList.count, i - 1 >= 0, i - 1 < userMaskList.count else {
            continue
        }
        if userMaskList[i].absolute_heading != userMaskList[i - 1].absolute_heading {
            changeIndices.append(i)
        }
    }
    changeIndices.append(userMaskList.count)
    
    var m_total_dist: Double = 0
    var p_total_dist: Double = 0
    
    var p_xyh: [Double] = []
    var user_xyh: [Double] = []

    print(getLocalTimeString() + " , (OlympusServiceManager) checkForTrajMatching : mask len = \(userMaskList.count)")
    print(getLocalTimeString() + " , (OlympusServiceManager) checkForTrajMatching : \(changeIndices.count-1) segments")
    
    guard linkCoord.count >= 2 else { return nil }
    
    let segmentCount = changeIndices.count-1
    if segmentCount == 1 {
        print(getLocalTimeString() + " , (OlympusServiceManager) checkForTrajMatching : \(segmentCount) seg // link \(linkCoord) , \(linkDirections)")
        let start = changeIndices[0]
        let end = changeIndices[1]

        let m_seg = Array(userMaskList[start..<end])
        let majorHeading = m_seg.first!.absolute_heading
        print(getLocalTimeString() + " , (OlympusServiceManager) checkForTrajMatching : majorHeading = \(majorHeading)")
        let oppositeHeading = compensateHeading(heading: majorHeading-180)
        
        var points = linkCoord
        var candidateDirections = [Double]()
        for mapHeading in linkDirections {
            if mapHeading != majorHeading && mapHeading != oppositeHeading {
                candidateDirections.append(mapHeading)
            }
        }
        
        if candidateDirections.isEmpty && mode != OlympusConstants.MODE_DR {
            let newX = linkCoord[0] + cos(majorHeading*OlympusConstants.D2R)
            let newY = linkCoord[1] + sin(majorHeading*OlympusConstants.D2R)
            print(getLocalTimeString() + " , (OlympusServiceManager) checkForTrajMatching : newXY = \(newX), \(newY)")
            let ppHeadings = OlympusPathMatchingCalculator.shared.getPathMatchingHeadings(building: fltResult.building_name, level: fltResult.level_name, x: newX, y: newY, PADDING_VALUE: 1, mode: mode)
            for mapHeading in ppHeadings {
                if mapHeading != majorHeading && mapHeading != oppositeHeading {
                    candidateDirections.append(mapHeading)
                }
            }
            points = [newX, newY]
        }
        
        print(getLocalTimeString() + " , (OlympusServiceManager) checkForTrajMatching : candidateDirections = \(candidateDirections)")
        let length = Double(sameCount)
        let propagatedPoints = OlympusPathMatchingCalculator.shared.findPropagatedPoints(fltResult: fltResult, originCoord: points, candidateDirections: candidateDirections, majorHeading: majorHeading, length: length, pathType: pathType)
        
        return (BadCaseType.STRAIGHT, propagatedPoints)
    } else {
        print(getLocalTimeString() + " , (OlympusServiceManager) checkForTrajMatching : \(segmentCount) seg // link \(linkCoord) , \(linkDirections)")
        
        var userPropagtionIndex: Int?
        var candidateDirections: [Double]?
        
        for i in 0..<changeIndices.count - 1 {
            let start = changeIndices[i]
            let end = changeIndices[i + 1]
            guard end - start >= 2 else {
                print(getLocalTimeString() + " , (OlympusServiceManager) checkForTrajMatching : \(i+1) seg too short")
                continue
            }
            
            let m_seg = Array(userMaskList[start..<end])
            let p_seg = Array(unitDRInfoList[start..<end])
            let majorHeading = m_seg.first!.absolute_heading
            print(getLocalTimeString() + " , (OlympusServiceManager) checkForTrajMatching : \(i+1) seg = \(start) ~ \(end)")
            print(getLocalTimeString() + " , (OlympusServiceManager) checkForTrajMatching : majorHeading = \(majorHeading)")
            
            // mask 거리 계산 (bounding box 기준)
            let mxs = m_seg.map { Double($0.x) }
            let mys = m_seg.map { Double($0.y) }
            let mdx = (mxs.max() ?? 0) - (mxs.min() ?? 0)
            let mdy = (mys.max() ?? 0) - (mys.min() ?? 0)
            let m_dist = hypot(mdx, mdy)
            m_total_dist += m_dist
            
            // 회전 + 이동 보정
            let aligned = alignPsegToMseg(m_seg: m_seg, p_seg: p_seg, majorHeading: majorHeading, seg_counts: changeIndices.count-1)
            
            print(getLocalTimeString() + " , (OlympusServiceManager) checkForTrajMatching : mask x // \(mxs)")
            print(getLocalTimeString() + " , (OlympusServiceManager) checkForTrajMatching : mask y // \(mys)")
            print(getLocalTimeString() + " , (OlympusServiceManager) checkForTrajMatching : aligned.x // \(aligned.x)")
            print(getLocalTimeString() + " , (OlympusServiceManager) checkForTrajMatching : aligned.y // \(aligned.y)")
            let pxs = aligned.x
            let pys = aligned.y
            let phs = aligned.h

            let p_dist = hypot(pxs.last! - pxs.first!, pys.last! - pys.first!)
            p_xyh = [pxs.last!, pys.last!, phs.last!]
            
            print(getLocalTimeString() + " , (OlympusServiceManager) checkForTrajMatching : aligned.h = \(phs)")
            p_total_dist += p_dist
            
            if start == 0 {
                // Node를 찾은 방향 설정
                var oppositeHeading: Double = compensateHeading(heading: majorHeading-180)
                var minDiffValue: Double = 360
                if (!linkDirections.isEmpty) {
                    for mapHeading in linkDirections {
                        var diffValue: Double = 0
                        
                        if (majorHeading > 270 && (mapHeading >= 0 && mapHeading < 90)) {
                            diffValue = abs(majorHeading - (mapHeading+360))
                        } else if (mapHeading > 270 && (majorHeading >= 0 && majorHeading < 90)) {
                            diffValue = abs(mapHeading - (majorHeading+360))
                        } else {
                            diffValue = abs(majorHeading - mapHeading)
                        }
                        
                        if diffValue < minDiffValue {
                            minDiffValue = diffValue
                            oppositeHeading = compensateHeading(heading: mapHeading-180)
                        }
                    }
                    userPropagtionIndex = end
                    candidateDirections = [majorHeading, oppositeHeading]
                }
                
                if let idx = userPropagtionIndex, let dirs = candidateDirections {
                    let pathType = mode == OlympusConstants.MODE_DR ? 1 : 0
                    let nodes = OlympusPathMatchingCalculator.shared.findNodesUsingCandidateDirections(fltResult: fltResult, originCoord: linkCoord, candidateDirections: dirs, pathType: pathType, type: .NORMAL)
                    
                    let alignedTraj = applyAlignment(to: unitDRInfoList, using: aligned.alignTransform)
                    let alignedHeading = alignedTraj.h
                    print(getLocalTimeString() + " , (OlympusServiceManager) checkForTrajMatching : userPropagtionIndex = \(idx)")
                    print(getLocalTimeString() + " , (OlympusServiceManager) checkForTrajMatching : alignedTraj = \(alignedTraj)")
                    
                    let group = DispatchGroup()
                    let queue = DispatchQueue(label: "traj.match.queue", attributes: .concurrent)

                    var minDist: Double = .infinity
                    var bestXYHS: [Double] = []
                    var bestNodeNumber: Int?

                    let lock = NSLock()
                    
                    for node in nodes {
                        group.enter()
                        queue.async {
                            defer { group.leave() }

                            // Index bounds check for alignedTraj and heading
                            guard alignedTraj.x.indices.contains(idx),
                                  alignedTraj.y.indices.contains(idx),
                                  alignedHeading.indices.contains(idx) else {
                                print("🚨 Index out of bounds in alignedTraj or heading")
                                return
                            }

                            let nodeCoord = node.nodeCoord
                            guard nodeCoord.count >= 2 else { return }
                            let offsetX = nodeCoord[0] - alignedTraj.x[idx]
                            let offsetY = nodeCoord[1] - alignedTraj.y[idx]

                            let shiftedX = alignedTraj.x.map { $0 + offsetX }
                            let shiftedY = alignedTraj.y.map { $0 + offsetY }

                            let pmResult = OlympusPathMatchingCalculator.shared.pathMatching(
                                building: fltResult.building_name,
                                level: fltResult.level_name,
                                x: shiftedX.last!,
                                y: shiftedY.last!,
                                heading: alignedHeading.last!,
                                HEADING_RANGE: OlympusConstants.HEADING_RANGE,
                                isUseHeading: true,
                                pathType: pathType,
                                PADDING_VALUES: OlympusConstants.PADDING_VALUES
                            )

                            guard pmResult.isSuccess, pmResult.xyhs.count >= 2 else {
                                print("🚨 Invalid pmResult"); return
                            }
                            let dx = linkCoord[0] - pmResult.xyhs[0]
                            let dy = linkCoord[1] - pmResult.xyhs[1]
                            let dist = sqrt(dx*dx + dy*dy)

                            lock.lock()
                            let localCopy = pmResult.xyhs
                            if dist < minDist {
                                minDist = dist
                                bestXYHS = localCopy
                                bestNodeNumber = node.nodeNumber
                            }
                            lock.unlock()
                        }
                    }

                    group.wait()
                    user_xyh = bestXYHS
                    
                    print(getLocalTimeString() + " , (OlympusServiceManager) checkForTrajMatching : best // dist = \(minDist), xyhs = \(bestXYHS), node = \(bestNodeNumber)")
                    
                    var points = [[Double]]()
                    points.append(user_xyh)
                    
                    return (BadCaseType.TURN, points)
                }
            }
        }
        print(getLocalTimeString() + " , (OlympusServiceManager) checkForTrajMatching : p_xyh = \(p_xyh)")
    }
    
    return nil
}


func variance(_ array: [Double]) -> Double {
    guard !array.isEmpty else { return 0 }
    let mean = array.reduce(0, +) / Double(array.count)
    let varSum = array.reduce(0) { $0 + pow($1 - mean, 2) }
    return varSum / Double(array.count)
}

func alignPsegToMseg(m_seg: [UserMask], p_seg: [UnitDRInfo], majorHeading: Double, seg_counts: Int) -> (x: [Double], y: [Double], h: [Double], alignTransform: AlignmentTransform) {
    let windowSize = 5
    let headings = p_seg.map { $0.heading }
    let n = headings.count
    var centralIdx = n / 2
    if seg_counts == 1 {
        centralIdx = 2
    } else {
        if n >= windowSize {
            var bestStart = 0
            var minVar = Double.infinity
            for i in 0...(n - windowSize) {
                let sub = Array(headings[i..<(i+windowSize)])
                let v = variance(sub)
                if v < minVar {
                    minVar = v
                    bestStart = i
                }
            }
            centralIdx = bestStart + windowSize / 2
        }
    }
    
    let rotateDeg = majorHeading - headings[centralIdx]
    
//        let px = p_seg.map { $0.length * cos($0.heading * .pi / 180) }
//        let py = p_seg.map { $0.length * sin($0.heading * .pi / 180) }
    let (px, py) = drXY(from: p_seg)
    
    let px_c = px[centralIdx]
    let py_c = py[centralIdx]
    let mx_c = Double(m_seg[centralIdx].x)
    let my_c = Double(m_seg[centralIdx].y)
    
    var alignedX: [Double] = []
    var alignedY: [Double] = []
    var alignedH: [Double] = []
    
    for i in 0..<px.count {
        let dx = px[i] - px_c
        let dy = py[i] - py_c
        let rad = rotateDeg * .pi / 180
        let xRot = dx * cos(rad) - dy * sin(rad)
        let yRot = dx * sin(rad) + dy * cos(rad)
        alignedX.append(xRot + mx_c)
        alignedY.append(yRot + my_c)
        
        let rawHeading = headings[i] + rotateDeg
        let correctedHeading = fmod((rawHeading + 360), 360)
        alignedH.append(correctedHeading)
    }
    
    let alignTransform = AlignmentTransform(
        rotateDeg: rotateDeg,
        drCenterX: px[centralIdx],
        drCenterY: py[centralIdx],
        maskCenterX: Double(m_seg[centralIdx].x),
        maskCenterY: Double(m_seg[centralIdx].y)
    )
    
    return (alignedX, alignedY, alignedH, alignTransform)
}

// From UnitDRInfo -> create x, y trajectory
func drXY(from drInfos: [UnitDRInfo]) -> ([Double], [Double]) {
    var x: [Double] = [0.0]
    var y: [Double] = [0.0]
    for i in 1..<drInfos.count {
        let dx = drInfos[i].length * cos(drInfos[i].heading * .pi / 180)
        let dy = drInfos[i].length * sin(drInfos[i].heading * .pi / 180)
        x.append(x[i - 1] + dx)
        y.append(y[i - 1] + dy)
    }
    return (x, y)
}

func applyAlignment(to p_seg: [UnitDRInfo], using transform: AlignmentTransform) -> (x: [Double], y: [Double], h: [Double]) {
    let (px, py) = drXY(from: p_seg)
    let headings = p_seg.map { $0.heading }
    
    var alignedX: [Double] = []
    var alignedY: [Double] = []
    var alignedH: [Double] = []
    
    let rad = transform.rotateDeg * .pi / 180
    
    for i in 0..<px.count {
        let dx = px[i] - transform.drCenterX
        let dy = py[i] - transform.drCenterY
        
        let xRot = dx * cos(rad) - dy * sin(rad)
        let yRot = dx * sin(rad) + dy * cos(rad)
        
        alignedX.append(xRot + transform.maskCenterX)
        alignedY.append(yRot + transform.maskCenterY)
        
        let rawHeading = headings[i] + transform.rotateDeg
        alignedH.append(fmod((rawHeading + 360), 360))
    }

    return (alignedX, alignedY, alignedH)
}
