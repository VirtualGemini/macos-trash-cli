# 11 — Complete v0.1.0 release acceptance

**What to build:** Turn the implemented command into an auditable v0.1.0 release candidate by completing the specified safety matrix, Finder recovery check, documentation alignment, architecture builds, and distribution decisions.

**Blocked by:** 04 — Provide the complete compatible command-line interface; 06 — Encapsulate the whitelisted system Trash capability; 07 — Move one Trash Input safely through the system Trash; 08 — Execute deterministic confirmation policy; 09 — Process an ordered batch Trash Operation; 10 — Emit stable JSON Trash Operation results.

**Status:** resolved

- [x] Automated acceptance demonstrates that every successful move passes through the system Trash API and that no production or test path provides permanent-delete fallback or direct Trash-directory manipulation.
- [x] The compatibility, Protected Path, root, symlink, dry-run, batch, JSON, test-envelope, identity-change, mount, volume, and File Provider rejection matrices pass with rejected cases proving zero Trash calls.
- [x] Local integration tests use only compile-time-isolated test artifacts and authorized run fixtures, execute serially, never recursively clean, and leave any non-empty Run Directory intact for inspection.
- [x] A human verifies the exact system-returned URL for a dedicated local-volume fixture in Finder and records whether “Put Back” restores it, without claiming universal restore capability.
- [x] External volume, network volume, and File Provider observations are recorded as a compatibility matrix rather than treated as universally supported behavior.
- [x] Primary help, compatibility help, README, security guidance, changelog, and release notes agree on Trash-only semantics, ignored options, warnings, unsupported operations, disk-space implications, and recovery limitations.
- [x] Debug and release builds cover all targets, and release artifacts are validated for both Apple Silicon and Intel architectures.
- [x] The minimum macOS target and initial Homebrew source-build or prebuilt-bottle strategy are explicitly decided and documented.
- [x] Signing, notarization, GitHub Release, and Homebrew steps either succeed with maintainer credentials or are captured as clearly owned release blockers.
- [x] The final two-axis review passes against repository standards and the v0.1.0 specification before the release commit is created.

## Implementation evidence — 2026-08-19

- `make ci` passed: formatting, SwiftLint, ShellCheck, actionlint, SPDX, dangerous-command, toolchain,
  system Trash boundary, policy ownership, Debug and Release builds, 253 pure tests, 97.48% production
  line coverage, and all policy tests.
- `make build-release-universal` passed with a real Mach-O universal `tc` containing `x86_64` and `arm64`;
  both slices report `minos 13.0`, and `tc --version` reports `tc 0.1.0`. Evidence:
  `docs/manual-testing/results/tc-v0-1-release-architecture-20260819/report.md`.
- The release pipeline is implemented and tested at the public shell boundary with doubles for
  universal binary, GitHub tag verification, GitHub Release, and checksum tools. It fails closed
  before `make ci` for an unverified tag. No Apple signing/notarization is required per ADR-0004.
- Existing 2026-08-18 Finder evidence covers local-volume Put Back, ordered batch, duplicate Trash names,
  and the production symbolic-link Finalizer. External, network, and File Provider rows remain
  compatibility observations owned by the maintainer.
- Remaining human actions were recorded in `docs/release-acceptance-v0.1.0.md` and have been updated
  for the unsigned source distribution (ADR-0004).
- Standards review: the staged diff was reviewed against repository standards; three findings were
  corrected before this acceptance was marked complete. Spec review: the 10 acceptance rows and PRD
  sections 17.3-17.5, 19, 21, 23, and 24 were independently traced; no missing or out-of-scope
  implementation remains. The delegated Spec review agent was unavailable due to a service parameter
  error, so this result is the primary-agent review evidence.

## Decisions — 2026-08-24 (grill-with-docs)

Permanent distribution decision (ADR-0004): the project will never require Apple Developer Program
membership, Developer ID signing, or notarization. The v0.1.0 release acceptance above is retained as
historical evidence. The actual v0.1.0 publication now follows:

- Source Distribution (primary) + Unsigned Binary Archives (`zip` + `tar.gz` with `sha256`) on GitHub Releases
- Homebrew Tap source build in `VirtualGemini/homebrew-tap` (`brew install VirtualGemini/tap/macos-trash-cli`)
- `Package.swift` no longer declares a SwiftLint package dependency; `scripts/run-swiftlint.sh` prefers a `brew`-installed `swiftlint`
- `scripts/run-release.sh` no longer requires `APPLE_*` or invokes `codesign`/`notarytool`/`spctl`; it uploads both archives and optionally auto-pushes the Tap bump when `HOMEBREW_TAP_DIR` is set
- Git tag `verification.verified` remains required

Follow-up work is tracked in issue 14.
