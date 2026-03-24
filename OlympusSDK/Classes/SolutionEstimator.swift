import Foundation
import TJLabsCommon
import TJLabsResource

class SolutionEstimator {
    
    init(sectorId: Int) {
        self.sectorId = sectorId
    }
    
    var sectorId: Int
    var preFixedLandmarkPos: [Float]?
    
    func getUvdBufferForEstimation(startIndex: Int, endIndex: Int, uvdBuffer: [UserVelocity]) -> [UserVelocity] {
        var slicedUvd = [UserVelocity]()
        for uvd in uvdBuffer {
            let uvdIndex = uvd.index
            if uvdIndex >= startIndex && uvdIndex <= endIndex {
                slicedUvd.append(uvd)
            }
        }
        
        return slicedUvd
    }
    
    func makeMultipleCandidateTrajectory(uvdBuffer: [UserVelocity], majorSection: [Float], pathHeadings: [Float], endHeading: Float? = nil) -> [[CandidateTrajectory]] {
        var trajList = [[CandidateTrajectory]]()
        if !majorSection.isEmpty {
            let headingForCompensation = majorSection.average - uvdBuffer[0].heading
            
            for pathHeading in pathHeadings {
                let startHeading = Float(TJLabsUtilFunctions.shared.compensateDegree(Double(pathHeading) - Double(headingForCompensation)))
                var coord: [Float] = [0, 0]
                var heading: Float = startHeading
                
                var resultBuffer: [CandidateTrajectory] = [CandidateTrajectory(index: uvdBuffer[0].index, x: 0, y: 0, heading: startHeading)]
                for i in 1..<uvdBuffer.count {
                    let curUvd = uvdBuffer[i]
                    let preUvd = uvdBuffer[i-1]
                    
                    let diffHeading: Float = Float(curUvd.heading - preUvd.heading)
                    let updatedHeading = TJLabsUtilFunctions.shared.compensateDegree(Double(heading + diffHeading))
                    let updatedHeadingRadian = TJLabsUtilFunctions.shared.degree2radian(degree: updatedHeading)

                    let dx = curUvd.length * cos(updatedHeadingRadian)
                    let dy = curUvd.length * sin(updatedHeadingRadian)
                    
                    coord[0] += Float(dx)
                    coord[1] += Float(dy)
                    heading = Float(updatedHeading)
                    
                    resultBuffer.append(CandidateTrajectory(index: curUvd.index, x: coord[0], y: coord[1], heading: heading))
                }
                
                if let endHeading = endHeading {
                    let lastHeading = TJLabsUtilFunctions.shared.compensateDegree(Double(resultBuffer[resultBuffer.count-1].heading))
                    let diffHeading = adjustHeading(Float(lastHeading), endHeading)
                    if diffHeading < Float(JupiterMode.HEADING_RANGE) {
                        trajList.append(resultBuffer)
                    }
                } else {
                    trajList.append(resultBuffer)
                }
            }
        }
  
        return trajList
    }
    
    private func adjustHeading(_ heading: Float, _ mapHeading: Float) -> Float {
        if heading > 270 && mapHeading < 90 {
            return abs(heading - (mapHeading + 360))
        } else if mapHeading > 270 && heading < 90 {
            return abs(mapHeading - (heading + 360))
        } else {
            return abs(heading - mapHeading)
        }
    }

    private func dist2(_ ax: Float, _ ay: Float, _ bx: Float, _ by: Float) -> Float {
        let dx = ax - bx
        let dy = ay - by
        return sqrt(dx * dx + dy * dy)
    }
    
