# 15 — Prepare v0.1.0-beta.1 publication

Status: ready-for-human

## Request

The maintainer confirmed that the first publication must be a beta, then asked to continue the
release preparation. Use the existing numbered-beta contract, `v0.1.0-beta.1`.

## Acceptance criteria

- The CLI reports `tc 0.1.0-beta.1`, with the existing information-command test proving its exact
  output and absence of filesystem inspection.
- CHANGELOG has a dated `[0.1.0-beta.1]` entry and matching release notes exist at
  `docs/releases/v0.1.0-beta.1.md`; documentation does not claim stable v0.1.0 was published.
- Installation documentation uses beta source/archive paths and explains that beta publication
  does not update the stable Homebrew tap.
- Existing beta pipeline policy checks, Debug and Release builds, pure tests, coverage, lint,
  and universal architecture/version validation pass.
- Standards and Spec reviews account for every changed file. Commits pass the repository's
  commit-range checks before a push or PR.
- Publication uses a GitHub-verified signed tag on the reviewed main-branch commit and the protected
  release workflow. Repository preparation and actual publication are recorded separately.

## Scope

Update release identity and documentation. Preserve the existing Trash behavior, CLI options,
JSON schema, unsigned distribution policy, and stable-only Homebrew publication.

## Evidence

- 2026-09-28: local and remote main both point to `f2ec28d9c14498b09dc93a8ef538a2a724f74503`;
  its GitHub CI run `33867179274` succeeded. No remote tags or GitHub Releases exist.
- The authenticated GitHub identity is `VirtualGemini`. The repository variables endpoint and
  `release` environment endpoint returned HTTP 404; release configuration remains unverified.
- GPG signing was successfully tested and the temporary tag deleted by the maintainer in the
  preceding session. No release tag has been created during this preparation.

## Repository validation — 2026-09-28

- `make ci` passed: Debug and Release target builds, formatting, SwiftLint, ShellCheck, actionlint,
  SPDX, safety boundary checks, all policy suites (including the beta release contract), and
  253 pure tests in 20 suites. Production line coverage remains 97.48%.
- `make build-release-universal` passed with an explicit beta output path. The retained executable
  is `.build/release-preparation/v0.1.0-beta.1/tc`; `lipo -archs` reports `x86_64 arm64`,
  `xcrun vtool -show-build` reports `minos 13.0` for both slices, and `--version` reports
  exactly `tc 0.1.0-beta.1`.
- `make test-integration` passed with run UUID `0c8dd2e8-4851-428a-b14f-40eb78d4cc37`.
  It exercised the guarded empty Run Directory only. No real Trash API was called.
- Independent Standards and Spec agent reviews covered all 12 changed/new files. The primary
  review confirmed the findings and clarified that the historical Homebrew blocker applies to
  stable v0.1.0. No unresolved implementation findings remain.

## Remaining publication steps

1. Validate the preparation commit and full branch range, then open the preparation PR.
2. Obtain maintainer review, merge the PR, and require passing main-branch CI.
3. Verify `RELEASE_ENABLED=true` and the protected `release` environment configuration with
   repository administration access. HTTP 404 responses do not establish whether they exist.
4. Create and verify the signed `v0.1.0-beta.1` tag at the reviewed main-branch commit, push that
   tag, and approve the protected release deployment. Confirm GitHub marks the tag as verified
   and publishes a prerelease with all four archive/checksum assets.

Repository preparation is validated; actual publication remains pending. The beta does not require
the stable Homebrew formula to be published.
