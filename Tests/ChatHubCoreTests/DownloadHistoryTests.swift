import Foundation
import Testing

@testable import ChatHubCore

@Suite("Download history")
struct DownloadHistoryTests {
    private func record(_ name: String = "a.pdf", id: UUID = UUID()) -> DownloadRecord {
        DownloadRecord(id: id, filename: name, accountName: "Work", destination: URL(fileURLWithPath: "/tmp/\(name)"))
    }

    @Test func newestDownloadComesFirstAndStartsInProgress() {
        var history = DownloadHistory()
        history.begin(record("one"))
        history.begin(record("two"))
        #expect(history.records.map(\.filename) == ["two", "one"])
        #expect(history.inProgressCount == 2)
    }

    @Test func finishingAndFailingUpdateOnlyThatRecord() {
        var history = DownloadHistory()
        let first = record("one")
        let second = record("two")
        history.begin(first)
        history.begin(second)
        history.finish(first.id)
        history.fail(second.id, message: "Network lost")
        #expect(history.records.first { $0.id == first.id }?.state == .finished)
        #expect(history.records.first { $0.id == second.id }?.state == .failed("Network lost"))
        #expect(history.inProgressCount == 0)
        history.finish(UUID())
        #expect(history.records.count == 2)
    }

    @Test func clearingKeepsRunningDownloadsOnly() {
        var history = DownloadHistory()
        let done = record("done")
        let running = record("running")
        history.begin(done)
        history.begin(running)
        history.finish(done.id)
        history.clearFinished()
        #expect(history.records.map(\.filename) == ["running"])
    }

    @Test func removingOneRecordLeavesTheRest() {
        var history = DownloadHistory()
        let first = record("one")
        history.begin(first)
        history.begin(record("two"))
        history.remove(first.id)
        #expect(history.records.map(\.filename) == ["two"])
    }

    @Test func theListIsCappedButNeverDropsARunningDownload() {
        var history = DownloadHistory()
        let running = record("running")
        history.begin(running)
        for index in 0..<(DownloadHistory.limit + 10) {
            let item = record("file\(index)")
            history.begin(item)
            history.finish(item.id)
        }
        #expect(history.records.count == DownloadHistory.limit)
        #expect(history.records.contains { $0.id == running.id })
        #expect(history.records.first?.filename == "file\(DownloadHistory.limit + 9)")
    }
}
