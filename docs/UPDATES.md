# Update notifications

ChatHub 0.3.0 checks the public GitHub Releases endpoint for
`huydq7-dev/ChatHub`. It checks shortly after launch when due, then every six
hours while the application is running. Closing the workspace window does not
quit the app. After a failed request it retries with a 30-minute backoff, without
interrupting chat. Users can disable background checks in Settings.

A newer stable release with a completed `ChatHub-macOS.dmg` or `.zip` asset shows
a native workspace banner. Actions offer Download Update, release notes, remind
later, or skip this version. Skipping one version does not hide later versions.
The ChatHub menu and Settings include Check for Updates; explicit checks ignore
skip preferences and report success/failure. Background checks never present
modal alerts or take focus.

The checker sends only a standard HTTPS request to GitHub with the installed app
version as its User-Agent. It does not access account profiles, conversations or
GitHub credentials. Download URLs are pinned to versioned installer assets under
the same repository. Drafts, prereleases, nonnumeric versions, external asset
URLs, unfinished assets and downgrades do not become update prompts.

## Installation boundary

This feature detects and announces updates. Download opens the official installer
in the user's browser. The user quits ChatHub and replaces the app in Applications.
It does not silently execute a download, overwrite the app, change signing policy
or remove any application data.

People who already installed 0.2.0 must install a release containing this checker
once manually. An installed binary cannot gain update detection from a Git push.
The public API requires a public repository/release and an internet connection;
rate limits and service outages are handled as failed checks, not as up-to-date.

Automatic installation would be a separate Sparkle integration with a persistent
Ed25519 signing identity, signed update feed/assets, appropriate sandbox helpers
and distribution signing verification. It is not enabled by this implementation.

## Publishing

1. Increase `MARKETING_VERSION` (stable `major.minor.patch`) and the build number
   in `project.yml` for each release, then run `xcodegen generate`.
2. Commit the source, generated Xcode project and workflow changes.
3. Push a matching tag, for example `v0.3.0` for the initial update-checker release.
4. The release workflow validates tag/version, runs tests, builds/packages and
   uploads both installers. Only a published stable release with uploaded assets
   will be offered to users.

The package script also checks the built app's actual version/build against
`project.yml`. This prevents a stale generated project from producing an installer
whose version differs from its release tag. Each new release gets a new tag;
do not overwrite old installers under an existing version.

## Validation

Core tests use a URLProtocol HTTP stub to verify release/version selection,
canonical asset URLs, prereleases, unfinished downloads and server errors.
Presentation tests verify opt-out, skip/future-version behavior, persisted timing
and retry backoff. Script tests verify tag/version/build consistency.
A successful check against the current public release does not certify a future
installer or automatic installation; this feature performs no installation.
