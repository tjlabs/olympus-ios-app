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

