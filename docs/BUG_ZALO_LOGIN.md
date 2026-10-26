# Zalo QR sign-in blocked by navigation policy

## Reproduction and signal

The running Release app remained on `id.zalo.me` after QR scanning. Its native
banner displayed “This service needs to open another website to continue” and
the pending destination's host was **jr.zaloapp.com**. No session URL, token,
cookie, QR code or personal identifier is retained in this report.

The account policy accepted `zalo.me` and `zalo.vn` but classified the next host
as an external website. Continuing in an external browser would switch cookie
stores and break the intended single-profile sign-in flow.

Regression command:

```sh
swift test --filter ZaloAuthenticationTests
```

Before the fix, the actual policy used by WKNavigationDelegate reported:

```text
authenticationChainStaysInTheSameAccountProfile:
Expectation failed: (policy.disposition(for: url) → .externalBrowser) == .inApp
Authentication host must stay in profile: jr.zaloapp.com
3 tests, 1 issue
```

This test locks down the reproduced navigation-policy failure. It does not claim
to complete QR authorization, which requires the user and their phone.

## Ranked causes and change

1. **Blocked authentication redirect** — directly observed in the native banner
   and reproduced in the real policy. Fixed by accepting only the exact HTTPS
   `jr.zaloapp.com` host for Zalo accounts.
2. **Cookie continuity** — a follow-up possibility if sign-in still fails after
   the redirect is accepted. No cookie-policy change has been made speculatively.
3. **Embedded-browser compatibility** — a follow-up possibility if the provider
   rejects WebKit after authorization. No browser impersonation or security
   exceptions have been added.

Other `zaloapp.com` hosts, nested/lookalike hosts, HTTP URLs and use of this host
by other providers remain external. HTTPS credential-in-URL checks remain intact.
Cancelled navigations also restore the already-loaded page status so a blocked
redirect does not leave a completed progress bar spinning indefinitely.

## Verification

The regression suite covers the observed chain, host boundaries and provider
isolation. All **26 tests** passed; the universal Release build, strict formatting
and code-signature checks passed. After restarting with the existing profiles and
refreshing the QR, the user completed phone authorization and confirmed reaching
the chat list. The original authenticated reproduction is therefore verified
resolved. Final evidence is also recorded in `VERIFICATION.md`.
