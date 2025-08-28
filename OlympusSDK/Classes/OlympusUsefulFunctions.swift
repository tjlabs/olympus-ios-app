import Foundation

public func getLocalTimeString() -> String {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"
    dateFormatter.locale = Locale(identifier:"ko_KR")
    let nowDate = Date()
    let convertNowStr = dateFormatter.string(from: nowDate)
    
    return convertNowStr
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

func compareTraj(index: Int,
                         userMaskBuffer: [UserMask],
                         unitDRInfoBuffer: [UnitDRInfo]) -> (Double, [Double], Int, [[Double]])? {
    
    let indexCount = 20
    let tailIndex = max(0, index - indexCount)
    
    let userMaskList = userMaskBuffer.filter { $0.index >= tailIndex && $0.index < index }
    let unitDRInfoList = unitDRInfoBuffer.filter { $0.index >= tailIndex && $0.index < index }
    
    guard userMaskList.count == indexCount,
          unitDRInfoList.count == indexCount else {
        return nil
    }
    
    // 전체 DR heading 분산
    let totalHeadings = unitDRInfoList.map { $0.heading }

    let headingVar = variance(totalHeadings)
    if headingVar < 225 {
        return nil
    }
    
    // heading 변화 구간 추출
    var changeIndices = [0]
    for i in 1..<userMaskList.count {
        if userMaskList[i].absolute_heading != userMaskList[i - 1].absolute_heading {
            changeIndices.append(i)
        }
    }
    changeIndices.append(userMaskList.count)
    
    var m_total_dist: Double = 0
    var p_total_dist: Double = 0
    
    var isFindTail: Bool = false
    var t_index: Int = 0
    var p_xyh: [Double] = []
    var alignedTraj: [[Double]] = []
//    print(getLocalTimeString() + " , (OlympusServiceManager) compareTraj : mask len = \(userMaskList.count)")
//    print(getLocalTimeString() + " , (OlympusServiceManager) compareTraj : \(changeIndices.count-1) segments")
    for i in 0..<changeIndices.count - 1 {
        let start = changeIndices[i]
        let end = changeIndices[i + 1]
        guard end - start >= 2 else {
//            print(getLocalTimeString() + " , (OlympusServiceManager) compareTraj : \(i+1) seg too short")
            continue
        }
        
        if !isFindTail {
            t_index = unitDRInfoList[start].index
            isFindTail = true
        }
        let m_seg = Array(userMaskList[start..<end])
        let p_seg = Array(unitDRInfoList[start..<end])
        let majorHeading = m_seg.first!.absolute_heading
//        print(getLocalTimeString() + " , (OlympusServiceManager) compareTraj : \(i+1) seg = \(start) ~ \(end)")
//        print(getLocalTimeString() + " , (OlympusServiceManager) compareTraj : majorHeading = \(majorHeading)")
        
        // mask 거리 계산 (bounding box 기준)
        let mxs = m_seg.map { Double($0.x) }
        let mys = m_seg.map { Double($0.y) }
        let mdx = (mxs.max() ?? 0) - (mxs.min() ?? 0)
        let mdy = (mys.max() ?? 0) - (mys.min() ?? 0)
        let m_dist = hypot(mdx, mdy)
        m_total_dist += m_dist
        
        // 회전 + 이동 보정
        let aligned = alignPsegToMseg(m_seg: m_seg, p_seg: p_seg, majorHeading: majorHeading, seg_counts: changeIndices.count-1)
        
//        print(getLocalTimeString() + " , (OlympusServiceManager) compareTraj : mask x // \(mxs)")
//        print(getLocalTimeString() + " , (OlympusServiceManager) compareTraj : mask y // \(mys)")
//        print(getLocalTimeString() + " , (OlympusServiceManager) compareTraj : aligned.x // \(aligned.x)")
//        print(getLocalTimeString() + " , (OlympusServiceManager) compareTraj : aligned.y // \(aligned.y)")
        let pxs = aligned.x
        let pys = aligned.y
        let phs = aligned.h
        for a in 0..<pxs.count {
            alignedTraj.append([pxs[a], pys[a], phs[a]])
        }
        let p_dist = hypot(pxs.last! - pxs.first!, pys.last! - pys.first!)
        p_xyh = [pxs.last!, pys.last!, phs.last!]
        
//        print(getLocalTimeString() + " , (OlympusServiceManager) compareTraj : aligned.h = \(phs)")
        p_total_dist += p_dist
    }
//    print(getLocalTimeString() + " , (OlympusServiceManager) compareTraj : p_xyh = \(p_xyh)")
//    print(getLocalTimeString() + " , (OlympusServiceManager) compareTraj : alignedTraj = \(alignedTraj)")
    
    let ratio = max(p_total_dist, 1.0) / max(m_total_dist, 1.0)
//        print(getLocalTimeString() + " , (OlympusServiceManager) compareTraj : ratio = \(ratio)")
//        print(getLocalTimeString() + " , (OlympusServiceManager) compareTraj : ----------------------------------")
    return ratio >= 2.0 ? (ratio, p_xyh, t_index, alignedTraj) : nil
}

func variance(_ array: [Double]) -> Double {
    guard !array.isEmpty else { return 0 }
    let mean = array.reduce(0, +) / Double(array.count)
    let varSum = array.reduce(0) { $0 + pow($1 - mean, 2) }
    return varSum / Double(array.count)
}

func alignPsegToMseg(m_seg: [UserMask], p_seg: [UnitDRInfo], majorHeading: Double, seg_counts: Int) -> (x: [Double], y: [Double], h: [Double]) {
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
    
    return (alignedX, alignedY, alignedH)
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
