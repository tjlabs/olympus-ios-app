
class TJLabsAssets {
    private class BundleFinder {}
    static func image(named name: String) -> UIImage? {
        let bundle = Bundle(for: BundleFinder.self)
        let url = bundle.url(forResource: "OlympusAssets", withExtension: "bundle")
        let resourceBundle = Bundle(url: url!)
        return UIImage(named: name, in: resourceBundle, compatibleWith: nil)
    }
}
