# v0.1.0 Release Acceptance Record

Status: release candidate; publication is blocked on maintainer credentials, CODEOWNER approval, and the owned Homebrew tap step below. External-volume observations are non-blocking compatibility evidence.

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
| Release pipeline contract | `make test-policy` runs `Tests/PolicyTests/run-release-tests.sh` | External signing, notarization, and GitHub tools are boundary doubles |

The release job invokes `make ci` before producing an artifact. `run-release.sh` then requires a clean
cryptographically signed tag, a dated changelog heading, protected Developer ID and App Store Connect
credentials, and a non-existing GitHub Release. It signs with the hardened runtime, notarizes the
archive with `xcrun notarytool`, records the submission and log JSON, runs `spctl`, writes a relocatable
SHA-256 file, and uploads all four evidence assets with `gh release create --verify-tag`. Any issue in
the notarization log, including a warning, prevents publication.

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

1. A maintainer must populate the protected `release` environment with `APPLE_SIGNING_IDENTITY`, the
   Developer ID Application `.p12` and password, and the App Store Connect API key/ID/issuer; no agent
   or pull request should receive these secrets. GitHub supplies the job-scoped `GITHUB_TOKEN`.
2. A maintainer with the release CODEOWNER must approve the workflow and run the signed `v0.1.0` tag.
   The job fails closed when the tag is unsigned, the release already exists, or any notarization step
   is not accepted.
3. The maintained Homebrew tap must publish the source-build formula after the GitHub archive checksum
   exists. A v0.1.0 bottle is intentionally not promised.
4. External-volume observations remain maintainer-owned compatibility evidence and must not be rewritten
   as universal support claims.

No real Trash API call is made by the release script or its policy test. The retained integration and
Finder evidence above are the only real Trash operations referenced by this record.
