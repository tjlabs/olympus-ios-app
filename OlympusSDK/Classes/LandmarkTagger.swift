import Foundation
import TJLabsCommon
import TJLabsResource

class LandmarkTagger {
    init(sectorId: Int) {
        self.sectorId = sectorId
    }
    
    var sectorId: Int
    var landmarkData = [String: [String: LandmarkData]]()
    var exceptionalTags: Set<String> = []
    
    let LADNMARK_DIST_THRESHOLD: Float = 30
    
    func setLandmarkData(key: String, data: [String: LandmarkData]) {
        self.landmarkData[key] = data
    }
    
    func setExceptionalTagInfo(id: String) {
        exceptionalTags.insert(id)
    }
    
    func findMatchedLandmarkWithUserPeak(userPeak: UserPeak, curResult: FineLocationTrackingOutput?, curResultBuffer: [FineLocationTrackingOutput]) -> (landmark: LandmarkData, matchedResult: FineLocationTrackingOutput)? {
        guard let curResult = curResult else { return nil }
        if exceptionalTags.contains(userPeak.id) { return nil }
        
        var isBuildingLevelMatched = false
        var matchedCurResult: FineLocationTrackingOutput?
        for result in curResultBuffer {
            if result.index == userPeak.peak_index {
                if result.building_name == curResult.building_name && result.level_name == curResult.level_name {
                    isBuildingLevelMatched = true
                    matchedCurResult = result
                    break
                }
            }
        }
        
        if !isBuildingLevelMatched { return nil }
        let key = "\(sectorId)_\(curResult.building_name)_\(curResult.level_name)"
        guard let landmarkData = self.landmarkData[key] else { return nil }
        guard let matchedLandmark = landmarkData[userPeak.id] else { return nil }
        
        JupiterLogger.i(tag: "LandmarkTagger", message: "(findMatchedLandmarkWithUserPeak) matchedLandmark: \(matchedLandmark)")
        
        return (matchedLandmark, matchedCurResult!)
    }
    
    func findBestLandmark(userPeak: UserPeak, landmark: LandmarkData, matchedResult: FineLocationTrackingOutput, peakLinkId: Int, peakLinkGroupId: Int) -> (PeakData, Int)? {
        let refX = Float(matchedResult.x)
        let refY = Float(matchedResult.y)

        var bestPeak: PeakData? = nil
        var bestPeakDist = Float.greatestFiniteMagnitude
        var bestPeakLinkId: Int?

        for peak in landmark.peaks {
            let peakX = Float(peak.x)
            let peakY = Float(peak.y)

            // 1) Landmark의 위치가 속한 Link 확인
            var lm = matchedResult
            lm.x = peakX
            lm.y = peakY
            guard let ld = PathMatcher.shared.getLinkInfoWithResult(sectorId: sectorId, result: lm) else { continue }

            // 2) UserPeak에서의 위치가 속한 Link의 Group ID와 1)에서 얻은 Link의 Group ID의 일치 확인
//            guard ld.group_id == peakLinkGroupId else { continue }
            guard ld.id == peakLinkId else { continue }

            // 3) UserPeak의 위치와 가장 가까운 Link를 2)의 후보군에서 찾기 (LADNMARK_DIST_THRESHOLD 조건도 만족)
            let dx = peakX - refX
            let dy = peakY - refY
            let dist = sqrt(dx*dx + dy*dy)

            if dist < bestPeakDist && dist <= LADNMARK_DIST_THRESHOLD {
                bestPeakDist = dist
                bestPeak = peak
                bestPeakLinkId = ld.id
            }
        }

        if let bestPeak = bestPeak, let bestPeakLinkId = bestPeakLinkId {
            JupiterLogger.i(tag: "LandmarkTagger", message: "(applyCorrection) selected peak=(\(bestPeak.x),\(bestPeak.y)) ward=\(landmark.ward_id) link=\(bestPeakLinkId) group=\(peakLinkGroupId) dist=\(bestPeakDist)")
            return (bestPeak, bestPeakLinkId)
        } else {
            JupiterLogger.i(tag: "LandmarkTagger", message: "(applyCorrection) no peak matched: ward=\(landmark.ward_id) curGroup=\(peakLinkGroupId) peaks=\(landmark.peaks.count)")
            return nil
        }
    }
    
    func reconstructTrajectory(peakIndex: Int, bestLandmark: PeakData, matchedResult: FineLocationTrackingOutput, startHeading: Double, uvdBuffer: [UserVelocity], curResultBuffer: [FineLocationTrackingOutput], mode: UserMode) -> ([[Double]], [FineLocationTrackingOutput])? {
        let uvdBufferFromPeakIndex: [UserVelocity] = uvdBuffer
            .filter { $0.index >= peakIndex }
            .sorted { $0.index < $1.index }
        
        guard uvdBufferFromPeakIndex.count >= 2 else {
            JupiterLogger.i(tag: "LandmarkTagger", message: "(applyCorrection) skip DR: uvd buffer count= \(uvdBufferFromPeakIndex.count)], peakIndex= \(peakIndex)")
            return nil
        }
        
        var fltResultBuffer = [FineLocationTrackingOutput]()
        var rawResultBuffer = [[Double]]()
        
        let startCoord = [Double(bestLandmark.x), Double(bestLandmark.y)]
        var coord: [Double] = startCoord
        var heading: Double = startHeading
        
        var pmCoord: [Double] = startCoord
        let defaultResult = curResultBuffer[curResultBuffer.count-1]
        
        for i in 1..<uvdBufferFromPeakIndex.count {
            let curUvd = uvdBufferFromPeakIndex[i]
            let preUvd = uvdBufferFromPeakIndex[i-1]
            
            let diffHeading = Double(curUvd.heading - preUvd.heading)
            let updatedHeading = TJLabsUtilFunctions.shared.compensateDegree(heading + diffHeading)
            let updatedHeadingRadian = TJLabsUtilFunctions.shared.degree2radian(degree: updatedHeading)

            let dx = Double(curUvd.length) * cos(updatedHeadingRadian)
            let dy = Double(curUvd.length) * sin(updatedHeadingRadian)
            
            coord[0] += dx
            coord[1] += dy
            heading = updatedHeading
            
            pmCoord[0] += dx
            pmCoord[1] += dy
            
            rawResultBuffer.append([coord[0], coord[1], heading])
            
            var fltResult = defaultResult
            if let pmResult = PathMatcher.shared.pathMatching(sectorId: sectorId, building: matchedResult.building_name, level: matchedResult.level_name, x: Float(pmCoord[0]), y: Float(pmCoord[1]), heading: Float(heading), isUseHeading: true, mode: mode, paddingValues: JupiterMode.PADDING_VALUES_DR) {
                pmCoord = [Double(pmResult.x), Double(pmResult.y)]
                fltResult.x = pmResult.x
                fltResult.y = pmResult.y
                fltResult.absolute_heading = Float(heading)
            } else {
                fltResult.x = Float(pmCoord[0])
                fltResult.y = Float(pmCoord[1])
                fltResult.absolute_heading = Float(heading)
            }
            fltResultBuffer.append(fltResult)
        }
        
        return (rawResultBuffer, fltResultBuffer)
    }
}
