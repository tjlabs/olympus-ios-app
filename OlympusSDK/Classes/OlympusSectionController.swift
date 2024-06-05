import Foundation

public class OlympusSectionController {
    
    var uvdForSection: [UserVelocity] = []
    var uvdSectionHeadings: [Double] = []
    var uvdSectionLength: Double = 0
    var sectionNumber: Int = 0
    
    var userStraightIndexes: [Int] = []
    var anchorTailIndex: Int = 0
    var anchorTailIndexCandidates: [Int] = []
    
    // new
    var anchorSectionNumber: Int = 0
    var requestSectionNumber: Int = 0
    var sameSectionCount: Int = 2
    
    public func initialize() {
        self.uvdForSection = []
        self.uvdSectionHeadings = []
        self.uvdSectionLength = 0
        self.sectionNumber = 0
        
        self.userStraightIndexes = []
        self.anchorTailIndex = 0
        self.anchorTailIndexCandidates = []
        
        self.anchorSectionNumber = 0
        self.requestSectionNumber = 0
        self.sameSectionCount = 2
    }
    
    public func checkIsNeedAnchorNodeUpdate(userVelocity: UserVelocity) -> Bool {
        var isNeedUpdate: Bool = false
        
        uvdForSection.append(userVelocity)
        uvdSectionLength += userVelocity.length
        uvdSectionHeadings.append(compensateHeading(heading: userVelocity.heading))
        
        let straightAngle: Double = OlympusConstants.SECTION_STRAIGHT_ANGLE
        let circularStandardDeviationAll = circularStandardDeviation(for: uvdSectionHeadings)
        if (circularStandardDeviationAll <= straightAngle) {
            // 섹션 유지중
            if (uvdSectionLength >= OlympusConstants.REQUIRED_SECTION_STRAIGHT_LENGTH) {
                if (anchorSectionNumber != sectionNumber) {
                    anchorSectionNumber = sectionNumber
                    isNeedUpdate = true
                }
            }
        } else {
            // 섹션 변화
            sectionNumber += 1
            uvdForSection = []
            uvdSectionLength = 0
            uvdSectionHeadings = []
            userStraightIndexes = []
        }
        
        return isNeedUpdate
    }
    
    public func checkIsNeedRequestFlt() -> Bool {
        var isNeedRequest: Bool = false
//        print(getLocalTimeString() + " , (Olympus) Request : (0) Section Length = \(uvdSectionLength)")
        if (uvdSectionLength >= OlympusConstants.REQUIRED_SECTION_REQUEST_LENGTH) {
            if (requestSectionNumber != sectionNumber) {
//                print(getLocalTimeString() + " , (Olympus) Request : (1) Section Length = \(uvdSectionLength)")
                requestSectionNumber = sectionNumber
                
                sameSectionCount = 2
                isNeedRequest = true
            } else {
                if (uvdSectionLength >= (OlympusConstants.REQUIRED_SECTION_REQUEST_LENGTH*Double(sameSectionCount))) {
//                    print(getLocalTimeString() + " , (Olympus) Request : (2) Section Length = \(uvdSectionLength)")
                    sameSectionCount += 1
                    isNeedRequest = true
                }
            }
        }
        
        return isNeedRequest
    }
    
    public func getSectionNumber() -> Int {
        return self.sectionNumber
    }
    
    public func getAnchorTailIndex() -> Int {
        return self.anchorTailIndex
    }
    
    public func setInitialAnchorTailIndex(value: Int) {
        self.anchorTailIndex = value
    }
}
