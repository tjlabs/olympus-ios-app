import Foundation

extension String {
    var hex: Int? {
        return Int(self, radix: 16)
    }
}

extension String {
  var localized: String {
    return NSLocalizedString(self, tableName: "Localizable", value: "**\(self)**", comment: "")
  }
  
  func localized(bundle: Bundle = .main, tableName: String = "Localizable") -> String {
    return NSLocalizedString(self, tableName: tableName, value: "**\(self)**", comment: "")
  }
  
}

extension String {
    func substring(from: Int, to: Int) -> String {
        guard from < count, to >= 0, to - from >= 0 else {
            return ""
        }
        
        // Index 값 획득
        let startIndex = index(self.startIndex, offsetBy: from)
        let endIndex = index(self.startIndex, offsetBy: to + 1) // '+1'이 있는 이유: endIndex는 문자열의 마지막 그 다음을 가리키기 때문
        
        // 파싱
        return String(self[startIndex ..< endIndex])
    }
}

extension String {
    var isValidURL: Bool {
        let detector = try! NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        if let match = detector.firstMatch(in: self, options: [], range: NSRange(location: 0, length: self.utf16.count)) {
            // it is a link, if the match covers the whole string
            return match.range.length == self.utf16.count
        } else {
            return false
        }
    }
}
