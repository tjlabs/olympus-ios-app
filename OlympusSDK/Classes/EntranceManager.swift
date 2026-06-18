
import Foundation
import TJLabsCommon
import TJLabsResource

class EntranceManager {
    init(sectorId: Int) {
        self.sectorId = sectorId
        
        self.curEntKey = nil
        self.checkStartEntTrackFlag = false
        self.checkStartEntTrackTimestamp = 0
        self.scaledDistance = 0
        self.isLastEntPos = false
        self.checkForcedStopEntTrackTimestamp = 0
        self.entTrackFinishedTimestamp = 0
    }
    
    deinit { }
    
    private let ENTERING_LSE_BUFFER_SIZE = 5
    private let ENTERING_LSE_MAX_STEP_DISTANCE: Float = 30
    private let ENTERING_LSE_MAX_PATH_LENGTH_DIFF: Float = 25
    private let ENTERING_LSE_MIN_DISPLACEMENT: Float = 3
    private let ENTERING_LSE_MAX_AVG_TRAJECTORY_DISTANCE: Float = 18
    private let ENTERING_LSE_MAX_END_TRAJECTORY_DISTANCE: Float = 22
    private let ENTERING_LSE_SEGMENT_HEADING_STD_THRESHOLD: Double = 8
    
    private var entRouteMap = [String: EntranceRouteData]()
    private var entDataMap = [String: EntranceData]()
    private var entOuterWardIdMap = [String: String]()
    private var entInnerWardIdMap = [String: String]()
    private var entRoutingOrigin = [String: [Int]]()
    
    var sectorId: Int
    private var curEntKey: String?
    private var checkStartEntTrackFlag: Bool
    private var checkStartEntTrackTimestamp: Int
    private var scaledDistance: Double
    private var isLastEntPos: Bool
    private var checkForcedStopEntTrackTimestamp: Int
    private var entTrackFinishedTimestamp: Int
    
    func toggleToOutdoor() {
        self.curEntKey = nil
        self.checkStartEntTrackFlag = false
        self.checkStartEntTrackTimestamp = 0
        self.scaledDistance = 0
        self.isLastEntPos = false
        self.checkForcedStopEntTrackTimestamp = 0
        self.entTrackFinishedTimestamp = 0
    }
    
    func setEntRouteData(key: String, data: EntranceRouteData) {
        self.entRouteMap[key] = data
    }
    
    func setEntData(key: String, data: EntranceData) {
        self.entDataMap[key] = data
        if let outermostWard = data.outermostWard {
            self.entOuterWardIdMap[key] = outermostWard.name
            JupiterLogger.i(tag: "EntranceManager", message: "(setEntData) \(key) outermostWard: \(outermostWard.name)")
        }
        
        if let innermostWard = data.innermostWard {
            self.entInnerWardIdMap[key] = innermostWard.name
            JupiterLogger.i(tag: "EntranceManager", message: "(setEntData) \(key) innermostWard : \(innermostWard.name) -> xy:[\(innermostWard.x), \(innermostWard.y)], h:[\(innermostWard.headings)]")
        }
    }
    
    func checkStartEntTrack(wardId: String, sec: Int) -> String? {
        if entRouteMap.isEmpty {
            curEntKey = nil
            checkStartEntTrackFlag = false
        }
        JupiterLogger.i(tag: "EntranceManager", message: "(checkStartEntTrack) - checkStartEntTrackFlag = \(checkStartEntTrackFlag) // wardId = \(wardId)")
        
        if !checkStartEntTrackFlag {
            JupiterLogger.i(tag: "EntranceManager", message: "(checkStartEntTrack) - entOuterWardIdMap = \(entOuterWardIdMap)")
            if entOuterWardIdMap.values.contains(wardId) {
                curEntKey = entOuterWardIdMap.first(where: { $0.value == wardId })?.key ?? nil
                checkStartEntTrackFlag = true
                checkStartEntTrackTimestamp = TJLabsUtilFunctions.shared.getCurrentTimeInMilliseconds(as: .int) as! Int
            }
        }
        
        JupiterLogger.i(tag: "EntranceManager", message: "(checkStartEntTrack) - entering entrance... // key = \(curEntKey)")
        let timeDiff = TJLabsUtilFunctions.shared.getCurrentTimeInMilliseconds(as: .int) as! Int - checkStartEntTrackTimestamp
        JupiterLogger.i(tag: "EntranceManager", message: "(checkStartEntTrack) - timeDiff = \(timeDiff)")
        
        if (timeDiff >= sec * JupiterTime.SECONDS_TO_MILLIS && checkStartEntTrackFlag) {
            checkStartEntTrackFlag = false
        }
        
        return curEntKey
    }
        
