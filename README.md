# ChatHub for macOS

A native SwiftUI workspace for everyday messaging. macOS 14+, Swift 6, AppKit and
WebKit. The application has no third-party runtime dependencies or ChatHub server.

## Install (For Users)

1. Download **`ChatHub-macOS.dmg`** from [GitHub Releases](../../releases/latest).
2. Open `ChatHub-macOS.dmg` and drag **`ChatHub.app`** into **`Applications`**.
3. Because builds are signed locally without an Apple Developer ID certificate, remove the macOS quarantine attribute once in Terminal before first launch:

```sh
xattr -cr /Applications/ChatHub.app
open -a /Applications/ChatHub.app
```

## Build & Package from Source

Open `ChatHub.xcodeproj` in Xcode 26+ and run the **ChatHub** scheme, or build from the command line:

```sh
bash scripts/build.sh Release
bash scripts/run.sh Release

# Package Universal .dmg and .zip installers into dist/
bash scripts/package.sh
```

The built app is `build/Build/Products/Release/ChatHub.app`. Local builds are ad-hoc
signed and sandboxed. XcodeGen is only needed when changing `project.yml`;
the generated Xcode project is included.

## What works in this implementation

- Native overview, service library, account editor, account search and settings.
- Compact icon rail or resizable account sidebar with saved layout, a unified
  native window toolbar and a searchable account switcher.
- Optional Zalo appearance layer: system font, coordinated light/dark colors,
  neutral navigation and softer conversation/bubble surfaces. Changes apply
  without reloading. Turn it off in Settings or the account menu.
- Telegram, Zalo, Messenger, WhatsApp, Discord and custom HTTPS web services.
- Multiple accounts per provider, each with a persistent isolated WebKit profile.
- Lazy loading and retained web views to preserve the open page across switches.
- File pickers, save dialogs and staged downloads that preserve existing files
  until the replacement has downloaded successfully.
- External links in the default browser; visible windows for allowed web sign-in
  popups; no custom TLS exceptions or unofficial messaging APIs.
- Native page search, back/forward, reload, offline feedback, retry after failed
  loads and reconnect of failed pages when the network returns.
- Atomic workspace metadata, validation, storage-error recovery and confirmed
  local-profile removal.
- System/light/dark appearance, English/Vietnamese system localization, semantic
  controls, accessibility labels and keyboard shortcuts.

Adding a service creates a **local account slot**, not a new provider account.
Sign in yourself on the provider's web page. Provider passwords are not collected
by ChatHub's native forms. Cookies, web storage and any provider-stored credentials
remain under WebKit's management; local metadata contains names, IDs and URLs.

## Shortcuts

| Shortcut | Action |
| --- | --- |
| ⌘N | Add an account |
| ⌘K | Search and switch accounts |
| ⌃⌘S | Expand/collapse the account sidebar |
| ⌘0 | Overview |
| ⌘1–9 | Switch to an account |
| ⌘R | Reload the current service |
| ⌘F | Find text in the loaded web page |
| ⇧⌘B | Open current page in the default browser |
| ⌘, | Settings |
| ⌘Q | Quit |

Closing the workspace window leaves the app and loaded sessions running. Clicking
the Dock icon reopens the window. Quitting ends the processes; cookies persist,
but restoration of drafts and history after relaunch depends on the provider.

## Boundaries to understand

The workspace is native; provider chat interfaces are their official websites.
This version does **not** merge conversation lists or search messages across
services. Page search can only find text the website has loaded into the page.

Native desktop notification forwarding, unread aggregation and push while the app
is quit are not implemented. Calls, screen sharing, encrypted history restoration
and sign-in compatibility must be checked per provider. Safari support alone does
not guarantee support in WKWebView. A configured provider is not a certification
that every provider feature works. No fake unread numbers or signed-in statuses
are shown.

If a service blocks an embedded browser or requires a browser-only authentication
flow, the fallback opens your browser with a **separate session**; it does not
transfer authentication back to ChatHub. This limitation requires a provider-
supported solution and cannot be fixed by styling.

## Development and verification

```sh
bash scripts/test.sh
node --test scripts/test-web.mjs
xcrun swift-format lint --strict --recursive Sources Tests scripts/render-icon.swift Package.swift
```

Swift Package Manager builds the app sources and tests the core models, URL trust
boundaries, navigation-error classification, storage and file replacement.
The native application is built and signed by Xcode. Both use Swift 6 concurrency
checking. Project generation: `xcodegen generate`.

App icon source: `scripts/render-icon.swift`. Rebuild it with:

```sh
xcrun swift scripts/render-icon.swift /tmp/ChatHub.iconset
iconutil -c icns /tmp/ChatHub.iconset -o Sources/ChatHub/Resources/AppIcon.icns
```

The implementation plan and acceptance criteria are in `docs/PLAN.md`; actual
verification evidence and the remaining authenticated checks are in
`docs/VERIFICATION.md`.

The 0.2 navigation and Zalo appearance changes are described in `docs/UI_UX_02.md`.
Only Zalo receives the optional stylesheet; other providers keep their own web
appearance. The theme checks the provider shell and falls back to the original
site if the expected structure is unavailable.

### Focused Zalo layout

With appearance matching enabled, ChatHub uses a borderless composer and soft
message surfaces, hides the duplicate provider rail, and hides named secondary
toolbar actions. The sliders button in the native window toolbar (**Show extra
service tools**) restores contacts, provider settings and the full chat toolbar
without a reload. The same preference is in Settings. Turning off appearance
matching restores the original provider interface.

### Update notifications (0.3.0+)

ChatHub automatically checks GitHub Releases every six hours while running and
shows a workspace banner when a newer stable installer is available. Use
**ChatHub → Check for Updates…** for an immediate check. Settings includes an
opt-out. Downloads use the official versioned DMG/ZIP; installation remains
manual. Users of older builds need to install a version containing this checker
once. See [update behavior and release steps](docs/UPDATES.md).
