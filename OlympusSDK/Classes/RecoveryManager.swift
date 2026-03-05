import Foundation
import TJLabsCommon
import TJLabsResource

class RecoveryManager {
    
    init(sectorId: Int) {
        self.sectorId = sectorId
    }
    
    var sectorId: Int
    private let pmGate = _PathMatcherGate()
    
    func getUvdBufferForRecovery(startIndex: Int, endIndex: Int, uvdBuffer: [UserVelocity]) -> [UserVelocity] {
        var slicedUvd = [UserVelocity]()
        for uvd in uvdBuffer {
            let uvdIndex = uvd.index
            if uvdIndex >= startIndex && uvdIndex <= endIndex {
                slicedUvd.append(uvd)
            }
        }
        
        return slicedUvd
    }
    
    func makeMultipleRecoveryTrajectory(uvdBuffer: [UserVelocity], majorSection: [Float], pathHeadings: [Float], endHeading: Float? = nil) -> [[RecoveryTrajectory]] {
        var trajList = [[RecoveryTrajectory]]()
//        JupiterLogger.i(tag: "RecoveryManager", message: "(makeMultipleRecoveryTrajectory) BadCase: pathHeadings= \(pathHeadings)")
        if !majorSection.isEmpty {
            let headingForCompensation = majorSection.average - uvdBuffer[0].heading
            
            for pathHeading in pathHeadings {
                let startHeading = Float(TJLabsUtilFunctions.shared.compensateDegree(Double(pathHeading) - Double(headingForCompensation)))
                var coord: [Float] = [0, 0]
                var heading: Float = startHeading
                
                var resultBuffer: [RecoveryTrajectory] = [RecoveryTrajectory(index: uvdBuffer[0].index, x: 0, y: 0, heading: startHeading)]
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
                    
                    resultBuffer.append(RecoveryTrajectory(index: curUvd.index, x: coord[0], y: coord[1], heading: heading))
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
    
    func recoverWithMultipleTraj(recoveryTrajList: [[RecoveryTrajectory]],
                                 userPeakAndLinksBuffer: [(UserPeak, [LinkData])],
                                 landmarks: (older: LandmarkData, recent: LandmarkData),
                                 curPmResult: FineLocationTrackingOutput,
                                 mode: UserMode) -> RecoveryResult? {
        let semaphore = DispatchSemaphore(value: 0)
        var output: RecoveryResult? = nil

        Task {
            output = await self.recoverWithMultipleTrajAsync(recoveryTrajList: recoveryTrajList,
                                                             userPeakAndLinksBuffer: userPeakAndLinksBuffer,
                                                             landmarks: landmarks,
                                                             curPmResult: curPmResult,
                                                             mode: mode)
            semaphore.signal()
        }

        semaphore.wait()
        return output
    }

    private func recoverWithMultipleTrajAsync(recoveryTrajList: [[RecoveryTrajectory]],
                                              userPeakAndLinksBuffer: [(UserPeak, [LinkData])],
                                              landmarks: (older: LandmarkData, recent: LandmarkData),
                                              curPmResult: FineLocationTrackingOutput,
                                              mode: UserMode) async -> RecoveryResult? {
        guard userPeakAndLinksBuffer.count >= 2 else { return nil }

        let olderUserPeak = userPeakAndLinksBuffer[userPeakAndLinksBuffer.count - 2].0
        let recentUserPeak = userPeakAndLinksBuffer[userPeakAndLinksBuffer.count - 1].0
        let recentUserLinks = userPeakAndLinksBuffer[userPeakAndLinksBuffer.count - 1].1
        let recentUserPeakIndex = recentUserPeak.peak_index

        JupiterLogger.i(tag: "RecoveryManager", message: "(recoverWithMultipleTrajAsync) olderPeakId: \(olderUserPeak.id), oldPeakIndex: \(olderUserPeak.peak_index), recentPeakId: \(recentUserPeak.id), recentPeakIndex: \(recentUserPeakIndex)")

        let olderLandmarkCands: [PeakData] = landmarks.older.peaks
        let recentLandmarkCands: [PeakData] = landmarks.recent.peaks

        let bestCandidate: _RecoveryCandidate? = await withTaskGroup(of: _RecoveryCandidate?.self) { group in
            for recoveryTraj in recoveryTrajList {
                group.addTask { [self, sectorId = self.sectorId] in
                    guard recoveryTraj.count >= 2 else { return nil }

                    var anchorIdx: Int? = nil
                    for i in 0..<recoveryTraj.count {
                        if recoveryTraj[i].index == recentUserPeakIndex {
                            anchorIdx = i
                            break
                        }
                    }
                    guard let aIdx = anchorIdx else { return nil }

                    var localBestLoss = Float.greatestFiniteMagnitude
                    var localBestShiftedTraj: [RecoveryTrajectory]? = nil
                    var localBestRecentCand: PeakData? = nil
                    var localBestOlderCand: PeakData? = nil
                    var localBestTail: FineLocationTrackingOutput? = nil
                    var localBestHead: FineLocationTrackingOutput? = nil
                    
                    for cand in recentLandmarkCands {
                        JupiterLogger.i(tag: "RecoveryManager", message: "(recoverWithMultipleTrajAsync) cand: [\(cand.x),\(cand.y)]")
                        let offsetX = Float(cand.x) - recoveryTraj[aIdx].x
                        let offsetY = Float(cand.y) - recoveryTraj[aIdx].y

                        var shiftedTraj: [RecoveryTrajectory] = []
                        shiftedTraj.reserveCapacity(recoveryTraj.count)
                        for p in recoveryTraj {
                            shiftedTraj.append(RecoveryTrajectory(index: p.index,
                                                                 x: p.x + offsetX,
                                                                 y: p.y + offsetY,
                                                                 heading: p.heading))
                        }
                        guard let first = shiftedTraj.first, let last = shiftedTraj.last else { continue }

                        // Tail PM
                        guard let tail = await self.pmGate.pathMatching(sectorId: sectorId,
                                                                       building: curPmResult.building_name,
                                                                       level: curPmResult.level_name,
                                                                       x: first.x,
                                                                       y: first.y,
                                                                       heading: first.heading,
                                                                       isUseHeading: false,
                                                                       mode: mode,
                                                                        paddingValues: JupiterMode.PADDING_VALUES_LARGE) else {
                            JupiterLogger.i(tag: "RecoveryManager", message: "(recoverWithMultipleTrajAsync) tail pm fail // [\(first.x),\(first.y),\(first.heading)]")
                            continue
                        }

                        var tailResult = curPmResult
                        tailResult.x = tail.x
                        tailResult.y = tail.y
                        tailResult.absolute_heading = tail.heading
                        
                        // Head PM
                        guard let head = await self.pmGate.pathMatching(sectorId: sectorId,
                                                                       building: curPmResult.building_name,
                                                                       level: curPmResult.level_name,
                                                                       x: last.x,
                                                                       y: last.y,
                                                                       heading: last.heading,
                                                                       isUseHeading: false,
                                                                       mode: mode,
                                                                       paddingValues: JupiterMode.PADDING_VALUES_LARGE) else {
                            JupiterLogger.i(tag: "RecoveryManager", message: "(recoverWithMultipleTrajAsync) head pm fail // [\(last.x),\(last.y),\(last.heading)]")
                            continue
                        }

                        var dist1 = Float.greatestFiniteMagnitude
                        var localOlderCand: PeakData? = nil

                        for oc in olderLandmarkCands {
                            var tmp = curPmResult
                            tmp.x = Float(oc.x)
                            tmp.y = Float(oc.y)

                            let peakDist = dist2(Float(oc.x), Float(oc.y), Float(cand.x), Float(cand.y))
                            if peakDist < 5 { continue }
                            tmp.absolute_heading = tail.heading

                            let d = dist2(Float(first.x), Float(first.y), Float(oc.x), Float(oc.y))
                            if d < dist1 {
                                dist1 = d
                                localOlderCand = oc
                            }
                        }

                        if dist1 == Float.greatestFiniteMagnitude {
                            dist1 = 1_000_000
                        }
                        
                        let residualIndices = buildIndicesBySizeAndBase(N: shiftedTraj.count, parts: 10)
                        JupiterLogger.i(tag: "RecoveryManager", message: "(recoverWithMultipleTrajAsync) shiftedTraj.count: \(shiftedTraj.count) -> residualIndices \(residualIndices)")
                        guard let lossPointResult = computeIntermediateLossByIndex(sectorId: sectorId,
                                                                                   curPmResult: curPmResult,
                                                                                   shiftedTraj: shiftedTraj,
                                                                                   targetIndices: residualIndices,
                                                                                   mode: mode) else {
                            JupiterLogger.i(tag: "RecoveryManager", message: "(recoverWithMultipleTrajAsync) lossPointResult fail")
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
                        
                        let loss_g_d: Float = lossDistSum
                        let loss_g_h: Float = lossHeadingSum
                        let loss_l = dist1
                        
                        let loss = loss_g_d + loss_g_h + loss_l
                        
                        if loss < localBestLoss {
                            localBestLoss = loss
                            localBestShiftedTraj = shiftedTraj
                            localBestRecentCand = cand
                            localBestOlderCand = localOlderCand

                            var bt = curPmResult
                            bt.x = tail.x
                            bt.y = tail.y
                            localBestTail = bt

                            var bh = curPmResult
                            bh.x = head.x
                            bh.y = head.y
                            localBestHead = bh
                        }
                    }

                    if let st = localBestShiftedTraj, let rc = localBestRecentCand {
                        return _RecoveryCandidate(loss: localBestLoss,
                                                 shiftedTraj: st,
                                                 recentCand: rc,
                                                 olderCand: localBestOlderCand,
                                                 tail: localBestTail,
                                                 head: localBestHead)
                    }
                    return nil
                }
            }

            var best: _RecoveryCandidate? = nil
            for await cand in group {
                guard let cand = cand else { continue }
                if best == nil || cand.loss < best!.loss {
                    best = cand
                }
            }
            return best
        }

        guard let best = bestCandidate else { return nil }
        
        var resultTraj = [[Double]]()
        resultTraj.reserveCapacity(best.shiftedTraj.count)
        for value in best.shiftedTraj {
            resultTraj.append([Double(value.x), Double(value.y)])
        }

        let bestOlder: [Int] = best.olderCand != nil ? [best.olderCand!.x, best.olderCand!.y] : [0, 0]
        let recoveryResult = RecoveryResult(traj: resultTraj,
                                            shiftedTraj: best.shiftedTraj,
                                            loss: best.loss,
                                            bestRecentCand: best.recentCand,
                                            bestOlder: bestOlder,
                                            bestResult: best.head)
        return recoveryResult
    }
    
    func searchWithMultipleTraj(recoveryTrajList: [[RecoveryTrajectory]],
                                userPeakBuffer: [UserPeak],
                                buildingLevelByUserPeak: (String, String),
                                landmarks: (older: LandmarkData, recent: LandmarkData),
                                mode: UserMode) -> RecoveryResult? {
        let semaphore = DispatchSemaphore(value: 0)
        var output: RecoveryResult? = nil

        Task {
            output = await self.searchWithMultipleTrajAsync(recoveryTrajList: recoveryTrajList,
                                                            userPeakBuffer: userPeakBuffer,
                                                            buildingLevelByUserPeak: buildingLevelByUserPeak,
                                                            landmarks: landmarks,
                                                            mode: mode)
            semaphore.signal()
        }

        semaphore.wait()
        return output
    }

    private func searchWithMultipleTrajAsync(recoveryTrajList: [[RecoveryTrajectory]],
                                             userPeakBuffer: [UserPeak],
                                             buildingLevelByUserPeak: (String, String),
                                             landmarks: (older: LandmarkData, recent: LandmarkData),
                                             mode: UserMode) async -> RecoveryResult? {
        guard userPeakBuffer.count >= 2 else { return nil }
        let building = buildingLevelByUserPeak.0
        let level = buildingLevelByUserPeak.1
        
        let olderUserPeak = userPeakBuffer[userPeakBuffer.count - 2]
        let recentUserPeak = userPeakBuffer[userPeakBuffer.count - 1]
        let recentUserPeakIndex = recentUserPeak.peak_index

        JupiterLogger.i(tag: "RecoveryManager", message: "(searchWithMultipleTrajAsync) olderPeakId: \(olderUserPeak.id), oldPeakIndex: \(olderUserPeak.peak_index), recentPeakId: \(recentUserPeak.id), recentPeakIndex: \(recentUserPeakIndex)")

        let olderLandmarkCands: [PeakData] = landmarks.older.peaks
        let recentLandmarkCands: [PeakData] = landmarks.recent.peaks

        let bestCandidate: _RecoveryCandidate? = await withTaskGroup(of: _RecoveryCandidate?.self) { group in
            for recoveryTraj in recoveryTrajList {
                group.addTask { [self, sectorId = self.sectorId] in
                    guard recoveryTraj.count >= 2 else { return nil }

                    var anchorIdx: Int? = nil
                    for i in 0..<recoveryTraj.count {
                        if recoveryTraj[i].index == recentUserPeakIndex {
                            anchorIdx = i
                            break
                        }
                    }
                    guard let aIdx = anchorIdx else { return nil }

                    var localBestLoss = Float.greatestFiniteMagnitude
                    var localBestShiftedTraj: [RecoveryTrajectory]? = nil
                    var localBestRecentCand: PeakData? = nil
                    var localBestOlderCand: PeakData? = nil
                    var localBestTail: FineLocationTrackingOutput? = nil
                    var localBestHead: FineLocationTrackingOutput? = nil
                    
                    for cand in recentLandmarkCands {
                        JupiterLogger.i(tag: "RecoveryManager", message: "(searchWithMultipleTrajAsync) cand: [\(cand.x),\(cand.y)]")
                        let offsetX = Float(cand.x) - recoveryTraj[aIdx].x
                        let offsetY = Float(cand.y) - recoveryTraj[aIdx].y

                        var shiftedTraj: [RecoveryTrajectory] = []
                        shiftedTraj.reserveCapacity(recoveryTraj.count)
                        for p in recoveryTraj {
                            shiftedTraj.append(RecoveryTrajectory(index: p.index,
                                                                 x: p.x + offsetX,
                                                                 y: p.y + offsetY,
                                                                 heading: p.heading))
                        }
                        guard let first = shiftedTraj.first, let last = shiftedTraj.last else { continue }

                        // Tail PM
                        guard let tail = await self.pmGate.pathMatching(sectorId: sectorId,
                                                                       building: building,
                                                                       level: level,
                                                                       x: first.x,
                                                                       y: first.y,
                                                                       heading: first.heading,
                                                                       isUseHeading: false,
                                                                       mode: mode,
                                                                        paddingValues: JupiterMode.PADDING_VALUES_LARGE) else {
                            JupiterLogger.i(tag: "RecoveryManager", message: "(searchWithMultipleTrajAsync) tail pm fail // [\(first.x),\(first.y),\(first.heading)]")
                            continue
                        }
                        
                        // Head PM
                        guard let head = await self.pmGate.pathMatching(sectorId: sectorId,
                                                                       building: building,
                                                                       level: level,
                                                                       x: last.x,
                                                                       y: last.y,
                                                                       heading: last.heading,
                                                                       isUseHeading: false,
                                                                       mode: mode,
                                                                       paddingValues: JupiterMode.PADDING_VALUES_LARGE) else {
                            JupiterLogger.i(tag: "RecoveryManager", message: "(searchWithMultipleTrajAsync) head pm fail // [\(last.x),\(last.y),\(last.heading)]")
                            continue
                        }
                        JupiterLogger.i(tag: "RecoveryManager", message: "(searchWithMultipleTrajAsync) : tail Heading=\(first.heading) , head Heading=\(last.heading)")
                        var dist1 = Float.greatestFiniteMagnitude
                        var localOlderCand: PeakData? = nil

                        for oc in olderLandmarkCands {
                            let ocX = Float(oc.x)
                            let ocY = Float(oc.y)
                            
                            let peakDist = dist2(ocX, ocY, Float(cand.x), Float(cand.y))
                            if peakDist < 5 { continue }
                            
                            let d = dist2(Float(first.x), Float(first.y), ocX, ocY)
                            if d < dist1 {
                                dist1 = d
                                localOlderCand = oc
                            }
                        }

                        if dist1 == Float.greatestFiniteMagnitude {
                            dist1 = 1_000_000
                        }
                        
                        let curPmResult = FineLocationTrackingOutput(mobile_time: 0, index: recoveryTraj[0].index, building_name: building, level_name: level, scc: 1.0, x: 0, y: 0, absolute_heading: 0)
                        let residualIndices = buildIndicesBySizeAndBase(N: shiftedTraj.count, parts: 10)
                        JupiterLogger.i(tag: "RecoveryManager", message: "(searchWithMultipleTrajAsync) shiftedTraj.count: \(shiftedTraj.count) -> residualIndices \(residualIndices)")
                        guard let lossPointResult = computeIntermediateLossByIndex(sectorId: sectorId,
                                                                                   curPmResult: curPmResult,
                                                                                   shiftedTraj: shiftedTraj,
                                                                                   targetIndices: residualIndices,
                                                                                   mode: mode) else {
                            JupiterLogger.i(tag: "RecoveryManager", message: "(searchWithMultipleTrajAsync) lossPointResult fail")
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
                        
                        let loss_g_d: Float = lossDistSum
                        let loss_g_h: Float = lossHeadingSum
                        let loss_l = dist1
                        
                        let loss = loss_g_d + loss_g_h + loss_l
                        
                        if loss < localBestLoss {
                            localBestLoss = loss
                            localBestShiftedTraj = shiftedTraj
                            localBestRecentCand = cand
                            localBestOlderCand = localOlderCand

                            var bt = curPmResult
                            bt.x = tail.x
                            bt.y = tail.y
                            bt.absolute_heading = tail.heading
                            localBestTail = bt

                            var bh = curPmResult
                            bh.x = head.x
                            bh.y = head.y
                            bh.absolute_heading = head.heading
                            localBestHead = bh
                        }
                    }

                    if let st = localBestShiftedTraj, let rc = localBestRecentCand {
                        return _RecoveryCandidate(loss: localBestLoss,
                                                  shiftedTraj: st,
                                                  recentCand: rc,
                                                  olderCand: localBestOlderCand,
                                                  tail: localBestTail,
                                                  head: localBestHead)
                    }
                    return nil
                }
            }

            var best: _RecoveryCandidate? = nil
            for await cand in group {
                guard let cand = cand else { continue }
                if best == nil || cand.loss < best!.loss {
                    best = cand
                }
            }
            return best
        }

        guard let best = bestCandidate else { return nil }
        
        var resultTraj = [[Double]]()
        resultTraj.reserveCapacity(best.shiftedTraj.count)
        for value in best.shiftedTraj {
            resultTraj.append([Double(value.x), Double(value.y)])
        }

        let bestOlder: [Int] = best.olderCand != nil ? [best.olderCand!.x, best.olderCand!.y] : [0, 0]
        let recoveryResult = RecoveryResult(traj: resultTraj,
                                            shiftedTraj: best.shiftedTraj,
                                            loss: best.loss,
                                            bestRecentCand: best.recentCand,
                                            bestOlder: bestOlder,
                                            bestResult: best.head)
        return recoveryResult
    }
    
    func trackWith2Peaks(trackingTrajList: [[RecoveryTrajectory]],
                         userPeakAndLinksBuffer: [(UserPeak, [LinkData])],
                         landmarks: (older: LandmarkData, recent: LandmarkData),
                         tuResultWhenRecentPeak: ixyhs,
                         curPmResult: FineLocationTrackingOutput,
                         mode: UserMode,
                         matchedNode: NodeData?,
                         distBestOnly: Bool = true) -> [RecoveryResult] {
        let semaphore = DispatchSemaphore(value: 0)
        var output: [RecoveryResult] = []

        Task {
            output = await self.trackWith2PeaksAsync(trackingTrajList: trackingTrajList,
                                                     userPeakAndLinksBuffer: userPeakAndLinksBuffer,
                                                     landmarks: landmarks,
                                                     tuResultWhenRecentPeak: tuResultWhenRecentPeak,
                                                     curPmResult: curPmResult,
                                                     mode: mode,
                                                     matchedNode: matchedNode,
                                                     distBestOnly: distBestOnly)
            semaphore.signal()
        }

        semaphore.wait()
        return output
    }
    
    private func trackWith2PeaksAsync(trackingTrajList: [[RecoveryTrajectory]],
                                      userPeakAndLinksBuffer: [(UserPeak, [LinkData])],
                                      landmarks: (older: LandmarkData, recent: LandmarkData),
                                      tuResultWhenRecentPeak: ixyhs,
                                      curPmResult: FineLocationTrackingOutput,
                                      mode: UserMode,
                                      matchedNode: NodeData?,
                                      distBestOnly: Bool) async -> [RecoveryResult] {
        guard userPeakAndLinksBuffer.count >= 2 else { return [] }
        let key = "\(sectorId)_\(curPmResult.building_name)_\(curPmResult.level_name)"
        guard let nodeData = PathMatcher.shared.nodeData[key], let linkData = PathMatcher.shared.linkData[key] else { return [] }

        let curLinkForConnectionCheck: LinkData? = await self.pmGate.getLinkInfoWithResult(sectorId: sectorId,
                                                                                           result: curPmResult,
                                                                                           checkAll: true,
                                                                                           acceptDist: 15)
        var isInNode = false
        if let _ = matchedNode {
            isInNode = true
        }
        JupiterLogger.i(tag: "RecoveryManager", message: "(trackWith2PeaksAsync) curPmResult [\(curPmResult.x),\(curPmResult.y),\(curPmResult.absolute_heading)] is in \(curLinkForConnectionCheck?.number) , isInNode = \(isInNode)")
        
        let olderUserPeak = userPeakAndLinksBuffer[userPeakAndLinksBuffer.count - 2].0
        let olderUserLinks = userPeakAndLinksBuffer[userPeakAndLinksBuffer.count - 2].1
        
        let recentUserPeak = userPeakAndLinksBuffer[userPeakAndLinksBuffer.count - 1].0
        let recentUserLinks = userPeakAndLinksBuffer[userPeakAndLinksBuffer.count - 1].1
        let recentUserGroupNums = recentUserLinks.map{$0.group_number}
        let recentUserPeakIndex = recentUserPeak.peak_index
        
        let olderLandmarkCands: [PeakData] = landmarks.older.peaks
        let recentLandmarkCands: [PeakData] = landmarks.recent.peaks
        
        let passPenalty = !distBestOnly
        JupiterLogger.i(tag: "RecoveryManager", message: "(trackWith2PeaksAsync) distBestOnly: \(distBestOnly)")
        let allCandidates: [_RecoveryCandidate] = await withTaskGroup(of: [_RecoveryCandidate].self) { group in
            for trackingTraj in trackingTrajList {
                group.addTask { [self,
                                 sectorId = self.sectorId,
                                 nodeData = nodeData,
                                 linkData = linkData,
                                 curLinkForConnectionCheck = curLinkForConnectionCheck,
                                 distBestOnly = distBestOnly] in
                    guard trackingTraj.count >= 2 else { return [] }
                    var anchorIdx: Int? = nil
                    for i in 0..<trackingTraj.count {
                        if trackingTraj[i].index == recentUserPeakIndex {
                            anchorIdx = i
                            break
                        }
                    }
                    guard let aIdx = anchorIdx else { return [] }

                    var localCandidates: [_RecoveryCandidate] = []
                    localCandidates.reserveCapacity(64)
                    
                    var selectedCands: [(PeakData, Int, Int, Bool, Float)] = []  // (cand, candGroupNum, candLinkNum, penalty)
                    selectedCands.reserveCapacity(recentLandmarkCands.count)
                    var selectedCandKeySet = Set<PeakXYKey>()
                    
                    var inLinkBest: (cand: PeakData, dist: Float)? = nil

                    // Out-of-group candidate policy
                    // - distBestOnly == true  : keep only the single best *directly connectable* candidate
                    // - distBestOnly == false : allow up to OUT_GROUP_MAX candidates reachable within 3 link-groups
                    let DBEST_GROUP_MAX: Int = 20

                    var dbestLinkGroupNum: Int?
                    var dbestLinkNum: Int?
                    var connectableBest: (cand: PeakData, dist: Float)? = nil

                    var dbestGroupPool: [(cand: PeakData, groupNum: Int, linkNum: Int, dist: Float)] = []
                    dbestGroupPool.reserveCapacity(16)

                    for cand in recentLandmarkCands {
                        let candLinkNums = cand.matched_links
                        var candLinkGroupNums: Set<Int> = []
                        for cNum in candLinkNums {
                            guard let matchedLinkWithCand = linkData[cNum] else { continue }
                            candLinkGroupNums.insert(matchedLinkWithCand.group_number)
                        }
                        JupiterLogger.i(tag: "RecoveryManager", message: "(trackWith2PeaksAsync) candLinkGroupNums= \(candLinkGroupNums)")
                        
                        var candResult = curPmResult
                        candResult.x = Float(cand.x)
                        candResult.y = Float(cand.y)
                        guard let candLink = await self.pmGate.getLinkInfoWithResult(sectorId: sectorId,
                                                                                     result: candResult,
                                                                                     checkAll: true,
                                                                                     acceptDist: 15) else { continue }
                        JupiterLogger.i(tag: "RecoveryManager", message: "(trackWith2PeaksAsync) candLink : number= \(candLink.number) , group_number= \(candLink.group_number) , xy= [\(cand.x),\(cand.y)]")
                        
                        for recentUserLink in recentUserLinks {
                            let d = self.dist2(Float(cand.x), Float(cand.y), Float(tuResultWhenRecentPeak.x), Float(tuResultWhenRecentPeak.y))
                            JupiterLogger.i(tag: "RecoveryManager", message: "(trackWith2PeaksAsync) recentUserLink : [n:\(recentUserLink.number), gn:\(recentUserLink.group_number)]")
                            var isInSameLinkGroup = false
                            if let matchedNode = matchedNode {
                                var groupNumSet: Set<Int> = []
                                for cLinkNum in matchedNode.connected_links {
                                    if let cLink = linkData[cLinkNum] {
                                        groupNumSet.insert(cLink.group_number)
                                    }
                                }
                                if !groupNumSet.isDisjoint(with: candLinkGroupNums) {
                                    isInSameLinkGroup = true
                                }
                            } else if candLinkGroupNums.contains(recentUserLink.group_number) {
                                isInSameLinkGroup = true
                            }
                            
                            if isInSameLinkGroup {
                                if let best = inLinkBest {
                                    if d < best.dist {
                                        inLinkBest = (cand: cand, dist: d)
                                    }
                                } else {
                                    inLinkBest = (cand: cand, dist: d)
                                }
                                
                                let candKey = PeakXYKey(
                                    x: cand.x,
                                    y: cand.y
                                )

                                if selectedCandKeySet.insert(candKey).inserted {
                                    selectedCands.append((cand, candLink.group_number, candLink.number, true, 1.0))
                                    JupiterLogger.i(tag: "RecoveryManager", message: "(trackWith2PeaksAsync) cand is inserted isInSameLinkGroup // cand [x:\(cand.x), y:\(cand.y), ln:\(candLink.number), lgn:\(candLink.group_number)]")
                                    continue
                                }
                            }

                            if distBestOnly {
                                let reachableWithinGroup = self.isLinkReachableWithGroupSwitchLimit(
                                    nodeData: nodeData,
                                    linkData: linkData,
                                    from: recentUserLink,
                                    to: candLink,
                                    maxGroupSwitches: 2
                                )
                                
                                JupiterLogger.i(tag: "RecoveryManager", message: "(trackWith2PeaksAsync) {distBestOnly true} reachableWithinGroup: from \(recentUserLink.number) to \(candLink.number) is \(reachableWithinGroup)")
                                guard reachableWithinGroup else { continue }
                                
                                if let best = connectableBest {
                                    if d < best.dist {
                                        connectableBest = (cand: cand, dist: d)
                                        dbestLinkGroupNum = candLink.group_number
                                        dbestLinkNum = candLink.number
                                    }
                                } else {
                                    connectableBest = (cand: cand, dist: d)
                                    dbestLinkGroupNum = candLink.group_number
                                    dbestLinkNum = candLink.number
                                }
                            } else {
                                let reachableWithin3Groups = self.isLinkReachableWithGroupSwitchLimit(
                                    nodeData: nodeData,
                                    linkData: linkData,
                                    from: recentUserLink,
                                    to: candLink,
                                    maxGroupSwitches: 2
                                )
                                JupiterLogger.i(tag: "RecoveryManager", message: "(trackWith2PeaksAsync) {distBestOnly false} reachableWithin3Groups: from \(recentUserLink.number) to \(candLink.number) is \(reachableWithin3Groups)")
                                guard reachableWithin3Groups else { continue }
                                dbestGroupPool.append((cand: cand, groupNum: candLink.group_number, linkNum: candLink.number, dist: d))
                            }
                        }
                    }
                    JupiterLogger.i(tag: "RecoveryManager", message: "(trackWith2PeaksAsync) inLinkBest: \(inLinkBest)")
                    JupiterLogger.i(tag: "RecoveryManager", message: "(trackWith2PeaksAsync) connectableBest: \(connectableBest)")
                    JupiterLogger.i(tag: "RecoveryManager", message: "(trackWith2PeaksAsync) dbestLinkPool: \(dbestGroupPool.map{$0.linkNum})")
                    JupiterLogger.i(tag: "RecoveryManager", message: "(trackWith2PeaksAsync) dbestGroupPool: \(dbestGroupPool.map{$0.groupNum})")

                    if distBestOnly {
                        if let inLinkBest = inLinkBest, let distBest = connectableBest {
                            if distBest.dist > inLinkBest.dist {
                                connectableBest = nil
                            }
                        }

                        if let extra = connectableBest?.cand, let extraGroupNum = dbestLinkGroupNum, let extraLinkNum = dbestLinkNum {
                            let extraCands = selectedCands.map{ $0.0 as PeakData }
                            if !extraCands.contains(where: { $0.x == extra.x && $0.y == extra.y && $0.rssi == extra.rssi }) {
                                let candKey = PeakXYKey(
                                    x: extra.x,
                                    y: extra.y
                                )

                                if selectedCandKeySet.insert(candKey).inserted {
                                    selectedCands.append((extra, extraGroupNum, extraLinkNum, false, 2.0))
                                }
                            }
                        }
                    } else {
                        dbestGroupPool.sort { $0.dist < $1.dist }
                        if dbestGroupPool.count > DBEST_GROUP_MAX {
                            dbestGroupPool = Array(dbestGroupPool.prefix(DBEST_GROUP_MAX))
                        }

                        let existing = selectedCands.map { $0.0 as PeakData }
                        for item in dbestGroupPool {
                            let cand = item.cand
                            if existing.contains(where: { $0.x == cand.x && $0.y == cand.y && $0.rssi == cand.rssi }) {
                                continue
                            }
                            
                            let candKey = PeakXYKey(
                                x: cand.x,
                                y: cand.y
                            )

                            if selectedCandKeySet.insert(candKey).inserted {
                                selectedCands.append((cand, item.groupNum, item.linkNum, false, 2.0))
                            }
                        }
                    }
                    JupiterLogger.i(tag: "RecoveryManager", message: "(trackWith2PeaksAsync) selectedCands: groupNums = \(selectedCands.map{$0.1})")
                    JupiterLogger.i(tag: "RecoveryManager", message: "(trackWith2PeaksAsync) selectedCands: linkNums = \(selectedCands.map{$0.2})")
                    for candTuple in selectedCands {
                        let cand = candTuple.0
                        let candLinkGroupNum = candTuple.1
                        let candLinkNum = candTuple.2
                        let isInSameLink = candTuple.3
                        let candPenalty = candTuple.4
                        
                        JupiterLogger.i(tag: "RecoveryManager", message: "(trackWith2PeaksAsync) selectedCands: [\(cand.x),\(cand.y)], groupNum:\(candLinkGroupNum), linkNum:\(candLinkNum)")
                        
                        let offsetX = Float(cand.x) - trackingTraj[aIdx].x
                        let offsetY = Float(cand.y) - trackingTraj[aIdx].y

                        var shiftedTraj: [RecoveryTrajectory] = []
                        shiftedTraj.reserveCapacity(trackingTraj.count)
                        for p in trackingTraj {
                            shiftedTraj.append(RecoveryTrajectory(index: p.index,
                                                                  x: p.x + offsetX,
                                                                  y: p.y + offsetY,
                                                                  heading: p.heading))
                        }
                        guard let first = shiftedTraj.first, let last = shiftedTraj.last else { continue }

                        // Tail PM
                        guard let tail = await self.pmGate.pathMatching(sectorId: sectorId,
                                                                        building: curPmResult.building_name,
                                                                        level: curPmResult.level_name,
                                                                        x: first.x,
                                                                        y: first.y,
                                                                        heading: first.heading,
                                                                        isUseHeading: false,
                                                                        mode: mode,
                                                                        paddingValues: JupiterMode.PADDING_VALUES_LARGE) else {
                            JupiterLogger.i(tag: "RecoveryManager", message: "(trackWith2PeaksAsync) tail pm fail // cand:[\(cand.x),\(cand.y)] // first:[\(first.x),\(first.y)]")
                            continue }

                        var tailResult = curPmResult
                        tailResult.x = tail.x
                        tailResult.y = tail.y
                        tailResult.absolute_heading = tail.heading

                        guard let tailLink = await self.pmGate.getLinkInfoWithResult(sectorId: sectorId,
                                                                                     result: tailResult,
                                                                                     checkAll: true, acceptDist: 15) else {
                            JupiterLogger.i(tag: "RecoveryManager", message: "(trackWith2PeaksAsync) tail link fail // cand:[\(cand.x),\(cand.y)]")
                            continue
                        }
                        let tailLinkGroupNum = tailLink.group_number
                        
                        let isUseHeading = distBestOnly ? false : true
                        // Head PM
                        guard let head = await self.pmGate.pathMatching(sectorId: sectorId,
                                                                        building: curPmResult.building_name,
                                                                        level: curPmResult.level_name,
                                                                        x: last.x,
                                                                        y: last.y,
                                                                        heading: last.heading,
                                                                        isUseHeading: isUseHeading,
                                                                        mode: mode,
                                                                        paddingValues: JupiterMode.PADDING_VALUES_LARGE) else {
                            JupiterLogger.i(tag: "RecoveryManager", message: "(trackWith2PeaksAsync) head pm fail // cand:[\(cand.x),\(cand.y)] // last:[\(last.x),\(last.y),\(last.heading)]")
                            continue
                        }

                        if !distBestOnly {
                            guard let curLink = curLinkForConnectionCheck else { continue }

                            var headResult = curPmResult
                            headResult.x = head.x
                            headResult.y = head.y
                            headResult.absolute_heading = head.heading

                            guard let headLinks = await self.pmGate.getLinkInfosWithResult(sectorId: sectorId,
                                                                                          result: headResult,
                                                                                          checkAll: true,
                                                                                          acceptDist: 15) else {
                                JupiterLogger.i(tag: "RecoveryManager", message: "(trackWith2PeaksAsync) head link fail // headResult:[\(headResult.x),\(headResult.y)]")
                                continue
                            }
                            
                            
                            let headNode = await self.pmGate.getNodeInfoWithResult(sectorId: sectorId, result: headResult)
                            let isHeadInNode = headNode == nil ? false : true
                            let headLinkGroupNums = headLinks.map{$0.group_number}
                            if headLinkGroupNums.contains(curLink.group_number) && !isHeadInNode && !head.headingFail && curPmResult.absolute_heading != head.heading {
                                JupiterLogger.i(tag: "RecoveryManager", message: "(trackWith2PeaksAsync) headPos = [\(head.x),\(head.y),\(head.heading)]")
                                JupiterLogger.i(tag: "RecoveryManager", message: "(trackWith2PeaksAsync) headLink and curLink is in same group")
                                continue
                            }
                            
                            for headLink in headLinks {
                                let reachable = self.isLinkReachableWithGroupSwitchLimit(nodeData: nodeData,
                                                                                        linkData: linkData,
                                                                                        from: curLink,
                                                                                        to: headLink,
                                                                                        maxGroupSwitches: 1)
                                JupiterLogger.i(tag: "RecoveryManager", message: "(trackWith2PeaksAsync) reachable fail //  headPos = [\(head.x),\(head.y)] // curLink:\(curLink.number) -> headLink:\(headLink.number)")
                                if !reachable {
                                    continue
                                }
                            }
                        }

                        var dist1 = Float.greatestFiniteMagnitude
                        var localOlderCand: PeakData? = nil

                        for oc in olderLandmarkCands {
                            var tmp = curPmResult
                            tmp.x = Float(oc.x)
                            tmp.y = Float(oc.y)

                            let peakDist = dist2(Float(oc.x), Float(oc.y), Float(cand.x), Float(cand.y))
                            if peakDist < 5 { continue }
                            tmp.absolute_heading = tail.heading

                            let d = dist2(Float(first.x), Float(first.y), Float(oc.x), Float(oc.y))
                            if d < dist1 {
                                dist1 = d
                                localOlderCand = oc
                            }
                        }

                        if dist1 == Float.greatestFiniteMagnitude {
                            dist1 = 1_000_000
                        }
                        
                        // 이부분에서 tail~head까지
                        let residualIndices = buildIndicesBySizeAndBase(N: shiftedTraj.count, parts: 10)
                        guard let lossPointResult = computeIntermediateLossByIndex(sectorId: sectorId,
                                                                                   curPmResult: curPmResult,
                                                                                   shiftedTraj: shiftedTraj,
                                                                                   targetIndices: residualIndices,
                                                                                   mode: mode) else { continue }
                        
                        let penalty: Float = !isInSameLink && !passPenalty ? candPenalty : 1.0
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
                        
                        let loss_g_d: Float = lossDistSum
                        let loss_g_h: Float = lossHeadingSum
                        let loss_l = dist1
                        
                        let loss = (loss_g_d + loss_g_h + loss_l) * penalty
                        JupiterLogger.i(tag: "RecoveryManager", message: "(trackWith2PeaksAsync) cand:\(cand.x),\(cand.y), loss_l:\(loss_l), loss_g_d:\(loss_g_d), loss_g_h:\(loss_g_h), loss:\(loss), penalty:\(penalty)")

                        var bt = curPmResult
                        bt.x = tail.x
                        bt.y = tail.y

                        var bh = curPmResult
                        bh.x = head.x
                        bh.y = head.y

                        localCandidates.append(
                            _RecoveryCandidate(loss: loss,
                                                   shiftedTraj: shiftedTraj,
                                                   recentCand: cand,
                                                   olderCand: localOlderCand,
                                                   tail: bt,
                                                   head: bh)
                        )
                        _ = tailLinkGroupNum
                    }
                    return localCandidates
                }
            }

            var all: [_RecoveryCandidate] = []
            all.reserveCapacity(256)

            for await list in group {
                all.append(contentsOf: list)
            }
            
            all.sort { $0.loss < $1.loss }
            let topN = Array(all)
            JupiterLogger.i(tag: "RecoveryManager", message: "(trackWith2PeaksAsync) candidates=\(all.count), top1=\(topN.first?.loss), top2=\(topN.count > 1 ? topN[1].loss : nil)")
            return topN
        }
        
        let candidates = allCandidates
        guard !candidates.isEmpty else { return [] }
        var results: [RecoveryResult] = []

        for cand in candidates {
            var resultTraj = [[Double]]()
            resultTraj.reserveCapacity(cand.shiftedTraj.count)
            for value in cand.shiftedTraj {
                resultTraj.append([Double(value.x), Double(value.y)])
            }

            let bestOlder: [Int] = cand.olderCand != nil ? [cand.olderCand!.x, cand.olderCand!.y] : [0, 0]
            let recoveryResult = RecoveryResult(traj: resultTraj,
                                                shiftedTraj: cand.shiftedTraj,
                                                loss: cand.loss,
                                                bestRecentCand: cand.recentCand,
                                                bestOlder: bestOlder,
                                                bestResult: cand.head,
                                                curLinkNum: curLinkForConnectionCheck?.number,
                                                curGroupNum: curLinkForConnectionCheck?.group_number)
            results.append(recoveryResult)
        }
        return results
    }
    
    func selectRecoveryResult(list: [RecoveryResult], alwaysFirst: Bool = false, linkConnection: Bool = false) -> (RecoveryResult, Float)? {
        let TT_LOW: Float = 20
        let TT_HIGH: Float = 30
        let RT_LOW: Float = 0.3
        let RT_HIGH: Float = 0.6
        let COORD_DIST_TH: Float = 5
        
        guard !list.isEmpty else { return nil }

        if linkConnection {
            let firstForKey = list[0]
            let key = "\(sectorId)_\(firstForKey.bestResult!.building_name)_\(firstForKey.bestResult!.level_name)"
            if let nodeData = PathMatcher.shared.nodeData[key],
               let linkData = PathMatcher.shared.linkData[key] {
                for r in list {
                    guard let curLinkNum = r.curLinkNum, let curLink = linkData[curLinkNum] else { continue }
                    let candLinkNums = r.bestRecentCand.matched_links
                    for num in candLinkNums {
                        guard let candLink = linkData[num] else { continue }
                        let ok = self.isLinkReachableWithGroupSwitchLimit(nodeData: nodeData,
                                                                          linkData: linkData,
                                                                          from: curLink,
                                                                          to: candLink,
                                                                          maxGroupSwitches: 2)
                        if ok {
                            JupiterLogger.i(tag: "RecoveryManager",
                                            message: "(selectRecoveryResult) linkConnection=true -> pick first connectable within 3 group_num // curLink=\(curLinkNum), candLink=\(candLink.number), curGroup=\(curLink.group_number), candGroup=\(candLink.group_number), loss=\(r.loss)")
                            return (r, 0.0)
                        }
                    }
                }
            }
        }
        
        let first = list[0]
        let firstCoord = [first.bestRecentCand.x, first.bestRecentCand.y]
        
        var second: RecoveryResult?
        for r in list {
            let rCoord = [r.bestRecentCand.x, r.bestRecentCand.y]
            if firstCoord.count >= 2 && rCoord.count >= 2 {
                let fx = Float(firstCoord[0])
                let fy = Float(firstCoord[1])
                let sx = Float(rCoord[0])
                let sy = Float(rCoord[1])
                let coordDist = self.dist2(fx, fy, sx, sy)
                if coordDist > COORD_DIST_TH {
                    second = r
                    break
                }
            }
        }
        
        if alwaysFirst {
            JupiterLogger.i(tag: "RecoveryManager", message: "(selectRecoveryResult) alwaysFirst // first: \(first.loss)")
            return (first, 0.0)
        }
        
        guard let second = second else {
            JupiterLogger.i(tag: "RecoveryManager", message: "(selectRecoveryResult) only first remains // list size: \(list.count) // first: \(first.loss)")
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

        if best.loss < TT_LOW && ratio < RT_HIGH  {
            JupiterLogger.i(tag: "RecoveryManager", message: "(selectRecoveryResult) choice best (1) // best: \(best.loss) , ratio: \(ratio)")
            return (best, ratio)
        } else if best.loss < TT_HIGH && ratio < RT_LOW {
            JupiterLogger.i(tag: "RecoveryManager", message: "(selectRecoveryResult) choice best (2) // best: \(best.loss) , ratio: \(ratio)")
            return (best, ratio)
        }
        JupiterLogger.i(tag: "RecoveryManager", message: "(selectRecoveryResult) do not select")
        JupiterLogger.i(tag: "RecoveryManager", message: "(selectRecoveryResult) first:[\(best.loss)] , second:[\(second.loss)] , ratio: \(ratio)")
        return nil
    }
    
    private actor _PathMatcherGate {
        func pathMatching(sectorId: Int,
                          building: String,
                          level: String,
                          x: Float,
                          y: Float,
                          heading: Float,
                          isUseHeading: Bool,
                          mode: UserMode,
                          paddingValues: [Float]) -> ixyhs? {
            return PathMatcher.shared.pathMatching(sectorId: sectorId,
                                                 building: building,
                                                 level: level,
                                                 x: x,
                                                 y: y,
                                                 heading: heading,
                                                 isUseHeading: isUseHeading,
                                                 mode: mode,
                                                 paddingValues: paddingValues)
        }

        func getLinkInfoWithResult(sectorId: Int,
                                   result: FineLocationTrackingOutput,
                                   checkAll: Bool, acceptDist: Float = 5) -> LinkData? {
            return PathMatcher.shared.getLinkInfoWithResult(sectorId: sectorId,
                                                            result: result,
                                                            checkAll: checkAll,
                                                            acceptDist: acceptDist)
        }
        
        func getLinkInfosWithResult(sectorId: Int,
                                    result: FineLocationTrackingOutput,
                                    checkAll: Bool, acceptDist: Float = 5) -> [LinkData]? {
             return PathMatcher.shared.getLinkInfosWithResult(sectorId: sectorId,
                                                             result: result,
                                                             checkAll: checkAll,
                                                             acceptDist: acceptDist)
         }
        
        func getNodeInfoWithResult(sectorId: Int,
                                   result: FineLocationTrackingOutput) -> NodeData? {
            return PathMatcher.shared.getNodeInfoWithResult(sectorId: sectorId, result: result)
        }
    }

    func getRecoveryRange(olderPeakIndex: Int, curIndex: Int) -> Float {
        let defaultRange: Float = 50
        let diffIndex = curIndex - olderPeakIndex
        let range = abs(Float(diffIndex)*1.5)
        return min(defaultRange, range)
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
    
    // 3Peaks
    func recoverWith3Peaks(recoveryTrajList: [[RecoveryTrajectory]],
                           userPeakAndLinkBuffer: [(UserPeak, LinkData)],
                           landmarks: (third: LandmarkData, second: LandmarkData, first: LandmarkData),
                           tuResultWhenThirdPeak: ixyhs,
                           resultWhenFisrtPeak: FineLocationTrackingOutput,
                           curPmResult: FineLocationTrackingOutput,
                           mode: UserMode,
                           inSameLink: Bool = false) -> RecoveryResult3Peaks? {
        let semaphore = DispatchSemaphore(value: 0)
        var output: RecoveryResult3Peaks? = nil

        Task {
            output = await self.recoverWith3PeaksAsync(recoveryTrajList: recoveryTrajList,
                                                       userPeakAndLinkBuffer: userPeakAndLinkBuffer,
                                                       landmarks: landmarks,
                                                       tuResultWhenThirdPeak: tuResultWhenThirdPeak,
                                                       resultWhenFisrtPeak: resultWhenFisrtPeak,
                                                       curPmResult: curPmResult,
                                                       mode: mode, inSameLink: inSameLink)
            semaphore.signal()
        }

        semaphore.wait()
        return output
    }
    
    private struct _RecoveryCandidate3Peaks {
        let loss: Float
        let shiftedTraj: [RecoveryTrajectory]
        let firstCand: PeakData
        let secondCand: PeakData?
        let thirdCand: PeakData?
        let tail: FineLocationTrackingOutput?
        let body: FineLocationTrackingOutput?
        let head: FineLocationTrackingOutput?
    }
    
    private func recoverWith3PeaksAsync(recoveryTrajList: [[RecoveryTrajectory]],
                                        userPeakAndLinkBuffer: [(UserPeak, LinkData)],
                                        landmarks: (third: LandmarkData, second: LandmarkData, first: LandmarkData),
                                        tuResultWhenThirdPeak: ixyhs,
                                        resultWhenFisrtPeak: FineLocationTrackingOutput,
                                        curPmResult: FineLocationTrackingOutput,
                                        mode: UserMode,
                                        inSameLink: Bool) async -> RecoveryResult3Peaks? {
        guard userPeakAndLinkBuffer.count >= 3 else {
            JupiterLogger.i(tag: "RecoveryManager", message: "(recoverWith3PeaksAsync) userPeakAndLinkBuffer is less than 3")
            return nil
        }
        let key = "\(sectorId)_\(curPmResult.building_name)_\(curPmResult.level_name)"
        guard let nodeData = PathMatcher.shared.nodeData[key], let linkData = PathMatcher.shared.linkData[key] else { return nil }

        guard let firstLink = await self.pmGate.getLinkInfoWithResult(sectorId: sectorId,
                                                                      result: resultWhenFisrtPeak,
                                                                      checkAll: true,
                                                                      acceptDist: 15) else { return nil }
        let firstLinkGroupNum = firstLink.group_number
        let thirdUserPeak = userPeakAndLinkBuffer[userPeakAndLinkBuffer.count - 3].0
        let thirdUserLink = userPeakAndLinkBuffer[userPeakAndLinkBuffer.count - 3].1
        
        let secondUserPeak = userPeakAndLinkBuffer[userPeakAndLinkBuffer.count - 2].0
        let secondUserPeakIndex = secondUserPeak.peak_index
        
        let firstUserPeak = userPeakAndLinkBuffer[userPeakAndLinkBuffer.count - 1].0
        let firstUserPeakIndex = firstUserPeak.peak_index

        JupiterLogger.i(tag: "RecoveryManager", message: "(recoverWith3PeaksAsync) third: \(thirdUserPeak.id), second: \(secondUserPeak.id), first: \(firstUserPeak.id)")
        JupiterLogger.i(tag: "RecoveryManager", message: "(recoverWith3PeaksAsync) thirdIndex: \(thirdUserPeak.peak_index), secondIndex: \(secondUserPeak.peak_index), firstIndex: \(firstUserPeak.peak_index)")
        
        let thirdLandmarkCands: [PeakData] = landmarks.third.peaks
        let secondLandmarkCands: [PeakData] = landmarks.second.peaks
        let firstLandmarkCands: [PeakData] = landmarks.first.peaks

        let bestCandidate: _RecoveryCandidate3Peaks? = await withTaskGroup(of: _RecoveryCandidate3Peaks?.self) { group in
            for recoveryTraj in recoveryTrajList {
                group.addTask { [self, sectorId = self.sectorId, nodeData = nodeData, linkData = linkData, firstLinkGroupNum = firstLinkGroupNum] in
                    guard recoveryTraj.count >= 2 else {
                        JupiterLogger.i(tag: "RecoveryManager", message: "(recoverWith3PeaksAsync) recoveryTraj size is less than 2")
                        return nil
                    }
                    
                    JupiterLogger.i(tag: "RecoveryManager", message: "(recoverWith3PeaksAsync) recoveryTraj: \(recoveryTraj.map {$0.index})")
                    var midIdx: Int? = nil
                    var anchorIdx: Int? = nil
                    for i in 0..<recoveryTraj.count {
                        let recoveryTrajIndex = recoveryTraj[i].index
                        if recoveryTrajIndex == secondUserPeakIndex {
                            midIdx = i
                        }
                        if recoveryTrajIndex == firstUserPeakIndex {
                            anchorIdx = i
                            break
                        }
                    }
                    guard let aIdx = anchorIdx, let mIdx = midIdx else {
                        JupiterLogger.i(tag: "RecoveryManager", message: "(recoverWith3PeaksAsync) anchorIdx or midIdx fail")
                        return nil
                    }

                    var localBestLoss = Float.greatestFiniteMagnitude
                    var localBestShiftedTraj: [RecoveryTrajectory]? = nil
                    var localBestFirstCand: PeakData? = nil
                    var localBestSecondCand: PeakData? = nil
                    var localBestThirdCand: PeakData? = nil
                    var localBestTail: FineLocationTrackingOutput? = nil
                    var localBestBody: FineLocationTrackingOutput? = nil
                    var localBestHead: FineLocationTrackingOutput? = nil

                    for cand in firstLandmarkCands {
                        // Enforce: the first-landmark candidate must lie on the same link-group as the current PM result.
                        if inSameLink {
                            var candResult = curPmResult
                            candResult.x = Float(cand.x)
                            candResult.y = Float(cand.y)
                            candResult.absolute_heading = curPmResult.absolute_heading
                            
                            guard let candLink = await self.pmGate.getLinkInfoWithResult(sectorId: sectorId,
                                                                                         result: candResult,
                                                                                         checkAll: true, acceptDist: 15) else {
                                continue
                            }
                            if candLink.group_number != firstLinkGroupNum {
                                continue
                            }
                        }
                        
                        let offsetX = Float(cand.x) - recoveryTraj[aIdx].x
                        let offsetY = Float(cand.y) - recoveryTraj[aIdx].y

                        var shiftedTraj: [RecoveryTrajectory] = []
                        shiftedTraj.reserveCapacity(recoveryTraj.count)
                        for p in recoveryTraj {
                            shiftedTraj.append(RecoveryTrajectory(index: p.index,
                                                                 x: p.x + offsetX,
                                                                 y: p.y + offsetY,
                                                                 heading: p.heading))
                        }
                        guard let first = shiftedTraj.first, let last = shiftedTraj.last else { continue }
                        let mid = shiftedTraj[mIdx]
                        
                        // Tail PM
                        guard let tail = await self.pmGate.pathMatching(sectorId: sectorId,
                                                                       building: curPmResult.building_name,
                                                                       level: curPmResult.level_name,
                                                                       x: first.x,
                                                                       y: first.y,
                                                                       heading: first.heading,
                                                                       isUseHeading: false,
                                                                       mode: mode,
                                                                       paddingValues: JupiterMode.PADDING_VALUES_HUGE) else { continue }

                        var tailResult = curPmResult
                        tailResult.x = tail.x
                        tailResult.y = tail.y
                        tailResult.absolute_heading = tail.heading

                        // Mid PM
                        guard let body = await self.pmGate.pathMatching(sectorId: sectorId,
                                                                       building: curPmResult.building_name,
                                                                       level: curPmResult.level_name,
                                                                       x: mid.x,
                                                                       y: mid.y,
                                                                       heading: mid.heading,
                                                                       isUseHeading: false,
                                                                       mode: mode,
                                                                       paddingValues: JupiterMode.PADDING_VALUES_LARGE) else { continue }

                        var bodyResult = curPmResult
                        bodyResult.x = body.x
                        bodyResult.y = body.y
                        bodyResult.absolute_heading = body.heading
                        
                        // Head PM
                        guard let head = await self.pmGate.pathMatching(sectorId: sectorId,
                                                                       building: curPmResult.building_name,
                                                                       level: curPmResult.level_name,
                                                                       x: last.x,
                                                                       y: last.y,
                                                                       heading: last.heading,
                                                                       isUseHeading: false,
                                                                       mode: mode,
                                                                       paddingValues: JupiterMode.PADDING_VALUES_HUGE) else {
                            continue
                        }
                        var headResult = curPmResult
                        headResult.x = head.x
                        headResult.y = head.y
                        headResult.absolute_heading = head.heading

                        // dist0: body? -> best second landmark (optionally group-constrained)
                        var dist0 = Float.greatestFiniteMagnitude
                        var localSecondCand: PeakData? = nil

                        for sc in secondLandmarkCands {
                            var tmp = curPmResult
                            tmp.x = Float(sc.x)
                            tmp.y = Float(sc.y)

                            let peakDist = dist2(Float(sc.x), Float(sc.y), Float(cand.x), Float(cand.y))
                            if peakDist < 2 { continue }
                            tmp.absolute_heading = tail.heading

                            let d = dist2(Float(body.x), Float(body.y), Float(sc.x), Float(sc.y))
                            if d < dist0 {
                                dist0 = d
                                localSecondCand = sc
                                bodyResult.x = Float(sc.x)
                                bodyResult.y = Float(sc.y)
                            }
                        }
                        
                        if dist0 == Float.greatestFiniteMagnitude {
                            dist0 = 1_000_000
                        }

                        var dist1 = Float.greatestFiniteMagnitude
                        var localThirdCand: PeakData? = nil
                        
                        for th in thirdLandmarkCands {
                            var tmp = curPmResult
                            tmp.x = Float(th.x)
                            tmp.y = Float(th.y)
                            
                            if let sc = localSecondCand {
                                let peakDist = dist2(Float(th.x), Float(th.y), Float(sc.x), Float(sc.y))
                                if peakDist < 2 { continue }
                                
                                let d = dist2(Float(tail.x), Float(tail.y), Float(th.x), Float(th.y))
                                if d < dist1 {
                                    dist1 = d
                                    localThirdCand = th
                                    tailResult.x = Float(th.x)
                                    tailResult.y = Float(th.y)
                                }
                            }
                        }

                        if dist1 == Float.greatestFiniteMagnitude {
                            dist1 = 1_000_000
                        }
                        
                        guard let tailLink = await self.pmGate.getLinkInfoWithResult(sectorId: sectorId,
                                                                                    result: tailResult,
                                                                                     checkAll: true, acceptDist: 60) else {
                            JupiterLogger.i(tag: "RecoveryManager", message: "(recoverWith3PeaksAsync) tail link fail [\(tailResult.x),\(tailResult.y)]")
                            continue
                        }
                        let tailLinkGroupNum = tailLink.group_number
                        
                        // dist2: tail -> TU result at third peak
                        let dist2v = dist2(Float(tail.x), Float(tail.y), Float(tuResultWhenThirdPeak.x), Float(tuResultWhenThirdPeak.y))

                        // dist3: head -> last (shifted traj last point)
                        let dist3 = dist2(Float(head.x), Float(head.y), Float(last.x), Float(last.y))

                        let loss = dist0 + dist1 + dist2v + dist3
                        if loss < localBestLoss {
                            localBestLoss = loss
                            localBestShiftedTraj = shiftedTraj
                            localBestFirstCand = cand
                            localBestSecondCand = localSecondCand
                            localBestThirdCand = localThirdCand

                            var bt = curPmResult
                            bt.x = tail.x
                            bt.y = tail.y
                            localBestTail = bt
                            
                            var bb = curPmResult
                            bb.x = body.x
                            bb.y = body.y
                            localBestBody = bb
                            
                            var bh = curPmResult
                            bh.x = head.x
                            bh.y = head.y
                            localBestHead = bh

                            _ = tailLinkGroupNum
                        }
                    }

                    if let st = localBestShiftedTraj, let rc = localBestFirstCand {
                        return _RecoveryCandidate3Peaks(loss: localBestLoss,
                                                        shiftedTraj: st,
                                                        firstCand: rc,
                                                        secondCand: localBestSecondCand,
                                                        thirdCand: localBestThirdCand,
                                                        tail: localBestTail,
                                                        body: localBestBody,
                                                        head: localBestHead)
                    }
                    return nil
                }
            }

            var best: _RecoveryCandidate3Peaks? = nil
            for await cand in group {
                guard let cand = cand else { continue }
                if best == nil || cand.loss < best!.loss {
                    best = cand
                }
            }
            return best
        }

        guard let best = bestCandidate else {
            JupiterLogger.i(tag: "RecoveryManager", message: "(recoverWith3PeaksAsync) bestCandidate nil")
            return nil
        }
        var resultTraj = [[Double]]()
        resultTraj.reserveCapacity(best.shiftedTraj.count)
        for value in best.shiftedTraj {
            resultTraj.append([Double(value.x), Double(value.y)])
        }

        let bestThird: [Int] = best.thirdCand != nil ? [best.thirdCand!.x, best.thirdCand!.y] : [0, 0]
        let bestSecond: [Int] = best.secondCand != nil ? [best.secondCand!.x, best.secondCand!.y] : [0, 0]
        let recoveryResult = RecoveryResult3Peaks(traj: resultTraj,
                                                  shiftedTraj: best.shiftedTraj,
                                                  loss: best.loss,
                                                  bestThird: bestThird,
                                                  bestSecond: bestSecond,
                                                  bestFirst: [best.firstCand.x, best.firstCand.y],
                                                  bestResult: best.head)
        return recoveryResult
    }
    
    // MARK: - Link connectivity validation (graph-based)
    private func isLinkReachableWithGroupSwitchLimit(nodeData: [Int: NodeData],
                                                    linkData: [Int: LinkData],
                                                    from startLink: LinkData,
                                                    to targetLink: LinkData,
                                                    maxGroupSwitches: Int = 1) -> Bool {
        if startLink.number == targetLink.number { return true }
        if maxGroupSwitches < 0 { return false }

        // Distance = min group-switch count to reach linkNum
        var dist: [Int: Int] = [startLink.number: 0]

        // Safe deque for 0-1 BFS: front stack + back queue + index
        var front: [Int] = [startLink.number]   // pushFront = append, popFront = popLast
        var back: [Int] = []                // pushBack = append, popFront when front empty uses back[backHead]
        var backHead = 0

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
                    if nbNum == targetLink.number { return true }

                    if cost == 0 {
                        pushFront(nbNum)
                    } else {
                        pushBack(nbNum)
                    }
                }
            }
        }

        return false
    }

    private func isHeadBodyTailConnectedViaGraph(nodeData: [Int: NodeData],
                                                linkData: [Int: LinkData],
                                                headLink: LinkData,
                                                bodyLink: LinkData,
                                                tailLink: LinkData) -> Bool {
        let maxGroupSwitches = 1
        if tailLink.group_number == bodyLink.group_number && bodyLink.group_number == headLink.group_number {
            return true
        }
        let tailToBody = isLinkReachableWithGroupSwitchLimit(nodeData: nodeData,
                                                            linkData: linkData,
                                                            from: tailLink,
                                                            to: bodyLink,
                                                            maxGroupSwitches: maxGroupSwitches)
        if !tailToBody { return false }

        let bodyToHead = isLinkReachableWithGroupSwitchLimit(nodeData: nodeData,
                                                            linkData: linkData,
                                                            from: bodyLink,
                                                            to: headLink,
                                                            maxGroupSwitches: maxGroupSwitches)
        return bodyToHead
    }
    
    private func isLinkReachableWithinHops(nodeData: [Int: NodeData],
                                          linkData: [Int: LinkData],
                                          from startLink: LinkData,
                                          to targetLink: LinkData,
                                          maxHops: Int) -> Bool {
        if startLink.number == targetLink.number { return true }
        if maxHops <= 0 { return false }

        @inline(__always)
        func neighbors(of link: LinkData) -> [Int] {
            var out: [Int] = []
            out.reserveCapacity(16)

            if let s = nodeData[link.start_node] {
                out.append(contentsOf: s.connected_links)
            }
            if let e = nodeData[link.end_node] {
                out.append(contentsOf: e.connected_links)
            }

            // Remove self and duplicates
            var unique: [Int] = []
            unique.reserveCapacity(out.count)
            for num in out {
                if num == link.number { continue }
                if unique.contains(num) { continue }
                unique.append(num)
            }
            return unique
        }

        var visited: Set<Int> = [startLink.number]
        var q: [(id: Int, d: Int)] = [(startLink.number, 0)]
        var head = 0

        while head < q.count {
            let (curId, d) = q[head]
            head += 1
            if d >= maxHops { continue }
            guard let curLink = linkData[curId] else { continue }

            for nbNum in neighbors(of: curLink) {
                if nbNum == targetLink.number { return true }
                if visited.contains(nbNum) { continue }
                visited.insert(nbNum)
                q.append((nbNum, d + 1))
            }
        }

        return false
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
    
    private func computeIntermediateLossByIndex(sectorId: Int,
                                                curPmResult: FineLocationTrackingOutput,
                                                shiftedTraj: [RecoveryTrajectory],
                                                targetIndices: [Int],
                                                mode: UserMode) -> [LossPointResult]? {
        
        if shiftedTraj.isEmpty || targetIndices.isEmpty { return nil }
        let key = "\(sectorId)_\(curPmResult.building_name)_\(curPmResult.level_name)"
        guard let nodeData = PathMatcher.shared.nodeData[key], let linkData = PathMatcher.shared.linkData[key] else { return nil }
        
        var lossPointResults = [LossPointResult]()
        
        var preLink: LinkData?
        var preIxyhs: ixyhs?
        for idx in targetIndices {
            let point = shiftedTraj[idx]
            
            guard let pm = PathMatcher.shared.pathMatchingWithHeadings(sectorId: sectorId,
                                                                 building: curPmResult.building_name,
                                                                 level: curPmResult.level_name,
                                                                 x: point.x, y: point.y, heading: point.heading,
                                                                 isUseHeading: false, mode: mode,
                                                                 paddingValues: JupiterMode.PADDING_VALUES_LARGE) else { continue }
            var newResult = curPmResult
            newResult.x = pm.xyhs.x
            newResult.y = pm.xyhs.y
            guard let matchedLink = PathMatcher.shared.getLinkInfoWithResult(sectorId: sectorId, result: newResult, checkAll: true) else { continue }
            if let pre = preLink, let preIxyhs = preIxyhs {
                if pre.group_number != matchedLink.group_number {
                    let isReachable = isLinkReachableWithGroupSwitchLimit(nodeData: nodeData, linkData: linkData, from: pre, to: matchedLink, maxGroupSwitches: 2)
                    if !isReachable {
                        JupiterLogger.i(tag: "RecoveryManager", message: "(computeIntermediateLossByIndex) [\(preIxyhs.x),\(preIxyhs.y)] to [\(pm.xyhs.x),\(pm.xyhs.y)] is not reachable")
                        JupiterLogger.i(tag: "RecoveryManager", message: "(computeIntermediateLossByIndex) \(pre.number) to \(matchedLink.number) is not reachable")
                        return nil
                    }
                }
            }
            preIxyhs = pm.xyhs
            preLink = matchedLink
            
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
    
    struct PeakXYKey: Hashable {
        let x: Int
        let y: Int
    }
}