    private func buildIndicesBySizeAndBase(N: Int, parts A: Int) -> [Int] {
        guard N > 0 else { return [] }
        guard A > 0 else { return [0] }

        let maxIndex = N - 1
        if A >= maxIndex {
            return Array(0...maxIndex)
        }

        return (0...A).map { i in
            Int(round(Double(maxIndex) * Double(i) / Double(A)))
        }
    }
    
    
    // MARK: - Searching
    func calculateLossParamAtEachCandInSearch(searchTrajList: [[CandidateTrajectory]],
                                              userPeakBuffer: [UserPeak],
                                              buildingLevelByUserPeak: (String, String),
                                              landmarks: (older: LandmarkData, recent: LandmarkData),
                                              mode: UserMode,
                                              isDrStraight: Bool,
                                              residualSplitter: Int = 10) -> [SearchResult] {
        guard userPeakBuffer.count >= 2 else { return [] }
        let building = buildingLevelByUserPeak.0
        let level = buildingLevelByUserPeak.1
        
        var resultList = [SearchResult]()

        let olderUserPeak = userPeakBuffer[userPeakBuffer.count - 2]
        let recentUserPeak = userPeakBuffer[userPeakBuffer.count - 1]
        
        let recentUserPeakIndex = recentUserPeak.peak_index
        
        let olderLandmarkCands: [PeakData] = landmarks.older.peaks
        let recentLandmarkCands: [PeakData] = landmarks.recent.peaks
        
        for searchTraj in searchTrajList {
            guard searchTraj.count >= 2 else { continue }
            var anchorIdx: Int? = nil
            for i in 0..<searchTraj.count {
                if searchTraj[i].index == recentUserPeakIndex {
                    anchorIdx = i
                    break
                }
            }
            guard let rpIdx = anchorIdx else { continue }
            
            for cand in recentLandmarkCands {
                JupiterLogger.i(tag: "RecoveryManager", message: "(calculateLossParamAtEachCandInSearch) CAND_START cand=[\(cand.x),\(cand.y)] matchedLinks=\(cand.matched_links)")

                // Recent Peak과 매칭되는 landmark 후보군들로 shit 시키기
                let offsetX = Float(cand.x) - searchTraj[rpIdx].x
                let offsetY = Float(cand.y) - searchTraj[rpIdx].y
                var shiftedTraj: [CandidateTrajectory] = []
                shiftedTraj.reserveCapacity(searchTraj.count)
                for p in searchTraj {
                    shiftedTraj.append(CandidateTrajectory(index: p.index,
                                                           x: p.x + offsetX,
                                                           y: p.y + offsetY,
                                                           heading: p.heading))
                }
                
                guard let first = shiftedTraj.first, let last = shiftedTraj.last else {
                    JupiterLogger.i(tag: "RecoveryManager", message: "(calculateLossParamAtEachCandInSearch) shiftedTraj first/last missing")
                    continue
                }
                
                guard let tail = PathMatcher.shared.pathMatching(sectorId: sectorId,
                                                                 building: building,
                                                                 level: level,
                                                                 x: first.x,
                                                                 y: first.y,
                                                                 heading: first.heading,
                                                                 isUseHeading: false,
                                                                 mode: mode,
                                                                 paddingValues: JupiterMode.PADDING_VALUES_LARGE) else {
                    JupiterLogger.i(tag: "RecoveryManager", message: "(calculateLossParamAtEachCandInSearch) tail pathMatching failed with [\(first.x),\(first.y),\(first.heading)]")
                    continue
                }
                
                guard let head = PathMatcher.shared.pathMatching(sectorId: sectorId,
                                                                 building: building,
                                                                 level: level,
                                                                 x: last.x,
                                                                 y: last.y,
                                                                 heading: last.heading,
                                                                 isUseHeading: isDrStraight,
                                                                 mode: mode,
                                                                 paddingValues: JupiterMode.PADDING_VALUES_LARGE) else {
                    JupiterLogger.i(tag: "RecoveryManager", message: "(calculateLossParamAtEachCandInSearch) head pathMatching failed with [\(last.x),\(last.y),\(last.heading)] // isUseHeading= \(isDrStraight)")
                    continue
                }
                
                //  traj의 꼬리 위치와 Old Peak과 매칭되는 landmark중 가장 가까운 것과의 거리
                var ocDist = Float.greatestFiniteMagnitude
                var localOlderCand: PeakData?

                for oc in olderLandmarkCands {
                    let ocX = Float(oc.x)
                    let ocY = Float(oc.y)

                    let lmDist = dist2(ocX, ocY, Float(cand.x), Float(cand.y))
                    if lmDist < 5 { continue }

                    let d = dist2(Float(first.x), Float(first.y), ocX, ocY)
                    if d < ocDist {
                        ocDist = d
                        localOlderCand = oc
                    }
                }
                
                let curPmResult = FineLocationTrackingOutput(mobile_time: 0, index: searchTraj[0].index, building_name: building, level_name: level, scc: 1.0, x: 0, y: 0, absolute_heading: 0)
                var headResult = curPmResult
                headResult.x = head.x
                headResult.y = head.y
                headResult.absolute_heading = head.heading
                
                // traj를 residualSplitter로 나눈 후, loss 계산
                let residualIndices = buildIndicesBySizeAndBase(N: shiftedTraj.count, parts: residualSplitter)
                guard let lossPointResult = computeIntermediateLossByIndex(sectorId: sectorId,
                                                                           curPmResult: curPmResult,
                                                                           shiftedTraj: shiftedTraj,
                                                                           targetIndices: residualIndices,
                                                                           mode: mode) else {
                    JupiterLogger.i(tag: "RecoveryManager", message: "(calculateLossParamAtEachCandInSearch) computeIntermediateLossByIndex failed")
                    JupiterLogger.i(tag: "RecoveryManager", message: "(calculateLossParamAtEachCandInSearch) residualIndices= \(residualIndices)")
                    continue
                }
                
                let lossDistSum = sqrt(
                    lossPointResult
                        .map { ($0.lossDist) * ($0.lossDist) }
                        .reduce(0.0, +)
                    / Float(residualIndices.count)
                )
                
                let lossHeadingSum = sqrt(
                    lossPointResult
                        .map { ($0.lossHeading) * ($0.lossHeading) }
                        .reduce(0.0, +)
                    / Float(residualIndices.count)
                )
                
                let loss_lm = ocDist
                let loss_g_d: Float = lossDistSum
                let loss_g_h: Float = lossHeadingSum
                
                let sResult = SearchResult(older: localOlderCand,
                                           recent: cand,
                                           traj: shiftedTraj,
                                           tail: tail,
                                           head: head,
                                           headResult: headResult,
                                           lossPointResultList: lossPointResult,
                                           loss_lm: loss_lm, loss_g_d: loss_g_d, loss_g_h: loss_g_h)
                
                
                resultList.append(sResult)
            }
        }
        
        return resultList
    }
    
