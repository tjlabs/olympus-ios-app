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
                            if peakDist < 2 { continue }
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
                                    mode: UserMode) -> RecoveryResult_v2? {
        let semaphore = DispatchSemaphore(value: 0)
        var output: RecoveryResult_v2? = nil

        Task {
            output = await self.recoverWithMultipleTrajAsync_v2(recoveryTrajList: recoveryTrajList,
                                                            userPeakAndLinkBuffer: userPeakAndLinkBuffer,
                                                            landmarks: landmarks,
                                                            tuResultWhenThirdPeak: tuResultWhenThirdPeak,
                                                            resultWhenFisrtPeak: resultWhenFisrtPeak,
                                                            curPmResult: curPmResult,
                                                            mode: mode)
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
                                                 mode: UserMode) async -> RecoveryResult_v2? {
        guard userPeakAndLinkBuffer.count >= 3 else { return nil }
        let key = "\(sectorId)_\(curPmResult.building_name)_\(curPmResult.level_name)"
        guard let nodeData = PathMatcher.shared.nodeData[key], let linkData = PathMatcher.shared.linkData[key] else { return nil }
        // Base link-group constraint: first landmark must be on the same link-group as current PM result.
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

        JupiterLogger.i(tag: "RecoveryManager", message: "(recover) third: \(thirdUserPeak.id), second: \(secondUserPeak.id), first: \(firstUserPeak.id)")
        
        let thirdLandmarkCands: [PeakData] = landmarks.third.peaks
        let secondLandmarkCands: [PeakData] = landmarks.second.peaks
        let firstLandmarkCands: [PeakData] = landmarks.first.peaks

        func dist2(_ ax: Float, _ ay: Float, _ bx: Float, _ by: Float) -> Float {
            let dx = ax - bx
            let dy = ay - by
            return sqrt(dx * dx + dy * dy)
        }

        let bestCandidate: _RecoveryCandidate_v2? = await withTaskGroup(of: _RecoveryCandidate_v2?.self) { group in
            for recoveryTraj in recoveryTrajList {
                group.addTask { [sectorId = self.sectorId, nodeData = nodeData, linkData = linkData, firstLinkGroupId = firstLinkGroupId] in
                    guard recoveryTraj.count >= 2 else { return nil }
                    
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
                    guard let aIdx = anchorIdx, let mIdx = midIdx else { return nil }

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
                        var candResult = curPmResult
                        candResult.x = Float(cand.x)
                        candResult.y = Float(cand.y)
                        candResult.absolute_heading = curPmResult.absolute_heading
                        
                        let distWithFirst = dist2(resultWhenFisrtPeak.x, resultWhenFisrtPeak.y, Float(cand.x), Float(cand.y))
                        if distWithFirst > Float(indexDiff*2.5) {
                            continue
                        }
                        
                        guard let candLink = await self.pmGate.getLinkInfoWithResult(sectorId: sectorId,
                                                                                     result: candResult,
                                                                                     checkAll: true, acceptDist: 15) else {
                            continue
                        }
                        if candLink.group_id != firstLinkGroupId {
                            continue
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
                                                                       paddingValues: JupiterMode.PADDING_VALUES_PDR) else { continue }

                        var tailResult = curPmResult
                        tailResult.x = tail.x
                        tailResult.y = tail.y
                        tailResult.absolute_heading = tail.heading

//                        guard let tailLink = await self.pmGate.getLinkInfoWithResult(sectorId: sectorId,
//                                                                                    result: tailResult,
//                                                                                     checkAll: true, acceptDist: 15) else {
//                            JupiterLogger.i(tag: "RecoveryManager", message: "(recover) tail link fail [\(tailResult.x),\(tailResult.y)]")
//                            continue
//                        }
//                        let tailLinkGroupId = tailLink.group_id
                        
                        // Mid PM
                        guard let body = await self.pmGate.pathMatching(sectorId: sectorId,
                                                                       building: curPmResult.building_name,
                                                                       level: curPmResult.level_name,
                                                                       x: mid.x,
                                                                       y: mid.y,
                                                                       heading: mid.heading,
                                                                       isUseHeading: false,
                                                                       mode: mode,
                                                                       paddingValues: JupiterMode.PADDING_VALUES_PDR) else { continue }

                        var bodyResult = curPmResult
                        bodyResult.x = body.x
                        bodyResult.y = body.y
                        bodyResult.absolute_heading = body.heading
                        
//                        guard let bodyLink = await self.pmGate.getLinkInfoWithResult(sectorId: sectorId,
//                                                                                     result: bodyResult,
//                                                                                     checkAll: true, acceptDist: 15) else {
//                            JupiterLogger.i(tag: "RecoveryManager", message: "(recover) body link fail [\(bodyResult.x),\(bodyResult.y)]")
//                            continue
//                        }
                        
                        // Head PM
                        guard let head = await self.pmGate.pathMatching(sectorId: sectorId,
                                                                       building: curPmResult.building_name,
                                                                       level: curPmResult.level_name,
                                                                       x: last.x,
                                                                       y: last.y,
                                                                       heading: last.heading,
                                                                       isUseHeading: false,
                                                                       mode: mode,
                                                                       paddingValues: JupiterMode.PADDING_VALUES_PDR) else {
                            continue
                        }
                        var headResult = curPmResult
                        headResult.x = head.x
                        headResult.y = head.y
                        headResult.absolute_heading = head.heading
                        
                        guard let headLink = await self.pmGate.getLinkInfoWithResult(sectorId: sectorId,
                                                                                     result: headResult,
                                                                                     checkAll: true, acceptDist: 15) else {
                            JupiterLogger.i(tag: "RecoveryManager", message: "(recover) head link fail [\(headResult.x),\(headResult.y)]")
                            continue
                        }

                        // Stronger plausibility filter: ensure head -> body -> tail is connectable on the map graph.
//                        guard self.isHeadBodyTailConnectedViaGraph(nodeData: nodeData,
//                                                                  linkData: linkData,
//                                                                  headLink: headLink,
//                                                                  bodyLink: bodyLink,
//                                                                  tailLink: tailLink) else {
//                             JupiterLogger.i(tag: "RecoveryManager", message: "(recover) graph connectivity failed")
//                            continue
//                        }

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
                        
                        guard let bodyLink = await self.pmGate.getLinkInfoWithResult(sectorId: sectorId,
                                                                                     result: bodyResult,
                                                                                     checkAll: true, acceptDist: 15) else {
                            JupiterLogger.i(tag: "RecoveryManager", message: "(recover) body link fail [\(bodyResult.x),\(bodyResult.y)]")
                            continue
                        }
                        
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
                                                                                     checkAll: true, acceptDist: 15) else {
                            JupiterLogger.i(tag: "RecoveryManager", message: "(recover) tail link fail [\(tailResult.x),\(tailResult.y)]")
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

        guard let best = bestCandidate else { return nil }

        let thirdCandMsg = best.thirdCand.map { "(\($0.x),\($0.y))" } ?? "nil"
//        JupiterLogger.i(tag: "RecoveryManager", message: "(recover) selected recentCand=(\(best.recentCand.x),\(best.recentCand.y)) olderCand=\(olderCandMsg) olderPeakIdx=\(olderUserPeak.peak_index) olderLinkGroup=\(olderUserLink.group_id) bestLoss=\(best.loss)")

        var resultTraj = [[Double]]()
        resultTraj.reserveCapacity(best.shiftedTraj.count)
        for value in best.shiftedTraj {
            resultTraj.append([Double(value.x), Double(value.y)])
        }

        let bestThird: [Int] = best.thirdCand != nil ? [best.thirdCand!.x, best.thirdCand!.y] : [0, 0]
        let bestSecond: [Int] = best.secondCand != nil ? [best.secondCand!.x, best.secondCand!.y] : [0, 0]
        let recoveryResult = RecoveryResult_v2(traj: resultTraj,
                                               loss: best.loss,
                                               bestThird: bestThird,
                                               bestSecond: bestSecond,
                                               bestFirst: [best.firstCand.x, best.firstCand.y],
                                               bestResult: best.head)
        return recoveryResult
    }
    // MARK: - Link connectivity validation (graph-based)

    /// 0-1 BFS on the *link graph* (links are adjacent if they share an endpoint node).
    /// Cost rule: moving to a neighbor link with the SAME group_id costs 0, otherwise costs 1.
    /// This effectively counts "group switches" instead of raw link hops.
    /// 0-1 BFS on the *link graph* (links are adjacent if they share an endpoint node).
    /// Cost rule: moving to a neighbor link with the SAME group_id costs 0, otherwise costs 1.
    /// This effectively counts "group switches" instead of raw link hops.
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

            // periodic compaction to avoid unbounded growth
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

    /// Ensures `tailLink -> bodyLink -> headLink` can be connected on the map, while limiting
    /// how many times we switch link-groups along the way.
    /// - Rule: traversing links within the same group_id does NOT count as a hop.
    /// - We reject paths that require switching groups 2+ times.
    private func isHeadBodyTailConnectedViaGraph(nodeData: [Int: NodeData],
                                                linkData: [Int: LinkData],
                                                headLink: LinkData,
                                                bodyLink: LinkData,
                                                tailLink: LinkData) -> Bool {
        // Allow at most 1 group switch between segments.
        let maxGroupSwitches = 1

        // Quick pass: if everything already in the same group, accept.
        if tailLink.group_id == bodyLink.group_id && bodyLink.group_id == headLink.group_id {
            return true
        }

        // tail -> body (by link graph)
        let tailToBody = isLinkReachableWithGroupSwitchLimit(nodeData: nodeData,
                                                            linkData: linkData,
                                                            from: tailLink,
                                                            to: bodyLink,
                                                            maxGroupSwitches: maxGroupSwitches)
        if !tailToBody { return false }

        // body -> head (by link graph)
        let bodyToHead = isLinkReachableWithGroupSwitchLimit(nodeData: nodeData,
                                                            linkData: linkData,
                                                            from: bodyLink,
                                                            to: headLink,
                                                            maxGroupSwitches: maxGroupSwitches)
        return bodyToHead
    }

}
