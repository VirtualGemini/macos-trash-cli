#!/bin/sh
# SPDX-License-Identifier: Apache-2.0

set -eu

ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)

fail() {
  echo "error: $1" >&2
  exit 1
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    fail "required universal-build command is unavailable: $1"
  fi
}

build_slice() {
  triple=$1
  scratch_path=$2

  swift build \
    --scratch-path "$scratch_path" \
    --configuration release \
    --product tc \
    --triple "$triple" \
    --disable-automatic-resolution \
    -Xswiftc -warnings-as-errors >&2

  swift build \
    --scratch-path "$scratch_path" \
    --configuration release \
    --product tc \
    --triple "$triple" \
    --disable-automatic-resolution \
    --show-bin-path
}

validate_minimum_macos() {
  binary=$1
  build_versions=$2
  xcrun vtool -show-build "$binary" >"$build_versions"
  if ! awk '
    $1 == "minos" {
      found = 1
      if ($2 != "13.0") invalid = 1
    }
    END { exit !(found && !invalid) }
  ' "$build_versions"; then
    fail "release slice does not declare macOS 13.0 as its minimum target: $binary"
  fi
}

if [ "$#" -ne 1 ]; then
  echo "usage: $0 <absolute-output-path>" >&2
  exit 2
fi

output_binary=$1
case "$output_binary" in
  /*) ;;
  *) fail "universal release output path must be absolute" ;;
esac
if [ -d "$output_binary" ]; then
  fail "universal release output path names a directory"
fi
for command_name in awk lipo swift xcrun; do
  require_command "$command_name"
done

cd "$ROOT"
work_dir=$(mktemp -d "${TMPDIR:-/tmp}/tc-universal-release.XXXXXX")
trap 'rm -rf "$work_dir"' EXIT HUP INT TERM
arm_bin_path=$(build_slice arm64-apple-macosx13.0 "$work_dir/arm64")
intel_bin_path=$(build_slice x86_64-apple-macosx13.0 "$work_dir/x86_64")
arm_binary="$arm_bin_path/tc"
intel_binary="$intel_bin_path/tc"
if [ ! -x "$arm_binary" ] || [ ! -x "$intel_binary" ]; then
  fail "SwiftPM did not produce both release executables"
fi

validate_minimum_macos "$arm_binary" "$work_dir/arm64-build-version.txt"
validate_minimum_macos "$intel_binary" "$work_dir/x86_64-build-version.txt"

universal_binary="$work_dir/tc"
lipo -create "$arm_binary" "$intel_binary" -output "$universal_binary"
lipo "$universal_binary" -verify_arch arm64 x86_64
chmod 755 "$universal_binary"
mkdir -p "$(dirname "$output_binary")"
mv -f "$universal_binary" "$output_binary"

printf 'built %s with architectures: %s\n' "$output_binary" "$(lipo "$output_binary" -archs)"
