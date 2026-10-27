import Foundation

public struct DownloadRecord: Identifiable, Equatable, Sendable {
    public enum State: Equatable, Sendable {
        case inProgress
        case finished
        case failed(String)
    }

    public let id: UUID
    public let filename: String
    public let accountName: String
    public let destination: URL
    public let startedAt: Date
    public var state: State

    public init(
        id: UUID = UUID(), filename: String, accountName: String, destination: URL,
        startedAt: Date = .now, state: State = .inProgress
    ) {
        self.id = id
        self.filename = filename
        self.accountName = accountName
        self.destination = destination
        self.startedAt = startedAt
        self.state = state
    }
}

/// Files the user saved from their accounts during this launch, newest first.
public struct DownloadHistory: Equatable, Sendable {
    public static let limit = 50

    public private(set) var records: [DownloadRecord] = []

    public init() {}

    public var inProgressCount: Int { records.filter { $0.state == .inProgress }.count }

    public mutating func begin(_ record: DownloadRecord) {
        records.removeAll { $0.id == record.id }
        records.insert(record, at: 0)
        // Keep the newest entries; a download still running is never dropped.
        while records.count > Self.limit, let oldest = records.lastIndex(where: { $0.state != .inProgress }) {
            records.remove(at: oldest)
        }
    }

    public mutating func finish(_ id: UUID) { update(id, to: .finished) }

    public mutating func fail(_ id: UUID, message: String) { update(id, to: .failed(message)) }

    public mutating func remove(_ id: UUID) { records.removeAll { $0.id == id } }

    public mutating func clearFinished() { records.removeAll { $0.state != .inProgress } }

    private mutating func update(_ id: UUID, to state: DownloadRecord.State) {
        guard let index = records.firstIndex(where: { $0.id == id }) else { return }
        records[index].state = state
    }
}
