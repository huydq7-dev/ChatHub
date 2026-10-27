import SwiftUI

#if SWIFT_PACKAGE
    import ChatHubCore
#endif

struct QuietHoursSettingsSection: View {
    @AppStorage(ChatAppearancePreferences.quietEnabledKey) private var isEnabled = false
    @AppStorage(ChatAppearancePreferences.quietStartKey) private var startMinute = QuietHours.defaultStartMinute
    @AppStorage(ChatAppearancePreferences.quietEndKey) private var endMinute = QuietHours.defaultEndMinute

    var body: some View {
        Section {
            Toggle(tr("Quiet hours"), isOn: $isEnabled)
            DatePicker(tr("From"), selection: time($startMinute), displayedComponents: .hourAndMinute)
                .disabled(!isEnabled)
            DatePicker(tr("To"), selection: time($endMinute), displayedComponents: .hourAndMinute)
                .disabled(!isEnabled)
        } header: {
            Text(tr("Do not disturb"))
        } footer: {
            Text(
                tr(
                    "No sounds, banners or Dock bounce during quiet hours. Unread badges keep updating. Snooze a single account from its context menu."
                ))
        }
    }

    private func time(_ minutes: Binding<Int>) -> Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(
                    bySettingHour: minutes.wrappedValue / 60, minute: minutes.wrappedValue % 60, second: 0,
                    of: Date()) ?? Date()
            },
            set: { date in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
                minutes.wrappedValue = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
            }
        )
    }
}

struct PrivacySettingsSection: View {
    @AppStorage(ChatAppearancePreferences.lockEnabledKey) private var lockEnabled = false
    @AppStorage(ChatAppearancePreferences.lockTimeoutKey) private var lockTimeout = 0
    @AppStorage(ChatAppearancePreferences.hidePreviewsKey) private var hidePreviews = false
    private let lockAvailable = AppLock.isAvailable

    var body: some View {
        Section {
            Toggle(tr("Require Touch ID or password"), isOn: $lockEnabled)
                .disabled(!lockAvailable)
            Picker(tr("Lock after leaving ChatHub for"), selection: $lockTimeout) {
                ForEach(AppLockPolicy.allowedTimeoutMinutes, id: \.self) { minutes in
                    Text(timeoutLabel(minutes)).tag(minutes)
                }
            }
            .disabled(!lockEnabled || !lockAvailable)
            Toggle(tr("Hide message previews in notifications"), isOn: $hidePreviews)
        } header: {
            Text(tr("Privacy"))
        } footer: {
            Text(
                lockAvailable
                    ? tr(
                        "ChatHub also locks when your Mac sleeps or the screen locks. Conversations stay hidden until you unlock."
                    )
                    : tr("Set a password or Touch ID on this Mac to use the lock."))
        }
    }

    private func timeoutLabel(_ minutes: Int) -> String {
        switch minutes {
        case 0: tr("Immediately")
        case 1: tr("1 minute")
        default: String(format: tr("%d minutes"), minutes)
        }
    }
}
