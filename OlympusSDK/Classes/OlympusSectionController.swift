import Foundation

public class OlympusSectionController {
    
    var uvdForSection: [UserVelocity] = []
    var uvdSectionHeadings: [Double] = []
    var sectionNumber: Int = 0
    var rqSectionNumber: Int = 0
    var rqSectionUvdIndex: Int = 0
    
    var userStraightIndexes: [Int] = []
    var anchorTailIndex: Int = 0
    var anchorTailIndexCandidates: [Int] = []
    
    public func initialize() {
        self.uvdForSection = []
        self.uvdSectionHeadings = []
        self.sectionNumber = 0
        self.rqSectionNumber = 0
        self.rqSectionUvdIndex = 0
        
        self.userStraightIndexes = []
        self.anchorTailIndex = 0
        self.anchorTailIndexCandidates = []
    }
    
    public func controlSection(userVelocity: UserVelocity) -> (Bool, Int) {
        var isNeedRequest: Bool = false
        var requestType: Int = -1
        
        uvdForSection.append(userVelocity)
        uvdSectionHeadings.append(userVelocity.heading)
        
        let straightAngle: Double = OlympusConstants.SECTION_STRAIGHT_ANGLE
        let circularStandardDeviationAll = circularStandardDeviation(for: uvdSectionHeadings)
        if (circularStandardDeviationAll <= straightAngle) {
//            print("Section : Straight \(uvdSectionHeadings)")
            if (uvdSectionHeadings.count >= OlympusConstants.REQUIRED_SECTION_STRAIGHT_IDX) {
                if (rqSectionNumber != sectionNumber) {
                    isNeedRequest = true
                    requestType = 0
                } else if (userVelocity.index - rqSectionUvdIndex > OlympusConstants.REQUIRED_SECTION_RQ_IDX) {
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
            userStraightIndexes.append(userVelocity.index)
        } else {
            if (uvdSectionHeadings.count >= OlympusConstants.REQUIRED_SECTION_STRAIGHT_IDX && !userStraightIndexes.isEmpty) {
                let newAnchorTailIndex = userStraightIndexes[0]
                anchorTailIndexCandidates.append(newAnchorTailIndex)
            }
            sectionNumber += 1
            uvdForSection = []
            uvdSectionHeadings = []
            userStraightIndexes = []
        }
        
        return (isNeedRequest, requestType)
    }
    
    public func getAnchorTailIndex() -> Int {
        return self.anchorTailIndex
    }
    
    public func setInitialAnchorTailIndex(value: Int) {
        self.anchorTailIndex = value
    }
    
    private func updateAnchorTailIndex(userIndex: Int, preIndex: Int, indexCandidates: [Int]) {
        if (userIndex - preIndex) > 40 {
            for idx in indexCandidates {
                let diffIndex = idx - preIndex
                if (0 < diffIndex) && (diffIndex < 10) {
                    
                }
            }
        }
    }
}
