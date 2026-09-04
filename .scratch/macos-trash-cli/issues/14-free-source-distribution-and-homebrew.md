# 14 — Ship v0.1.0 as source distribution with Homebrew Tap and unsigned binaries

**What to build:** Replace the signed/notarized release path with the free distribution strategy decided in ADR-0004: source-built Homebrew Tap plus optional unsigned universal archives.

**Blocked by:** 11 — Complete v0.1.0 release acceptance

**Status:** ready-for-human

- [x] `Package.swift` contains no SwiftLint package dependency; `make lint` works with a `brew`-installed `swiftlint` and the fallback artifact path.
- [x] `scripts/run-release.sh` requires only `GH_TOKEN`, validates a GitHub-verified annotated tag, runs `make ci`, builds the universal binary, and publishes unsigned `macos-trash-cli-vX.Y.Z-macos-universal.zip` + `.sha256` and `macos-trash-cli-vX.Y.Z-macos-universal.tar.gz` + `.sha256` via `gh release create --verify-tag`; no `codesign`/`notarytool`/`spctl`/`plutil` notarization is invoked.
- [x] `scripts/run-release.sh` auto-bumps `VirtualGemini/homebrew-tap` when `HOMEBREW_TAP_DIR` points to a clean clone, otherwise prints `sha256` values and the manual bump command; failure to push the tap never rolls back the GitHub Release.
- [x] `Tests/PolicyTests/run-release-tests.sh` asserts the unsigned double-archive contract, the tag-verified gate, and the absence of Apple tooling; `make test-policy` passes.
- [x] `README.md` Installation and release, `docs/release-acceptance-v0.1.0.md`, and `CHANGELOG.md` describe the source distribution primary path, the Homebrew Tap install (`brew install VirtualGemini/tap/macos-trash-cli`), and the unsigned binary Gatekeeper caveat.
- [ ] A Homebrew Formula for the source build exists in the tap (`Formula/macos-trash-cli.rb`), installs via `swift build --product tc`, and passes `brew audit --strict` and `brew test` against the tagged tarball.
- [x] `CONTEXT.md` Distribution Language and ADR-0004 record the permanent removal of Apple signing.

## Implementation evidence — 2026-09-03 (continuation)

- Repo-side distribution work is complete on `feat/11-v0-1-release-acceptance`:
  `Package.swift` declares `dependencies: []`; `scripts/run-swiftlint.sh` prefers
  `brew`-installed `swiftlint` with the legacy `.build/artifacts/swiftlint` fallback;
  `scripts/check-tool-versions.sh` rejects any `SwiftLint.git` manifest entry and pins the
  documented `SwiftLint 0.65.0` Homebrew version against `.tool-versions.lock`;
  `Tests/PolicyTests/check-tool-versions-tests.sh` covers both the dependency-absence and the
  documentation-version-drift rejections.
- `docs/development.md` toolchain, lint-wrapper, bootstrap, and dependency-policy sections
  describe the Homebrew SwiftLint flow and the zero-dependency package (ADR-0004).
- `scripts/run-release.sh` publishes only the unsigned `zip` + `tar.gz` archives with relocatable
  `sha256` files via `gh release create --verify-tag` after `make ci` and the GitHub-verified
  annotated-tag gate; tap commit/push failures after publication degrade to warnings and never
  roll back the release.
- `CHANGELOG.md` `[0.1.0]` records the unsigned archives, the
  `brew install VirtualGemini/tap/macos-trash-cli` primary path, and the Gatekeeper caveat.
- `make test-policy` constituent suites pass: doc-impact, policy-ownership, policy-changes,
  breaking-change, evidence-path, integration-runner, release, tool-versions, swift-toolchain,
  system-trash-boundary; ShellCheck is clean on all touched scripts.
- Remaining human-owned work: create `Formula/macos-trash-cli.rb` in
  `VirtualGemini/homebrew-tap` (source build via `swift build --product tc`), run
  `brew audit --strict` and `brew test` against the tagged tarball, and on a healthy toolchain
  run `make bootstrap` to regenerate the now pin-less `Package.resolved` (stale SwiftLint pins
  are still committed because the sandbox SwiftPM cannot rewrite the resolution file).