    func startEntTrack(currentTime: Int, uvd: UserVelocity) -> FineLocationTrackingOutput? {
        guard let curEntKey = self.curEntKey else { return nil }
        let entTrackData = curEntKey.split(separator: "_")
        let entTrackBuilding = String(entTrackData[1])
        
        let length = uvd.length
        
        guard let entData = entDataMap[curEntKey] else { return nil }
        let scale = Double(entData.velocityScale)
  
        let scaledLength = length*scale
        scaledDistance += scaledLength
        var roundedIndex = Int(round(scaledDistance))
//        JupiterLogger.i(tag: "EntranceManager", message: "(trackEntRoute) - uvd index = \(uvd.index) // length = \(length) // scale = \(scale) // scaledLength = \(scaledLength) // scaledDistance =\(scaledDistance)")
        
        guard let routeData = self.entRouteMap[curEntKey] else { return nil }
        let entRouteLevel = routeData.routeLevel
        let entRouteCoord = routeData.route
        
        if roundedIndex >= entRouteCoord.count-1 {
            roundedIndex = entRouteCoord.count-1
            isLastEntPos = true
        } else {
            isLastEntPos = false
        }
//        JupiterLogger.i(tag: "EntranceManager", message: "(trackEntRoute) - roundedIndex = \(roundedIndex) // route size = \(entRouteCoord.count-1)")
        
        let result = FineLocationTrackingOutput(mobile_time: currentTime,
                                                index: uvd.index,
                                                building_name: entTrackBuilding,
                                                level_name: entRouteLevel[roundedIndex],
                                                x: entRouteCoord[roundedIndex][0],
                                                y: entRouteCoord[roundedIndex][1],
                                                absolute_heading: entRouteCoord[roundedIndex][2])
//        JupiterLogger.i(tag: "EntranceManager", message: "(trackEntRoute) - entTrackResult : \(result.building_name) , \(result.level_name) , \(result.x) , \(result.y) , \(result.absolute_heading)")
        return result
    }
            
    func forcedStopEntTrack(bleAvg: [String: Double], sec: Int) -> Bool {
        guard let curEntKey = self.curEntKey else { return false }
        let currentTime = TJLabsUtilFunctions.shared.getCurrentTimeInMilliseconds(as: .int) as! Int
        
        JupiterLogger.i(tag: "EntranceManager", message: "(forcedStopEntTrack) - start & stop : stop -> forcedStopEntTrack // time = \(currentTime), isLastEntrancePosition = \(isLastEntPos)")

        if isLastEntPos && curEntKey != "" {
            if let bleID = entInnerWardIdMap[curEntKey] {
                let scannedRSSI = bleAvg[bleID]
                if scannedRSSI == nil && checkForcedStopEntTrackTimestamp != 0 {
                    let timeDiff = currentTime - checkForcedStopEntTrackTimestamp
                    if timeDiff >= sec*1000 {
                        return true
                    }
                } else {
                    checkForcedStopEntTrackTimestamp = TJLabsUtilFunctions.shared.getCurrentTimeInMilliseconds(as: .int) as! Int
                }
            }
        }
        return false
    }
    
    func getEntTrackEndBuilding() -> String {
        guard let curEntKey = self.curEntKey else { return "" }
        
        let keyString = curEntKey.split(separator: "_")
        if keyString.isEmpty || keyString.count < 4 {
            return ""
        } else {
            return String(keyString[1])
        }
    }
    
