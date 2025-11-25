import Foundation


struct NavigationNode {
    var nodeNumber: Int
    var nodeCoord: [Double]
    var firstHeading: Double?
    var lastHeading: Double?
    var turn: Bool
}

enum NavigationCheckType {
    case NODE_ADDED, TURN_OCCURRED, INIT, UNKNOWN
}

public class OlympusNavigationManager {
    
    public static let shared = OlympusNavigationManager()
    
    init () {
//        self.setDummyRoutes()
    }
    
    deinit { }
    
    var navigationOption: Bool = true
    
    var passedNode: PassedNodeInfo = PassedNodeInfo(nodeNumber: -1, nodeCoord: [], nodeHeadings: [], matchedIndex: -1, userHeading: 0)
    
    var passedNaviNodes = [NavigationNode]()
    var routeNaviNodes = [NavigationNode]()
    var routeNaviIndex: Int = 0
    var routeSize: Int = 0
    
    var isUseLastHeading: Bool = false
    
    var isStartNavigation: Bool = false
    
    var isNeedRepositioning: Bool = false
    
    func initailize() {
        self.passedNode = PassedNodeInfo(nodeNumber: -1, nodeCoord: [], nodeHeadings: [], matchedIndex: -1, userHeading: 0)
    }
    
    func setPassedNodeInfo(data: PassedNodeInfo) {
        self.passedNode = data
    }
    
