import Foundation
import Testing

@testable import ChatHubCore

@Suite("Zalo authentication redirects")
struct ZaloAuthenticationTests {
    @Test func authenticationChainStaysInTheSameAccountProfile() throws {
        let policy = NavigationPolicy(account: ChatAccount(service: .zalo, name: "Personal"))
        // The jr host is the redirect blocked in the real QR sign-in flow.
        // No real session URL, cookie or authentication token is stored in the fixture.
        let chain = [
            "https://chat.zalo.me/",
            "https://id.zalo.me/account?continue=https%3A%2F%2Fchat.zalo.me%2F",
            "https://jr.zaloapp.com/",
            "https://chat.zalo.me/",
        ]
        for address in chain {
            let url = try #require(URL(string: address))
            #expect(
                policy.disposition(for: url) == .inApp, "Authentication host must stay in profile: \(url.host ?? "")")
        }
    }

    @Test(arguments: [
        "https://jr.zaloapp.com.evil.example/", "https://eviljr.zaloapp.com/",
        "https://unrelated.zaloapp.com/", "https://sub.jr.zaloapp.com/", "http://jr.zaloapp.com/",
    ])
    func unrelatedOrInsecureSitesStayExternal(_ address: String) throws {
        let policy = NavigationPolicy(account: ChatAccount(service: .zalo, name: "Personal"))
        let url = try #require(URL(string: address))
        #expect(policy.disposition(for: url) == .externalBrowser)
    }

    @Test func zaloRedirectIsNotTrustedByOtherServices() throws {
        let url = try #require(URL(string: "https://jr.zaloapp.com/"))
        for service in ChatService.allCases where service != .zalo {
            let policy = NavigationPolicy(account: ChatAccount(service: service, name: "Other"))
            #expect(policy.disposition(for: url) == .externalBrowser)
        }
    }
}
