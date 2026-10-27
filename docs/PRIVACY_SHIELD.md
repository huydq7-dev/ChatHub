# Privacy Shield verification — 2026-10-27

## Behavior and implementation

Telegram Web A/K, Messenger and Zalo share one masking mechanism. Each service
supplies explicit sensitive surfaces and local hover boundaries. The stylesheet
is generated from that same target list. Descendant targets are excluded from
masking when a sensitive ancestor already masks them; this avoids cumulative
blur without overriding filters on every child. Identified avatars are clipped
separately from message attachments. Messenger SVG images retain their native
masks; message media is never rounded merely because it is inside a grid. Opacity and message image shapes stay intact.

Hover reveals one row, message or sensitive surface. Enclosing lists are rejected;
nested contact links reveal through their containing sensitive surface. Scrolling,
leaving the page, visibility changes, account switches and workspace deactivation
clear the reveal. Re-enabling the shield clears stale reveals too.

Native workspace focus is explicitly synchronized into WebKit's isolated client
world. Web document blur clears the current reveal but does not disable hover when
a native toolbar owns keyboard focus. Initial focus is included in scripts for
future documents, so background accounts cannot reveal through pointer events.

Privacy works when appearance matching is disabled. Theme attributes are removed
in this mode, preserving the original provider interface. Messenger palette
containers are not treated as messages: those containers can include the toolbar,
composer and whole conversation. No provider content is read or transmitted by
the appearance bridge, and no long-lived message mutation scanner is introduced.

## Automated evidence

- `swift test --enable-code-coverage`: **109 tests across 21 suites passed**.
- `node --test scripts/test-web.mjs scripts/test-notifications.mjs`:
  **34 tests passed**.
- `bash scripts/build.sh Release`: passed; strict app signature verification passed.
- Full repository `swift-format lint --strict`: passed.
- Both localization files passed `plutil -lint`; JS syntax and diff whitespace
  checks passed.

Regression tests exercise the shipped script/CSS in real WKWebView using synthetic
HTML. They cover one effective blur layer, controls and drafts staying clear,
media shape, local peeking, nested groups, list boundaries, context changes,
independence from theme and native focus. A BrowserSession integration test checks
focus updates and new-document focus injection in the isolated world using its
own temporary profile. It clears that profile's data and tears down its session.

The first focused regression run recorded 42 failed assertions before the fix.
Additional tests reproduced nested group/list failures and Messenger palette
container failures before their corresponding fixes. Older tests now check the
rendered ancestor blur rather than requiring multiple nested blur layers.

Test markup is a reproducible compatibility seam, not a certification of all live
provider layouts. Swift code coverage does not measure injected JavaScript or
prove complete provider coverage.

## Live observations

- Resumed authenticated UI checks after macOS was unlocked.
- Telegram sidebar hover was observed revealing one row while neighbors remained masked.
- Confirmed Zalo avatar variants are masked on the real sidebar and chat header;
  a hovered Zalo row reveals its identity without revealing neighboring rows.
- Confirmed Messenger header names and stickers/media are masked while call buttons,
  search, toolbar and composer remain usable. Found and added regressions for reply
  previews without `dir=auto`, readonly content, palette containers and media variants.
- Verified light appearance and the provider's original dark interface with
  **Match macOS Appearance** disabled; privacy remained active. Restored the user's
  original Dark/Rose appearance and appearance matching after testing.
- Completed final independent code review of cell boundaries, editor exclusions,
  native focus and avatar/media shape. No remaining review blocker was identified.
- The optional Web Inspector hung the computer-use accessibility reader. Closed its
  separate process through Activity Monitor and removed the temporary developer
  preference before the final Release build. No debug instrumentation remains.

Live observations cover sampled existing chats, not every provider feature or
markup variant. Automated isolated-world focus tests cover deactivation,
reactivation and navigation in addition to the sampled UI checks. No messages
were sent, edited or deleted for these checks.

Run only one ChatHub copy while testing: concurrent provider sessions can trigger
provider device-change notices. The local build is
`build/Build/Products/Release/ChatHub.app`; the installed Applications copy is not
replaced by the build script.

## Zalo circular-background follow-up

The user reported a large circle behind Zalo messages. Live comparison confirmed
it disappears when Privacy Shield is disabled. The avatar substring selector
`[class*="avatar"]` can also select layout state classes on the whole message
stream, applying a circular clip and blur to that large background. Hover could
then reveal neighboring messages through the same outer surface.

Replaced that substring selector with a shared explicit list of avatar component
classes. Substring matching remains only on `img` elements, which cannot be the
message-stream container. Existing Zalo image and initial-avatar tests still pass.
The new WebKit regression first reproduced three failures: circular clipping,
stream-level blur and revealing neighboring messages; all pass after the fix.

Release build/signature, 109 Swift tests, 34 Node tests, Swift formatting and JS
syntax checks passed. After the user finished with the add-account form, live verification of the
rebuilt Zalo chat confirmed the large circle is gone while Privacy Shield is
enabled; message content and avatars remain masked. No form was submitted or
cancelled by the agent.

## Scope

This feature obscures pixels for shoulder-surfing privacy. It does not redact the
provider DOM or accessibility tree and does not replace the app lock. WhatsApp,
Discord and custom services currently have no privacy adapters. Updates to a
provider's markup can require selector updates.
