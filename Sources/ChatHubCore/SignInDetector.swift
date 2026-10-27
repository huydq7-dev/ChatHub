import Foundation

/// Tells when a service has dropped the session and is asking to sign in again.
/// Only the page address and the presence of the sign-in screen are used, never message content.
public enum SignInDetector {
    /// Services that redirect to a recognizable sign-in address.
    public static func usesURLSignal(_ service: ChatService) -> Bool {
        [.zalo, .messenger, .discord].contains(service)
    }

    /// Services that show their sign-in screen on the same address; the page bridge reports it.
    public static func usesPageSignal(_ service: ChatService) -> Bool {
        service == .telegram
    }

    public static func isSignInPage(service: ChatService, url: URL?) -> Bool {
        guard let url, let host = url.host?.lowercased() else { return false }
        let path = url.path.lowercased()
        switch service {
        case .zalo:
            return host == "id.zalo.me"
        case .messenger:
            let onMeta = ["facebook.com", "messenger.com"].contains { host == $0 || host.hasSuffix("." + $0) }
            return onMeta && (path.hasPrefix("/login") || path.hasPrefix("/checkpoint"))
        case .discord:
            return host == "discord.com" && path.hasPrefix("/login")
        default:
            return false
        }
    }
}
