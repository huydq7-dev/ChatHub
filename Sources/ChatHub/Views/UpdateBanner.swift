import SwiftUI

struct UpdateBanner: View {
    @Environment(AppUpdater.self) private var updater

    var body: some View {
        if let update = updater.availableUpdate {
            HStack(spacing: HubSpace.sm) {
                Image(systemName: "arrow.down.circle.fill")
                    .foregroundStyle(HubStyle.accentText)
                    .accessibilityHidden(true)
                Text(String(format: tr("ChatHub %@ is available."), update.version.description))
                    .font(HubFont.body)
                    .foregroundStyle(HubStyle.textPrimary)
                Spacer(minLength: HubSpace.sm)
                Button(tr("Download Update")) { updater.downloadUpdate() }
                    .buttonStyle(.borderedProminent)
                Menu {
                    Button(tr("Release Notes")) { updater.openReleaseNotes() }
                    Button(tr("Remind Me Later")) { updater.remindLater() }
                    Button(tr("Skip This Version")) { updater.skipVersion() }
                } label: {
                    Image(systemName: "ellipsis")
                        .frame(width: 28, height: 28)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .help(tr("Update options"))
                .accessibilityLabel(tr("Update options"))
            }
            .padding(.horizontal, HubSpace.md)
            .padding(.vertical, HubSpace.xs)
            .background(HubStyle.raised)
            .overlay(alignment: .bottom) { Divider() }
        }
    }
}
