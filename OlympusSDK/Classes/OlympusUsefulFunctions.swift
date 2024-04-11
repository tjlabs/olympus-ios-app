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
    return (Date().timeIntervalSince1970 * 1000)
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

public func isResultHeadingStraight(drBuffer: [UnitDRInfo], fltResult: FineLocationTrackingFromServer) -> Bool {
    var isStraight: Bool = false
    let resultIndex = fltResult.index
    
    var matchedIndex: Int = -1
    
    for i in 0..<drBuffer.count {
        let drBufferIndex = drBuffer[i].index
        if (drBufferIndex == resultIndex) {
            matchedIndex = i
        }
    }
    
    if (matchedIndex != -1 && matchedIndex >= 4) {
        var startHeading: Double = 0
        var endHeading: Double = 0
        if (drBuffer.count < 5) {
            startHeading = drBuffer[0].heading
            endHeading = drBuffer[matchedIndex].heading
        } else {
            startHeading = drBuffer[matchedIndex-4].heading
            endHeading = drBuffer[matchedIndex].heading
        }
        
        if (abs(endHeading - startHeading) < 5.0) {
            isStraight = true
        } else {
            isStraight = false
        }
    }
    
    return isStraight
}

public func propagateUsingUvd(drBuffer: [UnitDRInfo], fltResult: FineLocationTrackingFromServer) -> (Bool, [Double]) {
    var isSuccess: Bool = false
    var propagationValues: [Double] = [0, 0, 0]
    let resultIndex = fltResult.index
    var matchedIndex: Int = -1
    
    for i in 0..<drBuffer.count {
        let drBufferIndex = drBuffer[i].index
        if (drBufferIndex == resultIndex) {
            matchedIndex = i
        }
    }
    
    var dx: Double = 0
    var dy: Double = 0
    var dh: Double = 0
    
    if (matchedIndex != -1) {
        let drBuffrerFromIndex = sliceArray(drBuffer, startingFrom: matchedIndex)
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
