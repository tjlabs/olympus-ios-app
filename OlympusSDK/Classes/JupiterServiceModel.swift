

struct xyhs {
    var x: Float = 0
    var y: Float = 0
    var heading: Float = 0
    var scale: Float = 0
}

struct EntranceCheckerResult {
    let is_entered: Bool
    let key: String
    
    init(is_entered: Bool, key: String) {
        self.is_entered = is_entered
        self.key = key
    }
}