    func controlPassedNodeInfo(passedNodeInfo: PassedNodeInfo) -> NavigationCheckType {
        var checkType: NavigationCheckType = .UNKNOWN
        guard let last = passedNaviNodes.last else {
            let naviNode = NavigationNode(nodeNumber: passedNodeInfo.nodeNumber, nodeCoord: passedNodeInfo.nodeCoord, firstHeading: passedNodeInfo.userHeading, turn: false)
            passedNaviNodes.append(naviNode)
            checkType = .INIT
//            print("(Olympus) DEBUG : passedNaviNodes = \((passedNaviNodes.map{$0.nodeNumber}))")
            return checkType
        }
        
        if last.nodeNumber == passedNodeInfo.nodeNumber {
            if last.firstHeading != passedNodeInfo.userHeading {
                if (last.lastHeading != nil) { return checkType }
                var prevNode = last
                prevNode.lastHeading = passedNodeInfo.userHeading
                prevNode.turn = true
                
                passedNaviNodes.removeLast()
                passedNaviNodes.append(prevNode)
                checkType = .TURN_OCCURRED
                print("(Olympus) DEBUG : TURN_OCCURRED 1 // passedNaviNodes = \(passedNaviNodes.map{$0.nodeNumber})")
            } else {
//                print("(Olympus) DEBUG : 사용자의 방향과 노드를 처음 지났을 때의 firstHeading이 같습니다.")
            }
        } else {
            // 다른 번호의 Node를 지남
//            let naviNode = NavigationNode(nodeNumber: passedNodeInfo.nodeNumber, firstHeading: passedNodeInfo.userHeading, turn: false)
//            passedNaviNodes.append(naviNode)
//            checkType = .NODE_ADDED
//            print("(Olympus) DEBUG : NODE_ADDED // passedNaviNodes = \(passedNaviNodes.map{$0.nodeNumber})")
            
            if isUseLastHeading {
                print("(Olympus) DEBUG : isUseLastHeading (true) // last.firstH = \(last.firstHeading) // last.lastH = \(last.lastHeading)")
                if let checkerHeading = last.lastHeading {
                    print("(Olympus) DEBUG : isUseLastHeading (true) // checkerHeading = \(checkerHeading) // passedNodeInfo.userHeading = \(passedNodeInfo.userHeading)")
                    if checkerHeading != passedNodeInfo.userHeading {
                        let naviNode = NavigationNode(nodeNumber: passedNodeInfo.nodeNumber, nodeCoord: passedNodeInfo.nodeCoord, firstHeading: passedNodeInfo.userHeading, turn: true)
                        passedNaviNodes.append(naviNode)
                        checkType = .TURN_OCCURRED
                        isUseLastHeading = false
                        print("(Olympus) DEBUG : TURN_OCCURRED 2 // passedNaviNodes = \(passedNaviNodes.map{$0.nodeNumber})")
                    } else {
                        let naviNode = NavigationNode(nodeNumber: passedNodeInfo.nodeNumber, nodeCoord: passedNodeInfo.nodeCoord, firstHeading: passedNodeInfo.userHeading, turn: false)
                        passedNaviNodes.append(naviNode)
                        checkType = .NODE_ADDED
                        print("(Olympus) DEBUG : NODE_ADDED // passedNaviNodes = \(passedNaviNodes.map{$0.nodeNumber})")
                    }
                } else {
                    let naviNode = NavigationNode(nodeNumber: passedNodeInfo.nodeNumber, nodeCoord: passedNodeInfo.nodeCoord, firstHeading: passedNodeInfo.userHeading, turn: false)
                    passedNaviNodes.append(naviNode)
                    checkType = .NODE_ADDED
                    print("(Olympus) DEBUG : NODE_ADDED // passedNaviNodes = \(passedNaviNodes.map{$0.nodeNumber})")
                }
            } else {
                let checkerHeading = last.firstHeading
                print("(Olympus) DEBUG : isUseLastHeading (false) // last.firstH = \(last.firstHeading) // last.lastH = \(last.lastHeading)")
                print("(Olympus) DEBUG : isUseLastHeading (false) // checkerHeading = \(checkerHeading) // passedNodeInfo.userHeading = \(passedNodeInfo.userHeading)")
                if checkerHeading != passedNodeInfo.userHeading {
                    let naviNode = NavigationNode(nodeNumber: passedNodeInfo.nodeNumber, nodeCoord: passedNodeInfo.nodeCoord, firstHeading: passedNodeInfo.userHeading, turn: true)
                    passedNaviNodes.append(naviNode)
                    checkType = .TURN_OCCURRED
                    print("(Olympus) DEBUG : TURN_OCCURRED 3 // passedNaviNodes = \(passedNaviNodes.map{$0.nodeNumber})")
                } else {
                    let naviNode = NavigationNode(nodeNumber: passedNodeInfo.nodeNumber, nodeCoord: passedNodeInfo.nodeCoord, firstHeading: passedNodeInfo.userHeading, turn: false)
                    passedNaviNodes.append(naviNode)
                    checkType = .NODE_ADDED
                    print("(Olympus) DEBUG : NODE_ADDED // passedNaviNodes = \(passedNaviNodes.map{$0.nodeNumber})")
                }
            }
            
//            if let checkerHeading = last.lastHeading {
//                if checkerHeading != passedNodeInfo.userHeading {
//                    print("(Olympus) DEBUG : TURN_OCCURRED 2 // checkerHeading = \(checkerHeading) // passedNodeInfo.userHeading = \(passedNodeInfo.userHeading)")
//                    let naviNode = NavigationNode(nodeNumber: passedNodeInfo.nodeNumber, firstHeading: passedNodeInfo.userHeading, turn: true)
//                    passedNaviNodes.append(naviNode)
//                    checkType = .TURN_OCCURRED
//                    isUseLastHeading = false
//                    print("(Olympus) DEBUG : TURN_OCCURRED 2 // passedNaviNodes = \(passedNaviNodes.map{$0.nodeNumber})")
//                } else {
//                    let naviNode = NavigationNode(nodeNumber: passedNodeInfo.nodeNumber, firstHeading: passedNodeInfo.userHeading, turn: false)
//                    passedNaviNodes.append(naviNode)
//                    checkType = .NODE_ADDED
//                    print("(Olympus) DEBUG : NODE_ADDED // passedNaviNodes = \(passedNaviNodes.map{$0.nodeNumber})")
//                }
//            } else {
//                let naviNode = NavigationNode(nodeNumber: passedNodeInfo.nodeNumber, firstHeading: passedNodeInfo.userHeading, turn: false)
//                passedNaviNodes.append(naviNode)
//                checkType = .NODE_ADDED
//                print("(Olympus) DEBUG : NODE_ADDED // passedNaviNodes = \(passedNaviNodes.map{$0.nodeNumber})")
//            }
            
//            if checkerHeading != passedNodeInfo.userHeading {
//                print("(Olympus) DEBUG : TURN_OCCURRED 2 // checkerHeading = \(checkerHeading) // passedNodeInfo.userHeading = \(passedNodeInfo.userHeading)")
//                let naviNode = NavigationNode(nodeNumber: passedNodeInfo.nodeNumber, firstHeading: passedNodeInfo.userHeading, turn: true)
//                passedNaviNodes.append(naviNode)
//                checkType = .TURN_OCCURRED
//                isUseLastHeading = false
//                print("(Olympus) DEBUG : TURN_OCCURRED 2 // passedNaviNodes = \(passedNaviNodes.map{$0.nodeNumber})")
//            } else {
//                let naviNode = NavigationNode(nodeNumber: passedNodeInfo.nodeNumber, firstHeading: passedNodeInfo.userHeading, turn: false)
//                passedNaviNodes.append(naviNode)
//                checkType = .NODE_ADDED
//                print("(Olympus) DEBUG : NODE_ADDED // passedNaviNodes = \(passedNaviNodes.map{$0.nodeNumber})")
//            }
        }
        
        let maxCount = 20
        if passedNaviNodes.count > maxCount {
            let overflow = passedNaviNodes.count - maxCount
            passedNaviNodes.removeFirst(overflow)
        }
        
        return checkType
    }
    
