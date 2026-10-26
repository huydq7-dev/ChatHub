import Foundation
import Testing

@testable import ChatHubCore

@Suite("Accounts and website boundaries")
struct AccountTests {
    @Test func accountNamesAreTrimmed() throws {
        let account = try ChatAccount(service: .telegram, name: "  Personal \n", subtitle: " Work ").validated()
        #expect(account.name == "Personal")
        #expect(account.subtitle == "Work")
    }

    @Test(arguments: ["", " \n ", String(repeating: "a", count: 81)])
    func invalidNamesAreRejected(_ name: String) {
        #expect(throws: AccountValidationError.invalidName) {
            try ChatAccount(service: .zalo, name: name).validated()
        }
    }

    @Test(arguments: [
        "http://example.com", "file:///etc/passwd", "javascript:alert(1)",
        "https://user:password@example.com", "https://example.com@evil.com", "//example.com", "https://", "",
    ])
    func unsafeCustomURLsAreRejected(_ value: String) {
        #expect(throws: AccountValidationError.invalidURL) { try SafeWebsiteURL.parse(value) }
    }

    @Test func validCustomURLPreservesPathAndQuery() throws {
        let url = try SafeWebsiteURL.parse(" https://chat.example.com/rooms?view=all ")
        #expect(url.absoluteString == "https://chat.example.com/rooms?view=all")
    }

    @Test func customAccountsRequireAWebsite() {
        #expect(throws: AccountValidationError.invalidURL) {
            try ChatAccount(service: .custom, name: "Team").validated()
        }
    }

    @Test func serviceAccountsDiscardCustomURLs() throws {
        let account = try ChatAccount(service: .telegram, name: "Chat", customURL: URL(string: "https://evil.com"))
            .validated()
        #expect(account.customURL == nil)
        #expect(account.url?.host == "web.telegram.org")
    }

    @Test func allBuiltInServicesHaveSecureHomes() {
        for service in ChatService.allCases where service != .custom {
            #expect(service.homeURL?.scheme == "https")
            #expect(
                NavigationPolicy(account: ChatAccount(service: service, name: "Test"))
                    .disposition(for: service.homeURL!) == .inApp)
        }
    }

    @Test(arguments: ["telegram.org.evil.com", "eviltelegram.org", "telegram-org.com"])
    func lookalikeHostsNeverBelongToProvider(_ host: String) {
        #expect(!NavigationPolicy.host(host, belongsTo: "telegram.org"))
    }

    @Test func subdomainsAndCaseAreSupported() {
        #expect(NavigationPolicy.host("WEB.Telegram.org", belongsTo: "telegram.org"))
        #expect(NavigationPolicy.host("telegram.org", belongsTo: "telegram.org"))
    }

    @Test func externalLinksAndUnsafeSchemesAreSeparated() throws {
        let policy = NavigationPolicy(account: ChatAccount(service: .messenger, name: "Personal"))
        #expect(policy.disposition(for: try #require(URL(string: "https://example.com"))) == .externalBrowser)
        #expect(policy.disposition(for: try #require(URL(string: "https://www.facebook.com/messages/"))) == .inApp)
        #expect(policy.disposition(for: try #require(URL(string: "http://www.facebook.com/"))) == .externalBrowser)
        #expect(policy.disposition(for: try #require(URL(string: "file:///tmp/test"))) == .blocked)
        #expect(policy.disposition(for: try #require(URL(string: "javascript:alert(1)"))) == .blocked)
        #expect(policy.disposition(for: try #require(URL(string: "https://user:secret@facebook.com"))) == .blocked)
    }

    @Test func customServiceNavigationUsesItsOwnDomain() throws {
        let account = ChatAccount(
            service: .custom, name: "Team", customURL: try SafeWebsiteURL.parse("https://chat.example.com"))
        let policy = NavigationPolicy(account: account)
        #expect(policy.disposition(for: try #require(URL(string: "https://chat.example.com/rooms"))) == .inApp)
        #expect(
            policy.disposition(for: try #require(URL(string: "https://chat.example.com.evil.org"))) == .externalBrowser)
        #expect(policy.disposition(for: try #require(URL(string: "https://accounts.google.com/"))) == .inApp)
    }
}
