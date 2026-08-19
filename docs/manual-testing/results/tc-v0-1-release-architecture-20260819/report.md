# tc v0.1.0 release architecture report

- Date: `2026-08-19`
- Command: `make build-release-universal`
- Output: `.artifacts/release-candidate/tc` (not committed)
- Swift: `Apple Swift 6.3.3`
- macOS SDK: `26.5`
- System Trash API: not called

The command built `tc` independently for `arm64-apple-macosx13.0` and
`x86_64-apple-macosx13.0`, combined the slices with `lipo`, and required both slice minimums to be
exactly macOS 13.0 before publishing the local candidate output.

## Observed result

```text
Mach-O universal binary with 2 architectures: [x86_64:Mach-O 64-bit executable x86_64] [arm64:Mach-O 64-bit executable arm64]
x86_64 arm64
tc 0.1.0
```

`xcrun vtool -show-build` reported the same build contract for each architecture:

```text
platform MACOS
minos 13.0
sdk 26.5
```

The unsigned local candidate SHA-256 was
`5732bcd66a25ac204f47780606c5d1da1e32579412b21e1e3b27975c8a30c96a`. This checksum identifies
only the local architecture evidence. The protected release workflow rebuilds the executable, applies
the Developer ID signature, notarizes the ZIP, and publishes a separate checksum for the final archive.
