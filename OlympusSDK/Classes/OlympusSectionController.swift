import Foundation

public class OlympusSectionController {
    
    var uvdForSection: [UserVelocity] = []
    var uvdSectionHeadings: [Double] = []
    var sectionNumber: Int = 0
    var rqSectionNumber: Int = 0
    var rqSectionUvdIndex: Int = 0
    
    public func initalize() {
        self.uvdForSection = []
        self.uvdSectionHeadings = []
        self.sectionNumber = 0
        self.rqSectionNumber = 0
        self.rqSectionUvdIndex = 0
    }
    
    public func controlSection(userVelocity: UserVelocity) -> (Bool, Int) {
        var isNeedRequest: Bool = false
        var requestType: Int = -1
        
        uvdForSection.append(userVelocity)
        uvdSectionHeadings.append(userVelocity.heading)
        
        let straightAngle: Double = 5
        let circularStandardDeviationAll = circularStandardDeviation(for: uvdSectionHeadings)
        if (circularStandardDeviationAll <= straightAngle) {
//            print("Section : Straight \(uvdSectionHeadings)")
            if (uvdSectionHeadings.count >= 5) {
                
                if (rqSectionNumber != sectionNumber) {
                    isNeedRequest = true
                    requestType = 0
                } else if (userVelocity.index - rqSectionUvdIndex > 5) {
                    isNeedRequest = true
                    requestType = 1
                }
                if (isNeedRequest) {
                    rqSectionNumber = sectionNumber
                    rqSectionUvdIndex = userVelocity.index
//                    print("Section : Request !! Index Count >= 5")
//                    print("Section : headings = \(uvdSectionHeadings)")
                }
            }
        } else {
            sectionNumber += 1
            uvdForSection = []
            uvdSectionHeadings = []
        }
        
        return (isNeedRequest, requestType)
    }
}
