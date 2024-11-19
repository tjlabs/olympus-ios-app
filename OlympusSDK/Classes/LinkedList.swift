import Foundation

public struct LinkedList<Value> {
    
    public var head: Node<Value>?
    public var tail: Node<Value>?
    
    public init() {}
    
    public var isEmpty: Bool {
        return head == nil
    }
    
    //MARK: - Push ( adding a value at the front of the list )
    public mutating func push(_ value: Value) {
        head = Node(value: value, next: head)
        if tail == nil {
            tail = head
        }
    }
    
    //MARK: - Append ( adding a value at the end of the list )
    public mutating func append(_ value: Value) {
        copyNodes()
        guard !isEmpty else{
            push(value)
            return
        }
        tail!.next = Node(value: value)
        tail = tail?.next
    }
    
    //MARK: - Insert ( adding a value at the particular place in the list )
    public func node(at index: Int) -> Node<Value>? {
        var currentNode = head
        var currentIndex = 0
        
        while currentNode != nil && currentIndex < index {
            currentNode = currentNode!.next
            currentIndex += 1
        }
        return currentNode
    }
    
    public mutating func insert(_ value: Value, after node: Node<Value>) {
        guard tail !== node else {
            append(value)
            return
        }
        node.next = Node(value: value, next: node.next)
    }
    
    //MARK: - Pop
    public mutating func pop() -> Value? {
        defer{
            head = head?.next
            if isEmpty {
                tail = nil
            }
        }
        return head?.value
    }
    
    //MARK: - Remove Last
    public mutating func removeLast() -> Value? {
        guard let head = head else {
            return nil
        }
        guard head.next != nil else {
            return pop()
        }
        var prev = head
        var current = head
        
        while let next = current.next {
            prev = current
            current = next
        }
        prev.next = nil
        tail = prev
        return current.value
    }
    
    //MARK: - Removing a particular node
    public mutating func remove(after node: Node<Value>) -> Value? {
        defer {
            if node.next === tail {
                tail = node
            }
            node.next = node.next?.next
        }
        return node.next?.value
    }
    
    private mutating func copyNodes(){
        guard !isKnownUniquelyReferenced(&head) else {
            return
        }
        guard var oldNode = head else {
            return
        }
        head = Node(value: oldNode.value)
        var newNode = head
        
        while let nextOldNode = oldNode.next {
            newNode?.next = Node(value: nextOldNode.value)
            newNode = newNode?.next
            
            oldNode = nextOldNode
        }
        tail = newNode
    }
    
    public var count: Int {
        guard var node = head else {
            return 0
        }
        
        var count = 1
        while let next = node.next {
            node = next
            count += 1
        }
        return count
    }
    
    public var last: Node<Value>? {
        guard var node = head else {
            return nil
        }
        
        while let next = node.next {
            node = next
        }
        return node
    }
}

extension LinkedList: CustomStringConvertible {
    
    public var description: String {
        guard let head = head else {
            return "Empty List"
        }
        return String(describing: head)
    }
}

extension LinkedList: Collection {
    
    public struct Index: Comparable {
        public var  node: Node<Value>?
        
        static public func ==(lhs: Index, rhs: Index) -> Bool {

            switch (lhs.node, rhs.node) {
            case let(left?, right?):
                return left.next === right.next
            case (nil,nil):
                return true
            default:
                return false
            }
        }
        
        static public func <(lhs: Index, rhs: Index) -> Bool {
            guard lhs != rhs else {
                return false
            }
            let nodes = sequence(first: lhs.node, next: {$0?.next})
            return nodes.contains { $0 === rhs.node }
        }
        
    }
    public var startIndex: Index {
        return Index(node: head)
    }
    public var endIndex: Index {
        return Index(node: tail?.next)
    }
    public func index(after i: Index) -> Index {
        return Index(node: i.node?.next)
    }
    public subscript(position: Index) -> Value {
        return position.node!.value
    }
}