    func getEntTrackEndLevel() -> String? {
        guard let curEntKey = self.curEntKey else { return nil }
        
        if let entRouteData = entRouteMap[curEntKey] {
            let entRouteLevel = entRouteData.routeLevel
            if !entRouteLevel.isEmpty {
                let levelName = entRouteLevel[entRouteLevel.count-1]
                JupiterLogger.i(tag: "EntranceManager", message: "(getEntTrackEndLevel) : levelName= \(levelName)")
                return levelName
            }
        }
        
        return nil
    }
    
    func setEntTrackFinishedTimestamp(time: Int) {
        self.entTrackFinishedTimestamp = time
    }
    
    func getEntInnermostWardCoord(key: String) -> [Float]? {
        guard let entData = entDataMap[key], let innermostWard = entData.innermostWard else { return nil }
        let coord: [Float] = [Float(innermostWard.x), Float(innermostWard.y)]
        return coord
    }
    
    func getEntInnermostWardIds() -> [String] {
        return Array(self.entInnerWardIdMap.values)
    }
    
    func stopEntTrack(wardId: String) -> InnermostWard? {
        guard let curEntKey = self.curEntKey,
              let innerWardId = entInnerWardIdMap[curEntKey],
              let entData = entDataMap[curEntKey],
              let innermostWard = entData.innermostWard else { return nil }
        
        if innerWardId == wardId {
            return innermostWard
        } else {
            return nil
        }
    }
    
    func isDrBufferStraightCircularStd(uvdBuffer: [UserVelocity], condition: Double = 5) -> (Bool, Double) {
        var headingBuffer = [Double]()
        for uvd in uvdBuffer {
            let compensatedHeading = TJLabsUtilFunctions.shared.compensateDegree(uvd.heading)
            headingBuffer.append(compensatedHeading)
        }
        let headingStd = TJLabsUtilFunctions.shared.calculateCircularStd(for: headingBuffer)
        return (headingStd <= condition) ? (true, headingStd) : (false, headingStd)
    }
    
