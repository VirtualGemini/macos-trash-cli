# Adopt source distribution with unsigned binaries and drop Apple signing

The project permanently removes Apple Developer ID signing, notarization, and `spctl` assessment from the v0.1.0 release pipeline. Paying for the Apple Developer Program is not justified for this open-source CLI. The primary distribution becomes Source Distribution built locally via Swift Package Manager and Homebrew Tap source build in `VirtualGemini/homebrew-tap`. Optional Unsigned Binary Archives (`zip` + `tar.gz` with `sha256`) are published to GitHub Releases for convenience, without any Apple credential (`APPLE_SIGNING_IDENTITY`, `APPLE_NOTARY_KEY_PATH`, etc.), `codesign`, `notarytool`, or `spctl` step. Git tag `verification.verified` remains required to prevent tag tampering. `Package.swift` no longer declares a SwiftLint package dependency so isolated Homebrew builds do not fetch development tooling.

## Considered Options

- Keep signed/notarized universal archive: best Gatekeeper UX, requires $99/year membership and protected secrets.
- Source-only with no binaries: zero credentials, but forces every user to have Swift 6 toolchain.
- Adopted: source primary + unsigned binaries as convenience: no paid membership, both `brew install` and direct download work, Gatekeeper warning documented as Recovery Limitation trade-off.

## Consequences

- `scripts/run-release.sh` no longer requires `APPLE_*`/`GH_TOKEN` beyond `GH_TOKEN`, no `codesign`/`notarytool`/`spctl`/`plutil` notarization log, and produces both archives.
- Homebrew formula is source-build only; no bottle promised for v0.1.0. Tap is updated automatically when `HOMEBREW_TAP_DIR` is configured.
- Documentation and `CONTEXT.md` Distribution Language reflect unsigned semantics; issue 11 is kept as historical acceptance with a decision appendix, issue 14 carries the new distribution work.