    func setRouteNaviNodes(routeNaviNodes: [NavigationNode]) {
        self.routeNaviNodes = routeNaviNodes
        self.routeSize = routeNaviNodes.count
    }
    
    public func setDummyRoutes(option: Bool) {
        if option {
            let routes = [NavigationNode(nodeNumber: 85, nodeCoord: [], turn: false),
                          NavigationNode(nodeNumber: 74, nodeCoord: [], turn: false),
                          NavigationNode(nodeNumber: 69, nodeCoord: [], lastHeading: 180, turn: true),
                          NavigationNode(nodeNumber: 68, nodeCoord: [], lastHeading: 270, turn: true),
                          NavigationNode(nodeNumber: 72, nodeCoord: [], turn: false),
                          NavigationNode(nodeNumber: 80, nodeCoord: [], lastHeading: 180, turn: true),
                          NavigationNode(nodeNumber: 79, nodeCoord: [], lastHeading: 90, turn: true),
                          NavigationNode(nodeNumber: 76, nodeCoord: [], lastHeading: 180, turn: true),
                          NavigationNode(nodeNumber: 75, nodeCoord: [], lastHeading: 270, turn: true),
                          NavigationNode(nodeNumber: 77, nodeCoord: [], turn: false),
                          NavigationNode(nodeNumber: 83, nodeCoord: [], turn: false),
                          NavigationNode(nodeNumber: 86, nodeCoord: [], lastHeading: 0, turn: true),
                          NavigationNode(nodeNumber: 87, nodeCoord: [], turn: false),
                          NavigationNode(nodeNumber: 88, nodeCoord: [], turn: false)]
            
            self.routeNaviNodes = routes
            self.routeSize = routes.count
        } else {
            let routes = [NavigationNode(nodeNumber: 85, nodeCoord: [], turn: false),
                          NavigationNode(nodeNumber: 74, nodeCoord: [], turn: false),
                          NavigationNode(nodeNumber: 69, nodeCoord: [], lastHeading: 180, turn: true),
                          NavigationNode(nodeNumber: 68, nodeCoord: [], lastHeading: 90, turn: true),
                          NavigationNode(nodeNumber: 63, nodeCoord: [], lastHeading: 180, turn: true),
                          NavigationNode(nodeNumber: 62, nodeCoord: [], lastHeading: 270, turn: true),
                          NavigationNode(nodeNumber: 67, nodeCoord: [], lastHeading: 180, turn: true),
                          NavigationNode(nodeNumber: 66, nodeCoord: [], lastHeading: 90, turn: true),
                          NavigationNode(nodeNumber: 61, nodeCoord: [], lastHeading: 180, turn: true),
                          NavigationNode(nodeNumber: 60, nodeCoord: [], lastHeading: 270, turn: true),
                          NavigationNode(nodeNumber: 65, nodeCoord: [], turn: false),
                          NavigationNode(nodeNumber: 70, nodeCoord: [], lastHeading: 0, turn: true),
                          NavigationNode(nodeNumber: 71, nodeCoord: [], turn: false)]
            
            self.routeNaviNodes = routes
            self.routeSize = routes.count
        }
    }
    
    func getNavigationRoute() {
        
    }
    
