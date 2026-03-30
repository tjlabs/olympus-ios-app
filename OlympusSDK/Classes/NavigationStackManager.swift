
import TJLabsCommon
import TJLabsResource

class NavigationStackManager {
    init() { }

    private let NAVI_ROUTE_RESULT_BUFFER_SIZE: Int = 200
    var indexAndNaviRouteResultBuffer = [(Int, RoutingRoute)]()
    
    func stackIndexAndNaviRouteResult(naviRouteResult: RoutingRoute, peakIndex: Int? = nil, uvd: UserVelocity) {
        if let peakIndex = peakIndex {
            self.indexAndNaviRouteResultBuffer = self.indexAndNaviRouteResultBuffer.filter { $0.0 >= peakIndex }
        }

        indexAndNaviRouteResultBuffer.append((uvd.index, naviRouteResult))
        if indexAndNaviRouteResultBuffer.count > NAVI_ROUTE_RESULT_BUFFER_SIZE {
            indexAndNaviRouteResultBuffer.remove(at: 0)
        }
    }
    
    func getIndexAndNaviRouteResultBuffer(size: Int) -> [(Int, RoutingRoute)] {
        guard size > 0 else { return [] }
        if indexAndNaviRouteResultBuffer.count <= size {
            return indexAndNaviRouteResultBuffer
        } else {
            return Array(indexAndNaviRouteResultBuffer.suffix(size))
        }
    }
    
    func getIndexAndNaviRouteResultBuffer(index: Int) -> [(Int, RoutingRoute)] {
        return self.indexAndNaviRouteResultBuffer.filter { $0.0 >= index }
    }
}
