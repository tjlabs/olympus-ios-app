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
    
    func findBestLandmark(userPeak: UserPeak, landmark: LandmarkData, matchedResult: FineLocationTrackingOutput) -> PeakData? {
        let key = "\(sectorId)_\(matchedResult.building_name)_\(matchedResult.level_name)"
        guard let linkData = PathMatcher.shared.linkData[key] else { return nil }
        
        guard let curLinkInfo = PathMatcher.shared.getCurPassedLinkInfo() else { return nil }
        let curLinkGroupId = curLinkInfo.group_id
        
        guard let nodeData = PathMatcher.shared.nodeData[key] else { return nil }

        func pointToSegmentDistance(px: Float, py: Float, ax: Float, ay: Float, bx: Float, by: Float) -> Float {
            let abx = bx - ax
            let aby = by - ay
            let apx = px - ax
            let apy = py - ay
            let denom = abx*abx + aby*aby
            if denom <= 1e-6 {
                let dx = px - ax
                let dy = py - ay
                return sqrt(dx*dx + dy*dy)
            }
            var t = (apx*abx + apy*aby) / denom
            t = max(0, min(1, t))
            let cx = ax + t*abx
            let cy = ay + t*aby
            let dx = px - cx
            let dy = py - cy
            return sqrt(dx*dx + dy*dy)
        }

        func findBestLinkId(forX x: Float, forY y: Float) -> (linkId: Int, dist: Float)? {
            var bestLinkId = -1
            var bestDist = Float.greatestFiniteMagnitude

            for (lid, ld) in linkData {
                guard let sNode = nodeData[ld.start_node], sNode.coords.count >= 2 else { continue }
                guard let eNode = nodeData[ld.end_node], eNode.coords.count >= 2 else { continue }

                let ax = sNode.coords[0]
                let ay = sNode.coords[1]
                let bx = eNode.coords[0]
                let by = eNode.coords[1]

                let d = pointToSegmentDistance(px: x, py: y, ax: ax, ay: ay, bx: bx, by: by)
                if d < bestDist {
                    bestDist = d
                    bestLinkId = lid
                }
            }

            guard bestLinkId != -1 else { return nil }
            return (bestLinkId, bestDist)
        }

        let refX = Float(matchedResult.x)
        let refY = Float(matchedResult.y)

        var bestPeak: PeakData? = nil
        var bestPeakDist = Float.greatestFiniteMagnitude
        var bestPeakLinkId: Int = -1

        for peak in landmark.peaks {
            let peakX = Float(peak.x)
            let peakY = Float(peak.y)

            // 1) Landmark의 위치가 속한 Link 확인
            guard let (lid, _) = findBestLinkId(forX: peakX, forY: peakY), let ld = linkData[lid] else { continue }

            // 2) UserPeak에서의 위치가 속한 Link의 Group ID와 1)에서 얻은 Link의 Group ID의 일치 확인
            guard ld.group_id == curLinkGroupId else { continue }

            // 3) UserPeak의 위치와 가장 가까운 Link를 2)의 후보군에서 찾기 (LADNMARK_DIST_THRESHOLD 조건도 만족)
            let dx = peakX - refX
            let dy = peakY - refY
            let dist = sqrt(dx*dx + dy*dy)

            if dist < bestPeakDist && dist <= LADNMARK_DIST_THRESHOLD {
                bestPeakDist = dist
                bestPeak = peak
                bestPeakLinkId = lid
            }
        }

        if let bestPeak = bestPeak {
            JupiterLogger.i(tag: "LandmarkTagger", message: "(applyCorrection) selected peak=(\(bestPeak.x),\(bestPeak.y)) ward=\(landmark.ward_id) link=\(bestPeakLinkId) group=\(curLinkGroupId) dist=\(bestPeakDist)")
            return bestPeak
        } else {
            JupiterLogger.i(tag: "LandmarkTagger", message: "(applyCorrection) no peak matched: ward=\(landmark.ward_id) curGroup=\(curLinkGroupId) peaks=\(landmark.peaks.count)")
            return nil
        }
    }
    
    func recontructTrajectory(peakIndex: Int, bestLandmark: PeakData, matchedResult: FineLocationTrackingOutput, startHeading: Double, uvdBuffer: [UserVelocity], curResultBuffer: [FineLocationTrackingOutput], mode: UserMode) -> ([[Double]], [FineLocationTrackingOutput])? {
        let uvdBufferFromPeakIndex: [UserVelocity] = uvdBuffer
            .filter { $0.index >= peakIndex }
            .sorted { $0.index < $1.index }

        guard uvdBufferFromPeakIndex.count >= 2 else {
            JupiterLogger.i(tag: "LandmarkTagger", message: "(applyCorrection) skip DR: uvdBufferFromPeakIndex.count=\(uvdBufferFromPeakIndex.count), peakIndex=\(peakIndex)")
            return nil
        }
        
        var fltResultBuffer = [FineLocationTrackingOutput]()
        var rawResultBuffer = [[Double]]()
        
        let startCoord = [Double(bestLandmark.x), Double(bestLandmark.y)]
        var coord: [Double] = startCoord
        var heading: Double = startHeading
        
        var pmCoord: [Double] = startCoord
        
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
            
            var fltResult = curResultBuffer[i]
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
