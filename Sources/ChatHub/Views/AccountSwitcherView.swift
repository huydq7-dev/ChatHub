import SwiftUI

#if SWIFT_PACKAGE
    import ChatHubCore
#endif

struct AccountSwitcherView: View {
    @Environment(WorkspaceStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var highlighted = "overview"
    @FocusState private var searchFocused: Bool

    private var matches: [ChatAccount] {
        store.accounts.filter {
            query.isEmpty || "\($0.name) \($0.subtitle) \($0.service.name)".localizedCaseInsensitiveContains(query)
        }
    }
    private var destinations: [String] {
        (showOverview ? ["overview"] : []) + matches.map { $0.id.uuidString }
    }
    private var showOverview: Bool { query.isEmpty || tr("Overview").localizedCaseInsensitiveContains(query) }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: HubSpace.sm) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(HubStyle.textSecondary)
                TextField(tr("Jump to an account…"), text: $query)
                    .textFieldStyle(.plain)
                    .font(HubFont.header)
                    .foregroundStyle(HubStyle.textPrimary)
                    .focused($searchFocused)
                    .onSubmit { open(highlighted) }
                    .onMoveCommand { move($0) }
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(HubStyle.textSecondary)
                }
                .buttonStyle(.plain)
                .help(tr("Cancel"))
                .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, HubSpace.lg)
            .padding(.vertical, HubSpace.md)
            .liquidGlassCard(cornerRadius: 0)

            Divider().overlay(HubStyle.border)

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: HubSpace.xxs) {
                        if showOverview {
                            switcherRow(id: "overview", title: tr("Overview"), subtitle: tr("Your workspace")) {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(HubStyle.raised)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .strokeBorder(HubStyle.border, lineWidth: 1)
                                    )
                                    .overlay {
                                        Image(systemName: "square.grid.2x2")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundStyle(HubStyle.accentText)
                                    }
                                    .frame(width: 34, height: 34)
                            }
                        }
                        ForEach(matches) { account in
                            switcherRow(
                                id: account.id.uuidString,
                                title: account.name,
                                subtitle: account.subtitle.isEmpty ? account.service.name : account.subtitle
                            ) {
                                ServiceIcon(service: account.service, size: 34)
                            }
                        }
                        if destinations.isEmpty {
                            ContentUnavailableView.search(text: query).frame(height: 190)
                        }
                    }
                    .padding(HubSpace.sm)
                }
                .onChange(of: highlighted) { _, value in proxy.scrollTo(value, anchor: .center) }
            }
            .frame(height: 292)
            .background(HubStyle.canvas)

            Divider().overlay(HubStyle.border)

            HStack {
                Text(tr("↑↓ to navigate · ↩ to open"))
                    .font(HubFont.meta)
                    .foregroundStyle(HubStyle.textSecondary)
                Spacer()
                Button(tr("Add account")) {
                    store.addAccountAfterSwitcher = true
                    dismiss()
                }
                .buttonStyle(.link)
                .font(HubFont.captionMedium)
            }
            .padding(.horizontal, HubSpace.lg)
            .padding(.vertical, HubSpace.sm)
            .background(HubStyle.surface)
        }
        .frame(width: 480)
        .background(HubStyle.canvas)
        .tint(HubStyle.accent)
        .onAppear {
            highlighted = store.selectedID?.uuidString ?? "overview"
            searchFocused = true
        }
        .onChange(of: query) { _, _ in highlighted = destinations.first ?? "" }
    }

    private func switcherRow<Icon: View>(
        id: String, title: String, subtitle: String, @ViewBuilder icon: () -> Icon
    ) -> some View {
        let isSelected = highlighted == id
        return Button {
            open(id)
        } label: {
            HStack(spacing: HubSpace.sm) {
                icon()
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(HubFont.rowTitle)
                        .foregroundStyle(HubStyle.textPrimary)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(HubFont.rowSubtitle)
                        .foregroundStyle(HubStyle.textSecondary)
                        .lineLimit(1)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "return")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(HubStyle.accentText)
                }
            }
            .padding(.horizontal, HubSpace.sm)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .liquidGlassCard(
                cornerRadius: HubRadius.row,
                tint: isSelected ? HubStyle.accent.opacity(0.18) : nil,
                interactive: true
            )
            .overlay(alignment: .leading) {
                if isSelected {
                    Capsule()
                        .fill(HubStyle.accentText)
                        .frame(width: 3, height: 18)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .id(id)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func move(_ direction: MoveCommandDirection) {
        let ids = destinations
        guard !ids.isEmpty else { return }
        let index = ids.firstIndex(of: highlighted) ?? 0
        if direction == .down { highlighted = ids[min(index + 1, ids.count - 1)] }
        if direction == .up { highlighted = ids[max(index - 1, 0)] }
    }

    private func open(_ id: String) {
        if id == "overview" {
            store.select(nil)
            dismiss()
        } else if let uuid = UUID(uuidString: id) {
            store.select(uuid)
            dismiss()
        }
    }
}
