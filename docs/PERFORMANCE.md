# Chat responsiveness

This patch targets scrolling, typing and window switching, including the report
that opening particular Messenger conversations stalls while others work normally.
Baseline: `5581fa2`, including the independently authored Telegram overlay-scroll fix.

## Changes

- Repeated SwiftUI updates of the same web host no longer take keyboard focus or
  invalidate its layout. Real account switches and window attachment still focus it.
- Background web sessions stay attached and connected, at their previous viewport
  size. Only the visible session receives live resize updates; switching catches up
  its frame before showing it.
- Native focus/appearance changes do not cross into JavaScript when unchanged.
  Navigation still restores focus at document start, commit and finish. Appearance
  bootstrap is cached per session and regenerated when settings change.
- Messenger activation no longer moves every matching scroller by one pixel or
  synthesizes scroll/resize events. Native display/layout invalidation remains.
- Window chrome configuration is idempotent and no longer forces synchronous
  layout of all windows whenever one window becomes key/main.

The patch does not suspend background sessions, remove provider editors, alter
message content, or change notification click routing.

## Before/after evidence

Real AppKit/WebKit tests use synthetic HTML, not accounts or message contents.
The counters below measure removed redundant work; **they are not FPS, input
latency or a guarantee that a particular provider conversation is fixed**.

| Workload | Before | After |
| --- | ---: | ---: |
| Focus requests during 100 same-session host updates | 100 | 0 |
| Background viewport changes during 100 host resizes | 100 | 0 |
| Forced layouts during 100 unchanged window configurations | 100 | 0 |
| Synthetic events from one Messenger activation with 100 scrollable nodes | 101 | 0 |
| JavaScript calls during 100 unchanged native focus updates | 100 | 0 |
| JavaScript calls during 100 unchanged appearance updates | 100 | 0 |

Machine-readable baseline/comparison: `.ecc/benchmarks/chat-responsiveness.json`.
Run `swift test --enable-code-coverage --filter ResponsivenessTests` to reproduce.

## TDD and review evidence

- RED `d5c8146`: five tests failed six expectations with the baseline counters above.
- GREEN `5577ed7`: the same five tests passed, all six counters zero.
- Review identified a focus lifecycle edge when the host was shown before it had a
  window. RED `926352f` reproduced failed focus on first attachment and reattachment.
- GREEN `691cdb2`: focus is assigned on actual window attachment; all six
  responsiveness tests pass and repeated updates remain no-ops.

The full suite also retains WebKit theme rendering, navigation-focus restoration,
and notification click tests from 0.3.1. No assertion or delivery gate was skipped.

Final verification: 54 Swift tests, 25 JavaScript tests, and three release tests
passed. Release built for arm64/x86_64 with Swift warnings treated as errors;
strict formatting, version validation and code-signature verification passed.
Coverage collection reports 100% of `WorkspaceWindowStyle`, 65.38% of
`ServiceWebView` and 17.68% of the whole binary, including largely unautomated UI.
This is not a claim of 80% whole-app coverage or of live provider verification.

## Live verification

After installing the Release build, reopen both an affected and an unaffected
Messenger conversation. Check opening, scrolling, Vietnamese IME composition,
switching windows and returning, then switching accounts and resizing the sidebar.
Drafts/caret and scroll position should remain stable; there should be no blank
Messenger pane. Background notifications need an independent live check.

The isolated fixture cannot reproduce all provider work, such as encrypted history
loading, media decoding or account-specific DOM. If an affected conversation still
lags, profile that exact interaction and compare against the original app/theme
without assuming the remaining cost comes from this bridge.
