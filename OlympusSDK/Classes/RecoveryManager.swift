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
    
    func makeMultipleRecoveryTrajectory(uvdBuffer: [UserVelocity], majorSection: [Float], pathHeadings: [Float], endHeading: Float) -> [[RecoveryTrajectory]] {
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
                
                let lastHeading = TJLabsUtilFunctions.shared.compensateDegree(Double(resultBuffer[resultBuffer.count-1].heading))
                let diffHeading = adjustHeading(Float(lastHeading), endHeading)
                if diffHeading < Float(JupiterMode.HEADING_RANGE) {
                    trajList.append(resultBuffer)
                }
//                JupiterLogger.i(tag: "RecoveryManager", message: "(makeMultipleRecoveryTrajectory) BadCase: pathHeading= \(pathHeading) // lastHeading= \(lastHeading) // endHeading= \(endHeading) // diffHeading= \(diffHeading)")
//                trajList.append(resultBuffer)
            }
        }
  
        return trajList
    }
    
    func makeLandmarkTrajectory(uvdBuffer: [UserVelocity], majorSection: [Float], alignDir: Float) -> [RecoveryTrajectory] {
        var trajList = [RecoveryTrajectory]()
        if !majorSection.isEmpty {
            let headingForCompensation = majorSection.average - uvdBuffer[0].heading
            
            let startHeading = Float(TJLabsUtilFunctions.shared.compensateDegree(Double(alignDir) - Double(headingForCompensation)))
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
            
            trajList = resultBuffer
            let lastHeading = TJLabsUtilFunctions.shared.compensateDegree(Double(resultBuffer[resultBuffer.count-1].heading))
            JupiterLogger.i(tag: "RecoveryManager", message: "(makeMultipleLandmarkTrajectory) 2 Peaks: alignDir= \(alignDir) // lastHeading= \(lastHeading)")
        }
  
        return trajList
    }
    
    func recoverWithLandmarkTraj(landmarkTraj: [RecoveryTrajectory],
                                 userPeakAndLinksBuffer: [(UserPeak, [LinkData])],
                                 landmarks: (older: LandmarkData, recent: LandmarkData),
                                 tuResultWhenOlderPeak: ixyhs,
                                 curPmResult: FineLocationTrackingOutput,
                                 mode: UserMode) -> RecoveryResult? {
        let semaphore = DispatchSemaphore(value: 0)
        var output: RecoveryResult? = nil

        Task {
            output = await self.recoverWithLandmarkTrajAsync(landmarkTraj: landmarkTraj,
                                                            userPeakAndLinksBuffer: userPeakAndLinksBuffer,
                                                            landmarks: landmarks,
                                                            tuResultWhenOlderPeak: tuResultWhenOlderPeak,
                                                            curPmResult: curPmResult,
                                                            mode: mode)
            semaphore.signal()
        }

        semaphore.wait()
        return output
    }
    
    private func recoverWithLandmarkTrajAsync(landmarkTraj: [RecoveryTrajectory],
                                             userPeakAndLinksBuffer: [(UserPeak, [LinkData])],
                                             landmarks: (older: LandmarkData, recent: LandmarkData),
                                             tuResultWhenOlderPeak: ixyhs,
                                             curPmResult: FineLocationTrackingOutput,
                                             mode: UserMode) async -> RecoveryResult? {
        guard userPeakAndLinksBuffer.count >= 2 else { return nil }

        let olderUserPeak = userPeakAndLinksBuffer[userPeakAndLinksBuffer.count - 2].0
        let olderUserLinks = userPeakAndLinksBuffer[userPeakAndLinksBuffer.count - 2].1

        let recentUserPeak = userPeakAndLinksBuffer[userPeakAndLinksBuffer.count - 1].0
        let recentUserLinks = userPeakAndLinksBuffer[userPeakAndLinksBuffer.count - 1].1
        
        let recentUserGroupIds = recentUserLinks.map{$0.group_id}
        
        let recentUserPeakIndex = recentUserPeak.peak_index

        JupiterLogger.i(tag: "RecoveryManager", message: "(recoverWithLandmarkTrajAsync) olderPeakId: \(olderUserPeak.id), oldPeakIndex: \(olderUserPeak.peak_index), recentPeakId: \(recentUserPeak.id), recentPeakIndex: \(recentUserPeakIndex)")

        let olderLandmarkCands: [PeakData] = landmarks.older.peaks
        let recentLandmarkCands: [PeakData] = landmarks.recent.peaks
        
        JupiterLogger.i(tag: "RecoveryManager", message: "(recoverWithLandmarkTrajAsync) 2 Peaks : recent // groupId=\(recentUserLinks.map{$0.group_id}), linkId=\(recentUserLinks.map{$0.id})")

        let bestCandidate: _RecoveryCandidate? = await withTaskGroup(of: _RecoveryCandidate?.self) { group in
            group.addTask { [sectorId = self.sectorId] in
                guard landmarkTraj.count >= 2 else { return nil }

                var anchorIdx: Int? = nil
                for i in 0..<landmarkTraj.count {
                    if landmarkTraj[i].index == recentUserPeakIndex {
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
                    let offsetX = Float(cand.x) - landmarkTraj[aIdx].x
                    let offsetY = Float(cand.y) - landmarkTraj[aIdx].y
                    
                    var candResult = curPmResult
                    candResult.x = Float(cand.x)
                    candResult.y = Float(cand.y)
                    guard let candLink = await self.pmGate.getLinkInfoWithResult(sectorId: sectorId,
                                                                                 result: candResult,
                                                                                 checkAll: true,
                                                                                 acceptDist: 15) else { continue }
                    
                    JupiterLogger.i(tag: "RecoveryManager", message: "(recoverWithLandmarkTrajAsync) 2 Peaks : cand // groupId=\(candLink.group_id), linkId=\(candLink.id)")
                    if !recentUserGroupIds.contains(candLink.group_id) {
                        JupiterLogger.i(tag: "RecoveryManager", message: "(recoverWithLandmarkTrajAsync) 2 Peaks : group ID is not same")
                        continue
                    }
                    
                    var shiftedTraj: [RecoveryTrajectory] = []
                    shiftedTraj.reserveCapacity(landmarkTraj.count)
                    for p in landmarkTraj {
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
                                                                   paddingValues: JupiterMode.PADDING_VALUES_MEDIUM) else { continue }

                    var tailResult = curPmResult
                    tailResult.x = tail.x
                    tailResult.y = tail.y
                    tailResult.absolute_heading = tail.heading

                    guard let tailLink = await self.pmGate.getLinkInfoWithResult(sectorId: sectorId,
                                                                                result: tailResult,
                                                                                checkAll: true, acceptDist: 15) else {
                        continue
                    }
                    let tailLinkGroupId = tailLink.group_id

                    // Head PM
                    guard let head = await self.pmGate.pathMatching(sectorId: sectorId,
                                                                   building: curPmResult.building_name,
                                                                   level: curPmResult.level_name,
                                                                   x: last.x,
                                                                   y: last.y,
                                                                   heading: last.heading,
                                                                   isUseHeading: false,
                                                                   mode: mode,
                                                                   paddingValues: JupiterMode.PADDING_VALUES_MEDIUM) else {
                        continue
                    }

                    // dist1: tail -> best older landmark (optionally group-constrained)
                    var dist1 = Float.greatestFiniteMagnitude
                    var localOlderCand: PeakData? = nil

                    for oc in olderLandmarkCands {
                        var tmp = curPmResult
                        tmp.x = Float(oc.x)
                        tmp.y = Float(oc.y)

                        let peakDist = self.dist2(Float(oc.x), Float(oc.y), Float(cand.x), Float(cand.y))
                        if peakDist < 5 { continue }
                        tmp.absolute_heading = tail.heading
//                            guard let ocLink = await self.pmGate.getLinkInfoWithResult(sectorId: sectorId,
//                                                                                      result: tmp,
//                                                                                      checkAll: true) else {
//                                continue
//                            }

                        let d = self.dist2(Float(tail.x), Float(tail.y), Float(oc.x), Float(oc.y))
                        if d < dist1 {
                            dist1 = d
                            localOlderCand = oc
                        }
                    }

                    if dist1 == Float.greatestFiniteMagnitude {
                        dist1 = 1_000_000
                    }

                    // dist2: tail -> TU result at older peak
                    let dist2v = self.dist2(Float(tail.x), Float(tail.y), Float(tuResultWhenOlderPeak.x), Float(tuResultWhenOlderPeak.y))

                    // dist3: head -> last (shifted traj last point)
                    let dist3 = self.dist2(Float(head.x), Float(head.y), Float(last.x), Float(last.y))

                    let loss = dist1 + dist2v + dist3
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

                        _ = tailLinkGroupId
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

        let olderCandMsg = best.olderCand.map { "(\($0.x),\($0.y))" } ?? "nil"
//        JupiterLogger.i(tag: "RecoveryManager", message: "(recover) selected recentCand=(\(best.recentCand.x),\(best.recentCand.y)) olderCand=\(olderCandMsg) olderPeakIdx=\(olderUserPeak.peak_index) olderLinkGroup=\(olderUserLink.group_id) bestLoss=\(best.loss)")

        var resultTraj = [[Double]]()
        resultTraj.reserveCapacity(best.shiftedTraj.count)
        for value in best.shiftedTraj {
            resultTraj.append([Double(value.x), Double(value.y)])
        }

        let bestOlder: [Int] = best.olderCand != nil ? [best.olderCand!.x, best.olderCand!.y] : [0, 0]
        let recoveryResult = RecoveryResult(traj: resultTraj,
                                            shiftedTraj: best.shiftedTraj,
                                            loss: best.loss,
                                            bestOlder: bestOlder,
                                            bestRecent: [best.recentCand.x, best.recentCand.y],
                                            bestResult: best.head)
        return recoveryResult
    }
    
    func recoverWithMultipleTraj(recoveryTrajList: [[RecoveryTrajectory]],
                                 userPeakAndLinksBuffer: [(UserPeak, [LinkData])],
                                 landmarks: (older: LandmarkData, recent: LandmarkData),
                                 tuResultWhenOlderPeak: ixyhs,
                                 curPmResult: FineLocationTrackingOutput,
                                 mode: UserMode,
                                 inSameLink: Bool = false) -> RecoveryResult? {
        let semaphore = DispatchSemaphore(value: 0)
        var output: RecoveryResult? = nil

        Task {
            output = await self.recoverWithMultipleTrajAsync(recoveryTrajList: recoveryTrajList,
                                                             userPeakAndLinksBuffer: userPeakAndLinksBuffer,
                                                             landmarks: landmarks,
                                                             tuResultWhenOlderPeak: tuResultWhenOlderPeak,
                                                             curPmResult: curPmResult,
                                                             mode: mode,
                                                             inSameLink: inSameLink)
            semaphore.signal()
        }

        semaphore.wait()
        return output
    }

    private func recoverWithMultipleTrajAsync(recoveryTrajList: [[RecoveryTrajectory]],
                                              userPeakAndLinksBuffer: [(UserPeak, [LinkData])],
                                              landmarks: (older: LandmarkData, recent: LandmarkData),
                                              tuResultWhenOlderPeak: ixyhs,
                                              curPmResult: FineLocationTrackingOutput,
                                              mode: UserMode,
                                              inSameLink: Bool) async -> RecoveryResult? {
        guard userPeakAndLinksBuffer.count >= 2 else { return nil }

        let olderUserPeak = userPeakAndLinksBuffer[userPeakAndLinksBuffer.count - 2].0
        let recentUserPeak = userPeakAndLinksBuffer[userPeakAndLinksBuffer.count - 1].0
        let recentUserLinks = userPeakAndLinksBuffer[userPeakAndLinksBuffer.count - 1].1
        let recentUserPeakIndex = recentUserPeak.peak_index

        JupiterLogger.i(tag: "RecoveryManager", message: "(recover) olderPeakId: \(olderUserPeak.id), oldPeakIndex: \(olderUserPeak.peak_index), recentPeakId: \(recentUserPeak.id), recentPeakIndex: \(recentUserPeakIndex)")

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
                        for recentUserLink in recentUserLinks {
                            if inSameLink {
                                var candResult = curPmResult
                                candResult.x = Float(cand.x)
                                candResult.y = Float(cand.y)
                                guard let candLink = await self.pmGate.getLinkInfoWithResult(sectorId: sectorId,
                                                                                             result: candResult,
                                                                                             checkAll: true,
                                                                                             acceptDist: 15) else { continue }
                                if candLink.group_id != recentUserLink.group_id { continue }
                                
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

                            // Tail PM
                            guard let tail = await self.pmGate.pathMatching(sectorId: sectorId,
                                                                           building: curPmResult.building_name,
                                                                           level: curPmResult.level_name,
                                                                           x: first.x,
                                                                           y: first.y,
                                                                           heading: first.heading,
                                                                           isUseHeading: false,
                                                                           mode: mode,
                                                                           paddingValues: JupiterMode.PADDING_VALUES_MEDIUM) else { continue }

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
                                                                           paddingValues: JupiterMode.PADDING_VALUES_MEDIUM) else {
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

                            let dist2v = dist2(Float(tail.x), Float(tail.y), Float(first.x), Float(first.y))

                            let dist3 = dist2(Float(head.x), Float(head.y), Float(last.x), Float(last.y))

                            let loss = dist1 + dist2v + dist3
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
                                            bestOlder: bestOlder,
                                            bestRecent: [best.recentCand.x, best.recentCand.y],
                                            bestResult: best.head)
        return recoveryResult
    }
    
    func trackWith2Peaks(recoveryTrajList: [[RecoveryTrajectory]],
                                     userPeakAndLinksBuffer: [(UserPeak, [LinkData])],
                                     landmarks: (older: LandmarkData, recent: LandmarkData),
                                     tuResultWhenOlderPeak: ixyhs,
                                     tuResultWhenRecentPeak: ixyhs,
                                     curPmResult: FineLocationTrackingOutput,
                                     mode: UserMode,
                                     matchedNode: NodeData?,
                                     outGroupBestOnly: Bool = true) -> [RecoveryResult] {
        let semaphore = DispatchSemaphore(value: 0)
        var output: [RecoveryResult] = []

        Task {
            output = await self.trackWith2PeaksAsync(recoveryTrajList: recoveryTrajList,
                                                     userPeakAndLinksBuffer: userPeakAndLinksBuffer,
                                                     landmarks: landmarks,
                                                     tuResultWhenOlderPeak: tuResultWhenOlderPeak,
                                                     tuResultWhenRecentPeak: tuResultWhenRecentPeak,
                                                     curPmResult: curPmResult,
                                                     mode: mode,
                                                     matchedNode: matchedNode,
                                                     outGroupBestOnly: outGroupBestOnly)
            semaphore.signal()
        }

        semaphore.wait()
        return output
    }
    
    private func trackWith2PeaksAsync(recoveryTrajList: [[RecoveryTrajectory]],
                                      userPeakAndLinksBuffer: [(UserPeak, [LinkData])],
                                      landmarks: (older: LandmarkData, recent: LandmarkData),
                                      tuResultWhenOlderPeak: ixyhs,
                                      tuResultWhenRecentPeak: ixyhs,
                                      curPmResult: FineLocationTrackingOutput,
                                      mode: UserMode,
                                      matchedNode: NodeData?,
                                      outGroupBestOnly: Bool) async -> [RecoveryResult] {
        guard userPeakAndLinksBuffer.count >= 2 else { return [] }
        let key = "\(sectorId)_\(curPmResult.building_name)_\(curPmResult.level_name)"
        guard let nodeData = PathMatcher.shared.nodeData[key], let linkData = PathMatcher.shared.linkData[key] else { return [] }

        // Current PM result's link info (used for returning curLinkId/curGroupId, and optionally for connectivity checks)
        let curLinkForConnectionCheck: LinkData? = await self.pmGate.getLinkInfoWithResult(sectorId: sectorId,
                                                                                           result: curPmResult,
                                                                                           checkAll: true,
                                                                                           acceptDist: 15)
        
        let olderUserPeak = userPeakAndLinksBuffer[userPeakAndLinksBuffer.count - 2].0
        let olderUserLinks = userPeakAndLinksBuffer[userPeakAndLinksBuffer.count - 2].1
        
        let recentUserPeak = userPeakAndLinksBuffer[userPeakAndLinksBuffer.count - 1].0
        let recentUserLinks = userPeakAndLinksBuffer[userPeakAndLinksBuffer.count - 1].1
        let recentUserGroupIds = recentUserLinks.map{$0.group_id}
        let recentUserPeakIndex = recentUserPeak.peak_index
        
        let olderLandmarkCands: [PeakData] = landmarks.older.peaks
        let recentLandmarkCands: [PeakData] = landmarks.recent.peaks
        
        let passPenalty = !outGroupBestOnly
        let linkConnection = !outGroupBestOnly
        
        let allCandidates: [_RecoveryCandidateWide] = await withTaskGroup(of: [_RecoveryCandidateWide].self) { group in
            for recoveryTraj in recoveryTrajList {
                group.addTask { [self,
                                 sectorId = self.sectorId,
                                 nodeData = nodeData,
                                 linkData = linkData,
                                 linkConnection = linkConnection,
                                 curLinkForConnectionCheck = curLinkForConnectionCheck,
                                 outGroupBestOnly = outGroupBestOnly] in
                    guard recoveryTraj.count >= 2 else { return [] }
                    var anchorIdx: Int? = nil
                    for i in 0..<recoveryTraj.count {
                        if recoveryTraj[i].index == recentUserPeakIndex {
                            anchorIdx = i
                            break
                        }
                    }
                    guard let aIdx = anchorIdx else { return [] }

                    var localCandidates: [_RecoveryCandidateWide] = []
                    localCandidates.reserveCapacity(64)
                    
                    var selectedCands: [(PeakData, Int, Int, Bool)] = []  // (cand, candGroupId, candLinkId)
                    selectedCands.reserveCapacity(recentLandmarkCands.count)

                    var inLinkBest: (cand: PeakData, dist: Float)? = nil

                    // Out-of-group candidate policy
                    // - outGroupBestOnly == true  : keep only the single best *directly connectable* candidate
                    // - outGroupBestOnly == false : allow up to OUT_GROUP_MAX candidates reachable within 3 link-groups
                    let OUT_GROUP_MAX: Int = 20

                    var outLinkGroupId: Int?
                    var outLinkId: Int?
                    var connectableBest: (cand: PeakData, dist: Float)? = nil

                    var outGroupPool: [(cand: PeakData, groupId: Int, linkId: Int, dist: Float)] = []
                    outGroupPool.reserveCapacity(16)

                    for cand in recentLandmarkCands {
                        var candResult = curPmResult
                        candResult.x = Float(cand.x)
                        candResult.y = Float(cand.y)
                        guard let candLink = await self.pmGate.getLinkInfoWithResult(sectorId: sectorId,
                                                                                     result: candResult,
                                                                                     checkAll: true,
                                                                                     acceptDist: 15) else { continue }
                        
                        for recentUserLink in recentUserLinks {
                            JupiterLogger.i(tag: "RecoveryManager", message: "(trackWith2PeaksAsync) candLink.group_id: \(candLink.group_id)")
                            let d = self.dist2(Float(cand.x), Float(cand.y), Float(tuResultWhenRecentPeak.x), Float(tuResultWhenRecentPeak.y))

                            var isInSameLinkGroup = false
                            if let matchedNode = matchedNode {
                                var groupIdSet: Set<Int> = []
                                for cLinkId in matchedNode.connected_links {
                                    if let cLink = linkData[cLinkId] {
                                        groupIdSet.insert(cLink.group_id)
                                    }
                                }

                                if groupIdSet.contains(candLink.group_id) {
                                    isInSameLinkGroup = true
                                }
    //                            JupiterLogger.i(tag: "RecoveryManager", message: "(trackWith2PeaksAsync) groupIdSet: \(groupIdSet)")
                            } else if candLink.group_id == recentUserLink.group_id {
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
                                
                                selectedCands.append((cand, candLink.group_id, candLink.id, true))
                                continue
                            }

                            if outGroupBestOnly {
                                // Keep only the single best candidate that is directly connectable (shares an endpoint node).
                                let candNodes = [candLink.start_node, candLink.end_node]
                                let recentNodes = [recentUserLink.start_node, recentUserLink.end_node]
                                let isDirectlyConnectable = candNodes.contains(where: { recentNodes.contains($0) })
                                guard isDirectlyConnectable else { continue }

                                if let best = connectableBest {
                                    if d < best.dist {
                                        connectableBest = (cand: cand, dist: d)
                                        outLinkGroupId = candLink.group_id
                                        outLinkId = candLink.id
                                    }
                                } else {
                                    connectableBest = (cand: cand, dist: d)
                                    outLinkGroupId = candLink.group_id
                                    outLinkId = candLink.id
                                }
                            } else {
                                let reachableWithin3Groups = self.isLinkReachableWithGroupSwitchLimit(
                                    nodeData: nodeData,
                                    linkData: linkData,
                                    from: recentUserLink,
                                    to: candLink,
                                    maxGroupSwitches: 3
                                )
                                JupiterLogger.i(tag: "RecoveryManager", message: "(trackWith2PeaksAsync) reachableWithin3Groups: from \(recentUserLink.id) to \(candLink.id) is \(reachableWithin3Groups)")
                                guard reachableWithin3Groups else { continue }
                                outGroupPool.append((cand: cand, groupId: candLink.group_id, linkId: candLink.id, dist: d))
                            }
                        }
                    }
                    JupiterLogger.i(tag: "RecoveryManager", message: "(trackWith2PeaksAsync) outLinkPool: \(outGroupPool.map{$0.linkId})")
                    JupiterLogger.i(tag: "RecoveryManager", message: "(trackWith2PeaksAsync) outGroupPool: \(outGroupPool.map{$0.groupId})")

                    if outGroupBestOnly {
                        if let inLinkBest = inLinkBest, let outLinkBest = connectableBest {
                            if outLinkBest.dist > inLinkBest.dist {
                                connectableBest = nil
                            }
                        }

                        // Add the single best directly-connectable candidate (if any), avoiding duplicates.
                        if let extra = connectableBest?.cand, let extraGroupId = outLinkGroupId, let extraLinkId = outLinkId {
                            let extraCands = selectedCands.map{ $0.0 as PeakData }
                            if !extraCands.contains(where: { $0.x == extra.x && $0.y == extra.y && $0.rssi == extra.rssi }) {
                                selectedCands.append((extra, extraGroupId, extraLinkId, false))
                            }
                        }
                    } else {
                        // Add up to OUT_GROUP_MAX out-of-group candidates (sorted by TU-distance), avoiding duplicates.
                        outGroupPool.sort { $0.dist < $1.dist }
                        if outGroupPool.count > OUT_GROUP_MAX {
                            outGroupPool = Array(outGroupPool.prefix(OUT_GROUP_MAX))
                        }

                        let existing = selectedCands.map { $0.0 as PeakData }
                        for item in outGroupPool {
                            let cand = item.cand
                            if existing.contains(where: { $0.x == cand.x && $0.y == cand.y && $0.rssi == cand.rssi }) {
                                continue
                            }
                            selectedCands.append((cand, item.groupId, item.linkId, false))
                        }
                    }
                    JupiterLogger.i(tag: "RecoveryManager", message: "(trackWith2PeaksAsync) selectedCands: groupIds = \(selectedCands.map{$0.1})")
                    JupiterLogger.i(tag: "RecoveryManager", message: "(trackWith2PeaksAsync) selectedCands: linkIds = \(selectedCands.map{$0.2})")
                    for candTuple in selectedCands {
                        for recentUserLink in recentUserLinks {
                            let cand = candTuple.0
                            let candLinkGroupId = candTuple.1
                            let candLinkId = candTuple.2
                            let isInSameLink = candTuple.3
                            JupiterLogger.i(tag: "RecoveryManager", message: "(trackWith2PeaksAsync) selectedCands: [\(cand.x),\(cand.y)], groupId:\(candLinkGroupId), linkId:\(candLinkId)")
                            
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
                                                                            paddingValues: JupiterMode.PADDING_VALUES_MEDIUM) else {
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
                            let tailLinkGroupId = tailLink.group_id

                            // Head PM
                            guard let head = await self.pmGate.pathMatching(sectorId: sectorId,
                                                                            building: curPmResult.building_name,
                                                                            level: curPmResult.level_name,
                                                                            x: last.x,
                                                                            y: last.y,
                                                                            heading: last.heading,
                                                                            isUseHeading: false,
                                                                            mode: mode,
                                                                            paddingValues: JupiterMode.PADDING_VALUES_MEDIUM) else {
                                JupiterLogger.i(tag: "RecoveryManager", message: "(trackWith2PeaksAsync) head pm fail // cand:[\(cand.x),\(cand.y)] // first:[\(last.x),\(last.y)]")
                                continue
                            }

                            if linkConnection {
                                guard let curLink = curLinkForConnectionCheck else { continue }

                                var headResult = curPmResult
                                headResult.x = head.x
                                headResult.y = head.y
                                headResult.absolute_heading = head.heading

                                guard let headLink = await self.pmGate.getLinkInfoWithResult(sectorId: sectorId,
                                                                                              result: headResult,
                                                                                              checkAll: true,
                                                                                              acceptDist: 15) else {
                                    continue
                                }

                                let reachable = self.isLinkReachableWithGroupSwitchLimit(nodeData: nodeData,
                                                                                        linkData: linkData,
                                                                                        from: curLink,
                                                                                        to: headLink,
                                                                                        maxGroupSwitches: 1)
                                if !reachable {
                                    continue
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

                            let dist2v = dist2(Float(tail.x), Float(tail.y), Float(first.x), Float(first.y))
                            let dist3 = dist2(Float(head.x), Float(head.y), Float(last.x), Float(last.y))

                            var penalty: Float = 1.0
                            if !isInSameLink && !passPenalty {
                                if let candLink = linkData[candLinkId] {
                                    let reachableWithinOneSwitch = self.isLinkReachableWithGroupSwitchLimit (
                                        nodeData: nodeData,
                                        linkData: linkData,
                                        from: candLink,
                                        to: recentUserLink,
                                        maxGroupSwitches: 1
                                    )
                                    if !reachableWithinOneSwitch {
                                        penalty = 2.0
                                    }
                                } else {
                                    penalty = 2.0
                                }
                            }

                            let loss = (dist1 + dist2v + dist3) * penalty
                            JupiterLogger.i(tag: "RecoveryManager", message: "(trackWith2PeaksAsync) cand:\(cand.x),\(cand.y), loss:\(loss), penalty:\(penalty)")

                            var bt = curPmResult
                            bt.x = tail.x
                            bt.y = tail.y

                            var bh = curPmResult
                            bh.x = head.x
                            bh.y = head.y

                            localCandidates.append(
                                _RecoveryCandidateWide(loss: loss,
                                                       shiftedTraj: shiftedTraj,
                                                       recentCand: cand,
                                                       olderCand: localOlderCand,
                                                       tail: bt,
                                                       head: bh,
                                                       recentCandLinkId: candLinkId,
                                                       recentCandGroupId: candLinkGroupId)
                            )
                            _ = tailLinkGroupId
                        }
                    }
                    return localCandidates
                }
            }

            var all: [_RecoveryCandidateWide] = []
            all.reserveCapacity(256)

            for await list in group {
                all.append(contentsOf: list)
            }

            all.sort { $0.loss < $1.loss }
            let topN = Array(all)
            JupiterLogger.i(tag: "RecoveryManager", message: "(recoverWithMultipleTrajAsyncWide) candidates=\(all.count), top1=\(topN.first?.loss), top2=\(topN.count > 1 ? topN[1].loss : nil)")
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
            var recoveryResult = RecoveryResult(traj: resultTraj,
                                                shiftedTraj: cand.shiftedTraj,
                                                loss: cand.loss,
                                                bestOlder: bestOlder,
                                                bestRecent: [cand.recentCand.x, cand.recentCand.y],
                                                bestResult: cand.head,
                                                curLinkId: curLinkForConnectionCheck?.id,
                                                curGroupId: curLinkForConnectionCheck?.group_id,
                                                recentCandLinkId: cand.recentCandLinkId,
                                                recentCandGroupId: cand.recentCandGroupId)
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
                    guard let curLinkId = r.curLinkId, let candLinkId = r.recentCandLinkId else { continue }
                    guard let curLink = linkData[curLinkId], let candLink = linkData[candLinkId] else { continue }
                    if curLinkId == candLinkId { continue }
                    let ok = self.isLinkReachableWithGroupSwitchLimit(nodeData: nodeData,
                                                                      linkData: linkData,
                                                                      from: curLink,
                                                                      to: candLink,
                                                                      maxGroupSwitches: 3)
                    if ok {
                        JupiterLogger.i(tag: "RecoveryManager",
                                        message: "(selectRecoveryResult) linkConnection=true -> pick first connectable within 3 group_id // curLink=\(curLinkId), candLink=\(candLinkId), curGroup=\(curLink.group_id), candGroup=\(candLink.group_id), loss=\(r.loss)")
                        return (r, 0.0)
                    }
                }
            }
        }

        let first = list[0]
        if alwaysFirst {
            JupiterLogger.i(tag: "RecoveryManager", message: "(selectRecoveryResult) alwaysFirst // first: \(first.loss)")
            return (first, 0.0)
        }
        guard list.count >= 2 else {
            JupiterLogger.i(tag: "RecoveryManager", message: "(selectRecoveryResult) list size \(list.count) // first: \(first.loss)")
            return (first, 0.0)
        }

        let second = list[1]
        let best = (first.loss <= second.loss) ? first : second
        let runnerUp = (first.loss <= second.loss) ? second : first

        if runnerUp.loss <= 0 {
            return (best, 0.0)
        }
        
        let firstCoord = first.bestRecent // [x,y]
        let secondCoord = second.bestRecent // [x,y]

        var coordDist = Float.greatestFiniteMagnitude
        if firstCoord.count >= 2 && secondCoord.count >= 2 {
            let fx = Float(firstCoord[0])
            let fy = Float(firstCoord[1])
            let sx = Float(secondCoord[0])
            let sy = Float(secondCoord[1])
            coordDist = self.dist2(fx, fy, sx, sy)
        }

        let ratio = best.loss / runnerUp.loss

        if coordDist <= COORD_DIST_TH {
            if best.loss < TT_HIGH {
                JupiterLogger.i(tag: "RecoveryManager", message: "(selectRecoveryResult) close coords (dist=\(coordDist)) -> accept best // best: \(best.loss), ratio: \(ratio)")
                return (best, ratio)
            }
        }
        
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
    
    // Using Fisrt ~ Third
    func recoverWithMultipleTraj_v2(recoveryTrajList: [[RecoveryTrajectory]],
                                    userPeakAndLinkBuffer: [(UserPeak, LinkData)],
                                    landmarks: (third: LandmarkData, second: LandmarkData, first: LandmarkData),
                                    tuResultWhenThirdPeak: ixyhs,
                                    resultWhenFisrtPeak: FineLocationTrackingOutput,
                                    curPmResult: FineLocationTrackingOutput,
                                    mode: UserMode,
                                    inSameLink: Bool = false) -> RecoveryResult_v2? {
        let semaphore = DispatchSemaphore(value: 0)
        var output: RecoveryResult_v2? = nil

        Task {
            output = await self.recoverWithMultipleTrajAsync_v2(recoveryTrajList: recoveryTrajList,
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
    
    private struct _RecoveryCandidate_v2 {
        let loss: Float
        let shiftedTraj: [RecoveryTrajectory]
        let firstCand: PeakData
        let secondCand: PeakData?
        let thirdCand: PeakData?
        let tail: FineLocationTrackingOutput?
        let body: FineLocationTrackingOutput?
        let head: FineLocationTrackingOutput?
    }
    
    private func recoverWithMultipleTrajAsync_v2(recoveryTrajList: [[RecoveryTrajectory]],
                                                 userPeakAndLinkBuffer: [(UserPeak, LinkData)],
                                                 landmarks: (third: LandmarkData, second: LandmarkData, first: LandmarkData),
                                                 tuResultWhenThirdPeak: ixyhs,
                                                 resultWhenFisrtPeak: FineLocationTrackingOutput,
                                                 curPmResult: FineLocationTrackingOutput,
                                                 mode: UserMode,
                                                 inSameLink: Bool) async -> RecoveryResult_v2? {
        guard userPeakAndLinkBuffer.count >= 3 else {
            JupiterLogger.i(tag: "RecoveryManager", message: "(recoverWithMultipleTrajAsync_v2) userPeakAndLinkBuffer is less than 3")
            return nil
        }
        let key = "\(sectorId)_\(curPmResult.building_name)_\(curPmResult.level_name)"
        guard let nodeData = PathMatcher.shared.nodeData[key], let linkData = PathMatcher.shared.linkData[key] else { return nil }

        guard let firstLink = await self.pmGate.getLinkInfoWithResult(sectorId: sectorId,
                                                                      result: resultWhenFisrtPeak,
                                                                      checkAll: true,
                                                                      acceptDist: 15) else { return nil }
        
        let indexDiff = Float(curPmResult.index - resultWhenFisrtPeak.index)
        let firstLinkGroupId = firstLink.group_id
        let thirdUserPeak = userPeakAndLinkBuffer[userPeakAndLinkBuffer.count - 3].0
        let thirdUserLink = userPeakAndLinkBuffer[userPeakAndLinkBuffer.count - 3].1
        
        let secondUserPeak = userPeakAndLinkBuffer[userPeakAndLinkBuffer.count - 2].0
        let secondUserPeakIndex = secondUserPeak.peak_index
        
        let firstUserPeak = userPeakAndLinkBuffer[userPeakAndLinkBuffer.count - 1].0
        let firstUserPeakIndex = firstUserPeak.peak_index

        JupiterLogger.i(tag: "RecoveryManager", message: "(recoverWithMultipleTrajAsync_v2) third: \(thirdUserPeak.id), second: \(secondUserPeak.id), first: \(firstUserPeak.id)")
        JupiterLogger.i(tag: "RecoveryManager", message: "(recoverWithMultipleTrajAsync_v2) thirdIndex: \(thirdUserPeak.peak_index), secondIndex: \(secondUserPeak.peak_index), firstIndex: \(firstUserPeak.peak_index)")
        
        let thirdLandmarkCands: [PeakData] = landmarks.third.peaks
        let secondLandmarkCands: [PeakData] = landmarks.second.peaks
        let firstLandmarkCands: [PeakData] = landmarks.first.peaks

        let bestCandidate: _RecoveryCandidate_v2? = await withTaskGroup(of: _RecoveryCandidate_v2?.self) { group in
            for recoveryTraj in recoveryTrajList {
                group.addTask { [self, sectorId = self.sectorId, nodeData = nodeData, linkData = linkData, firstLinkGroupId = firstLinkGroupId] in
                    guard recoveryTraj.count >= 2 else {
                        JupiterLogger.i(tag: "RecoveryManager", message: "(recoverWithMultipleTrajAsync_v2) recoveryTraj size is less than 2")
                        return nil
                    }
                    
                    JupiterLogger.i(tag: "RecoveryManager", message: "(recoverWithMultipleTrajAsync_v2) recoveryTraj: \(recoveryTraj.map {$0.index})")
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
                        JupiterLogger.i(tag: "RecoveryManager", message: "(recoverWithMultipleTrajAsync_v2) anchorIdx or midIdx fail")
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
                            if candLink.group_id != firstLinkGroupId {
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
                        
//                        guard let bodyLink = await self.pmGate.getLinkInfoWithResult(sectorId: sectorId,
//                                                                                     result: bodyResult,
//                                                                                     checkAll: true, acceptDist: 15) else {
//                            JupiterLogger.i(tag: "RecoveryManager", message: "(recover) body link fail [\(bodyResult.x),\(bodyResult.y)]")
//                            continue
//                        }
                        
                        // dist1: tail? -> best third landmark (optionally group-constrained)
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
                            JupiterLogger.i(tag: "RecoveryManager", message: "(recoverWithMultipleTrajAsync_v2) tail link fail [\(tailResult.x),\(tailResult.y)]")
                            continue
                        }
                        let tailLinkGroupId = tailLink.group_id
                        
//                        guard self.isHeadBodyTailConnectedViaGraph(nodeData: nodeData,
//                                                                  linkData: linkData,
//                                                                  headLink: headLink,
//                                                                  bodyLink: bodyLink,
//                                                                  tailLink: tailLink) else {
//                            JupiterLogger.i(tag: "RecoveryManager", message: "(recover) graph connectivity failed")
//                            continue
//                        }
                        
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

                            _ = tailLinkGroupId
                        }
                    }

                    if let st = localBestShiftedTraj, let rc = localBestFirstCand {
                        return _RecoveryCandidate_v2(loss: localBestLoss,
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

            var best: _RecoveryCandidate_v2? = nil
            for await cand in group {
                guard let cand = cand else { continue }
                if best == nil || cand.loss < best!.loss {
                    best = cand
                }
            }
            return best
        }

        guard let best = bestCandidate else {
            JupiterLogger.i(tag: "RecoveryManager", message: "(recoverWithMultipleTrajAsync_v2) bestCandidate nil")
            return nil
        }
        var resultTraj = [[Double]]()
        resultTraj.reserveCapacity(best.shiftedTraj.count)
        for value in best.shiftedTraj {
            resultTraj.append([Double(value.x), Double(value.y)])
        }

        let bestThird: [Int] = best.thirdCand != nil ? [best.thirdCand!.x, best.thirdCand!.y] : [0, 0]
        let bestSecond: [Int] = best.secondCand != nil ? [best.secondCand!.x, best.secondCand!.y] : [0, 0]
        let recoveryResult = RecoveryResult_v2(traj: resultTraj,
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
        if startLink.id == targetLink.id { return true }
        if maxGroupSwitches < 0 { return false }

        // Distance = min group-switch count to reach linkId
        var dist: [Int: Int] = [startLink.id: 0]

        // Safe deque for 0-1 BFS: front stack + back queue + index
        var front: [Int] = [startLink.id]   // pushFront = append, popFront = popLast
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
            for id in out {
                if id == link.id { continue }
                if unique.contains(id) { continue }
                unique.append(id)
            }
            return unique
        }

        while let curId = popFront() {
            guard let curLink = linkData[curId] else { continue }
            let curDist = dist[curId] ?? Int.max
            if curDist > maxGroupSwitches { continue }

            for nbId in neighbors(of: curLink) {
                guard let nbLink = linkData[nbId] else { continue }

                let cost = (nbLink.group_id == curLink.group_id) ? 0 : 1
                let nd = curDist + cost
                if nd > maxGroupSwitches { continue }

                let prev = dist[nbId] ?? Int.max
                if nd < prev {
                    dist[nbId] = nd
                    if nbId == targetLink.id { return true }

                    if cost == 0 {
                        pushFront(nbId)
                    } else {
                        pushBack(nbId)
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
        if tailLink.group_id == bodyLink.group_id && bodyLink.group_id == headLink.group_id {
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
        if startLink.id == targetLink.id { return true }
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
            for id in out {
                if id == link.id { continue }
                if unique.contains(id) { continue }
                unique.append(id)
            }
            return unique
        }

        var visited: Set<Int> = [startLink.id]
        var q: [(id: Int, d: Int)] = [(startLink.id, 0)]
        var head = 0

        while head < q.count {
            let (curId, d) = q[head]
            head += 1
            if d >= maxHops { continue }
            guard let curLink = linkData[curId] else { continue }

            for nbId in neighbors(of: curLink) {
                if nbId == targetLink.id { return true }
                if visited.contains(nbId) { continue }
                visited.insert(nbId)
                q.append((nbId, d + 1))
            }
        }

        return false
    }

    private func dist2(_ ax: Float, _ ay: Float, _ bx: Float, _ by: Float) -> Float {
        let dx = ax - bx
        let dy = ay - by
        return sqrt(dx * dx + dy * dy)
    }

}
