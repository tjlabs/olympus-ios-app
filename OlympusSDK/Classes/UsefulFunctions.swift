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

public func convertToDoubleArray(intArray: [Int]) -> [Double] {
    return intArray.map { Double($0) }
}

public func containsArray(_ array2D: [[Double]], _ targetArray: [Double]) -> Bool {
    for array in array2D {
        if array == targetArray {
            return true
        }
    }
    return false
}
