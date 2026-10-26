import Foundation
import Testing

@testable import ChatHubCore

@Suite("Durable workspace storage")
struct WorkspaceRepositoryTests {
    private func withRepository(_ body: (WorkspaceRepository) throws -> Void) throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("ChatHubTests-\(UUID())")
        defer { try? FileManager.default.removeItem(at: folder) }
        try body(WorkspaceRepository(fileURL: folder.appendingPathComponent("workspace.json")))
    }

    @Test func firstLaunchIsAnEmptyWorkspace() throws {
        try withRepository { repository in
            let loaded = try repository.load()
            #expect(loaded == WorkspaceArchive())
            #expect(!FileManager.default.fileExists(atPath: repository.fileURL.path))
        }
    }

    @Test func roundTripKeepsProfilesAndSelectionStable() throws {
        try withRepository { repository in
            let personal = ChatAccount(service: .telegram, name: "Personal")
            let work = ChatAccount(service: .telegram, name: "Work")
            let archive = WorkspaceArchive(accounts: [personal, work], selectedAccountID: work.id)
            try repository.save(archive)
            let loaded = try repository.load()
            #expect(loaded == archive)
            #expect(personal.id != work.id)
            let permissions =
                try FileManager.default.attributesOfItem(atPath: repository.fileURL.path)[.posixPermissions] as? Int
            #expect(permissions == 0o600)
        }
    }

    @Test func changingSelectionAndRemovingAccountPersists() throws {
        try withRepository { repository in
            let account = ChatAccount(service: .zalo, name: "Family")
            try repository.save(WorkspaceArchive(accounts: [account], selectedAccountID: account.id))
            try repository.save(WorkspaceArchive(accounts: [account]))
            let deselected = try repository.load()
            #expect(deselected.selectedAccountID == nil)
            try repository.save(WorkspaceArchive())
            let empty = try repository.load()
            #expect(empty.accounts.isEmpty)
        }
    }

    @Test func corruptArchiveIsPreserved() throws {
        try withRepository { repository in
            try FileManager.default.createDirectory(
                at: repository.fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let original = Data("not valid JSON".utf8)
            try original.write(to: repository.fileURL)
            #expect(throws: (any Error).self) { try repository.load() }
            let preserved = try Data(contentsOf: repository.fileURL)
            #expect(preserved == original)
        }
    }

    @Test func newerArchiveVersionsAreNotSilentlyAccepted() throws {
        try withRepository { repository in
            try FileManager.default.createDirectory(
                at: repository.fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data(#"{"version":99,"accounts":[]}"#.utf8).write(to: repository.fileURL)
            #expect(throws: WorkspaceStorageError.self) { try repository.load() }
        }
    }

    @Test func invalidWritesLeaveExistingWorkspaceIntact() throws {
        try withRepository { repository in
            let account = ChatAccount(service: .messenger, name: "Friends")
            let valid = WorkspaceArchive(accounts: [account])
            try repository.save(valid)
            #expect(throws: WorkspaceStorageError.self) {
                try repository.save(WorkspaceArchive(accounts: [account, account]))
            }
            #expect(throws: WorkspaceStorageError.self) {
                try repository.save(WorkspaceArchive(accounts: [account], selectedAccountID: UUID()))
            }
            let loaded = try repository.load()
            #expect(loaded == valid)
        }
    }
}
