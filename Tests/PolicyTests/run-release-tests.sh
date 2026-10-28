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
if [ "$1" = -C ]; then
  case "$3" in
    push) exit "${TC_TAP_PUSH_STATUS:-0}" ;;
    add) [ "${TC_TAP_STAGE_FAIL:-false}" = false ] || exit 1 ;;
    commit) [ "${TC_TAP_COMMIT_FAIL:-false}" = false ] || exit 1 ;;
  esac
  exec "$TC_REAL_GIT" "$@"
fi
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
printf '%s\n' "tc ${TC_RELEASE_VERSION:-0.1.0}"
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

cat >"$fake_bin/ditto" <<'EOF'
#!/bin/sh
set -eu
printf 'ditto %s\n' "$*" >>"$TC_RELEASE_TRACE"
for argument in "$@"; do output=$argument; done
printf '%s\n' 'zip archive' >"$output"
EOF

cat >"$fake_bin/tar" <<'EOF'
#!/bin/sh
set -eu
printf 'tar %s\n' "$*" >>"$TC_RELEASE_TRACE"
archive=""
prev=""
for arg in "$@"; do
  if [ "$prev" = "-czf" ]; then
    archive=$arg
    break
  fi
  prev=$arg
done
if [ -z "$archive" ]; then
  for arg in "$@"; do archive=$arg; done
fi
printf '%s\n' 'tar archive' >"$archive"
EOF

cat >"$fake_bin/xcrun" <<'EOF'
#!/bin/sh
set -eu
printf 'xcrun %s\n' "$*" >>"$TC_RELEASE_TRACE"
case "$1 $2" in
  'vtool -show-build')
    printf '%s\n' 'Load command 0' '      minos 13.0'
    ;;
  *) exit 1 ;;
esac
EOF

cat >"$fake_bin/shasum" <<'EOF'
#!/bin/sh
set -eu
printf 'shasum %s\n' "$*" >>"$TC_RELEASE_TRACE"
case "$3" in
  */source.tar.gz) hash=bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb ;;
  *) hash=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa ;;
esac
printf '%s  %s\n' "$hash" "$3"
EOF

cat >"$fake_bin/gh" <<'EOF'
#!/bin/sh
set -eu
printf 'gh %s\n' "$*" >>"$TC_RELEASE_TRACE"
case "$1 $2" in
  'repo view') printf '%s\n' 'VirtualGemini/macos-trash-cli'; exit 0 ;;
  'release view') exit 1 ;;
  'release create') exit 0 ;;
  'api repos/{owner}/{repo}/git/ref/tags/'*)
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

cat >"$fake_bin/curl" <<'EOF'
#!/bin/sh
set -eu
printf 'curl %s\n' "$*" >>"$TC_RELEASE_TRACE"
[ "${TC_SOURCE_DOWNLOAD_FAIL:-false}" = false ] || exit 22
while [ "$#" -gt 0 ]; do
  if [ "$1" = --output ]; then
    shift
    printf '%s\n' 'source archive' >"$1"
    exit 0
  fi
  shift
done
exit 1
EOF

