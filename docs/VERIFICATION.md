# Verification — 2026-10-26

## Automated evidence

- Debug Xcode build: passed on the host Mac, Swift 6 strict concurrency.
- Swift test suite: 31 tests across 7 suites passed, including parameterized cases.
- Web appearance script: 6 Node tests passed.
- Core line coverage: **81.87%** (149/182 lines); sidebar layout persistence:
  **100%** (17/17 lines). This is coverage of those models,
  not a claim about SwiftUI or authenticated web flows.
- Swift formatting/lint: passed `swift-format lint --strict`.
- Info.plist, entitlements and both localization files: passed `plutil -lint`.
- Build/run/test shell scripts: passed `bash -n`.
- Release Xcode build: **passed**, universal arm64 + x86_64, with Swift compiler
  warnings treated as errors. Xcode emits its informational App Intents metadata
  warning because the app does not use the App Intents framework; no Swift source
  warnings remain.
- App signature: passed `codesign --verify --deep --strict`; App Sandbox, network,
  user-selected file access, camera and audio-input entitlements are present.
  Release does not include `get-task-allow` debug access.
- Secret-signature and trailing-whitespace scan: 31 text files, no findings.

The tool's outer sandbox initially prevented Swift compiler plugins and the Swift
test runner from starting. Build and tests were rerun with approved execution
permissions. App Sandbox, HTTPS validation and the tests themselves remain enabled.
An intermediate test build was invalidated by a concurrent source edit; it was
rerun from the final sources rather than counting that attempt as a pass.

## Live observations

- Native app opened successfully with its app icon and system dark appearance.
- The user added Telegram, Zalo and Messenger through the real account flow.
- Zalo's official QR sign-in page rendered. A cancelled web navigation also
  produced legacy `WebKitErrorDomain` error 102; the initial app incorrectly
  covered the live page with a failure overlay. Fixed the classification and
  added regression tests. Genuine network and certificate errors stay visible.
- Messenger reached a Meta security-check page. The security check belongs to the
  provider and must be completed by the user; no bypass is implemented.
- Existing user-added account metadata and WebKit profiles are preserved across
  application rebuilds.
- Final Release app launched with all **4** user-added accounts retained. The
  Zalo QR sign-in page finished loading with no false failure overlay.
- Overview and account sidebar visually reviewed in system dark appearance.
  Improved selected-label and small-heading contrast for dark mode.
- Native service picker and custom-account editor opened successfully. Submitting
  an HTTP URL displayed validation and did not save an account; cancelling the
  editor left the user's account list intact.
- Switched away from the Debug app and launched the verified Release app with
  user approval. Later keyboard smoke actions were interrupted by the computer-use
  concurrent-user guard while the user interacted with the app; keyboard actions
  are implemented but are not counted as an independently completed smoke test.

## Authenticated daily-use matrix

These checks require sign-in and are **pending**, not inferred from a loaded page:

| Flow | Telegram | Zalo | Messenger |
| --- | --- | --- | --- |
| Sign-in/2FA fully completed | Pending | Passed — user confirmed chat list | Pending |
| Send/receive + Vietnamese IME | Pending | Pending | Pending |
| Paste image + upload/download file | Pending | Pending | Pending |
| Draft + scroll retained across account switches | Pending | Pending | Pending |
| Session retained after quit/relaunch | Pending | Passed on 0.2 UI relaunch | Pending |
| Reconnect after offline and sleep/wake | Pending | Pending | Pending |
| Multiple signed-in accounts | Pending | Pending | Pending |
| CPU/RAM/battery over a working day | Pending | Pending | Pending |

Profile isolation is implemented with one stable UUID-backed website data store
per account. Profile removal stops the session and clears all WebKit website data
using `removeData`, which supports a store still retained during a SwiftUI view
transition. No provider account is deleted.

WhatsApp, Discord and custom services are available in the service library but
have not been authenticated or certified here. Provider availability is distinct
from provider feature completeness.

## Explicit limitations

- No native notification forwarding, closed-app push, cross-service message index,
  unified inbox or synthesized unread badges.
- Voice/video calling and screen sharing depend on the provider's embedded-web
  support; they have not passed acceptance testing.
- External-browser fallback has separate browser cookies. It does not sign the
  embedded account in automatically.
