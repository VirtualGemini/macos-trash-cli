# Security Policy

## Supported versions

Before tc 1.0, security fixes are provided for the latest released minor version only. After 1.0,
the supported-version policy will be stated here for each release line.

## Reporting a vulnerability

Do not open a public issue for a suspected vulnerability involving permanent data loss, protected
path bypasses, test-whitelist escapes, unsafe Trash cleanup, privilege handling, code signing, or
release-secret exposure.

Use the repository Security tab and its private vulnerability-reporting flow. If private reporting
is unavailable, contact the maintainer privately through the repository owner profile before public
disclosure.

Include:

- affected version or commit;
- reproduction conditions;
- paths, flags, filesystem, and volume type involved;
- whether a real Trash operation occurred;
- expected and actual behavior;
- impact and any known mitigation.

Reports should use synthetic data only. Never reproduce a report against `/`, a real home directory,
or user data.

## Release and recovery safety

The v0.1 release is intended for macOS 13 or later. The primary distribution is a source build; the
optional GitHub Release archives are unsigned and are accompanied by detached SHA-256 checksums. Apple
Developer ID signing and notarization are not required (ADR-0004). Verify a downloaded archive against
its published checksum before opening it; macOS Gatekeeper may require an explicit user approval for an
unsigned binary. The protected GitHub `release` environment controls publication, and pull requests
and ordinary CI jobs never receive its release credentials.

tc moves entries to the system Trash and never permanently deletes them or empties Trash. Moving an
entry normally does not free disk space immediately. Finder controls Put Back, and recovery can be
unavailable or different on external, network, and File Provider volumes. A report about a recovery
failure must include the exact system-returned Trash URL and volume type while using only synthetic
fixtures.

Compatibility options `-r`, `-R`, `-d`, and `-x` have no effect; `-P` warns that secure overwrite is
not performed; and `-W` is unsupported. `--strict-options` rejects every no-effect option. None of
these options enables permanent deletion or bypasses Protected Path policy.

## Response process

The maintainer will acknowledge the report, assess severity, prepare a regression test using the
project's fake filesystem or authorized test whitelist, and coordinate disclosure. Security releases
must pass the complete safety review and release gates in `docs/development.md`.
