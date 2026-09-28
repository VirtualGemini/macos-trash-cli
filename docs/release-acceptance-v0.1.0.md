# v0.1.0 Release Acceptance Record

Stable v0.1.0 status: release candidate; stable publication is blocked on a GitHub-verified signed tag, CODEOWNER approval, and the owned Homebrew tap step below. External-volume observations are non-blocking compatibility evidence. No Apple signing or notarization is required (ADR-0004).

The first publication candidate is now `v0.1.0-beta.1`, tracked in
[issue 15](../.scratch/macos-trash-cli/issues/15-prepare-v0-1-0-beta-1.md).
The dated results below remain historical v0.1 acceptance evidence. The beta uses its own matching
CLI version, changelog entry, and [release notes](releases/v0.1.0-beta.1.md), and must pass current
automated gates before publication. The Homebrew formula is a stable-release owner action;
beta publication skips the tap. GitHub tag verification and the protected release workflow still apply.

This record is the auditable evidence index for issue 11. It distinguishes repository evidence from
actions that require a protected GitHub environment or a maintainer's Finder session. Paths and home
directories in retained logs are normalized to `REPO_ROOT`, `TEST_CONTAINER`, and `HOME_TRASH`.

## Automated evidence

| Requirement | Evidence | Boundary |
| --- | --- | --- |
| System Trash only, no permanent-delete fallback | `make check-system-trash-boundary`; `Tests/TrashPlatformTests/*`; `Tests/TrashCoreTests/*` | Pure spies and static policy; no real Trash call |
| Compatibility, Protected Path, root, symlink, dry-run, batch, JSON, identity, mount, volume, and File Provider rejection matrices | `make test`; `make test-policy`; `Tests/TrashPlatformTests/TestSafetyFailureMatrixTests.swift`; `Tests/TrashCoreTests/*` | Fake filesystem and zero-call Trash spies |
| Compile-time-isolated serial integration | [`integration.log`](manual-testing/results/tc-test-product-identity-acceptance-20260818/integration.log) | `tc-test build=TC_TESTING`; no Trash capability requested |
| Ordered real-filesystem acceptance | [`ordered-batch.log`](manual-testing/results/tc-test-product-identity-acceptance-20260818/ordered-batch.log) | Authorized Run Directory; Finder receipts retained; no recursive cleanup |
| Same-name Finder receipts | [`duplicate-trash-name.log`](manual-testing/results/tc-test-product-identity-acceptance-20260818/duplicate-trash-name.log) | Two exact source generations; distinct system URLs |
| Debug and Release target builds | `make build`; `make build-release`; product-identity report metadata | All package targets; no real Trash API |
| Release architecture artifact | [`report.md`](manual-testing/results/tc-v0-1-release-architecture-20260819/report.md) | `scripts/build-universal-release.sh`; arm64+x86_64, macOS 13.0 minimum |
| Release pipeline contract | `make test-policy` runs `Tests/PolicyTests/run-release-tests.sh` | Unsigned zip+tar.gz with sha256 and GitHub tag verification are boundary doubles; no Apple signing |

The release job invokes `make ci` before producing an artifact. `run-release.sh` then requires a clean
GitHub-verified signed tag, a dated changelog heading, and a non-existing GitHub Release. It builds the
universal binary, validates `tc --version`, produces unsigned `zip` and `tar.gz` archives with relocatable
`sha256` files, and uploads all four assets with `gh release create --verify-tag`. No `codesign`,
`notarytool`, or `spctl` step is executed.

## Finder recovery evidence

The dedicated local-volume acceptance was completed on 2026-08-18. The complete normalized transcript
is [`put-back-race-manual.log`](manual-testing/results/tc-test-product-identity-acceptance-20260818/put-back-race-manual.log).
The maintainer performed Finder Put Back on the first item; the same process immediately re-trashed it,
and Finder showed Put Back for the exact second system-returned URL immediately after completion. This
proves the tested local-volume case only; it does not claim universal recovery.

The production symbolic-link Finalizer case is recorded in
[`put-back-symlink-production-manual.log`](manual-testing/results/tc-test-product-identity-acceptance-20260818/put-back-symlink-production-manual.log).
The maintainer performed the Finder control Put Back, the production path reported
`foundation-finalizer=production-cleaned` and `trash-warning=none`, and Finder showed Put Back for the
final exact target immediately after completion.

## Volume compatibility matrix

| Volume / provider | Observation | Release interpretation | Owner / next evidence |
| --- | --- | --- | --- |
| Local macOS volume | Finder receipts and Put Back observed; ordered batch and Finalizer passed | Supported for the tested local case | Maintainer evidence above |
| External volume | Not exercised by the authorized Test Safety Context; behavior is volume-specific | Compatibility observation, not a universal support claim | @VirtualGemini: run a synthetic fixture on each target volume |
| Network volume | Not exercised; network locations are rejected by local integration policy | Compatibility observation, not a release blocker for local volumes | @VirtualGemini: record Finder result and exact receipt if separately approved |
| iCloud / File Provider | Not exercised; File Provider special roots are rejected before any Trash API call | Compatibility observation, not a universal support claim | @VirtualGemini: record provider and OS version if separately approved |

## Owned release blockers

1. The protected `release` environment needs only `GH_TOKEN` for `gh release create`. No Apple
   Developer Program membership or `APPLE_*` secrets are required.
2. A maintainer with the release CODEOWNER must approve the workflow and run the `v0.1.0` tag.
   The job fails closed when the tag is not GitHub-verified or the release already exists.
3. The maintained Homebrew tap `VirtualGemini/homebrew-tap` publishes the source-build formula;
   `run-release.sh` auto-pushes the bump when `HOMEBREW_TAP_DIR` is configured, otherwise it prints
   the `sha256` values for manual bump. A v0.1.0 bottle is intentionally not promised.
4. External-volume observations remain maintainer-owned compatibility evidence and must not be rewritten
   as universal support claims.

No real Trash API call is made by the release script or its policy test. The retained integration and
Finder evidence above are the only real Trash operations referenced by this record.
