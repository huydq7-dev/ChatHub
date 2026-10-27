import Foundation

public enum ChatService: String, Codable, CaseIterable, Identifiable, Sendable {
    case telegram, zalo, messenger, whatsapp, discord, custom

    public var id: String { rawValue }

    public var name: String {
        switch self {
        case .telegram: "Telegram"
        case .zalo: "Zalo"
        case .messenger: "Messenger"
        case .whatsapp: "WhatsApp"
        case .discord: "Discord"
        case .custom: "Custom service"
        }
    }

    public var homeURL: URL? {
        switch self {
        case .telegram: URL(string: "https://web.telegram.org/a/")
        case .zalo: URL(string: "https://chat.zalo.me/")
        case .messenger: URL(string: "https://www.facebook.com/messages/")
        case .whatsapp: URL(string: "https://web.whatsapp.com/")
        case .discord: URL(string: "https://discord.com/app")
        case .custom: nil
        }
    }

    public var navigationDomains: [String] {
        switch self {
        case .telegram: ["telegram.org", "t.me"]
        case .zalo: ["zalo.me", "zalo.vn"]
        case .messenger: ["facebook.com", "messenger.com", "meta.com"]
        case .whatsapp: ["whatsapp.com"]
        case .discord: ["discord.com"]
        case .custom: []
        }
    }

    /// Cross-domain authentication endpoints are exact hosts, not domain-wide exceptions.
    public var authenticationHosts: [String] {
        switch self {
        case .zalo: ["jr.zaloapp.com"]
        default: []
        }
    }
}

public struct ChatAccount: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var service: ChatService
    public var name: String
    public var subtitle: String
    public var customURL: URL?
    public let createdAt: Date
    public var notificationsMuted: Bool

    public init(
        id: UUID = UUID(), service: ChatService, name: String,
        subtitle: String = "", customURL: URL? = nil, createdAt: Date = .now,
        notificationsMuted: Bool = false
    ) {
        self.id = id
        self.service = service
        self.name = name
        self.subtitle = subtitle
        self.customURL = customURL
        self.createdAt = createdAt
        self.notificationsMuted = notificationsMuted
    }

    /// Workspaces saved before muting existed have no `notificationsMuted` key.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        service = try container.decode(ChatService.self, forKey: .service)
        name = try container.decode(String.self, forKey: .name)
        subtitle = try container.decode(String.self, forKey: .subtitle)
        customURL = try container.decodeIfPresent(URL.self, forKey: .customURL)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        notificationsMuted = try container.decodeIfPresent(Bool.self, forKey: .notificationsMuted) ?? false
    }

    public var url: URL? { service == .custom ? customURL : service.homeURL }

    public func validated() throws -> ChatAccount {
        var account = self
        account.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        account.subtitle = subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !account.name.isEmpty, account.name.count <= 80 else {
            throw AccountValidationError.invalidName
        }
        guard account.subtitle.count <= 120 else { throw AccountValidationError.invalidSubtitle }
        if service == .custom {
            guard let customURL else { throw AccountValidationError.invalidURL }
            account.customURL = try SafeWebsiteURL.parse(customURL.absoluteString)
        } else {
            account.customURL = nil
        }
        return account
    }
}

public enum AccountValidationError: Error, LocalizedError, Equatable {
    case invalidName, invalidSubtitle, invalidURL

    public var errorDescription: String? {
        switch self {
        case .invalidName: "Enter a name between 1 and 80 characters."
        case .invalidSubtitle: "Keep the account label under 120 characters."
        case .invalidURL: "Enter a valid HTTPS website without a username or password."
        }
    }
}

public enum SafeWebsiteURL {
    public static func parse(_ input: String) throws -> URL {
        let value = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty,
            let components = URLComponents(string: value),
            components.scheme?.lowercased() == "https",
            let host = components.host, !host.isEmpty,
            !host.contains(where: { $0.isWhitespace }),
            components.user == nil, components.password == nil,
            let url = components.url
        else { throw AccountValidationError.invalidURL }
        return url
    }
}
