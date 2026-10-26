import Foundation

public enum HubAccent: String, CaseIterable, Codable, Equatable, Identifiable, Sendable {
    case iris, ocean, emerald, amber, rose, graphite

    public var id: String { rawValue }
}

public enum HubDensity: String, CaseIterable, Codable, Equatable, Identifiable, Sendable {
    case compact, standard, comfortable

    public var id: String { rawValue }
}

public enum HubTextScale: String, CaseIterable, Codable, Equatable, Identifiable, Sendable {
    case small, standard, large

    public var id: String { rawValue }
}

public struct BrowserAppearance: Equatable, Sendable {
    public var isDark: Bool
    public var themeEnabled: Bool
    public var reduceMotion: Bool
    public var showServiceTools: Bool
    public var accent: HubAccent
    public var density: HubDensity
    public var textScale: HubTextScale

    public init(
        isDark: Bool = false,
        themeEnabled: Bool = true,
        reduceMotion: Bool = false,
        showServiceTools: Bool = false,
        accent: HubAccent = .iris,
        density: HubDensity = .standard,
        textScale: HubTextScale = .standard
    ) {
        self.isDark = isDark
        self.themeEnabled = themeEnabled
        self.reduceMotion = reduceMotion
        self.showServiceTools = showServiceTools
        self.accent = accent
        self.density = density
        self.textScale = textScale
    }
}

public enum WebAppearancePolicy {
    public static func supportsService(_ service: ChatService) -> Bool {
        [.telegram, .zalo, .messenger].contains(service)
    }

    public static func supportsTheme(service: ChatService, url: URL?) -> Bool {
        guard let url, url.scheme?.lowercased() == "https",
            let host = url.host?.lowercased(), url.user == nil, url.password == nil
        else { return false }
        switch service {
        case .zalo:
            return host == "chat.zalo.me" && (url.path == "/" || url.path.isEmpty)
        case .telegram:
            return host == "web.telegram.org" && ["/a", "/a/"].contains(url.path)
        case .messenger:
            let isMessengerHost = ["messenger.com", "www.messenger.com"].contains(host)
            let isFacebookHost = ["facebook.com", "www.facebook.com", "web.facebook.com"].contains(host)
            guard isMessengerHost || isFacebookHost else { return false }
            if isFacebookHost {
                return url.path == "/messages" || url.path.hasPrefix("/messages/")
            }
            return url.path == "/" || url.path.isEmpty || url.path.hasPrefix("/t/") || url.path.hasPrefix("/e2ee/")
        default:
            return false
        }
    }
}
