#!/bin/sh
# SPDX-License-Identifier: Apache-2.0

set -eu

ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/../.." && pwd)
TEMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/tc-release-tests.XXXXXX")
trap 'rm -rf "$TEMP_DIR"' EXIT HUP INT TERM

repo="$TEMP_DIR/repo"
fake_bin="$TEMP_DIR/bin"
output_dir="$TEMP_DIR/output"
trace_file="$TEMP_DIR/trace"
mkdir -p "$repo/scripts" "$repo/docs/releases" "$fake_bin" "$output_dir"
cp "$ROOT/scripts/run-release.sh" "$repo/scripts/"
cp "$ROOT/scripts/build-universal-release.sh" "$repo/scripts/"
chmod 755 "$repo/scripts/run-release.sh"
chmod 755 "$repo/scripts/build-universal-release.sh"

cat >"$repo/CHANGELOG.md" <<'EOF'
# Changelog

## [0.1.0] - 2026-08-18

- First release.
EOF
cat >"$repo/docs/releases/v0.1.0.md" <<'EOF'
# macos-trash-cli v0.1.0

First release.
EOF
printf '%s\n' 'license' >"$repo/LICENSE"
printf '%s\n' 'notice' >"$repo/NOTICE"
printf '%s\n' '# macos-trash-cli' >"$repo/README.md"

cat >"$fake_bin/git" <<'EOF'
#!/bin/sh
set -eu
printf 'git %s\n' "$*" >>"$TC_RELEASE_TRACE"
case "$1 $2" in
  'status --porcelain') exit 0 ;;
  'rev-parse HEAD') printf '%s\n' '0123456789abcdef'; exit 0 ;;
  'rev-list -n') printf '%s\n' '0123456789abcdef'; exit 0 ;;
esac
echo "unexpected git invocation: $*" >&2
exit 1
EOF

cat >"$fake_bin/make" <<'EOF'
#!/bin/sh
set -eu
printf 'make %s\n' "$*" >>"$TC_RELEASE_TRACE"
[ "$*" = ci ]
EOF

cat >"$fake_bin/swift" <<'EOF'
#!/bin/sh
set -eu
printf 'swift %s\n' "$*" >>"$TC_RELEASE_TRACE"
scratch=''
show_bin_path=false
while [ "$#" -gt 0 ]; do
  case "$1" in
    --scratch-path)
      shift
      scratch=$1
      ;;
    --show-bin-path) show_bin_path=true ;;
  esac
  shift
done
[ -n "$scratch" ]
mkdir -p "$scratch/release"
cat >"$scratch/release/tc" <<'BINARY'
#!/bin/sh
[ "$1" = --version ]
printf '%s\n' 'tc 0.1.0'
BINARY
chmod 755 "$scratch/release/tc"
if [ "$show_bin_path" = true ]; then
  printf '%s\n' "$scratch/release"
fi
EOF

cat >"$fake_bin/lipo" <<'EOF'
#!/bin/sh
set -eu
printf 'lipo %s\n' "$*" >>"$TC_RELEASE_TRACE"
case "$1" in
  -create)
    first=$2
    shift 2
    while [ "$1" != -output ]; do shift; done
    shift
    cp "$first" "$1"
    chmod 755 "$1"
    ;;
  *)
    case "$2" in
      -verify_arch) exit 0 ;;
      -archs) printf '%s\n' 'x86_64 arm64' ;;
      *) exit 1 ;;
    esac
    ;;
esac
EOF

cat >"$fake_bin/codesign" <<'EOF'
#!/bin/sh
set -eu
printf 'codesign %s\n' "$*" >>"$TC_RELEASE_TRACE"
EOF

cat >"$fake_bin/ditto" <<'EOF'
#!/bin/sh
set -eu
printf 'ditto %s\n' "$*" >>"$TC_RELEASE_TRACE"
for argument in "$@"; do output=$argument; done
printf '%s\n' 'zip archive' >"$output"
EOF

cat >"$fake_bin/xcrun" <<'EOF'
#!/bin/sh
set -eu
printf 'xcrun %s\n' "$*" >>"$TC_RELEASE_TRACE"
case "$1 $2" in
  'vtool -show-build')
    printf '%s\n' 'Load command 0' '      minos 13.0'
    ;;
  'notarytool submit')
    printf '%s\n' '{"id":"11111111-2222-3333-4444-555555555555","status":"Accepted"}'
    ;;
  'notarytool log')
    if [ "${TC_RELEASE_NOTARY_ISSUES:-none}" = warning ]; then
      printf '%s\n' '{"status":"Accepted","issues":[{"severity":"warning"}]}'
    else
      printf '%s\n' '{"status":"Accepted","issues":null}'
    fi
    ;;
  *) exit 1 ;;