    func checkFollowingNaviRoute(type: NavigationCheckType, fltResult: FineLocationTrackingFromServer) -> NavigationNode? {
        if isNeedRepositioning { return nil }
        if type == .INIT {
            guard let first = self.routeNaviNodes.first else { return nil }
            guard let user = self.passedNaviNodes.first else { return nil }
            
            if first.nodeNumber == user.nodeNumber {
                self.routeNaviIndex += 1
                self.isStartNavigation = true
            }
        } else if type == .NODE_ADDED {
            // 사용자의 Node가 추가됨
//            print("(Olympus) DEBUG 2 : checkUserFollowingRoute // \(type)")
            let answerNode = self.routeNaviNodes[routeNaviIndex]
            let currentNode = self.passedNaviNodes[self.passedNaviNodes.count-1]
            
            if answerNode.nodeNumber == currentNode.nodeNumber {
                // 추가된 Node와 Navi Node가 같다면
                if answerNode.turn {
                    // 회전이 발생해야하는 Node 라면, 사용자의 회전을 기다려서 확인해야한다
                    self.isUseLastHeading = false
                    print("(Olympus) DEBUG : 사용자는 \(currentNode.nodeNumber) Node에서 회전 해야하니, 판단을 유보합니다")
                } else {
                    // 잘 따라가고 있다
                    self.routeNaviIndex += 1
                    print("(Olympus) DEBUG : \(currentNode.nodeNumber) Node는 단순히 지나가는 Node이니 잘 따라가고 있습니다")
                }
            } else {
                // 추가된 Node와 Navi Node가 다르다면
                // 추가된 Node에서 회전이 일어났는지 확인?
            }
        } else if type == .TURN_OCCURRED {
            // 노드에서 사용자의 회전이 발생함
//            print("(Olympus) DEBUG 2 : checkUserFollowingRoute // \(type)")
            let answerNode = self.routeNaviNodes[routeNaviIndex]
            let currentNode = self.passedNaviNodes[self.passedNaviNodes.count-1]
            
            if answerNode.nodeNumber == currentNode.nodeNumber {
                var userHeading = currentNode.lastHeading
                if answerNode.turn {
                    // 잘 따라가고 있다
                    self.isUseLastHeading = true
                    self.routeNaviIndex += 1
                    if currentNode.lastHeading == nil {
                        let nodeHeadings = OlympusPathMatchingCalculator.shared.getPathMatchingHeadings(building: fltResult.building_name, level: fltResult.level_name, x: currentNode.nodeCoord[0], y: currentNode.nodeCoord[1], PADDING_VALUE: 1, mode: OlympusConstants.MODE_DR)
                        let nearestHeading = OlympusPathMatchingCalculator.shared.getNearestNodeHeading(userHeading: fltResult.absolute_heading, nodeHeadings: nodeHeadings)
                        
                        var prevNode = currentNode
//                        prevNode.lastHeading = answerNode.lastHeading
                        prevNode.lastHeading = nearestHeading
                        passedNaviNodes.removeLast()
                        passedNaviNodes.append(prevNode)
                        userHeading = prevNode.lastHeading
                    }
                    
                    if let answerLastHeading = answerNode.lastHeading, let userLastHeading = userHeading {
                        if answerLastHeading != userLastHeading {
                            self.isNeedRepositioning = true
                        }
                    } else {
                        self.isNeedRepositioning = true
                    }
                    
                    if isNeedRepositioning {
                        print("(Olympus) DEBUG : 사용자는 \(currentNode.nodeNumber)에서 회전했지만, \(answerNode.lastHeading)방향으로 회전하지 않고, \(userHeading)방향으로 회전했습니다.")
                    } else {
                        print("(Olympus) DEBUG : 사용자는 \(currentNode.nodeNumber)에서 회전했고 잘 따라가고 있습니다. // isUseLastHeading = \(isUseLastHeading)")
                        print("(Olympus) DEBUG : answer turn = \(answerNode.lastHeading) // user turn = f:\(currentNode.firstHeading),l:\(passedNaviNodes[passedNaviNodes.count-1].lastHeading)")
                    }
                }
            } else {
                // 서로 다른 Node에서 회전이 발생한 상황
                print("(Olympus) DEBUG : 사용자는 \(currentNode.nodeNumber)에서 회전했지만, Navi는 \(answerNode.nodeNumber)에서 회전해야 합니다")
                return answerNode
            }
        } else {
            return nil
        }
        return nil
    }
    
    func forceUpdate() {
        self.isUseLastHeading = true
        self.routeNaviIndex += 1
    }
}
