import Foundation
import Testing

@testable import ChatHubCore

struct WebAppearancePolicyTests {
    @Test func onlyTheZaloChatApplicationIsThemed() throws {
        #expect(WebAppearancePolicy.supportsTheme(service: .zalo, url: URL(string: "https://chat.zalo.me/")))
        #expect(
            WebAppearancePolicy.supportsTheme(service: .zalo, url: URL(string: "https://chat.zalo.me/#conversation")))
    }

    @Test(arguments: [
        "https://id.zalo.me/account", "https://jr.zaloapp.com/", "http://chat.zalo.me/",
        "https://chat.zalo.me/trusted-device-bridge.html", "https://chat.zalo.me.evil.example/",
        "https://user:password@chat.zalo.me/",
    ])
    func signInPagesAndOtherOriginsAreNeverThemed(_ address: String) {
        #expect(!WebAppearancePolicy.supportsTheme(service: .zalo, url: URL(string: address)))
    }

    @Test func customServicesCannotInheritZaloInjection() {
        for service in ChatService.allCases where service != .zalo {
            #expect(!WebAppearancePolicy.supportsTheme(service: service, url: URL(string: "https://chat.zalo.me/")))
        }
        #expect(!WebAppearancePolicy.supportsTheme(service: .zalo, url: nil))
    }
    @Test(arguments: [
        (ChatService.telegram, "https://web.telegram.org/a/#123"),
        (.messenger, "https://www.facebook.com/messages/"),
        (.messenger, "https://www.facebook.com/messages/e2ee/t/123"),
        (.messenger, "https://web.facebook.com/messages/"),
        (.messenger, "https://facebook.com/messages/t/456"),
        (.messenger, "https://www.messenger.com/t/123"),
        (.messenger, "https://www.messenger.com/e2ee/t/123"),
        (.messenger, "https://messenger.com/"),
    ])
    func supportedChatRoutesReceiveTheirOwnAdapter(service: ChatService, address: String) {
        #expect(WebAppearancePolicy.supportsTheme(service: service, url: URL(string: address)))
    }

    @Test(arguments: [
        (ChatService.telegram, "https://web.telegram.org/k/"),
        (.telegram, "https://web.telegram.org.evil.example/a/"),
        (.messenger, "https://www.facebook.com/login/"),
        (.messenger, "https://www.facebook.com/checkpoint/"),
        (.messenger, "https://www.facebook.com/marketplace/"),
        (.messenger, "https://www.facebook.com/messages-evil"),
        (.messenger, "https://www.facebook.com.evil.example/messages/"),
        (.messenger, "http://www.facebook.com/messages/"),
        (.messenger, "https://user:password@www.facebook.com/messages/"),
    ])
    func unsupportedRoutesRemainOriginal(service: ChatService, address: String) {
        #expect(!WebAppearancePolicy.supportsTheme(service: service, url: URL(string: address)))
    }
}