    func calculateSearchResult(lossParamAtEachCand: [SearchResult]) -> SelectedSearch? {
        guard let best = lossParamAtEachCand.min(by: {
            let lhsLoss = $0.loss_lm + $0.loss_g_d + $0.loss_g_h
            let rhsLoss = $1.loss_lm + $1.loss_g_d + $1.loss_g_h
            return lhsLoss < rhsLoss
        }) else {
            return nil
        }
        
        let loss = best.loss_lm + best.loss_g_d + best.loss_g_h
        let selected = SelectedSearch(older: best.older,
                                      recent: best.recent,
                                      traj: best.traj,
                                      tail: best.tail,
                                      head: best.head,
                                      headResult: best.headResult,
                                      loss: loss)
        
        return selected
    }
    
    // MARK: - Tracking
    func calculateLossParamAtEachCand(trackingTrajList: [[CandidateTrajectory]],
                                      userPeakAndLinksBuffer: [(UserPeak, [LinkData])],
                                      landmarks: (older: LandmarkData, recent: LandmarkData),
                                      tuResultWhenRecentPeak: ixyhs? = nil,
                                      curPmResult: FineLocationTrackingOutput,
                                      mode: UserMode,
                                      matchedNode: NodeData?,
                                      isDrStraight: Bool,
                                      residualSplitter: Int = 10,
                                      maxGroupSwitchLimit: Int = 2) -> [CandidateResult] {
        
        guard userPeakAndLinksBuffer.count >= 2 else { return [] }
        let key = "\(sectorId)_\(curPmResult.building_name)_\(curPmResult.level_name)"
        guard let nodeData = PathMatcher.shared.nodeData[key], let linkData = PathMatcher.shared.linkData[key] else { return [] }
        
        var resultList = [CandidateResult]()
        guard let curPmLinks: [LinkData] = PathMatcher.shared.getLinkInfosWithResult(sectorId: sectorId,
                                                                                     result: curPmResult,
                                                                                     checkAll: true,
                                                                                     acceptDist: 15) else { return [] }
        let isBadCase: Bool = tuResultWhenRecentPeak == nil ? true : false
        let curLinkNums: [Int] = curPmLinks.map{$0.number}
        let curLinkGroupNums: [Int] = curPmLinks.map{ $0.group_number }
        let isInNode = matchedNode == nil ? false : true
        JupiterLogger.i(tag: "RecoveryManager", message: "(calculateLossParam) curPmResult [\(curPmResult.x),\(curPmResult.y),\(curPmResult.absolute_heading)] is in [\(curPmLinks.map{$0.number})] links, isInNode = \(isInNode)")
        
        let olderUserPeak = userPeakAndLinksBuffer[userPeakAndLinksBuffer.count - 2].0
        let olderUserLinks = userPeakAndLinksBuffer[userPeakAndLinksBuffer.count - 2].1
        
        let recentUserPeak = userPeakAndLinksBuffer[userPeakAndLinksBuffer.count - 1].0
        let recentUserLinks = userPeakAndLinksBuffer[userPeakAndLinksBuffer.count - 1].1
        let recentUserGroupNums = recentUserLinks.map{$0.group_number}
        let recentUserPeakIndex = recentUserPeak.peak_index
        
        let olderLandmarkCands: [PeakData] = landmarks.older.peaks
        let recentLandmarkCands: [PeakData] = landmarks.recent.peaks
        
        for trackingTraj in trackingTrajList {
            guard trackingTraj.count >= 2 else { continue }
            var anchorIdx: Int? = nil
            for i in 0..<trackingTraj.count {
                if trackingTraj[i].index == recentUserPeakIndex {
                    anchorIdx = i
                    break
                }
            }
            guard let rpIdx = anchorIdx else { continue }
            
            for cand in recentLandmarkCands {
                JupiterLogger.i(tag: "RecoveryManager", message: "(calculateLossParam) CAND_START cand=[\(cand.x),\(cand.y)] matchedLinks=\(cand.matched_links)")
                let candLinkNums = cand.matched_links
                var candLinkGroupNums: Set<Int> = []
                for cNum in candLinkNums {
                    guard let matchedLinkWithCand = linkData[cNum] else { continue }
                    candLinkGroupNums.insert(matchedLinkWithCand.group_number)
                }
                JupiterLogger.i(tag: "RecoveryManager", message: "(calculateLossParam) candLinkGroupNums= \(candLinkGroupNums)")

                // 1. Candidate에 대해 Recent User Link와 같은 Link Group 내에 있는지 확인
                let isInSameLinkGroup = !candLinkGroupNums.isDisjoint(with: Set(recentUserGroupNums))
                
                // 2. Candidate에 대해 Recent User Peak이 발생했을 당시 위치와 거리 계산
                var distWithRecentPeakResult: Float?
                if let tuResultWhenRecentPeak = tuResultWhenRecentPeak {
                    distWithRecentPeakResult = self.dist2(Float(cand.x), Float(cand.y), Float(tuResultWhenRecentPeak.x), Float(tuResultWhenRecentPeak.y))
                }

                // 3. 이전 Recent Peak과 현재 꼬리에서 가장 가까운 Old Peak과의 거리
                
                // Recent Peak과 매칭되는 landmark 후보군들로 shit 시키기
                let offsetX = Float(cand.x) - trackingTraj[rpIdx].x
                let offsetY = Float(cand.y) - trackingTraj[rpIdx].y
                var shiftedTraj: [CandidateTrajectory] = []
                shiftedTraj.reserveCapacity(trackingTraj.count)
                for p in trackingTraj {
                    shiftedTraj.append(CandidateTrajectory(index: p.index,
                                                           x: p.x + offsetX,
                                                           y: p.y + offsetY,
                                                           heading: p.heading))
                }
                
                guard let first = shiftedTraj.first, let last = shiftedTraj.last else {
                    JupiterLogger.i(tag: "RecoveryManager", message: "(calculateLossParam) shiftedTraj first/last missing")
                    continue
                }
                
                guard let tail = PathMatcher.shared.pathMatching(sectorId: sectorId,
                                                                 building: curPmResult.building_name,
                                                                 level: curPmResult.level_name,
                                                                 x: first.x,
                                                                 y: first.y,
                                                                 heading: first.heading,
                                                                 isUseHeading: false,
                                                                 mode: mode,
                                                                 paddingValues: JupiterMode.PADDING_VALUES_LARGE) else {
                    JupiterLogger.i(tag: "RecoveryManager", message: "(calculateLossParam) tail pathMatching failed with [\(first.x),\(first.y),\(first.heading)]")
                    continue
                }
                
                guard let head = PathMatcher.shared.pathMatching(sectorId: sectorId,
                                                                 building: curPmResult.building_name,
                                                                 level: curPmResult.level_name,
                                                                 x: last.x,
                                                                 y: last.y,
                                                                 heading: last.heading,
                                                                 isUseHeading: isDrStraight,
                                                                 mode: mode,
                                                                 paddingValues: JupiterMode.PADDING_VALUES_LARGE) else {
                    JupiterLogger.i(tag: "RecoveryManager", message: "(calculateLossParam) head pathMatching failed with [\(last.x),\(last.y),\(last.heading)] // isUseHeading= \(isDrStraight)")
                    continue
                }
                
                // 4. head에서 curPmResult까지 몇번의 Link Group 전환으로 도달 가능한지
                var headResult = curPmResult
                headResult.x = head.x
                headResult.y = head.y
                headResult.absolute_heading = head.heading

                guard let headLinks = PathMatcher.shared.getLinkInfosWithResult(sectorId: sectorId, result: headResult, checkAll: true, acceptDist: 15) else {
                    JupiterLogger.i(tag: "RecoveryManager", message: "(calculateLossParam) getLinkInfosWithResult failed with head [\(head.x),\(head.y),\(head.heading)] ")
                    continue
                }
                JupiterLogger.i(tag: "RecoveryManager", message: "(calculateLossParam) head [\(head.x),\(head.y),\(head.heading)] is in \(headLinks.map{$0.number}) links")
                let reachableResult = isLinkReachableWithGroupSwitchLimit(nodeData: nodeData, linkData: linkData, from: curPmLinks, to: headLinks, maxGroupSwitches: 3)
                if !reachableResult.isReachable {
                    JupiterLogger.i(tag: "RecoveryManager", message: "(calculateLossParam) head [\(head.x),\(head.y),\(head.heading)] to curPm [\(curPmResult.x),\(curPmResult.y),\(curPmResult.absolute_heading)] is not reachable")
                    continue
                }
                guard let switchCount = reachableResult.switchCount else { continue }
                
                // 5. traj의 꼬리 위치와 Old Peak과 매칭되는 landmark중 가장 가까운 것과의 거리
                var ocDist = Float.greatestFiniteMagnitude
                var localOlderCand: PeakData?

                for oc in olderLandmarkCands {
                    var tmp = curPmResult
                    tmp.x = Float(oc.x)
                    tmp.y = Float(oc.y)

                    let lmDist = dist2(Float(oc.x), Float(oc.y), Float(cand.x), Float(cand.y))
                    if lmDist < 5 { continue }
                    tmp.absolute_heading = tail.heading

                    let d = dist2(Float(first.x), Float(first.y), Float(oc.x), Float(oc.y))
                    if d < ocDist {
                        ocDist = d
                        localOlderCand = oc
                    }
                }
                
                // 6. traj를 residualSplitter로 나눈 후, loss 계산
                let residualIndices = buildIndicesBySizeAndBase(N: shiftedTraj.count, parts: residualSplitter)
                guard let lossPointResult = computeIntermediateLossByIndex(sectorId: sectorId,
                                                                           curPmResult: curPmResult,
                                                                           shiftedTraj: shiftedTraj,
                                                                           targetIndices: residualIndices,
                                                                           mode: mode) else {
                    JupiterLogger.i(tag: "RecoveryManager", message: "(calculateLossParam) computeIntermediateLossByIndex failed")
                    JupiterLogger.i(tag: "RecoveryManager", message: "(calculateLossParam) residualIndices= \(residualIndices)")
                    continue
                }
                
                let lossDistSum = sqrt(
                    lossPointResult
                        .map { ($0.lossDist) * ($0.lossDist) }
                        .reduce(0.0, +)
                    / Float(residualIndices.count)
                )
                
                let lossHeadingSum = sqrt(
                    lossPointResult
                        .map { ($0.lossHeading) * ($0.lossHeading) }
                        .reduce(0.0, +)
                    / Float(residualIndices.count)
                )
                
                let loss_lm = ocDist
                let loss_g_d: Float = lossDistSum
                let loss_g_h: Float = lossHeadingSum
                
                let cResult = CandidateResult(older: localOlderCand,
                                              recent: cand,
                                              links: candLinkNums, linkGroups: candLinkGroupNums,
                                              traj: shiftedTraj,
                                              tail: tail, head: head,
                                              headResult: headResult,
                                              isInSameLinkGroup: isInSameLinkGroup, linkGroupSwitchCount: switchCount,
                                              distWithRecentPeakResult: distWithRecentPeakResult,
                                              lossPointResultList: lossPointResult,
                                              loss_lm: loss_lm, loss_g_d: loss_g_d, loss_g_h: loss_g_h)
                
                resultList.append(cResult)
            }
        }
        
        return resultList
    }
    