chmod 755 "$fake_bin"/*

PATH="$fake_bin:$PATH" \
  TC_RELEASE_TRACE="$trace_file" \
  RELEASE_OUTPUT_DIR="$output_dir" \
  GH_TOKEN='test-token' \
  "$repo/scripts/run-release.sh" v0.1.0

archive_zip="$output_dir/macos-trash-cli-v0.1.0-macos-universal.zip"
checksum_zip="$archive_zip.sha256"
archive_tar="$output_dir/macos-trash-cli-v0.1.0-macos-universal.tar.gz"
checksum_tar="$archive_tar.sha256"
for artifact in "$archive_zip" "$checksum_zip" "$archive_tar" "$checksum_tar"; do
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

assert_not_trace() {
  pattern=$1
  description=$2
  if grep -Fq -- "$pattern" "$trace_file"; then
    echo "test failure: release pipeline unexpectedly $description" >&2
    cat "$trace_file" >&2
    exit 1
  fi
}

assert_trace 'make ci' 'run every non-destructive release gate'
assert_trace '--triple arm64-apple-macosx13.0' 'build the Apple Silicon slice for macOS 13'
assert_trace '--triple x86_64-apple-macosx13.0' 'build the Intel slice for macOS 13'
assert_trace '-verify_arch arm64 x86_64' 'validate both universal binary slices'
assert_trace 'ditto -c -k' 'create the zip archive'
assert_trace 'tar -czf' 'create the tar.gz archive'
assert_trace 'shasum -a 256' 'compute sha256 checksums'
assert_not_trace 'codesign' 'invoke Apple codesign'
assert_not_trace 'notarytool' 'invoke Apple notarytool'
assert_not_trace 'spctl' 'invoke Gatekeeper assessment'
assert_trace 'gh api repos/{owner}/{repo}/git/tags/tag-object-sha --jq .verification.verified' \
  'require GitHub to verify the remote annotated tag signature'
assert_trace 'gh release create v0.1.0' 'publish the existing tag as a GitHub Release'
assert_trace '--verify-tag' 'require the release tag to exist on GitHub'
assert_not_trace '--prerelease' 'mark a stable release as a prerelease'

if [ "$(cat "$checksum_zip")" \
  != "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa  $(basename "$archive_zip")" ]; then
  echo 'test failure: zip checksum file is not relocatable beside the release archive' >&2
  exit 1
fi
if [ "$(cat "$checksum_tar")" \
  != "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa  $(basename "$archive_tar")" ]; then
  echo 'test failure: tar.gz checksum file is not relocatable beside the release archive' >&2
  exit 1
fi

# Exercise the optional stable tap update with a real disposable Git repository.
TC_REAL_GIT=$(command -v git)
export TC_REAL_GIT
tap="$TEMP_DIR/tap"
"$TC_REAL_GIT" init -q "$tap"
"$TC_REAL_GIT" -C "$tap" config user.name 'Release Test'
"$TC_REAL_GIT" -C "$tap" config user.email 'release-test@example.invalid'
"$TC_REAL_GIT" -C "$tap" config commit.gpgsign false
"$TC_REAL_GIT" -C "$tap" config core.hooksPath /dev/null
mkdir -p "$tap/Formula"
formula="$tap/Formula/macos-trash-cli.rb"
for scenario in success inferred-version download-failure invalid-template unquoted-hash single-quoted-version parenthesized-version staging-failure commit-failure push-failure; do
  cat >"$formula" <<'EOF'
class MacosTrashCli < Formula
  url "https://github.com/VirtualGemini/macos-trash-cli/archive/refs/tags/v0.0.9.tar.gz"
  version "0.0.9"
  sha256 "cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc"
end
EOF
  if [ "$scenario" = inferred-version ]; then
    sed '/^  version /d' "$formula" >"$TEMP_DIR/inferred-formula"
    mv "$TEMP_DIR/inferred-formula" "$formula"
  fi
  if [ "$scenario" = invalid-template ]; then
    printf '  sha256 "duplicate"\n' >>"$formula"
  fi
  if [ "$scenario" = unquoted-hash ]; then
    sed 's/sha256 "[a-f0-9]*"/sha256 old_hash/' "$formula" >"$TEMP_DIR/invalid-formula"
    mv "$TEMP_DIR/invalid-formula" "$formula"
  fi
  if [ "$scenario" = single-quoted-version ]; then
    sed "s/version \"0.0.9\"/version '0.0.9'/" "$formula" >"$TEMP_DIR/invalid-version"
    mv "$TEMP_DIR/invalid-version" "$formula"
  fi
  if [ "$scenario" = parenthesized-version ]; then
    sed 's/version "0.0.9"/version("0.0.9")/' "$formula" >"$TEMP_DIR/parenthesized-version"
    mv "$TEMP_DIR/parenthesized-version" "$formula"
  fi
  "$TC_REAL_GIT" -C "$tap" add .
  "$TC_REAL_GIT" -C "$tap" commit -qm "Fixture $scenario" --allow-empty
  cp "$formula" "$TEMP_DIR/previous-formula"
  download_fail=false
  push_status=0
  stage_fail=false
  commit_fail=false
  [ "$scenario" != download-failure ] || download_fail=true
  [ "$scenario" != push-failure ] || push_status=1
  [ "$scenario" != staging-failure ] || stage_fail=true
  [ "$scenario" != commit-failure ] || commit_fail=true
  PATH="$fake_bin:$PATH" TC_RELEASE_TRACE="$TEMP_DIR/$scenario-trace" \
    TC_SOURCE_DOWNLOAD_FAIL="$download_fail" TC_TAP_PUSH_STATUS="$push_status" \
    TC_TAP_STAGE_FAIL="$stage_fail" TC_TAP_COMMIT_FAIL="$commit_fail" \
    HOMEBREW_TAP_DIR="$tap" RELEASE_OUTPUT_DIR="$TEMP_DIR/$scenario-output" \
    GH_TOKEN=test-token "$repo/scripts/run-release.sh" v0.1.0 >"$TEMP_DIR/$scenario.log" 2>&1
  case "$scenario" in
    success|inferred-version|staging-failure|commit-failure|push-failure)
      for expected in 'v0.1.0.tar.gz' \
        'sha256 "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"'; do
        if ! grep -Fq "$expected" "$formula"; then
          echo "test failure: $scenario formula does not contain $expected" >&2
          cat "$formula" >&2
          exit 1
        fi
      done
      if [ "$scenario" != inferred-version ]; then
        grep -Fq 'version "0.1.0"' "$formula"
      fi
      grep -Fq 'https://github.com/VirtualGemini/macos-trash-cli/archive/refs/tags/v0.1.0.tar.gz' \
        "$TEMP_DIR/$scenario-trace"
      ;;
    *)
      cmp "$formula" "$TEMP_DIR/previous-formula"
      if grep -Fq "git -C $tap push" "$TEMP_DIR/$scenario-trace"; then
        echo 'test failure: failed tap update reached push' >&2
        exit 1
      fi
      ;;
  esac
  if [ "$scenario" != success ] && [ "$scenario" != inferred-version ]; then
    grep -Fq 'warning:' "$TEMP_DIR/$scenario.log"
  fi
done

unverified_trace="$TEMP_DIR/unverified-trace"
unverified_error="$TEMP_DIR/unverified-error"
if PATH="$fake_bin:$PATH" \
  TC_RELEASE_TRACE="$unverified_trace" \
  TC_RELEASE_REMOTE_VERIFIED=false \
  RELEASE_OUTPUT_DIR="$TEMP_DIR/unverified-output" \
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

error_file="$TEMP_DIR/invalid-tag-error"
if PATH="$fake_bin:$PATH" TC_RELEASE_TRACE="$trace_file" \
  "$repo/scripts/run-release.sh" 0.1.0 >"$TEMP_DIR/invalid-tag-output" 2>"$error_file"; then
  echo 'test failure: release pipeline accepted a tag without the v prefix' >&2
  exit 1
fi
if [ "$(cat "$error_file")" != 'error: release tag must use vX.Y.Z or vX.Y.Z-beta.N' ]; then
  echo 'test failure: invalid release tag did not produce the stable diagnostic' >&2
  cat "$error_file" >&2
  exit 1
fi

rc_error="$TEMP_DIR/rc-tag-error"
if PATH="$fake_bin:$PATH" TC_RELEASE_TRACE="$trace_file" \
  "$repo/scripts/run-release.sh" v0.1.0-rc.1 >"$TEMP_DIR/rc-tag-output" 2>"$rc_error"; then
  echo 'test failure: release pipeline accepted a non-beta prerelease tag' >&2
  exit 1
fi
if [ "$(cat "$rc_error")" != 'error: release tag must use vX.Y.Z or vX.Y.Z-beta.N' ]; then
  echo 'test failure: non-beta prerelease tag did not produce the stable diagnostic' >&2
  cat "$rc_error" >&2
  exit 1
fi

beta_repo="$TEMP_DIR/beta-repo"
beta_bin="$TEMP_DIR/beta-bin"
beta_output="$TEMP_DIR/beta-output"
beta_trace="$TEMP_DIR/beta-trace"
beta_log="$TEMP_DIR/beta-output.log"
mkdir -p "$beta_repo/scripts" "$beta_repo/docs/releases" "$beta_output"
cp "$repo/scripts/run-release.sh" "$beta_repo/scripts/"
cp "$repo/scripts/build-universal-release.sh" "$beta_repo/scripts/"
chmod 755 "$beta_repo/scripts/run-release.sh"
chmod 755 "$beta_repo/scripts/build-universal-release.sh"
cat >"$beta_repo/CHANGELOG.md" <<'EOF'
# Changelog

## [0.1.0-beta.1] - 2026-09-03

- First beta.
EOF
cat >"$beta_repo/docs/releases/v0.1.0-beta.1.md" <<'EOF'
# macos-trash-cli v0.1.0-beta.1

First beta.
EOF
printf '%s\n' 'license' >"$beta_repo/LICENSE"
printf '%s\n' 'notice' >"$beta_repo/NOTICE"
printf '%s\n' '# macos-trash-cli' >"$beta_repo/README.md"
mkdir -p "$beta_bin"
for tool in git make swift lipo ditto tar xcrun shasum; do
  printf '#!/bin/sh\nset -eu\nexec "%s/%s" "$@"\n' "$fake_bin" "$tool" >"$beta_bin/$tool"
  chmod 755 "$beta_bin/$tool"
done
cat >"$beta_bin/gh" <<'EOF'
#!/bin/sh
set -eu
printf 'gh %s\n' "$*" >>"$TC_RELEASE_TRACE"
case "$1 $2" in
  'release view') exit 1 ;;
  'release create') exit 0 ;;
  'api repos/{owner}/{repo}/git/ref/tags/'*)
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
chmod 755 "$beta_bin/gh"
# Point the beta fixture at the shared fake git root by reusing its trace contract:
# the fake git only answers status/rev-parse/rev-list, which are tag-independent.
PATH="$beta_bin:$PATH" \
  TC_RELEASE_TRACE="$beta_trace" \
  TC_RELEASE_VERSION='0.1.0-beta.1' \
  HOMEBREW_TAP_DIR="$tap" \
  RELEASE_OUTPUT_DIR="$beta_output" \
  GH_TOKEN='test-token' \
  "$beta_repo/scripts/run-release.sh" v0.1.0-beta.1 >"$beta_log" 2>&1
beta_archive_zip="$beta_output/macos-trash-cli-v0.1.0-beta.1-macos-universal.zip"
beta_checksum_zip="$beta_archive_zip.sha256"
beta_archive_tar="$beta_output/macos-trash-cli-v0.1.0-beta.1-macos-universal.tar.gz"
beta_checksum_tar="$beta_archive_tar.sha256"
for artifact in "$beta_archive_zip" "$beta_checksum_zip" "$beta_archive_tar" "$beta_checksum_tar"; do
  if [ ! -f "$artifact" ]; then
    echo "test failure: beta pipeline did not create $(basename "$artifact")" >&2
    exit 1
  fi
done
if ! grep -Fq -- 'gh release create v0.1.0-beta.1' "$beta_trace"; then
  echo 'test failure: beta pipeline did not publish the beta tag' >&2
  cat "$beta_trace" >&2
  exit 1
fi
if ! grep -Fq -- '--prerelease' "$beta_trace"; then
  echo 'test failure: beta pipeline did not mark the GitHub Release as a prerelease' >&2
  cat "$beta_trace" >&2
  exit 1
fi
if ! grep -Fq -- 'skipping tap bump for prerelease v0.1.0-beta.1' "$beta_log"; then
  echo 'test failure: beta pipeline did not skip the Homebrew Tap bump' >&2
  cat "$beta_log" >&2
  exit 1
fi

if grep -Fq "git -C $tap" "$beta_trace" || grep -Fq 'curl ' "$beta_trace"; then
  echo 'test failure: beta release touched the stable tap or downloaded formula source' >&2
  exit 1
fi

echo 'Release pipeline tests passed.'
