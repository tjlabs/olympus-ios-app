import Foundation

extension String {
    var hex: Int? {
        return Int(self, radix: 16)
    }
    
    var localized: String {
      return NSLocalizedString(self, tableName: "Localizable", value: "**\(self)**", comment: "")
    }
    
    func localized(bundle: Bundle = .main, tableName: String = "Localizable") -> String {
      return NSLocalizedString(self, tableName: tableName, value: "**\(self)**", comment: "")
    }
    
    func substring(from: Int, to: Int) -> String {
        guard from < count, to >= 0, to - from >= 0 else {
            return ""
        }
        
        let startIndex = index(self.startIndex, offsetBy: from)
        let endIndex = index(self.startIndex, offsetBy: to + 1)
        
        return String(self[startIndex ..< endIndex])
    }
}
