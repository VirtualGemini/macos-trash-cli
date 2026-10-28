# 16 — Provide beta Homebrew source installation

Status: ready-for-human

## Request

The maintainer authorized completing the proposed Homebrew distribution work on 2026-10-28:
retain the beta release, publish an independent beta formula, correct source checksums in the
stable tap updater, and close the stale beta publication record.

## Acceptance criteria

- `VirtualGemini/homebrew-tap` contains `Formula/macos-trash-cli-beta.rb`, pinned to the
  `v0.1.0-beta.1` source tarball and its actual SHA-256. It builds only the production `tc` product.
- `brew install VirtualGemini/tap/macos-trash-cli-beta`, `brew audit --strict`, and `brew test`
  pass. Installed version and help are verified without any real Trash Operation.
- The stable updater hashes the source URL it writes to the formula, never a binary archive;
  updates URL, SHA-256, and an optional explicit version together; and leaves the formula unchanged
  on a source-download or template-validation failure. Publication remains successful if an optional
  tap update fails. Regression tests distinguish source and binary checksums.
- Beta release automation continues to skip stable tap updates. The beta formula is maintained
  separately; documentation explains the opt-in channel and Swift 6 build prerequisite.
- Issue 15 records the completed PR, signed tag, and prerelease. Stable v0.1.0 remains unpublished.
- Required repository checks and independent Standards and Spec reviews pass before the PR is ready.

## Scope

No CLI, Trash behavior, or Apple-signing policy changes. No new release tag is created.
Stable formula publication remains a future v0.1.0 action under issue 14.

## Evidence — 2026-10-28

- Published https://github.com/VirtualGemini/homebrew-tap at `5364618`, containing the beta
  source formula, installation/maintenance README, and Apache-2.0 license. A fresh public clone
  matches the locally audited formula.
- Source URL: `https://github.com/VirtualGemini/macos-trash-cli/archive/refs/tags/v0.1.0-beta.1.tar.gz`.
  SHA-256: `4d9e90cfb432516ba3ed4b0c31d2ab3981076a7c663bd98f64ed507e591aadb1`.
  The GitHub annotated tag is verified and resolves to `62ba5e2`.
- Source installation succeeded with Homebrew 6.0.21 and Apple Swift 6.3.3 from Command Line Tools.
  `brew audit --strict VirtualGemini/tap/macos-trash-cli-beta` and
  `brew test VirtualGemini/tap/macos-trash-cli-beta` passed. Version output is `tc 0.1.0-beta.1`.
- `make ci` passed: Debug/Release builds, lint and policy gates, 253 pure tests, 97.48% production
  line coverage. After review fixes, the release regression suite and ShellCheck passed again.
- The new regression initially failed against the old updater, exposing the stale explicit version
  and binary checksum. Current coverage includes inferred/explicit versions, download failure,
  duplicate fields, unquoted checksum, single-quoted/parenthesized version, staging/commit/push
  failures, and beta isolation even with a configured stable tap.
- Independent Standards and Spec reviews found malformed-template and staging-failure gaps plus
  inaccurate failure-state wording. All were corrected and independently rechecked; no findings remain.
- No real Trash API was called. Stable publication and its formula remain future work in issue 14.
- Repository changes require maintainer review through the preparation PR before merge.