- Empty WebKit profile directories may remain after an account is removed; all
  website data must be cleared through WebKit before removing account metadata.
- Local ad-hoc signing is for this Mac. Public distribution needs Developer ID,
  notarization and a signed update mechanism.

Daily-use readiness remains conditional on the authenticated checks above. The
current deliverable is a functional local implementation with automated core
verification, not a claim of completed provider certification.

## Zalo authentication follow-up

The user's subsequent failed sign-in exposed a second issue: a redirect to the
exact host `jr.zaloapp.com` was classified as external. The regression first
failed on that host, then passed after adding a provider-specific exact-host rule.
HTTP, other `zaloapp.com` hosts and use by other providers remain external.
See `BUG_ZALO_LOGIN.md` for the repro and scope of the fix.

The updated universal Release build passed with Swift warnings treated as errors;
the 26-test suite, strict formatting and code-signature verification also passed.
The updated app was launched with all four existing account slots retained.
The user scanned the refreshed QR, authorized sign-in on their phone and explicitly
confirmed **“Đã vào danh sách chat”**. The original sign-in failure no longer
reproduces in that authenticated flow. No conversations were opened or messages
sent by the agent as part of this check. File operations, sleep/wake and prolonged
daily use remain separate pending checks.

## ChatHub 0.2 UI/UX pass

The native unified window toolbar, compact account rail, expanded sidebar,
account switcher and optional Zalo appearance are implemented. Release builds
for arm64/x86_64, Swift warning-as-error compilation, 31 Swift tests, 6 JavaScript
tests, strict formatting, localization validation and code-signature verification
pass. The script tests cover lifecycle/DOM boundaries, not actual CSS rendering.

Live checks completed against the authenticated app:

- Zalo retained sign-in across the UI update and reached its chat list directly.
- Dark/light appearance matched ChatHub visually, including provider navigation,
  conversation list, text bubbles and composer. Icons retained their glyphs.
- The 72-point rail expanded to a named list; the native divider was dragged from
  208 to 286 points, then the sidebar collapsed back to 72 points.
- An existing composer draft remained visible during layout changes; the agent
  did not edit it or send a message.

The user interacted with the app concurrently; computer-use guards interrupted
some subsequent restore-width/account-switcher actions. A public-AppKit divider
restorer was added to respect saved width on expansion and a sheet-dismissal
handoff prevents overlapping account dialogs. These final source changes build
and pass tests. A final live relaunch/verification is pending the user's readiness
to avoid interrupting their draft.

The optional theme can be disabled in Settings or the Zalo account menu. It is
limited to the top-level chat application and falls back to the provider's
original appearance when the expected application shell is missing. It does not
turn the provider interface into native controls or add message access APIs.

## Update notifications — 0.3.0

- Universal Release (arm64 + x86_64): passed with Swift warnings treated as errors,
  using `/private/tmp/chathub-updates-validation` to avoid another active build's
  shared build database. A locked shared database was not counted as a pass.
- 46 Swift tests in 11 suites passed, including release parsing/selection,
  canonical installer URLs, stable-only updates, opt-out, skip/future versions,
  persisted scheduling and error backoff. No final Swift source warnings.
- 16 JavaScript tests and 3 release-validation script tests passed.
- Strict Swift lint, localization/plist validation, diff whitespace validation and
  the update-source secret-signature scan passed.
- The built 0.3.0 / build 3 metadata matched `project.yml` and tag `v0.3.0`;
  deep/strict code-signature verification passed.
- Real HTTPS smoke check using the shipped GitHub client, simulating installed
  version 0.1.0, detected the public stable 0.2.0 release and selected its exact
  version-pinned official DMG URL. It did not download/install that DMG or modify
  application preferences.
- The WebKit void-alert callback's actor annotation differs between SwiftPM's
  overlay and Xcode's explicit importer on this SDK. A build-mode type alias
  matches each imported requirement while invocation stays on the main actor.
- Native menu/notification visual inspection was interrupted by the concurrent
  user-action guard. The running app was not quit or replaced during this pass.
  Source integration and compiled UI are verified; a visible new-release banner
  in the user's session is not claimed as independently inspected.

The update feature only detects/releases notifications and opens a canonical
GitHub installer URL after a user action. Automatic installation/Sparkle are not
implemented. No release or tag was published by this task. People using a build
without the checker need one manual installation first. See `UPDATES.md`.