    func maybePromoteEnteringToTrackingUsingLse(
        curResult: FineLocationTrackingOutput?,
        uvd: UserVelocity,
        uvdBuffer: [UserVelocity],
        lseSnapshotBuffer: [SingleEpochSnapshot],
        majorSection: [Float]
    ) -> FineLocationTrackingOutput? {
        func logSkip(
            _ reason: String,
            buildingName: String? = nil,
            levelName: String? = nil,
            matchedSnapshotCount: Int? = nil,
            extra: String? = nil
        ) {
            let resolvedBuildingName = buildingName ?? curResult?.building_name ?? "nil"
            let resolvedLevelName = levelName ?? curResult?.level_name ?? "nil"
            let resolvedMatchedSnapshotCount = matchedSnapshotCount.map(String.init) ?? "nil"
            let extraMessage = extra.map { ", \($0)" } ?? ""

            JupiterLogger.i(
                tag: "EntranceManager",
                message: "skip tracking transition: \(reason), index=\(uvd.index), building=\(resolvedBuildingName), level=\(resolvedLevelName), uvdBufferCount=\(uvdBuffer.count), lseSnapshotBufferCount=\(lseSnapshotBuffer.count), matchedSnapshotCount=\(resolvedMatchedSnapshotCount)\(extraMessage)"
            )
        }
        
        JupiterLogger.i(tag: "EntranceManager", message: "(maybePromoteEnteringToTrackingUsingLse) : uvd= \(uvd.index)")
        
        // LSE 기준으로 ENTERING 구간이 충분히 안정적일 때만 TRACKING으로 승격한다.
        guard let baseResult = curResult else {
            logSkip("curResult is nil")
            return nil
        }
        var finalResult = baseResult

        let snapshots = getEnteringSingleEpochSnapshotsFor(lseSnapshotBuffer: lseSnapshotBuffer, buildingName: baseResult.building_name)
        if snapshots.count < ENTERING_LSE_BUFFER_SIZE {
            logSkip(
                "insufficient matched LSE snapshots",
                buildingName: baseResult.building_name,
                levelName: baseResult.level_name,
                matchedSnapshotCount: snapshots.count,
                extra: "requiredSnapshotCount=\(ENTERING_LSE_BUFFER_SIZE)"
            )
            return nil
        }

        // 층 정보는 시뮬레이션과 실제가 다를 수 있어 버퍼 다수결로 최종 층을 정한다.
        let dominantLevelName = resolveDominantEnteringLseLevelName(
            snapshots: snapshots,
            fallbackLevelName: baseResult.level_name
        )
        JupiterLogger.i(tag: "EntranceManager", message: "(maybePromoteEnteringToTrackingUsingLse) dominantLevelName= \(dominantLevelName)")
        // 최근 LSE 버퍼가 만들어내는 이동 방향을 절대 heading 기준으로 사용한다.
        guard let lseTrendHeading = resolveEnteringLseTrendHeading(
            snapshots: snapshots,
            buildingName: baseResult.building_name,
            levelName: baseResult.level_name
        ) else {
            logSkip(
                "failed to resolve LSE trend heading",
                buildingName: baseResult.building_name,
                levelName: baseResult.level_name,
                matchedSnapshotCount: snapshots.count
            )
            return nil
        }
        
        JupiterLogger.i(tag: "EntranceManager", message: "(maybePromoteEnteringToTrackingUsingLse) lseTrendHeading= \(lseTrendHeading)")
        // LSE 자체가 크게 튀는 상황이면 UVD와 비교하기 전에 바로 배제한다.
        let lseStepDistances: [Float] = zip(snapshots, snapshots.dropFirst()).map { prev, next in
            let dx = next.result.x - prev.result.x
            let dy = next.result.y - prev.result.y
            return sqrt(dx * dx + dy * dy)
        }
        JupiterLogger.i(tag: "EntranceManager", message: "(maybePromoteEnteringToTrackingUsingLse) lseStepDistances= \(lseStepDistances)")
        let maxStepDistance = lseStepDistances.max() ?? 0

        if maxStepDistance > ENTERING_LSE_MAX_STEP_DISTANCE {
            logSkip(
                "unstable LSE step",
                buildingName: baseResult.building_name,
                levelName: baseResult.level_name,
                matchedSnapshotCount: snapshots.count,
                extra: "maxStepDistance=\(maxStepDistance), threshold=\(ENTERING_LSE_MAX_STEP_DISTANCE), steps=\(lseStepDistances)"
            )
            return nil
        }

        guard let firstSnapshot = snapshots.first else {
            logSkip(
                "missing first snapshot after snapshot validation",
                buildingName: baseResult.building_name,
                levelName: baseResult.level_name,
                matchedSnapshotCount: snapshots.count
            )
            return nil
        }
        guard let firstContext = firstSnapshot.requestContext else {
            logSkip(
                "missing first snapshot request context",
                buildingName: baseResult.building_name,
                levelName: baseResult.level_name,
                matchedSnapshotCount: snapshots.count
            )
            return nil
        }
        guard !majorSection.isEmpty else {
            logSkip(
                "majorSection is empty",
                buildingName: baseResult.building_name,
                levelName: baseResult.level_name,
                matchedSnapshotCount: snapshots.count
            )
            return nil
        }
        // UVD의 상대 heading을 LSE trend heading 기준으로 재정렬하기 위한 offset이다.
        let majorHeading = Float(majorSection.map { Double($0) }.reduce(0, +) / Double(majorSection.count))
        let headingCompensation = lseTrendHeading - majorHeading

        var segmentEndpointDistances: [Float] = []
        var propagatedPoints: [(index: Int, x: Float, y: Float)] = []

        propagatedPoints.append((
            index: firstContext.index,
            x: firstSnapshot.result.x,
            y: firstSnapshot.result.y
        ))

        var lastAlignedHeading = lseTrendHeading
        JupiterLogger.i(tag: "EntranceManager", message: "(maybePromoteEnteringToTrackingUsingLse) lastAlignedHeading= \(lastAlignedHeading)")

        for (prevSnapshot, nextSnapshot) in zip(snapshots, snapshots.dropFirst()) {
            JupiterLogger.i(tag: "EntranceManager", message: "(maybePromoteEnteringToTrackingUsingLse) prevContext= \(prevSnapshot.requestContext)")
            JupiterLogger.i(tag: "EntranceManager", message: "(maybePromoteEnteringToTrackingUsingLse) nextContext= \(nextSnapshot.requestContext)")
            guard let prevContext = prevSnapshot.requestContext, let nextContext = nextSnapshot.requestContext else {
                logSkip(
                    "missing snapshot request context in segment",
                    buildingName: baseResult.building_name,
                    levelName: baseResult.level_name,
                    matchedSnapshotCount: snapshots.count,
                    extra: "prevSnapshotIndex=\(prevSnapshot.result.index), nextSnapshotIndex=\(nextSnapshot.result.index)"
                )
                return nil
            }
            // 각 LSE snapshot 사이의 UVD만 잘라서, 해당 짧은 구간이 직진/안정 구간인지 먼저 본다.
            let segmentUvd = uvdBuffer.filter {
                $0.index > prevContext.index && $0.index <= nextContext.index
            }

            if segmentUvd.count < 2 {
                logSkip(
                    "insufficient UVD samples in segment",
                    buildingName: baseResult.building_name,
                    levelName: baseResult.level_name,
                    matchedSnapshotCount: snapshots.count,
                    extra: "segmentStartIndex=\(prevContext.index), segmentEndIndex=\(nextContext.index), segmentUvdCount=\(segmentUvd.count)"
                )
                return nil
            }

            let straightResult = isDrBufferStraightCircularStd(
                uvdBuffer: segmentUvd,
                condition: ENTERING_LSE_SEGMENT_HEADING_STD_THRESHOLD
            )

            let isStableSegment = straightResult.0
            let headingStd = straightResult.1

            if !isStableSegment {
                logSkip(
                    "unstable heading std in segment",
                    buildingName: baseResult.building_name,
                    levelName: baseResult.level_name,
                    matchedSnapshotCount: snapshots.count,
                    extra: "segmentStartIndex=\(prevContext.index), segmentEndIndex=\(nextContext.index), segmentUvdCount=\(segmentUvd.count), headingStd=\(headingStd), threshold=\(ENTERING_LSE_SEGMENT_HEADING_STD_THRESHOLD)"
                )
                return nil
            }

            var propagatedX = prevSnapshot.result.x
            var propagatedY = prevSnapshot.result.y

            // 이전 LSE 점을 시작점으로 두고, 보정된 heading으로 UVD를 다시 적분해서 다음 LSE 점까지 예측한다.
            for bufferedUvd in segmentUvd {
                let compensatedHeading = TJLabsUtilFunctions.shared.compensateDegree(
                    bufferedUvd.heading + Double(headingCompensation)
                )

                let rad = TJLabsUtilFunctions.shared.degree2radian(degree: compensatedHeading)

                propagatedX += Float(bufferedUvd.length) * Float(cos(rad))
                propagatedY += Float(bufferedUvd.length) * Float(sin(rad))

                propagatedPoints.append((
                    index: bufferedUvd.index,
                    x: propagatedX,
                    y: propagatedY
                ))

                lastAlignedHeading = Float(compensatedHeading)
            }

            let dx = propagatedX - nextSnapshot.result.x
            let dy = propagatedY - nextSnapshot.result.y
            let endpointDistance = sqrt(dx*dx + dy*dy)

            segmentEndpointDistances.append(endpointDistance)
        }
        
        // 각 구간의 끝점 오차가 작아야, LSE가 보여준 궤적과 UVD 적분 결과가 같은 움직임이라고 본다.
        let avgTrajectoryDistance = Float(
            segmentEndpointDistances.map { Double($0) }.reduce(0, +) / Double(segmentEndpointDistances.count)
        )

        let maxTrajectoryDistance = segmentEndpointDistances.max() ?? Float.greatestFiniteMagnitude

        if avgTrajectoryDistance > ENTERING_LSE_MAX_AVG_TRAJECTORY_DISTANCE ||
            maxTrajectoryDistance > ENTERING_LSE_MAX_END_TRAJECTORY_DISTANCE {

            logSkip(
                "propagated trajectory mismatch",
                buildingName: baseResult.building_name,
                levelName: dominantLevelName,
                matchedSnapshotCount: snapshots.count,
                extra: "avgTrajectoryDistance=\(avgTrajectoryDistance), avgThreshold=\(ENTERING_LSE_MAX_AVG_TRAJECTORY_DISTANCE), maxTrajectoryDistance=\(maxTrajectoryDistance), maxThreshold=\(ENTERING_LSE_MAX_END_TRAJECTORY_DISTANCE), distances=\(segmentEndpointDistances)"
            )
            return nil
        }

        // 전체 이동거리도 함께 비교해서, 종점만 우연히 맞는 케이스를 줄인다.
        let lsePathLength = calculatePolylineLength(
            points: snapshots.map { ($0.result.x, $0.result.y) }
        )

        let propagatedPathLength = calculatePolylineLength(
            points: propagatedPoints.map { ($0.x, $0.y) }
        )

        let pathLengthDiff = abs(lsePathLength - propagatedPathLength)
        JupiterLogger.i(tag: "EntranceManager", message: "(maybePromoteEnteringToTrackingUsingLse) lsePathLength= \(lsePathLength), propagatedPathLength= \(propagatedPathLength), pathLengthDiff= \(pathLengthDiff)")
        if pathLengthDiff > ENTERING_LSE_MAX_PATH_LENGTH_DIFF {
            logSkip(
                "path length mismatch",
                buildingName: baseResult.building_name,
                levelName: dominantLevelName,
                matchedSnapshotCount: snapshots.count,
                extra: "lsePathLength=\(lsePathLength), propagatedPathLength=\(propagatedPathLength), pathLengthDiff=\(pathLengthDiff), threshold=\(ENTERING_LSE_MAX_PATH_LENGTH_DIFF)"
            )
            return nil
        }

        // 최종 propagated 위치를 path matching 해서 TRACKING 시작 위치로 정규화한다.
        guard let lastPropagated = propagatedPoints.last else {
            logSkip(
                "missing propagated endpoint",
                buildingName: baseResult.building_name,
                levelName: dominantLevelName,
                matchedSnapshotCount: snapshots.count
            )
            return nil
        }

        let propagatedHeading = lastAlignedHeading
        JupiterLogger.i(tag: "EntranceManager", message: "(maybePromoteEnteringToTrackingUsingLse) propagatedHeading= \(propagatedHeading)")
        guard let pmResult = PathMatcher.shared.pathMatching(
            sectorId: sectorId,
            building: baseResult.building_name,
            level: dominantLevelName,
            x: lastPropagated.x,
            y: lastPropagated.y,
            heading: propagatedHeading,
            isUseHeading: true,
            mode: UserMode.MODE_VEHICLE,
            paddingValues: JupiterMode.PADDING_VALUES_MEDIUM
        ) else {
            logSkip(
                "path matching failed for propagated endpoint",
                buildingName: baseResult.building_name,
                levelName: dominantLevelName,
                matchedSnapshotCount: snapshots.count,
                extra: "x=\(lastPropagated.x), y=\(lastPropagated.y), heading=\(propagatedHeading)"
            )
            return nil
        }
        
        JupiterLogger.i(
            tag: "EntranceManager",
            message: "promote ENTERING -> TRACKING: index=\(uvd.index), dominantLevel=\(dominantLevelName), majorHeading=\(majorHeading), lseTrendHeading=\(lseTrendHeading), headingCompensation=\(headingCompensation), maxStepDistance=\(maxStepDistance), avgTrajectoryDistance=\(avgTrajectoryDistance), maxTrajectoryDistance=\(maxTrajectoryDistance), lsePathLength=\(lsePathLength), propagatedPathLength=\(propagatedPathLength), pathLengthDiff=\(pathLengthDiff)"
        )
        
        finalResult.index = lastPropagated.index
        finalResult.level_name = dominantLevelName
        finalResult.x = pmResult.x
        finalResult.y = pmResult.y
        finalResult.absolute_heading = pmResult.heading
        
        return finalResult
    }
    
