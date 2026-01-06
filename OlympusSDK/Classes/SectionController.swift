
import TJLabsCommon

class SectionController {
    init() { }
    
    private var uvdSectionHeadings = [Double]()
    private var uvdSectionLength: Double = 0
    
    var sectionNumber: Int = 0
    var anchorTailIndex: Int = 0
    private var anchorSectionNumber: Int = 0
    var preUserHeading: Float = 0
    
    let SECTION_STRAIGHT_ANGLE: Double = 10
    let REQUIRED_SECTION_STRAIGHT_LENGTH: Double = 6
    
    func initialize() {
        uvdSectionHeadings = [Double]()
        uvdSectionLength = 0
        sectionNumber = 0
        anchorTailIndex = 0
        anchorSectionNumber = 0
    }
    
    func initSection() {
        sectionNumber += 1
        uvdSectionLength = 0
        uvdSectionHeadings = [Double]()
    }
    
    func getSectionNumber() -> Int {
        return sectionNumber
    }
    
    func getAnchorTailIndex() -> Int {
        return anchorTailIndex
    }
    
    func setAnchorTailIndex(index: Int) {
        self.anchorTailIndex = index
    }
    
    func extendedCheckIsNeedAnchorNodeUpdate(uvdLength: Double, curHeading: Float) -> Bool {
        var isNeedUpdate = false
        
        uvdSectionLength += uvdLength
        uvdSectionHeadings.append(TJLabsUtilFunctions.shared.compensateDegree(Double(curHeading)))
        
        var diffHeading = TJLabsUtilFunctions.shared.compensateDegree(Double(curHeading) - Double(preUserHeading))
        if diffHeading > 270 { diffHeading = 360 - diffHeading }
        
        preUserHeading = curHeading
        
        let circularStdAll = TJLabsUtilFunctions.shared.calculateCircularStd(for: uvdSectionHeadings)
        
        if diffHeading == 0 && circularStdAll <= SECTION_STRAIGHT_ANGLE {
            if uvdSectionLength >= REQUIRED_SECTION_STRAIGHT_LENGTH {
                if anchorSectionNumber != sectionNumber {
                    anchorSectionNumber = sectionNumber
                    isNeedUpdate = true
                }
            }
        } else {
            sectionNumber += 1
            uvdSectionLength = 0
            uvdSectionHeadings = []
        }
        
        return isNeedUpdate
    }
    
    func setInitialAnchorTailIndex(value: Int) {
        anchorTailIndex = value
    }
    
    func getSectionLength() -> Double {
        return uvdSectionLength
    }
}
