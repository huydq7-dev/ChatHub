import Foundation

public struct WorkspaceArchive: Codable, Equatable, Sendable {
    public static let currentVersion = 1
    public let version: Int
    public var accounts: [ChatAccount]
    public var selectedAccountID: UUID?

    public init(accounts: [ChatAccount] = [], selectedAccountID: UUID? = nil) {
        version = Self.currentVersion
        self.accounts = accounts
        self.selectedAccountID = selectedAccountID
    }
}

public enum WorkspaceStorageError: Error, LocalizedError {
    case unsupportedVersion(Int)
    case duplicateAccount
    case invalidSelection

    public var errorDescription: String? {
        switch self {
        case .unsupportedVersion(let version):
            "This workspace was saved by a different version of ChatHub (format \(version))."
        case .duplicateAccount: "The workspace contains duplicate account identifiers."
        case .invalidSelection: "The selected account no longer exists."
        }
    }
}

public struct WorkspaceRepository: Sendable {
    public let fileURL: URL

    public init(fileURL: URL) { self.fileURL = fileURL }

    public func load() throws -> WorkspaceArchive {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return WorkspaceArchive() }
        let archive = try JSONDecoder().decode(WorkspaceArchive.self, from: Data(contentsOf: fileURL))
        try validate(archive)
        return archive
    }

    public func save(_ archive: WorkspaceArchive) throws {
        try validate(archive)
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(archive).write(to: fileURL, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
    }

    private func validate(_ archive: WorkspaceArchive) throws {
        guard archive.version == WorkspaceArchive.currentVersion else {
            throw WorkspaceStorageError.unsupportedVersion(archive.version)
        }
        guard Set(archive.accounts.map(\.id)).count == archive.accounts.count else {
            throw WorkspaceStorageError.duplicateAccount
        }
        if let selected = archive.selectedAccountID,
            !archive.accounts.contains(where: { $0.id == selected })
        {
            throw WorkspaceStorageError.invalidSelection
        }
        for account in archive.accounts { _ = try account.validated() }
    }
}
