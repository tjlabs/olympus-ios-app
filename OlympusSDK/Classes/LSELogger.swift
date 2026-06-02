import Foundation

enum LSELogger {
    static func d(tag: String, message: String) {
        JupiterLogger.d(tag: tag, message: message)
    }

    static func i(tag: String, message: String) {
        JupiterLogger.i(tag: tag, message: message)
    }

    static func w(tag: String, message: String) {
        JupiterLogger.w(tag: tag, message: message)
    }

    static func e(tag: String, message: String) {
        JupiterLogger.e(tag: tag, message: message)
    }
}
