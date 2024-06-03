import Foundation


public func += <V> ( left: inout [V], right: V) {
    left.append(right)
}

public func + <V>(left: Array<V>, right: V) -> Array<V>
{
    var map = Array<V>()
    for (v) in left {
        map.append(v)
    }

    map.append(right)

    return map
}

public func sliceArray<T>(_ array: [T], startingFrom index: Int) -> [T] {
    guard index >= 0 && index < array.count else {
        return []
    }
    
    return Array(array[index...])
}

func sliceDoubleArrayToIndex(array: [Double], endIndex: Int) -> [Double]? {
    guard endIndex >= 0, endIndex < array.count else {
        return nil
    }

    return Array(array[0...endIndex])
}


public func circularStandardDeviation(for array: [Double]) -> Double {
    guard !array.isEmpty else {
        return 20.0
    }
    
    let meanAngle = circularMean(for: array)
    let circularDifferences = array.map { angleDifference($0, meanAngle) }
    
    var powSum: Double = 0
    for i in 0..<circularDifferences.count {
        powSum += circularDifferences[i]*circularDifferences[i]
    }
    let circularVariance = powSum / Double(circularDifferences.count)
    
    return sqrt(circularVariance)
}

public func circularMean(for array: [Double]) -> Double {
    guard !array.isEmpty else {
        return 0.0
    }
    
    var sinSum = 0.0
    var cosSum = 0.0
    
    for angle in array {
        sinSum += sin(angle * .pi / 180.0)
        cosSum += cos(angle * .pi / 180.0)
    }
    
    let meanSin = sinSum / Double(array.count)
    let meanCos = cosSum / Double(array.count)
    
    let meanAngle = atan2(meanSin, meanCos) * 180.0 / .pi
    
    return (meanAngle < 0) ? meanAngle + 360.0 : meanAngle
}

public func angleDifference(_ a1: Double, _ a2: Double) -> Double {
    let diff = abs(a1 - a2)
    return (diff <= 180.0) ? diff : 360.0 - diff
}

public func getMinMaxValues(for array: [[Double]]) -> [Double] {
    guard !array.isEmpty else {
        return []
    }
    
    var xMin = array[0][0]
    var yMin = array[0][1]
    var xMax = array[0][0]
    var yMax = array[0][1]
    
    for row in array {
        xMin = min(xMin, row[0])
        yMin = min(yMin, row[1])
        xMax = max(xMax, row[0])
        yMax = max(yMax, row[1])
    }
    
    return [xMin, yMin, xMax, yMax]
}

public func subtractConstant(from array: [Double], constant: Double) -> [Double] {
    let newArray = array.map { abs($0 - constant) }
    if let minIndex = newArray.enumerated().min(by: { $0.element < $1.element })?.offset {
        var mutableArray = array
        mutableArray.remove(at: minIndex)
        return mutableArray
    } else {
        return array
    }
}

public func convertIntArrayToDoubleArray(_ array: [Int]) -> [Double] {
    let doubleArray = array.map { Double($0) }
    return doubleArray
}

extension Array where Element: BinaryInteger {

    public var average: Double {
        if self.isEmpty {
            return 0.0
        } else {
            let sum = self.reduce(0, +)
            return Double(sum) / Double(self.count)
        }
    }

}

extension Array where Element: BinaryFloatingPoint {

    public var average: Double {
        if self.isEmpty {
            return 0.0
        } else {
            let sum = self.reduce(0, +)
            return Double(sum) / Double(self.count)
        }
    }

}

extension Array where Element == Double {
    var mean: Double {
        return reduce(0, +) / Double(count)
    }
    
    var standardDeviation: Double {
        let meanValue = mean
        let squareSum = reduce(0, {$0 + pow($1 - meanValue, 2)})
        return sqrt(squareSum / Double(count))
    }
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

public func indexOfMaxRateOfChange(in array: [Double]) -> Int {
    var maxRateOfChange: Double = 0.0
    var indexOfMaxChange: Int = 0

    for i in 1..<array.count {
        let rateOfChange = abs(array[i] - array[i - 1])
        if rateOfChange > maxRateOfChange {
            maxRateOfChange = rateOfChange
            indexOfMaxChange = i
        }
    }
    return indexOfMaxChange
}
