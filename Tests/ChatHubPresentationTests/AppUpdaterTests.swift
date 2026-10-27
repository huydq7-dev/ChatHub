import Foundation
import Testing

@testable import ChatHub

#if SWIFT_PACKAGE
    import ChatHubCore
#endif

@MainActor
struct AppUpdaterTests {
    @Test func automaticChecksCanBeDisabledAndSkipDoesNotHideFutureVersions() async throws {
        let name = "ChatHubUpdaterTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let client = UpdateClientStub()
        let model = AppUpdater(defaults: defaults, client: client, installedVersion: "0.2.0")
        let now = Date(timeIntervalSince1970: 100_000)
        model.automaticChecksEnabled = false
        await model.check(manual: false, now: now)
        #expect(await client.requests == 0)
        model.automaticChecksEnabled = true
        await model.check(manual: false, now: now)
        #expect(model.availableUpdate?.version == ReleaseVersion("0.3.0"))
        model.skipVersion()
        await model.check(manual: false, now: now.addingTimeInterval(UpdateCheckPolicy.interval))
        #expect(model.availableUpdate == nil)
        await client.setVersion("0.4.0")
        await model.check(manual: false, now: now.addingTimeInterval(UpdateCheckPolicy.interval * 2))
        #expect(model.availableUpdate?.version == ReleaseVersion("0.4.0"))
        #expect(model.lastChecked != nil)
    }

    @Test func retryBackoffAndSettingsSurviveRelaunchWithoutBackgroundAlerts() async throws {
        let name = "ChatHubUpdaterTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let client = UpdateClientStub()
        await client.fail()
        let now = Date(timeIntervalSince1970: 100_000)
        let model = AppUpdater(defaults: defaults, client: client, installedVersion: "0.2.0")
        await model.check(manual: false, now: now)
        #expect(model.availableUpdate == nil)
        #expect(model.lastChecked == nil)
        #expect(!model.isChecking)
        let relaunched = AppUpdater(defaults: defaults, client: client, installedVersion: "0.2.0")
        await relaunched.check(manual: false, now: now.addingTimeInterval(60))
        #expect(await client.requests == 1)
        await relaunched.check(manual: false, now: now.addingTimeInterval(UpdateCheckPolicy.retryInterval))
        #expect(await client.requests == 2)
        relaunched.automaticChecksEnabled = false
        #expect(!AppUpdater(defaults: defaults, client: client).automaticChecksEnabled)
    }
}

private actor UpdateClientStub: ReleaseChecking {
    private(set) var requests = 0
    private var version = "0.3.0"
    private var fails = false
    func setVersion(_ value: String) { version = value }
    func fail() { fails = true }
    func latestUpdate(after installed: ReleaseVersion) async throws -> ReleaseUpdate? {
        requests += 1
        if fails { throw ReleaseCheckError.rateLimited }
        return ReleaseUpdate(
            version: ReleaseVersion(version)!,
            downloadURL: URL(
                string: "https://github.com/huydq7-dev/ChatHub/releases/download/v\(version)/ChatHub-macOS.dmg")!,
            releaseURL: URL(string: "https://github.com/huydq7-dev/ChatHub/releases/tag/v\(version)")!
        )
    }
}
