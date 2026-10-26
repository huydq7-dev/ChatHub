import Foundation
import Testing

@testable import ChatHubCore

struct DownloadedFileTests {
    @Test func completedDownloadCanReplaceAnExistingFile() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("ChatHubDownloadTest-\(UUID())")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let source = folder.appendingPathComponent("source")
        let destination = folder.appendingPathComponent("destination")
        try Data("previous".utf8).write(to: destination)
        try Data("downloaded".utf8).write(to: source)
        try DownloadedFile.install(from: source, to: destination)
        let saved = try String(contentsOf: destination, encoding: .utf8)
        #expect(saved == "downloaded")
    }

    @Test func failedDownloadDoesNotDestroyExistingFile() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("ChatHubDownloadTest-\(UUID())")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let destination = folder.appendingPathComponent("destination")
        try Data("keep me".utf8).write(to: destination)
        #expect(throws: (any Error).self) {
            try DownloadedFile.install(from: folder.appendingPathComponent("missing"), to: destination)
        }
        let saved = try String(contentsOf: destination, encoding: .utf8)
        #expect(saved == "keep me")
    }
}
