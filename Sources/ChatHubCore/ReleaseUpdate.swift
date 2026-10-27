import Foundation

/// Stable release tags and app versions share a numeric major.minor.patch format.
public struct ReleaseVersion: Comparable, Equatable, Sendable, CustomStringConvertible {
    private let parts: [Int]

    public init?(_ value: String) {
        var text = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("v") { text.removeFirst() }
        let components = text.split(separator: ".", omittingEmptySubsequences: false)
        guard components.count == 3 else { return nil }
        var parsed: [Int] = []
        for component in components {
            guard !component.isEmpty,
                component.utf8.allSatisfy({ $0 >= 48 && $0 <= 57 }),
                component.count == 1 || component.first != "0",
                let number = Int(component)
            else { return nil }
            parsed.append(number)
        }
        parts = parsed
    }

    public var description: String { parts.map(String.init).joined(separator: ".") }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.parts.lexicographicallyPrecedes(rhs.parts)
    }
}

public struct ReleaseUpdate: Equatable, Sendable {
    public let version: ReleaseVersion
    public let downloadURL: URL
    public let releaseURL: URL

    public init(version: ReleaseVersion, downloadURL: URL, releaseURL: URL) {
        self.version = version
        self.downloadURL = downloadURL
        self.releaseURL = releaseURL
    }
}

public protocol ReleaseChecking: Sendable {
    func latestUpdate(after installed: ReleaseVersion) async throws -> ReleaseUpdate?
}

public enum ReleaseCheckError: Error, Equatable, Sendable {
    case unavailable, invalidResponse, rateLimited
    case http(Int)
}

public struct GitHubReleaseClient: ReleaseChecking {
    public static let repository = "huydq7-dev/ChatHub"
    public static let releasesURL = URL(string: "https://github.com/\(repository)/releases/latest")!
    private let session: URLSession

    public init(session: URLSession = URLSession(configuration: .ephemeral)) { self.session = session }

    public func latestUpdate(after installed: ReleaseVersion) async throws -> ReleaseUpdate? {
        let url = URL(string: "https://api.github.com/repos/\(Self.repository)/releases/latest")!
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("ChatHub/\(installed)", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw ReleaseCheckError.invalidResponse }
        switch response.statusCode {
        case 200: break
        case 404: throw ReleaseCheckError.unavailable
        case 403, 429: throw ReleaseCheckError.rateLimited
        default: throw ReleaseCheckError.http(response.statusCode)
        }
        guard data.count <= 1_048_576 else { throw ReleaseCheckError.invalidResponse }
        let release: Payload
        do { release = try JSONDecoder().decode(Payload.self, from: data) } catch {
            throw ReleaseCheckError.invalidResponse
        }
        guard !release.draft, !release.prerelease, let version = ReleaseVersion(release.tagName) else { return nil }
        guard version > installed else { return nil }
        // Construct canonical repository URLs; do not open URLs supplied in remote release notes.
        let base = "https://github.com/\(Self.repository)/releases"
        for filename in ["ChatHub-macOS.dmg", "ChatHub-macOS.zip"] {
            let expected = "\(base)/download/\(release.tagName)/\(filename)"
            if release.assets.contains(where: {
                $0.name == filename && $0.state == "uploaded" && $0.size > 0 && $0.browserDownloadURL == expected
            }), let download = URL(string: expected), let notes = URL(string: "\(base)/tag/\(release.tagName)") {
                return ReleaseUpdate(version: version, downloadURL: download, releaseURL: notes)
            }
        }
        // Releases may be visible before their installer assets finish uploading.
        throw ReleaseCheckError.unavailable
    }

    private struct Payload: Decodable {
        let tagName: String
        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case draft, prerelease, assets
        }
        let draft: Bool
        let prerelease: Bool
        let assets: [Asset]
    }

    private struct Asset: Decodable {
        let name: String
        let state: String
        let size: Int
        let browserDownloadURL: String
        enum CodingKeys: String, CodingKey {
            case name, state, size
            case browserDownloadURL = "browser_download_url"
        }
    }
}

public enum UpdateCheckPolicy {
    public static let interval: TimeInterval = 6 * 60 * 60
    public static let retryInterval: TimeInterval = 30 * 60

    public static func isDue(enabled: Bool, lastAttempt: Date?, now: Date, retrying: Bool) -> Bool {
        guard enabled else { return false }
        guard let lastAttempt else { return true }
        // Recover from a corrected clock or restored preferences from another machine.
        return lastAttempt > now || now.timeIntervalSince(lastAttempt) >= (retrying ? retryInterval : interval)
    }
}
