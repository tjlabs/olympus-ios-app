public class OlympusPathMatchingCalculator {
    
    public var PpCoord = [String: [[Double]]]()
    public var PpType = [String: [Int]]()
    public var PpMinMax = [Double]()
    public var PpMagScale = [String: [Double]]()
    public var PpHeading = [String: [String]]()
    public var EntranceMatchingArea = [String: [[Double]]]()
    public var IsLoadPp = [String: Bool]()
    
    init() {
        
    }
    
    public func parseRoad(data: String) -> ([Int], [[Double]], [Double], [String] ) {
        var roadType = [Int]()
        var road = [[Double]]()
        var roadScale = [Double]()
        var roadHeading = [String]()
        
        var roadX = [Double]()
        var roadY = [Double]()
        
        let roadString = data.components(separatedBy: .newlines)
        for i in 0..<roadString.count {
            if (roadString[i] != "") {
                let lineData = roadString[i].components(separatedBy: ",")
                
                roadType.append(Int(Double(lineData[0])!))
                roadX.append(Double(lineData[1])!)
                roadY.append(Double(lineData[2])!)
                roadScale.append(Double(lineData[3])!)
                
                var headingArray: String = ""
                if (lineData.count > 4) {
                    for j in 4..<lineData.count {
                        headingArray.append(lineData[j])
                        if (lineData[j] != "") {
                            headingArray.append(",")
                        }
                    }
                }
                roadHeading.append(headingArray)
            }
        }
        road = [roadX, roadY]
        self.PpMinMax = [roadX.min() ?? 0, roadY.min() ?? 0, roadX.max() ?? 0, roadY.max() ?? 0]
        
        return (roadType, road, roadScale, roadHeading)
    }
}