    private func computeIntermediateLossByIndex(sectorId: Int,
                                                curPmResult: FineLocationTrackingOutput,
                                                shiftedTraj: [CandidateTrajectory],
                                                targetIndices: [Int],
                                                maxGroupSwitches: Int = 1,
                                                mode: UserMode) -> [LossPointResult]? {
        
        if shiftedTraj.isEmpty || targetIndices.isEmpty { return nil }
        let key = "\(sectorId)_\(curPmResult.building_name)_\(curPmResult.level_name)"
        guard let nodeData = PathMatcher.shared.nodeData[key], let linkData = PathMatcher.shared.linkData[key] else { return nil }
        
        var lossPointResults = [LossPointResult]()
        
        var preLinks: [LinkData]?
        var preIxyhs: ixyhs?
        
        let FAIL_TH = Int(Double(targetIndices.count-1) * 0.3)
        JupiterLogger.i(tag: "RecoveryManager", message: "(computeIntermediateLossByIndex) : FAIL_TH= \(FAIL_TH)")
        var failCount = 0
        for idx in targetIndices {
            let point = shiftedTraj[idx]
            guard let pm = PathMatcher.shared.pathMatchingWithHeadings(sectorId: sectorId,
                                                                 building: curPmResult.building_name,
                                                                 level: curPmResult.level_name,
                                                                 x: point.x, y: point.y, heading: point.heading,
                                                                 isUseHeading: false, mode: mode,
                                                                 paddingValues: JupiterMode.PADDING_VALUES_MEDIUM) else { return nil }
            var newResult = curPmResult
            newResult.x = pm.xyhs.x
            newResult.y = pm.xyhs.y
            guard let matchedLinks = PathMatcher.shared.getLinkInfosWithResult(sectorId: sectorId, result: newResult, checkAll: true) else { return nil }
            if let _pre = preLinks, let _preIxyhs = preIxyhs {
                let curLinkGroupNums = Set(matchedLinks.map{$0.group_number})
                let preLinkGroupNums = Set(_pre.map{$0.group_number})
                if !curLinkGroupNums.isDisjoint(with: preLinkGroupNums) {
                    let isReachable = isLinkReachableWithGroupSwitchLimit(nodeData: nodeData, linkData: linkData, from: _pre, to: matchedLinks, maxGroupSwitches: maxGroupSwitches).0
                    if !isReachable {
                        JupiterLogger.i(tag: "RecoveryManager", message: "(computeIntermediateLossByIndex) idx \(idx) fail -> [\(_preIxyhs.x),\(_preIxyhs.y)] to [\(pm.xyhs.x),\(pm.xyhs.y)] is not reachable")
                        JupiterLogger.i(tag: "RecoveryManager", message: "(computeIntermediateLossByIndex) pre \(_pre) link to matched \(matchedLinks) link is not reachable")
                        failCount += 1
                    }
                }
            }
            preIxyhs = pm.xyhs
            preLinks = matchedLinks
            if failCount >= FAIL_TH {
                JupiterLogger.i(tag: "RecoveryManager", message: "(computeIntermediateLossByIndex) : failCount= \(failCount)")
                return nil
            }
            
            let dx = pm.xyhs.x - point.x
            let dy = pm.xyhs.y - point.y
            let lossDist = sqrt(dx*dx + dy*dy)
            let headingList = pm.matchedHeadings
            var minDiffHeading = Float.greatestFiniteMagnitude
            if !headingList.isEmpty {
                for h in headingList {
                    let lossHeading = adjustHeading(point.heading, h)
                    if lossHeading < minDiffHeading {
                        minDiffHeading = lossHeading
                    }
                }
            }

            let lossPoint = LossPointResult(index: idx, traj: [point.x, point.y], pm: [pm.xyhs.x, pm.xyhs.y], lossDist: lossDist, lossHeading: minDiffHeading)
            lossPointResults.append(lossPoint)
        }
        
        return lossPointResults.isEmpty ? nil : lossPointResults
    }
    
