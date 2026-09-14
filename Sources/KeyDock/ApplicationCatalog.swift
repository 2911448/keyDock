import AppKit

struct CatalogApp: Identifiable {
    let url: URL
    let name: String
    let bundleIdentifier: String?
    var id: String { url.path }
}

final class ApplicationCatalog: ObservableObject {
    @Published var apps: [CatalogApp] = []
    @Published var isLoading = false
    private var iconCache: [String: NSImage] = [:]

    func icon(at path: String) -> NSImage {
        if let cached = iconCache[path] { return cached }
        let image = NSWorkspace.shared.icon(forFile: path)
        iconCache[path] = image
        return image
    }

    static func application(at url: URL) -> CatalogApp? {
        guard url.pathExtension.lowercased() == "app", let bundle = Bundle(url: url), bundle.executableURL != nil else { return nil }
        let displayName = (bundle.localizedInfoDictionary?["CFBundleDisplayName"] as? String)
            ?? (bundle.infoDictionary?["CFBundleDisplayName"] as? String)
            ?? (bundle.infoDictionary?["CFBundleName"] as? String)
            ?? url.deletingPathExtension().lastPathComponent
        return CatalogApp(url: url, name: displayName, bundleIdentifier: bundle.bundleIdentifier)
    }

    func reload() {
        guard !isLoading else { return }
        isLoading = true
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let roots = ["/Applications", "/System/Applications", NSHomeDirectory() + "/Applications", "/System/Library/CoreServices/Applications"]
            var found: [String: CatalogApp] = [:]
            for root in roots {
                // macOS marks the /Applications/Safari.app redirect as hidden. It is still a launchable app.
                guard let enumerator = FileManager.default.enumerator(at: URL(fileURLWithPath: root), includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsPackageDescendants]) else { continue }
                for case let url as URL in enumerator where url.pathExtension.lowercased() == "app" {
                    if let app = Self.application(at: url), app.bundleIdentifier != Bundle.main.bundleIdentifier {
                        found[url.resolvingSymlinksInPath().path] = app
                    }
                }
            }
            let sorted = found.values.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            DispatchQueue.main.async { self?.apps = sorted; self?.isLoading = false }
        }
    }
}