    private func getEnteringSingleEpochSnapshotsFor(
        lseSnapshotBuffer: [SingleEpochSnapshot],
        buildingName: String
    ) -> [SingleEpochSnapshot] {
        Array(lseSnapshotBuffer.suffix(ENTERING_LSE_BUFFER_SIZE)).filter {
            $0.result.building_name == buildingName
        }
    }

    private func resolveTrendHeading(
        snapshots: [SingleEpochSnapshot],
        minDistance: Float,
        buildingName: String,
        levelName: String
    ) -> Float? {
        guard snapshots.count >= 2 else { return nil }

        var sumDx: Float = 0
        var sumDy: Float = 0

        for i in 1..<snapshots.count {
            sumDx += (snapshots[i].result.x - snapshots[i - 1].result.x)
            sumDy += (snapshots[i].result.y - snapshots[i - 1].result.y)
        }

        let displacement = sqrt(sumDx * sumDx + sumDy * sumDy)
        JupiterLogger.i(tag: "EntranceManager", message: "(resolveTrendHeading) sumDx= \(sumDx), sumDy= \(sumDy)")
        JupiterLogger.i(tag: "EntranceManager", message: "(resolveTrendHeading) displacement= \(displacement)")
        guard displacement >= minDistance else { return nil }
        let headingRadian = atan2(Double(sumDy), Double(sumDx))
        let headingDegree = TJLabsUtilFunctions.shared.radian2degree(radian: headingRadian)
        JupiterLogger.i(tag: "EntranceManager", message: "(resolveTrendHeading) headingRadian= \(headingRadian), headingDegree= \(headingDegree)")
        return Float(TJLabsUtilFunctions.shared.compensateDegree(headingDegree))
    }

