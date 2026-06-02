import Foundation

final class OlympusSecretConfig {
    static let shared = OlympusSecretConfig()

    private enum Constants {
        static let bundleName = "OlympusConfiguration"
        static let localPlistName = "OlympusSecretConfig.local"
        static let plistName = "OlympusSecretConfig"
        static let clientSecretKey = "LSE_CLIENT_SECRET"
    }

    private class BundleFinder {}

    private let configBundle: Bundle?
    private let configDictionary: [String: Any]

    private init() {
        let bundle = Bundle(for: BundleFinder.self)
        let configBundleURL = bundle.url(forResource: Constants.bundleName, withExtension: "bundle")
        let configBundle = configBundleURL.flatMap(Bundle.init(url:))
        self.configBundle = configBundle

        guard
            let configBundle,
            let config = Self.loadConfig(from: configBundle)
        else {
            self.configDictionary = [:]
            return
        }

        self.configDictionary = config
    }

    private static func loadConfig(from bundle: Bundle) -> [String: Any]? {
        let plistNames = [Constants.localPlistName, Constants.plistName]

        for plistName in plistNames {
            guard let configURL = bundle.url(forResource: plistName, withExtension: "plist") else {
                continue
            }

            if let config = NSDictionary(contentsOf: configURL) as? [String: Any] {
                return config
            }
        }

        return nil
    }

    var lseClientSecret: String? {
        guard let rawValue = configDictionary[Constants.clientSecretKey] as? String else {
            return nil
        }

        let trimmedValue = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedValue.isEmpty, trimmedValue != "__LSE_CLIENT_SECRET__" else {
            return nil
        }

        return trimmedValue
    }
}
