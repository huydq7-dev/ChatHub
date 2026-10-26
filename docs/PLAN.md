# ChatHub — macOS implementation plan

## Product decision

A local, native macOS workspace for personal messaging accounts. The window,
navigation, account management, settings, errors, file interactions and keyboard
commands belong to ChatHub. Each service renders its official web experience in
an isolated WebKit profile. No message scraping, unofficial account APIs, fake
conversations or fabricated unread counts.

Minimum OS: macOS 14. Stack: Swift 6, SwiftUI, AppKit, WebKit. No external runtime
dependencies. Telegram, Zalo, Messenger, WhatsApp, Discord and custom HTTPS sites
are selectable services. Web compatibility is not assumed from browser support.

## Implementation sequence

1. **Native workspace** — overview/onboarding, service library, account sidebar,
   keyboard commands, system appearance, accessible controls and account editing.
2. **Real sessions** — persistent UUID-backed website stores, lazy creation,
   retain loaded sessions across switching, navigation boundaries, uploads,
   downloads, JavaScript dialogs, explicit camera/microphone permission.
3. **Durability** — atomic metadata storage, safe URL validation, migration version,
   recovery UI, loading progress, retry, process-crash handling, data deletion.
4. **Verification and delivery** — Swift tests for persistence and security
   boundaries, strict compilation, formatting, signed local app, live UI check,
   reproducible build/run instructions and an honest integration test matrix.

## Acceptance criteria

- A new user can add an account and reach its real sign-in page.
- Account identifiers and profile identifiers remain stable after relaunch.
- Switching accounts does not recreate an already loaded web view.
- External links do not silently replace a conversation; web auth flows can run.
- File saves require a destination selected by the user.
- Removing an account offers explicit deletion of that profile's local web data.
- Storage failures never silently overwrite an unreadable account archive.
- Errors are actionable and are never presented as successful connections.
- Native UI works in light/dark appearances, keyboard navigation and VoiceOver.

## Integration validation requiring user sign-in

For every service: login/2FA, relaunch, send/receive text, Vietnamese IME,
paste/upload/download files, draft + scroll retention, reconnect, sleep/wake,
multiple accounts and prolonged CPU/RAM usage. Calls, screen sharing, encrypted
history restoration and background notifications are separate checks. They are
not promised by this first implementation. Native Telegram via TDLib remains a
later integration after the workspace is proven in daily use.

## Release boundary

The first deliverable is an executable local app and maintainable source. It is
not declared production-validated until authenticated service checks and a daily
use soak pass. External distribution additionally needs Developer ID signing,
notarization, an update channel and service branding/terms review.

## Delivered in this workspace

All four implementation steps above have a working first implementation. A
universal, ad-hoc-signed `ChatHub.app` is built under
`build/Build/Products/Release/`. The final Release app has been launched with the
user's accounts retained. The evidence and unresolved authenticated acceptance
checks are recorded in `docs/VERIFICATION.md`. Notifications and a native TDLib
client are future capabilities, not represented as implemented features.