esac
EOF

cat >"$fake_bin/plutil" <<'EOF'
#!/bin/sh
set -eu
printf 'plutil %s\n' "$*" >>"$TC_RELEASE_TRACE"
case "$2" in
  id) printf '%s\n' '11111111-2222-3333-4444-555555555555' ;;
  status) printf '%s\n' 'Accepted' ;;
  issues)
    case "$1" in
      -type)
        if [ "${TC_RELEASE_NOTARY_ISSUES:-none}" = warning ]; then
          printf '%s\n' 'array'
        else
          printf '%s\n' '(any)'
        fi
        ;;
      -extract) printf '%s\n' '1' ;;
      *) exit 1 ;;
    esac
    ;;
  *) exit 1 ;;
esac
EOF

cat >"$fake_bin/spctl" <<'EOF'
#!/bin/sh
set -eu
printf 'spctl %s\n' "$*" >>"$TC_RELEASE_TRACE"
EOF

cat >"$fake_bin/shasum" <<'EOF'
#!/bin/sh
set -eu
printf 'shasum %s\n' "$*" >>"$TC_RELEASE_TRACE"
printf '%s  %s\n' 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa' "$3"
EOF

cat >"$fake_bin/gh" <<'EOF'
#!/bin/sh
set -eu
printf 'gh %s\n' "$*" >>"$TC_RELEASE_TRACE"
case "$1 $2" in
  'release view') exit 1 ;;
  'release create') exit 0 ;;
  'api repos/{owner}/{repo}/git/ref/tags/v0.1.0')
    printf '%s\n' 'tag-object-sha'
    ;;
  'api repos/{owner}/{repo}/git/tags/tag-object-sha')
    case "$*" in
      *verification.verified*) printf '%s\n' "${TC_RELEASE_REMOTE_VERIFIED:-true}" ;;
      *object.sha*) printf '%s\n' '0123456789abcdef' ;;
      *) exit 1 ;;
    esac
    ;;
  *) exit 1 ;;
esac
EOF

