# ChatHub 0.2 — native appearance and navigation

## Navigation

The account sidebar now defaults to a 72-point icon rail. The native window
toolbar expands it to a resizable account list (208–320 points). Both the expanded
state and width persist. Collapsing does not discard the last expanded width.
Compact rows retain accessible account names, tooltips and selection markers;
account errors are distinct from unread badges. Pointer targets are at least
44 points high. Motion respects the macOS Reduce Motion preference.

The unified native toolbar replaces the old web-style back/forward/reload row.
Browser navigation, reload and account actions live in an overflow menu. The
always-visible host/status footer is removed; offline and failure feedback stays.
⌃⌘S toggles the sidebar; ⌘K opens a searchable account switcher. Existing ⌘0–9
shortcuts remain. The overview prioritizes existing accounts rather than repeating
the onboarding hero and full service catalog on every visit.

## Zalo appearance

The bundled stylesheet maps Zalo's public semantic color tokens to ChatHub's
light/dark surfaces, text, borders and selected states. The blue Zalo navigation
strip becomes neutral. Typography inherits the system font while the provider's
icon fonts are preserved. Text bubbles and conversation rows receive restrained
corner rounding without changing virtualized row heights. Text bubbles no longer
have outlines. The composer uses a single rounded surface with no input border,
box shadow or text-editor focus rectangle. Search and buttons keep keyboard focus
indicators; the editor keeps its insertion caret.

The layer runs only on the top-level HTTPS `chat.zalo.me/` application, in WebKit's
isolated client world. Sign-in pages, `jr.zaloapp.com`, the trusted-device bridge,
subframes and other providers do not receive it. It checks the provider shell
before applying, observes initial app hydration only and then disconnects. It
does not read messages, fetch remote styles, replace editor controls or change provider
preferences. An unsupported shell retains its original appearance.

Settings and the Zalo account menu expose **Match macOS Appearance**. Toggling
this removes/restores only ChatHub's stylesheet and attributes without reloading
the web view. Changing ChatHub's appearance updates loaded sessions and subsequent
navigations. The original service theme remains available as a fallback.

## Focused chat layout

Focused layout is the default when ChatHub appearance is enabled. ChatHub's native
window toolbar now leads with the ChatHub mark/name, with the account name as
secondary context. The redundant 64-pixel provider rail is hidden and the
conversation pane uses the provider's own width variable to avoid an empty gutter.
Compact provider layouts also account for the hidden rail.

**Show extra service tools** on the native toolbar restores the service rail and
full chat toolbar immediately, without navigation or replacement of controls.
The preference is also available in Settings and persists. Appearance matching
can independently restore the entire original service interface.

Focused mode hides only named screenshot, contact-sharing, formatting, importance,
task and reminder toolbar buttons, identified in the public component bundle.
Photo/file/sticker and More controls remain. Unknown controls remain visible.
Emoji/send, replies, upload state, rich-text editing, search, unread filters and
conversation information are preserved. Existing conversation contents and
avatars, including official service accounts, remain authentic.

This is a scoped presentation layer over the official web application. It is not
a native message renderer or a supported Zalo messaging API. Provider markup
changes require rechecking layout; authentication pages are excluded.

## Verification

- Swift tests cover theme origin boundaries and sidebar preference durability.
- Seven Node tests execute the shipped JavaScript against a minimal DOM seam:
  live appearance changes, disable/re-enable, asynchronous hydration, observer
  teardown, auth/bridge exclusions, unsupported layouts and reversible tool visibility.
- UI and CSS rendering still require live inspection; the JavaScript tests do
  not stand in for browser rendering or authenticated messaging acceptance.

Actual build and live check results are recorded in `VERIFICATION.md`.
