import Foundation
import WebKit

#if SWIFT_PACKAGE
    import ChatHubCore
#endif

enum ServiceTheme {
    private static var resourceBundle: Bundle {
        #if SWIFT_PACKAGE
            .module
        #else
            .main
        #endif
    }

    private static let cachedScript: String? = resource("WebAppearance", extension: "js")
    private static let cachedCommonCSS: String? = resource("ChatAppearance", extension: "css")
    private static let cachedAdapterCSS: [ChatService: String] = {
        var result: [ChatService: String] = [:]
        for service in ChatService.allCases where WebAppearancePolicy.supportsService(service) {
            if let css = resource(service.rawValue.capitalized + "Appearance", extension: "css") {
                result[service] = css
            }
        }
        return result
    }()

    static func bootstrap(service: ChatService, appearance: BrowserAppearance) -> String? {
        guard WebAppearancePolicy.supportsService(service),
            let script = cachedScript,
            let commonCSS = cachedCommonCSS,
            let adapterCSS = cachedAdapterCSS[service],
            let cssData = try? JSONEncoder().encode(commonCSS + "\n" + adapterCSS),
            let cssLiteral = String(data: cssData, encoding: .utf8)
        else { return nil }
        return "(function(css, initialSettings, service) {\n" + script + "\n})(" + cssLiteral + ", "
            + settingsLiteral(appearance) + ", \"" + service.rawValue + "\");"
    }

    private static func resource(_ name: String, extension fileExtension: String) -> String? {
        guard let url = resourceBundle.url(forResource: name, withExtension: fileExtension) else { return nil }
        return try? String(contentsOf: url, encoding: .utf8)
    }

    static func settings(_ appearance: BrowserAppearance) -> [String: Any] {
        [
            "dark": appearance.isDark,
            "enabled": appearance.themeEnabled,
            "reduceMotion": appearance.reduceMotion,
            "showServiceTools": appearance.showServiceTools,
            "accent": appearance.accent.rawValue,
            "density": appearance.density.rawValue,
            "textScale": appearance.textScale.rawValue,
        ]
    }

    private static func settingsLiteral(_ appearance: BrowserAppearance) -> String {
        "{dark: \(appearance.isDark), enabled: \(appearance.themeEnabled), reduceMotion: \(appearance.reduceMotion), showServiceTools: \(appearance.showServiceTools), accent: \"\(appearance.accent.rawValue)\", density: \"\(appearance.density.rawValue)\", textScale: \"\(appearance.textScale.rawValue)\"}"
    }
}