chmod 755 "$fake_bin"/*
printf '%s\n' 'private key' >"$TEMP_DIR/AuthKey.p8"

PATH="$fake_bin:$PATH" \
  TC_RELEASE_TRACE="$trace_file" \
  RELEASE_OUTPUT_DIR="$output_dir" \
  APPLE_SIGNING_IDENTITY='Developer ID Application: Example (TEAMID)' \
  APPLE_NOTARY_KEY_PATH="$TEMP_DIR/AuthKey.p8" \
  APPLE_NOTARY_KEY_ID='KEYID' \
  APPLE_NOTARY_ISSUER_ID='11111111-2222-3333-4444-555555555555' \
  GH_TOKEN='test-token' \
  "$repo/scripts/run-release.sh" v0.1.0

archive="$output_dir/macos-trash-cli-v0.1.0-macos-universal.zip"
checksum="$archive.sha256"
submission="$output_dir/macos-trash-cli-v0.1.0-notarization.json"
notary_log="$output_dir/macos-trash-cli-v0.1.0-notarization-log.json"
for artifact in "$archive" "$checksum" "$submission" "$notary_log"; do
  if [ ! -f "$artifact" ]; then
    echo "test failure: release pipeline did not create $(basename "$artifact")" >&2
    exit 1
  fi
done

assert_trace() {
  pattern=$1
  description=$2
  if ! grep -Fq -- "$pattern" "$trace_file"; then
    echo "test failure: release pipeline did not $description" >&2
    cat "$trace_file" >&2
    exit 1
  fi
}

assert_trace 'make ci' 'run every non-destructive release gate'
assert_trace '--triple arm64-apple-macosx13.0' 'build the Apple Silicon slice for macOS 13'
assert_trace '--triple x86_64-apple-macosx13.0' 'build the Intel slice for macOS 13'
assert_trace '-verify_arch arm64 x86_64' 'validate both universal binary slices'
assert_trace 'codesign --force --options runtime --timestamp --sign Developer ID Application: Example (TEAMID)' \
  'apply the Developer ID hardened-runtime signature'
assert_trace 'xcrun notarytool submit' 'submit the signed archive to Apple notarization'
assert_trace 'spctl --assess --type execute' 'assess the notarized command with Gatekeeper'
assert_trace 'gh api repos/{owner}/{repo}/git/tags/tag-object-sha --jq .verification.verified' \
  'require GitHub to verify the remote annotated tag signature'
assert_trace 'gh release create v0.1.0' 'publish the existing signed tag as a GitHub Release'
assert_trace '--verify-tag' 'require the release tag to exist on GitHub'

if [ "$(cat "$checksum")" \
  != "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa  $(basename "$archive")" ]; then
  echo 'test failure: checksum file is not relocatable beside the release archive' >&2
  exit 1
fi

unverified_trace="$TEMP_DIR/unverified-trace"
unverified_error="$TEMP_DIR/unverified-error"
if PATH="$fake_bin:$PATH" \
  TC_RELEASE_TRACE="$unverified_trace" \
  TC_RELEASE_REMOTE_VERIFIED=false \
  RELEASE_OUTPUT_DIR="$TEMP_DIR/unverified-output" \
  APPLE_SIGNING_IDENTITY='Developer ID Application: Example (TEAMID)' \
  APPLE_NOTARY_KEY_PATH="$TEMP_DIR/AuthKey.p8" \
  APPLE_NOTARY_KEY_ID='KEYID' \
  APPLE_NOTARY_ISSUER_ID='11111111-2222-3333-4444-555555555555' \
  GH_TOKEN='test-token' \
  "$repo/scripts/run-release.sh" v0.1.0 >"$TEMP_DIR/unverified-output.log" 2>"$unverified_error"; then
  echo 'test failure: release pipeline accepted a tag without GitHub signature verification' >&2
  exit 1
fi
if [ "$(cat "$unverified_error")" \
  != 'error: release tag must carry a GitHub-verified cryptographic signature' ]; then
  echo 'test failure: unverified tag did not produce the stable diagnostic' >&2
  cat "$unverified_error" >&2
  exit 1
fi
if grep -Fq 'make ci' "$unverified_trace"; then
  echo 'test failure: unverified tag reached release build gates' >&2
  exit 1
fi

notary_warning_trace="$TEMP_DIR/notary-warning-trace"
notary_warning_error="$TEMP_DIR/notary-warning-error"
if PATH="$fake_bin:$PATH" \
  TC_RELEASE_TRACE="$notary_warning_trace" \
  TC_RELEASE_NOTARY_ISSUES=warning \
  RELEASE_OUTPUT_DIR="$TEMP_DIR/notary-warning-output" \
  APPLE_SIGNING_IDENTITY='Developer ID Application: Example (TEAMID)' \
  APPLE_NOTARY_KEY_PATH="$TEMP_DIR/AuthKey.p8" \
  APPLE_NOTARY_KEY_ID='KEYID' \
  APPLE_NOTARY_ISSUER_ID='11111111-2222-3333-4444-555555555555' \
  GH_TOKEN='test-token' \
  "$repo/scripts/run-release.sh" v0.1.0 \
    >"$TEMP_DIR/notary-warning-output.log" 2>"$notary_warning_error"; then
  echo 'test failure: release pipeline accepted a notarization warning' >&2
  exit 1
fi
case "$(cat "$notary_warning_error")" in
  *'error: Apple notarization log contains issues; inspect '*) ;;
  *)
    echo 'test failure: notarization warning did not produce the stable diagnostic' >&2
    cat "$notary_warning_error" >&2
    exit 1
    ;;
esac
if grep -Fq 'gh release create' "$notary_warning_trace"; then
  echo 'test failure: notarization warning reached GitHub Release publication' >&2
  exit 1
fi

error_file="$TEMP_DIR/invalid-tag-error"
if PATH="$fake_bin:$PATH" TC_RELEASE_TRACE="$trace_file" \
  "$repo/scripts/run-release.sh" 0.1.0 >"$TEMP_DIR/invalid-tag-output" 2>"$error_file"; then
  echo 'test failure: release pipeline accepted a tag without the v prefix' >&2
  exit 1
fi
if [ "$(cat "$error_file")" != 'error: release tag must use vX.Y.Z' ]; then
  echo 'test failure: invalid release tag did not produce the stable diagnostic' >&2
  cat "$error_file" >&2
  exit 1
fi

echo 'Release pipeline tests passed.'
