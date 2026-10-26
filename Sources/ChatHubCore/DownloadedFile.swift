import Foundation

public enum DownloadedFile {
    /// Stage a finished download beside its destination before replacing an existing file.
    /// A failed download never truncates the user's previous file.
    public static func install(from source: URL, to destination: URL) throws {
        let staged = destination.deletingLastPathComponent()
            .appendingPathComponent(".chathub-\(UUID().uuidString).download")
        defer { try? FileManager.default.removeItem(at: staged) }
        try FileManager.default.copyItem(at: source, to: staged)
        if FileManager.default.fileExists(atPath: destination.path) {
            _ = try FileManager.default.replaceItemAt(destination, withItemAt: staged)
        } else {
            try FileManager.default.moveItem(at: staged, to: destination)
        }
    }
}
