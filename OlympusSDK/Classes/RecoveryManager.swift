import Foundation
import TJLabsCommon
import TJLabsResource

class RecoveryManager {
    
    init(sectorId: Int) {
        self.sectorId = sectorId
    }
    
    var sectorId: Int
    
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
            
//            if dist1 == Float.greatestFiniteMagnitude {
//                // No group-consistent older landmark -> heavily penalize
//                dist1 = 1_000_000
//            }
//
//            // dist2: distance between tail xy and TU result at older peak
//            let dist2v = dist2(Float(tail.x), Float(tail.y), Float(tuResultWhenOlderPeak.x), Float(tuResultWhenOlderPeak.y))
//
//            // dist3: distance between head xy and current PM result xy
//            let dist3 = dist2(Float(head.x), Float(head.y), Float(last.x), Float(last.y))
//
//            // 5) Loss (equal weights for now)
//            let loss = dist1 + dist2v + dist3
//            if loss < bestLoss {
//                bestLoss = loss
//                bestShiftedTraj = shiftedTraj
//                bestRecentCand = cand
//                bestOlderCand = localBestOlderCand
//
//                var bt = curPmResult
//                bt.x = tail.x
//                bt.y = tail.y
//                bestTail = bt
//
//                var bh = curPmResult
//                bh.x = head.x
//                bh.y = head.y
//                bestHead = bh
//            }
        }

        if let bestShiftedTraj = bestShiftedTraj, let bestRecentCand = bestRecentCand {
            let olderCandMsg = bestOlderCand.map { "(\($0.x),\($0.y))" } ?? "nil"
            JupiterLogger.i(tag: "RecoveryManager", message: "(recover) selected recentCand=(\(bestRecentCand.x),\(bestRecentCand.y)) olderCand=\(olderCandMsg) olderPeakIdx=\(olderUserPeak.peak_index) olderLinkGroup=\(olderUserLink.group_id) bestLoss=\(bestLoss)")
            // If needed later, these can be returned too:
            _ = bestTail
            _ = bestHead
            
            var resultTraj = [[Double]]()
            for value in bestShiftedTraj {
                resultTraj.append([Double(value.x), Double(value.y)])
            }
            
            let recoveryResult = RecoveryResult(traj: resultTraj, loss: bestLoss, bestOlder: [bestOlderCand!.x, bestOlderCand!.y], bestRecent: [bestRecentCand.x, bestRecentCand.y])
            return recoveryResult
//            return (traj: bestShiftedTraj, loss: bestLoss, olderCand: bestOlderCand, recentCand: bestRecentCand)
        } else {
            JupiterLogger.i(tag: "RecoveryManager", message: "(recover) failed: no valid shifted trajectory candidates. recentCands=\(recentLandmarkCands.count)")
            return nil
        }
    }
}