    private func resolveEnteringLseTrendHeading(snapshots: [SingleEpochSnapshot], buildingName: String, levelName: String) -> Float? {
        if snapshots.count < ENTERING_LSE_BUFFER_SIZE  {
            return nil
        }
        
        return resolveTrendHeading(
            snapshots: snapshots,
            minDistance: ENTERING_LSE_MIN_DISPLACEMENT,
            buildingName: buildingName,
            levelName: levelName
        )
    }

    private func resolveDominantEnteringLseLevelName(
        snapshots: [SingleEpochSnapshot],
        fallbackLevelName: String
    ) -> String {
        let normalizedLevelCounts = snapshots.reduce(into: [String: Int]()) { counts, snapshot in
            let normalizedLevel = TJLabsUtilFunctions.shared.removeLevelDirectionString(
                levelName: snapshot.result.level_name
            )
            counts[normalizedLevel, default: 0] += 1
        }

        guard let dominantNormalizedLevel = normalizedLevelCounts.max(by: { lhs, rhs in
            if lhs.value == rhs.value {
                return lhs.key > rhs.key
            }
            return lhs.value < rhs.value
        })?.key else {
            return fallbackLevelName
        }

        return snapshots.reversed().first(where: {
            TJLabsUtilFunctions.shared.removeLevelDirectionString(levelName: $0.result.level_name) == dominantNormalizedLevel
        })?.result.level_name ?? fallbackLevelName
    }

    private func calculatePolylineLength(points: [(Float, Float)]) -> Float {
        if points.count < 2 {
            return 0
        }
        var total: Float = 0
        for i in 1..<points.count {
            let dx = points[i].0 - points[i-1].0
            let dy = points[i].1 - points[i-1].1
            total += sqrt(dx*dx + dy*dy)
        }
        return total
    }
}
