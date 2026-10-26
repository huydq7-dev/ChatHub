import Foundation

public enum NavigationDisposition: Equatable, Sendable {
    case inApp, externalBrowser, blocked
}

public struct NavigationPolicy: Sendable {
    public static let authenticationDomains = [
        "accounts.google.com", "login.microsoftonline.com", "login.live.com",
        "appleid.apple.com", "account.apple.com",
    ]

    private let account: ChatAccount

    public init(account: ChatAccount) { self.account = account }

    public static func host(_ host: String, belongsTo domain: String) -> Bool {
        let normalized = host.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "."))
        let domain = domain.lowercased()
        return normalized == domain || normalized.hasSuffix("." + domain)
    }

    public func disposition(for url: URL) -> NavigationDisposition {
        guard let scheme = url.scheme?.lowercased() else { return .blocked }
        if ["mailto", "tel"].contains(scheme) { return .externalBrowser }
        guard ["https", "http"].contains(scheme), let host = url.host,
            url.user == nil, url.password == nil
        else { return .blocked }
        // Never load insecure top-level pages within a signed-in account profile.
        guard scheme == "https" else { return .externalBrowser }
        if account.service.authenticationHosts.contains(host.lowercased()) { return .inApp }
        let serviceDomains =
            account.service == .custom
            ? [account.url?.host].compactMap { $0 } : account.service.navigationDomains
        let domains = serviceDomains + Self.authenticationDomains
        return domains.contains { Self.host(host, belongsTo: $0) } ? .inApp : .externalBrowser
    }
}
