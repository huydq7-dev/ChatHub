import AppKit
import SwiftUI

#if SWIFT_PACKAGE
    import ChatHubCore
#endif

struct DownloadsPopover: View {
    private let center = DownloadCenter.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(tr("Downloads"))
                    .font(HubFont.rowTitle)
                    .foregroundStyle(HubStyle.textPrimary)
                Spacer()
                Button(tr("Clear Finished")) { center.clearFinished() }
                    .buttonStyle(.link)
                    .font(HubFont.captionMedium)
                    .disabled(center.history.records.allSatisfy { $0.state == .inProgress })
            }
            .padding(HubSpace.md)
            Divider().overlay(HubStyle.border)
            if center.history.records.isEmpty {
                Text(tr("Files you save from your accounts appear here."))
                    .font(HubFont.caption)
                    .foregroundStyle(HubStyle.textSecondary)
                    .padding(HubSpace.md)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(center.history.records) { record in
                            DownloadRow(record: record) { center.remove(record.id) }
                        }
                    }
                }
                .frame(maxHeight: 320)
            }
        }
        .frame(width: 340)
        .background(HubStyle.surface)
    }
}

private struct DownloadRow: View {
    let record: DownloadRecord
    let remove: () -> Void

    private var fileExists: Bool { FileManager.default.fileExists(atPath: record.destination.path) }

    var body: some View {
        HStack(spacing: HubSpace.sm) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: record.destination.path))
                .resizable()
                .frame(width: 28, height: 28)
                .opacity(record.state == .finished && fileExists ? 1 : 0.5)
            VStack(alignment: .leading, spacing: 2) {
                Text(record.filename)
                    .font(HubFont.rowTitle)
                    .foregroundStyle(HubStyle.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                statusLine
            }
            Spacer(minLength: 0)
            actions
        }
        .padding(.horizontal, HubSpace.md)
        .padding(.vertical, HubSpace.xs)
    }

    @ViewBuilder private var statusLine: some View {
        switch record.state {
        case .inProgress:
            HStack(spacing: HubSpace.xxs) {
                ProgressView().controlSize(.mini)
                Text(tr("Downloading…"))
            }
            .font(HubFont.meta)
            .foregroundStyle(HubStyle.textSecondary)
        case .finished:
            Text(fileExists ? record.accountName : tr("Moved or deleted"))
                .font(HubFont.meta)
                .foregroundStyle(HubStyle.textSecondary)
        case .failed(let message):
            Text(message)
                .font(HubFont.meta)
                .foregroundStyle(.red)
                .lineLimit(2)
        }
    }

    @ViewBuilder private var actions: some View {
        HStack(spacing: HubSpace.xs) {
            if record.state == .finished && fileExists {
                Button {
                    NSWorkspace.shared.open(record.destination)
                } label: {
                    Image(systemName: "arrow.up.forward.app")
                }
                .help(tr("Open"))
                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([record.destination])
                } label: {
                    Image(systemName: "magnifyingglass")
                }
                .help(tr("Show in Finder"))
            }
            if record.state != .inProgress {
                Button(action: remove) {
                    Image(systemName: "xmark")
                }
                .help(tr("Remove from list"))
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(HubStyle.textSecondary)
    }
}
