import Foundation
import Observation

#if SWIFT_PACKAGE
    import ChatHubCore
#endif

/// Remembers files saved during this launch so they can be found again. Nothing is written to disk.
@MainActor @Observable
final class DownloadCenter {
    static let shared = DownloadCenter()

    private(set) var history = DownloadHistory()

    func begin(id: UUID, filename: String, accountName: String, destination: URL) {
        history.begin(
            DownloadRecord(id: id, filename: filename, accountName: accountName, destination: destination))
    }

    func finish(_ id: UUID) { history.finish(id) }
    func fail(_ id: UUID, message: String) { history.fail(id, message: message) }
    func remove(_ id: UUID) { history.remove(id) }
    func clearFinished() { history.clearFinished() }
}