    private func isLinkReachableWithGroupSwitchLimit(
        nodeData: [Int: NodeData],
        linkData: [Int: LinkData],
        from startLinks: [LinkData],
        to targetLinks: [LinkData],
        maxGroupSwitches: Int = 1
    ) -> (isReachable: Bool, switchCount: Int?) {
        guard !startLinks.isEmpty, !targetLinks.isEmpty else { return (false, nil) }
        if maxGroupSwitches < 0 { return (false, nil) }

        let startNums = Set(startLinks.map { $0.number })
        let targetNums = Set(targetLinks.map { $0.number })

        if !startNums.isDisjoint(with: targetNums) {
            return (true, 0)
        }

        var dist: [Int: Int] = [:]
        var front: [Int] = []
        var back: [Int] = []
        var backHead = 0

        for start in startLinks {
            dist[start.number] = 0
            front.append(start.number)
        }

        @inline(__always)
        func popFront() -> Int? {
            if let v = front.popLast() { return v }
            guard backHead < back.count else { return nil }
            let v = back[backHead]
            backHead += 1

            if backHead > 1024 && backHead * 2 > back.count {
                back.removeFirst(backHead)
                backHead = 0
            }
            return v
        }

        @inline(__always)
        func pushFront(_ v: Int) { front.append(v) }

        @inline(__always)
        func pushBack(_ v: Int) { back.append(v) }

        func neighbors(of link: LinkData) -> [Int] {
            var out: [Int] = []
            out.reserveCapacity(16)

            if let s = nodeData[link.start_node] {
                out.append(contentsOf: s.connected_links)
            }
            if let e = nodeData[link.end_node] {
                out.append(contentsOf: e.connected_links)
            }

            var unique: [Int] = []
            unique.reserveCapacity(out.count)
            for num in out {
                if num == link.number { continue }
                if unique.contains(num) { continue }
                unique.append(num)
            }
            return unique
        }

        while let curNum = popFront() {
            guard let curLink = linkData[curNum] else { continue }
            let curDist = dist[curNum] ?? Int.max
            if curDist > maxGroupSwitches { continue }

            for nbNum in neighbors(of: curLink) {
                guard let nbLink = linkData[nbNum] else { continue }

                let cost = (nbLink.group_number == curLink.group_number) ? 0 : 1
                let nd = curDist + cost
                if nd > maxGroupSwitches { continue }

                let prev = dist[nbNum] ?? Int.max
                if nd < prev {
                    dist[nbNum] = nd

                    if targetNums.contains(nbNum) {
                        return (true, nd)
                    }

                    if cost == 0 {
                        pushFront(nbNum)
                    } else {
                        pushBack(nbNum)
                    }
                }
            }
        }
        return (false, nil)
    }
    
