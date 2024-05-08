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
        uvdSectionHeadings.append(compensateHeading(heading: userVelocity.heading))
        
        let straightAngle: Double = OlympusConstants.SECTION_STRAIGHT_ANGLE
        let circularStandardDeviationAll = circularStandardDeviation(for: uvdSectionHeadings)
        if (circularStandardDeviationAll <= straightAngle) {
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
                }
            }
            userStraightIndexes.append(userVelocity.index)
        } else {
            print("Anchor : Index = \(userVelocity.index)")
            print("Anchor : num(uvdSectionHeadings) = \(uvdSectionHeadings.count)")
            print("Anchor : userStraightIndexes = \(userStraightIndexes)")
            if (uvdSectionHeadings.count >= OlympusConstants.REQUIRED_SECTION_STRAIGHT_IDX && !userStraightIndexes.isEmpty) {
                let newAnchorTailIndex = userStraightIndexes[0]
                anchorTailIndexCandidates.append(newAnchorTailIndex)
                updateAnchorTailIndex(userIndex: userVelocity.index, anchorTailIndex: self.anchorTailIndex, indexCandidates: self.anchorTailIndexCandidates)
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
    
    private func updateAnchorTailIndex(userIndex: Int, anchorTailIndex: Int, indexCandidates: [Int]) {
        print("Anchor : userIndex - anchorTailIndex = \(userIndex - anchorTailIndex)")
        if (userIndex - anchorTailIndex) > 100 {
            var newIndexCandidates = [Int]()
            
            for idx in indexCandidates {
                let diffIndex = idx - anchorTailIndex
                print("Anchor : diffIndex = \(diffIndex)")
                if diffIndex > 0 {
                    newIndexCandidates.append(idx)
                }
            }
            
            print("Anchor (before) : tailIndex = \(self.anchorTailIndex)")
            print("Anchor (before) : tailIndex Candidates = \(self.anchorTailIndexCandidates)")
            if (newIndexCandidates.isEmpty) {
                let lastIndex = self.anchorTailIndexCandidates[self.anchorTailIndexCandidates.count-1]
                self.anchorTailIndexCandidates = [lastIndex]
                self.anchorTailIndex = lastIndex
            } else {
                self.anchorTailIndexCandidates = newIndexCandidates
                self.anchorTailIndex = anchorTailIndexCandidates[0]
            }
            
            print("Anchor (after) : tailIndex = \(self.anchorTailIndex)")
            print("Anchor (after) : tailIndex Candidates = \(self.anchorTailIndexCandidates)")
        }
    }
}
