import Foundation
import Testing

@testable import ChatHubCore

struct ReleaseUpdateTests {
    @Test func comparesNumericVersionsRatherThanStrings() throws {
        #expect(try #require(ReleaseVersion("v0.10.0")) > #require(ReleaseVersion("0.9.9")))
        #expect(ReleaseVersion("v1.2.3") == ReleaseVersion("1.2.3"))
    }

    @Test(arguments: [
        "", "1.2", "1.02.3", "1.2.3-beta.1", "v../1", "1.2.3/evil", "1.2.٣", "9999999999999999999999999.0.0",
    ])
    func invalidOrNonStableVersionsAreRejected(_ value: String) { #expect(ReleaseVersion(value) == nil) }

    @Test func scheduledChecksRespectOptOutAndBackOff() {
        let now = Date(timeIntervalSince1970: 100_000)
        #expect(!UpdateCheckPolicy.isDue(enabled: false, lastAttempt: nil, now: now, retrying: false))
        #expect(UpdateCheckPolicy.isDue(enabled: true, lastAttempt: nil, now: now, retrying: false))
        #expect(!UpdateCheckPolicy.isDue(enabled: true, lastAttempt: now, now: now, retrying: true))
        let recent = now.addingTimeInterval(-3600)
        #expect(UpdateCheckPolicy.isDue(enabled: true, lastAttempt: recent, now: now, retrying: true))
        #expect(!UpdateCheckPolicy.isDue(enabled: true, lastAttempt: recent, now: now, retrying: false))
        #expect(
            UpdateCheckPolicy.isDue(enabled: true, lastAttempt: now.addingTimeInterval(60), now: now, retrying: false))
    }

    @Test func publishedInstallerIsPinnedToItsReleaseAndDMGIsPreferred() async throws {
        let client = client(body: payload(assets: [asset("ChatHub-macOS.zip"), asset("ChatHub-macOS.dmg")]))
        let update = try await client.latestUpdate(after: #require(ReleaseVersion("0.2.0")))
        #expect(update?.version == ReleaseVersion("0.3.0"))
        #expect(
            update?.downloadURL.absoluteString
                == "https://github.com/huydq7-dev/ChatHub/releases/download/v0.3.0/ChatHub-macOS.dmg")
    }

    @Test func alreadyInstalledOrOlderVersionsNeverPrompt() async throws {
        let client = client(body: payload())
        #expect(try await client.latestUpdate(after: #require(ReleaseVersion("0.3.0"))) == nil)
        #expect(try await client.latestUpdate(after: #require(ReleaseVersion("0.4.0"))) == nil)
    }

    @Test func draftsAndPrereleasesNeverPrompt() async throws {
        for flags in [(true, false), (false, true)] {
            let client = client(body: payload(draft: flags.0, prerelease: flags.1))
            #expect(try await client.latestUpdate(after: #require(ReleaseVersion("0.2.0"))) == nil)
        }
    }

    @Test func externalOrUnfinishedAssetsCannotBecomeDownloadActions() async throws {
        for badAsset in [
            asset("ChatHub-macOS.dmg", url: "https://evil.example/app.dmg"), asset("ChatHub-macOS.dmg", state: "new"),
            asset("ChatHub-macOS.dmg", size: 0),
        ] {
            let client = client(body: payload(assets: [badAsset]))
            await #expect(throws: ReleaseCheckError.unavailable) {
                try await client.latestUpdate(after: #require(ReleaseVersion("0.2.0")))
            }
        }
    }

    @Test(arguments: [403, 429, 500])
    func serverErrorsCannotBeMisreportedAsUpToDate(_ status: Int) async throws {
        let client = client(status: status, body: payload())
        await #expect(throws: status == 500 ? ReleaseCheckError.http(500) : .rateLimited) {
            try await client.latestUpdate(after: #require(ReleaseVersion("0.2.0")))
        }
    }

    private func asset(_ name: String, url: String? = nil, state: String = "uploaded", size: Int = 1024) -> [String:
        Any]
    {
        [
            "name": name, "state": state, "size": size,
            "browser_download_url": url ?? "https://github.com/huydq7-dev/ChatHub/releases/download/v0.3.0/\(name)",
        ]
    }

    private func payload(draft: Bool = false, prerelease: Bool = false, assets: [[String: Any]]? = nil) -> Data {
        try! JSONSerialization.data(withJSONObject: [
            "tag_name": "v0.3.0", "draft": draft, "prerelease": prerelease,
            "assets": assets ?? [asset("ChatHub-macOS.dmg")],
        ])
    }

    private func client(status: Int = 200, body: Data) -> GitHubReleaseClient {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [ReleaseStubProtocol.self]
        config.httpAdditionalHeaders = ["X-Test-Response": body.base64EncodedString(), "X-Test-Status": String(status)]
        return GitHubReleaseClient(session: URLSession(configuration: config))
    }
}

private final class ReleaseStubProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let status = Int(request.value(forHTTPHeaderField: "X-Test-Status") ?? "200")!
        let data = Data(base64Encoded: request.value(forHTTPHeaderField: "X-Test-Response")!)!
        client?.urlProtocol(
            self,
            didReceive: HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!,
            cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
