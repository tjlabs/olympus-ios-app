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
    
    var requestSectionNumberInDRMode: Int = 0
    var sameSectionCountInDRMode: Int = 1
    
    var preUserHeading: Double = 0
    
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
        self.requestSectionNumberInDRMode = 0
        self.sameSectionCountInDRMode = 1
    }
    
    public func setSectionUserHeading(value: Double) {
        self.preUserHeading = value
    }
    
    public func extendedCheckIsNeedAnchorNodeUpdate(userVelocity: UserVelocity, userHeading: Double) -> Bool {
        var isNeedUpdate: Bool = false
        
        uvdForSection.append(userVelocity)
        uvdSectionLength += userVelocity.length
        uvdSectionHeadings.append(compensateHeading(heading: userVelocity.heading))
        
        var diffHeading = compensateHeading(heading: userHeading - preUserHeading)
        if diffHeading > 270 {
            diffHeading = 360 - diffHeading
        }
        self.preUserHeading = userHeading
        
        let straightAngle: Double = OlympusConstants.SECTION_STRAIGHT_ANGLE
        let circularStandardDeviationAll = circularStandardDeviation(for: uvdSectionHeadings)
        
        if (diffHeading == 0) && (circularStandardDeviationAll <= straightAngle) {
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
//            print(getLocalTimeString() + " , (Olympus) Section : section changed at \(userVelocity.index) index")
        }
        
        return isNeedUpdate
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
    
    public func checkIsNeedRequestFlt(isAmbiguous: Bool) -> (Bool, Bool) {
        var isNeedRequest: Bool = false
        var isSectionChanged: Bool = false
        let RQ_LENGTH = isAmbiguous ? (OlympusConstants.REQUIRED_SECTION_REQUEST_LENGTH/2) : OlympusConstants.REQUIRED_SECTION_REQUEST_LENGTH
        if (uvdSectionLength >= RQ_LENGTH) {
            if (requestSectionNumber != sectionNumber) {
                requestSectionNumber = sectionNumber
                sameSectionCount = 2
                isNeedRequest = true
                isSectionChanged = true
            } else {
                if (uvdSectionLength >= (RQ_LENGTH*Double(sameSectionCount))) {
                    sameSectionCount += 1
                    isNeedRequest = true
                }
            }
        }
        return (isNeedRequest, isSectionChanged)
    }
    
    public func checkIsNeedRequestFltInDRMode() -> (Bool, Bool) {
        var isNeedRequest: Bool = false
        var isSectionChanged: Bool = false
//        print(getLocalTimeString() + " , (Olympus) isDRMode : Section Length = \(uvdSectionLength)")
        if (uvdSectionLength >= OlympusConstants.REQUIRED_SECTION_REQUEST_LENGTH_IN_DR) {
            if (requestSectionNumberInDRMode != sectionNumber) {
                requestSectionNumberInDRMode = sectionNumber
                sameSectionCountInDRMode = 1
                isNeedRequest = false
                isSectionChanged = true
            } else {
                if (uvdSectionLength >= (OlympusConstants.REQUIRED_SECTION_REQUEST_LENGTH_IN_DR*Double(sameSectionCountInDRMode))) {
                    sameSectionCountInDRMode += 1
                    isNeedRequest = true
                }
            }
        }
//        print(getLocalTimeString() + " , (Olympus) isDRMode : \(requestSectionNumberInDRMode) , \(sectionNumber) // isNeedRequest = \(isNeedRequest)")
        return (isNeedRequest, isSectionChanged)
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
    
    public func setDRModeRequestSectionNumber() {
        self.requestSectionNumberInDRMode = self.sectionNumber
//        print(getLocalTimeString() + " , (Olympus) isDRMode : setDRModeRequestSectionNumber = \(self.requestSectionNumberInDRMode)")
    }
}