    func calculateJupiterResult(lossParamAtEachCand: [CandidateResult], isLinkNotChanged: Bool) -> [SelectedCandidate] {
        guard !lossParamAtEachCand.isEmpty else { return [] }
        
        typealias ScoredCand = (cand: CandidateResult, loss: Float)
        
        var selected: [ScoredCand] = []
        selected.reserveCapacity(lossParamAtEachCand.count)
        
        if isLinkNotChanged {
            // 정상 주행 상태에서는 link group 전환이 많지 않은 후보만 허용
            for cand in lossParamAtEachCand {
                guard cand.linkGroupSwitchCount <= 1 else { continue }
                let penalty: Float = !cand.isInSameLinkGroup ? 2.0 : 1.0
                let loss = (cand.loss_lm + cand.loss_g_d + cand.loss_g_h) * penalty
                selected.append((cand: cand, loss: loss))
            }
        } else {
            // 1. cand.isInSameLinkGroup을 만족하는 후보군들은 반드시 포함
            for cand in lossParamAtEachCand where cand.isInSameLinkGroup {
                let penalty: Float = 1.0
                let loss = (cand.loss_lm + cand.loss_g_d + cand.loss_g_h) * penalty
                selected.append((cand: cand, loss: loss))
            }
            
            // 2. cand.isInSameLinkGroup과 무관하게 distWithRecentPeakResult 값이 가장 작은 후보군을 하나 뽑음
            if let minDistCand = lossParamAtEachCand.min(by: {
                ($0.distWithRecentPeakResult ?? Float.greatestFiniteMagnitude) < ($1.distWithRecentPeakResult ?? Float.greatestFiniteMagnitude)
            }) {
                let isAlreadyIncluded = selected.contains {
                    $0.cand.recent?.x == minDistCand.recent?.x &&
                    $0.cand.recent?.y == minDistCand.recent?.y &&
                    $0.cand.head.x == minDistCand.head.x &&
                    $0.cand.head.y == minDistCand.head.y
                }
                
                // 3. 2에서 뽑아낸 후보군이 기존 포함 후보가 아니면 추가
                if !isAlreadyIncluded {
                    let penalty: Float = 1.0
                    let loss = (minDistCand.loss_lm + minDistCand.loss_g_d + minDistCand.loss_g_h) * penalty
                    selected.append((cand: minDistCand, loss: loss))
                }
            }
        }
        
        selected.sort { lhs, rhs in
            if lhs.loss == rhs.loss {
                return (lhs.cand.distWithRecentPeakResult ?? Float.greatestFiniteMagnitude) < (rhs.cand.distWithRecentPeakResult ?? Float.greatestFiniteMagnitude)
            }
            return lhs.loss < rhs.loss
        }
        
        var results: [SelectedCandidate] = []
        results.reserveCapacity(min(2, selected.count))
        var seenKeys = Set<String>()
        
        for item in selected {
            let cand = item.cand
            let recentX = cand.recent?.x ?? -1
            let recentY = cand.recent?.y ?? -1
            let key = "\(recentX)_\(recentY)_\(cand.head.x)_\(cand.head.y)"
            if !seenKeys.insert(key).inserted { continue }
            
            let selectedCand = SelectedCandidate(older: cand.older,
                                                 recent: cand.recent,
                                                 links: cand.links,
                                                 linkGroups: cand.linkGroups,
                                                 traj: cand.traj,
                                                 tail: cand.tail,
                                                 head: cand.head,
                                                 headResult: cand.headResult,
                                                 loss: item.loss)
            
            if results.isEmpty {
                results.append(selectedCand)
            } else {
                let first = results[0]
                if let fRecent = first.recent, let sRecent = selectedCand.recent {
                    let dist = dist2(Float(fRecent.x), Float(fRecent.y), Float(sRecent.x), Float(sRecent.y))
                    if dist < 5 {
                        continue
                    } else {
                        results.append(selectedCand)
                    }
                }
            }
            
            if results.count == 2 { break }
        }
        
        return results
    }
    
