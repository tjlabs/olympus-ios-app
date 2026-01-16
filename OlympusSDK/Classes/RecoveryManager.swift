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
    
    func makeRecoveryTrajectory(uvdBuffer: [UserVelocity], startHeading: Float) -> [RecoveryTrajectory] {
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
        
        return resultBuffer
    }
    
//    (traj: [RecoveryTrajectory], loss: Float, recentCand: PeakData, olderCand: PeakData?)?
    func recover(recoveryTraj: [RecoveryTrajectory],
                 userPeakAndLinkBuffer: [(UserPeak, LinkData)],
                 landmarks: (older: LandmarkData, recent: LandmarkData),
                 tuResultWhenOlderPeak: ixyhs,
                 curPmResult: FineLocationTrackingOutput,
                 mode: UserMode) -> RecoveryResult? {
        guard userPeakAndLinkBuffer.count >= 2 else { return nil }
        guard recoveryTraj.count >= 2 else { return nil }

        let olderUserPeak = userPeakAndLinkBuffer[userPeakAndLinkBuffer.count - 2].0
        let olderUserLink = userPeakAndLinkBuffer[userPeakAndLinkBuffer.count - 2].1

        let recentUserPeak = userPeakAndLinkBuffer[userPeakAndLinkBuffer.count - 1].0
        let recentUserPeakIndex = recentUserPeak.peak_index
        JupiterLogger.i(tag: "RecoveryManager", message: "(recover) olderPeakId: \(olderUserPeak.id), oldPeakIndex: \(olderUserPeak.peak_index), recentPeakId: \(recentUserPeak.id), recentPeakIndex: \(recentUserPeakIndex)")
        var arrayIndex: Int? = nil
        for i in 0..<recoveryTraj.count {
            if recoveryTraj[i].index == recentUserPeakIndex {
                arrayIndex = i
                break
            }
        }
        JupiterLogger.i(tag: "RecoveryManager", message: "(recover) arrayIndex: \(arrayIndex)")
        guard let anchorIdx = arrayIndex else {
            return nil
        }

        let olderLandmarkCands: [PeakData] = landmarks.older.peaks
        let recentLandmarkCands: [PeakData] = landmarks.recent.peaks

        func dist2(_ ax: Float, _ ay: Float, _ bx: Float, _ by: Float) -> Float {
            let dx = ax - bx
            let dy = ay - by
            return sqrt(dx * dx + dy * dy)
        }

        var bestLoss = Float.greatestFiniteMagnitude
        var bestShiftedTraj: [RecoveryTrajectory]? = nil
        var bestRecentCand: PeakData? = nil
        var bestOlderCand: PeakData? = nil
        var bestTail: FineLocationTrackingOutput? = nil
        var bestHead: FineLocationTrackingOutput? = nil

        // RecoveryTrajectory 는 index: Int, x: Float, y: Float, heading: Float 으로 구성됨
        for cand in recentLandmarkCands {
            let candXY: [Float] = [Float(cand.x), Float(cand.y)]
            let offsetX = candXY[0] - recoveryTraj[anchorIdx].x
            let offsetY = candXY[1] - recoveryTraj[anchorIdx].y

            // 1) Create shiftedTraj by applying offset to every point
            var shiftedTraj: [RecoveryTrajectory] = []
            shiftedTraj.reserveCapacity(recoveryTraj.count)
            for p in recoveryTraj {
                shiftedTraj.append(RecoveryTrajectory(index: p.index,
                                                     x: p.x + offsetX,
                                                     y: p.y + offsetY,
                                                     heading: p.heading))
            }
            guard let first = shiftedTraj.first, let last = shiftedTraj.last else { continue }
            if cand.x == 185 && cand.y == 246 {
                JupiterLogger.i(tag: "RecoveryManager", message: "(recover) check!! // traj: \(recoveryTraj)")
            }
            
            // 2) Map-match tail (first point) and compute tail link group
            guard let tail = PathMatcher.shared.pathMatching(sectorId: self.sectorId,
                                                            building: curPmResult.building_name,
                                                            level: curPmResult.level_name,
                                                            x: first.x,
                                                            y: first.y,
                                                            heading: first.heading,
                                                            isUseHeading: false,
                                                            mode: mode,
                                                            paddingValues: JupiterMode.PADDING_VALUES_DR) else { continue }

            var tailResult = curPmResult
            tailResult.x = tail.x
            tailResult.y = tail.y
            tailResult.absolute_heading = tail.heading
            JupiterLogger.i(tag: "RecoveryManager", message: "(recover) check!! // tailXY: [\(tail.x), \(tail.y)]")
            guard let tailLink = PathMatcher.shared.getLinkInfoWithResult(sectorId: sectorId, result: tailResult, checkAll: true) else {
                JupiterLogger.i(tag: "RecoveryManager", message: "(recover) tail link not found")
                continue
            }
            let tailLinkGroupId = tailLink.group_id

            // 3) Map-match head (last point)
            guard let head = PathMatcher.shared.pathMatching(sectorId: self.sectorId,
                                                            building: curPmResult.building_name,
                                                            level: curPmResult.level_name,
                                                            x: last.x,
                                                            y: last.y,
                                                            heading: last.heading,
                                                            isUseHeading: false,
                                                            mode: mode,
                                                             paddingValues: JupiterMode.PADDING_VALUES_DR) else {
                JupiterLogger.i(tag: "RecoveryManager", message: "(recover) head pm fail: [\(last.x),\(last.y),\(last.heading)]")
                continue
            }
            JupiterLogger.i(tag: "RecoveryManager", message: "(recover) check!! // headXY: [\(head.x), \(head.y)]")
            // 4) Compute dist metrics
            // dist1: min distance between tail xy and older landmark candidates that lie on a link with the same group
            var dist1 = Float.greatestFiniteMagnitude
            var localBestOlderCand: PeakData? = nil
            for oc in olderLandmarkCands {
                var tmp = curPmResult
                tmp.x = Float(oc.x)
                tmp.y = Float(oc.y)
                let peakDist = dist2(Float(oc.x), Float(oc.y), Float(cand.x), Float(cand.y))
                if peakDist < 10 { continue }
                tmp.absolute_heading = tail.heading

                guard let ocLink = PathMatcher.shared.getLinkInfoWithResult(sectorId: sectorId, result: tmp) else { continue }
                JupiterLogger.i(tag: "RecoveryManager", message: "(recover) olderXY: [\(oc.x),\(oc.y)] // linkGroupId: older= \(ocLink.group_id), tail= \(tailLinkGroupId)")
//                guard ocLink.group_id == tailLinkGroupId else { continue }
                
                let d = dist2(Float(tail.x), Float(tail.y), Float(oc.x), Float(oc.y))
                if d < dist1 {
                    dist1 = d
                    localBestOlderCand = oc
                }
                
                JupiterLogger.i(tag: "RecoveryManager", message: "(recover) localBestOlderCand: \(localBestOlderCand)")
                if dist1 == Float.greatestFiniteMagnitude {
                    // No group-consistent older landmark -> heavily penalize
                    dist1 = 1_000_000
                }

                // dist2: distance between tail xy and TU result at older peak
                let dist2v = dist2(Float(tail.x), Float(tail.y), Float(tuResultWhenOlderPeak.x), Float(tuResultWhenOlderPeak.y))

                // dist3: distance between head xy and current PM result xy
                let dist3 = dist2(Float(head.x), Float(head.y), Float(last.x), Float(last.y))

                // 5) Loss (equal weights for now)
                let loss = dist1 + dist2v + dist3
                if loss < bestLoss {
                    bestLoss = loss
                    bestShiftedTraj = shiftedTraj
                    bestRecentCand = cand
                    bestOlderCand = localBestOlderCand

                    var bt = curPmResult
                    bt.x = tail.x
                    bt.y = tail.y
                    bestTail = bt

                    var bh = curPmResult
                    bh.x = head.x
                    bh.y = head.y
                    bestHead = bh
                }
            }
        }

        if let bestShiftedTraj = bestShiftedTraj, let bestRecentCand = bestRecentCand {
            let olderCandMsg = bestOlderCand.map { "(\($0.x),\($0.y))" } ?? "nil"
            JupiterLogger.i(tag: "RecoveryManager", message: "(recover) selected recentCand=(\(bestRecentCand.x),\(bestRecentCand.y)) olderCand=\(olderCandMsg) olderPeakIdx=\(olderUserPeak.peak_index) olderLinkGroup=\(olderUserLink.group_id) bestLoss=\(bestLoss)")
            _ = bestTail
            _ = bestHead
            
            var resultTraj = [[Double]]()
            for value in bestShiftedTraj {
                resultTraj.append([Double(value.x), Double(value.y)])
            }
            
            let recoveryResult = RecoveryResult(traj: resultTraj,
                                                loss: bestLoss,
                                                bestOlder: [bestOlderCand!.x, bestOlderCand!.y],
                                                bestRecent: [bestRecentCand.x, bestRecentCand.y],
                                                bestResult: nil)
            return recoveryResult
//            return (traj: bestShiftedTraj, loss: bestLoss, olderCand: bestOlderCand, recentCand: bestRecentCand)
        } else {
            JupiterLogger.i(tag: "RecoveryManager", message: "(recover) failed: no valid shifted trajectory candidates. recentCands=\(recentLandmarkCands.count)")
            return nil
        }
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
//                JupiterLogger.i(tag: "RecoveryManager", message: "(makeMultipleRecoveryTrajectory) BadCase: pathHeading= \(pathHeading) // lastHeading= \(lastHeading) // endHeading= \(endHeading) // diffHeading= \(diffHeading)")
                if diffHeading < Float(JupiterMode.HEADING_RANGE) {
                    trajList.append(resultBuffer)
                }
            }
        }
  
        return trajList
    }
    
    func recoverWithMultipleTraj(recoveryTrajList: [[RecoveryTrajectory]],
                                 userPeakAndLinkBuffer: [(UserPeak, LinkData)],
                                 landmarks: (older: LandmarkData, recent: LandmarkData),
                                 tuResultWhenOlderPeak: ixyhs,
                                 curPmResult: FineLocationTrackingOutput,
                                 mode: UserMode) -> RecoveryResult? {
        let semaphore = DispatchSemaphore(value: 0)
        var output: RecoveryResult? = nil

        Task {
            output = await self.recoverWithMultipleTrajAsync(recoveryTrajList: recoveryTrajList,
                                                            userPeakAndLinkBuffer: userPeakAndLinkBuffer,
                                                            landmarks: landmarks,
                                                            tuResultWhenOlderPeak: tuResultWhenOlderPeak,
                                                            curPmResult: curPmResult,
                                                            mode: mode)
            semaphore.signal()
        }

        semaphore.wait()
        return output
    }

    private struct _RecoveryCandidate {
        let loss: Float
        let shiftedTraj: [RecoveryTrajectory]
        let recentCand: PeakData
        let olderCand: PeakData?
        let tail: FineLocationTrackingOutput?
        let head: FineLocationTrackingOutput?
    }

    private func recoverWithMultipleTrajAsync(recoveryTrajList: [[RecoveryTrajectory]],
                                             userPeakAndLinkBuffer: [(UserPeak, LinkData)],
                                             landmarks: (older: LandmarkData, recent: LandmarkData),
                                             tuResultWhenOlderPeak: ixyhs,
                                             curPmResult: FineLocationTrackingOutput,
                                             mode: UserMode) async -> RecoveryResult? {
        guard userPeakAndLinkBuffer.count >= 2 else { return nil }

        let olderUserPeak = userPeakAndLinkBuffer[userPeakAndLinkBuffer.count - 2].0
        let olderUserLink = userPeakAndLinkBuffer[userPeakAndLinkBuffer.count - 2].1

        let recentUserPeak = userPeakAndLinkBuffer[userPeakAndLinkBuffer.count - 1].0
        let recentUserPeakIndex = recentUserPeak.peak_index

//        JupiterLogger.i(tag: "RecoveryManager", message: "(recover) olderPeakId: \(olderUserPeak.id), oldPeakIndex: \(olderUserPeak.peak_index), recentPeakId: \(recentUserPeak.id), recentPeakIndex: \(recentUserPeakIndex)")

        let olderLandmarkCands: [PeakData] = landmarks.older.peaks
        let recentLandmarkCands: [PeakData] = landmarks.recent.peaks

        func dist2(_ ax: Float, _ ay: Float, _ bx: Float, _ by: Float) -> Float {
            let dx = ax - bx
            let dy = ay - by
            return sqrt(dx * dx + dy * dy)
        }

        let bestCandidate: _RecoveryCandidate? = await withTaskGroup(of: _RecoveryCandidate?.self) { group in
            for recoveryTraj in recoveryTrajList {
                group.addTask { [sectorId = self.sectorId] in
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
                                                                       paddingValues: JupiterMode.PADDING_VALUES_DR) else { continue }

                        var tailResult = curPmResult
                        tailResult.x = tail.x
                        tailResult.y = tail.y
                        tailResult.absolute_heading = tail.heading

                        guard let tailLink = await self.pmGate.getLinkInfoWithResult(sectorId: sectorId,
                                                                                    result: tailResult,
                                                                                    checkAll: true) else {
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
                                                                       paddingValues: JupiterMode.PADDING_VALUES_DR) else {
                            continue
                        }

                        // dist1: tail -> best older landmark (optionally group-constrained)
                        var dist1 = Float.greatestFiniteMagnitude
                        var localOlderCand: PeakData? = nil

                        for oc in olderLandmarkCands {
                            var tmp = curPmResult
                            tmp.x = Float(oc.x)
                            tmp.y = Float(oc.y)

                            let peakDist = dist2(Float(oc.x), Float(oc.y), Float(cand.x), Float(cand.y))
                            if peakDist < 5 { continue }
                            tmp.absolute_heading = tail.heading
//                            guard let ocLink = await self.pmGate.getLinkInfoWithResult(sectorId: sectorId,
//                                                                                      result: tmp,
//                                                                                      checkAll: true) else {
//                                continue
//                            }

                            let d = dist2(Float(tail.x), Float(tail.y), Float(oc.x), Float(oc.y))
                            if d < dist1 {
                                dist1 = d
                                localOlderCand = oc
                            }
                        }

                        if dist1 == Float.greatestFiniteMagnitude {
                            dist1 = 1_000_000
                        }

                        // dist2: tail -> TU result at older peak
                        let dist2v = dist2(Float(tail.x), Float(tail.y), Float(tuResultWhenOlderPeak.x), Float(tuResultWhenOlderPeak.y))

                        // dist3: head -> last (shifted traj last point)
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
                                            loss: best.loss,
                                            bestOlder: bestOlder,
                                            bestRecent: [best.recentCand.x, best.recentCand.y],
                                            bestResult: best.head)
        return recoveryResult
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
                                  checkAll: Bool) -> LinkData? {
            return PathMatcher.shared.getLinkInfoWithResult(sectorId: sectorId,
                                                           result: result,
                                                           checkAll: checkAll)
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
}
