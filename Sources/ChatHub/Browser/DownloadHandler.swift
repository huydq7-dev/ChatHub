import AppKit
import WebKit

#if SWIFT_PACKAGE
    import ChatHubCore
#endif

@MainActor
final class DownloadHandler: NSObject, WKDownloadDelegate {
    private weak var window: NSWindow?
    private let completion: (Error?) -> Void
    private var destination: URL?
    private var stagingDirectory: URL?
    private var stagingFile: URL?
    private var hasSecurityScope = false
    private var activeDownload: WKDownload?
    private var didComplete = false

    init(download: WKDownload, window: NSWindow?, completion: @escaping @MainActor @Sendable (Error?) -> Void) {
        activeDownload = download
        self.window = window
        self.completion = completion
    }

    func download(
        _ download: WKDownload, decideDestinationUsing response: URLResponse,
        suggestedFilename: String, completionHandler: @escaping @MainActor @Sendable (URL?) -> Void
    ) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = URL(fileURLWithPath: suggestedFilename).lastPathComponent
        panel.canCreateDirectories = true
        guard let window else {
            completionHandler(nil)
            finish(nil)
            return
        }
        panel.beginSheetModal(for: window) { [self] result in
            guard result == .OK, let url = panel.url else {
                completionHandler(nil)
                finish(nil)
                return
            }
            do {
                let folder = FileManager.default.temporaryDirectory.appendingPathComponent("ChatHub-\(UUID())")
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                stagingDirectory = folder
                stagingFile = folder.appendingPathComponent("download")
                hasSecurityScope = url.startAccessingSecurityScopedResource()
                destination = url
                completionHandler(stagingFile)
            } catch {
                completionHandler(nil)
                finish(error)
            }
        }
    }

    func downloadDidFinish(_ download: WKDownload) {
        do {
            if let stagingFile, let destination {
                try DownloadedFile.install(from: stagingFile, to: destination)
            }
            finish(nil)
        } catch { finish(error) }
    }

    func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
        finish(error)
    }

    func cancel() {
        activeDownload?.cancel { _ in }
        finish(nil)
    }

    private func finish(_ error: Error?) {
        guard !didComplete else { return }
        didComplete = true
        activeDownload = nil
        if hasSecurityScope { destination?.stopAccessingSecurityScopedResource() }
        if let stagingDirectory { try? FileManager.default.removeItem(at: stagingDirectory) }
        completion(error)
    }
}