    func selectCandidate(filtered: [SelectedCandidate]) -> (SelectedCandidate, Float)? {
        let TT_VERY_LOW: Float = 10
        let TT_LOW: Float = 20
        let TT_HIGH: Float = 30
        let RT_LOW: Float = 0.3
        let RT_HIGH: Float = 0.6
        
        guard !filtered.isEmpty else { return nil }
        
        let first = filtered[0]
        let second: SelectedCandidate? = filtered.count > 1 ? filtered[1] : nil
        
        guard let second = second else {
            JupiterLogger.i(tag: "SolutionEstimator", message: "(selectCandidate) only first remains // filtered size: \(filtered.count) // first: \(first.loss)")
            if first.loss > 40 {
                return nil
            } else {
                return (first, 0.0)
            }
        }
        
        let best = (first.loss <= second.loss) ? first : second
        let runnerUp = (first.loss <= second.loss) ? second : first

        if runnerUp.loss <= 0 {
            return (best, 0.0)
        }
        
        let ratio = best.loss / runnerUp.loss
        if best.loss < TT_VERY_LOW && second.loss < TT_VERY_LOW {
            let firstResult = best.headResult
            let secondResult = runnerUp.headResult
            let d = dist2(firstResult.x, firstResult.y, secondResult.x, secondResult.y)
            if d <= 10 {
                JupiterLogger.i(tag: "SolutionEstimator", message: "(selectCandidate) choice best (0) // best: \(best.loss) , ratio: \(ratio) , d: \(d)")
                return (best, ratio)
            } else {
                JupiterLogger.i(tag: "SolutionEstimator", message: "(selectCandidate) do not select // best & second ambiguos")
                return nil
            }
        } else if best.loss < TT_LOW && ratio < RT_HIGH  {
            JupiterLogger.i(tag: "SolutionEstimator", message: "(selectCandidate) choice best (1) // best: \(best.loss) , ratio: \(ratio)")
            return (best, ratio)
        } else if best.loss < TT_HIGH && ratio < RT_LOW {
            JupiterLogger.i(tag: "SolutionEstimator", message: "(selectCandidate) choice best (2) // best: \(best.loss) , ratio: \(ratio)")
            return (best, ratio)
        }
        JupiterLogger.i(tag: "SolutionEstimator", message: "(selectCandidate) do not select")
        JupiterLogger.i(tag: "SolutionEstimator", message: "(selectCandidate) first:[\(best.loss)] , second:[\(second.loss)] , ratio: \(ratio)")
        return nil
    }
    
    func calculateBadCaseResult(lossParamAtEachCand: [CandidateResult]) -> SelectedCandidate? {
        guard let best = lossParamAtEachCand.min(by: {
            let lhsLoss = $0.loss_lm + $0.loss_g_d + $0.loss_g_h
            let rhsLoss = $1.loss_lm + $1.loss_g_d + $1.loss_g_h
            return lhsLoss < rhsLoss
        }) else {
            return nil
        }
        
        let loss = best.loss_lm + best.loss_g_d + best.loss_g_h
        let selected = SelectedCandidate(older: best.older,
                                         recent: best.recent,
                                         links: best.links,
                                         linkGroups: best.linkGroups,
                                         traj: best.traj,
                                         tail: best.tail,
                                         head: best.head,
                                         headResult: best.headResult,
                                         loss: loss)
        
        return selected
    }
}
