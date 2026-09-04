#!/bin/sh
# SPDX-License-Identifier: Apache-2.0

set -eu

ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)

os=$(uname -s)
arch=$(uname -m)
swiftlint_command=
if command -v swiftlint >/dev/null 2>&1; then
  swiftlint_command=$(command -v swiftlint)
else
  artifact_root="$ROOT/.build/artifacts/swiftlint"

  case "$os-$arch" in
    Darwin-*) artifact_path='*/macos/swiftlint' ;;
    Linux-aarch64 | Linux-arm64) artifact_path='*/linux/arm64/swiftlint' ;;
    Linux-x86_64 | Linux-amd64) artifact_path='*/linux/amd64/swiftlint' ;;
    *)
      echo "error: unsupported SwiftLint host: $os $arch" >&2
      echo "hint: brew install swiftlint" >&2
      exit 1
      ;;
  esac

  swiftlint_command=$(find "$artifact_root" -type f -path "$artifact_path" -print -quit 2>/dev/null || true)

  if [ -z "$swiftlint_command" ]; then
    echo "error: SwiftLint is unavailable; install with 'brew install swiftlint' or use the legacy .build artifact if present" >&2
    exit 1
  fi
fi

if [ "$os" = "Darwin" ]; then
  developer_dir=$(xcode-select -p)
  DYLD_FRAMEWORK_PATH="$developer_dir/usr/lib:$developer_dir/Toolchains/XcodeDefault.xctoolchain/usr/lib"
  export DYLD_FRAMEWORK_PATH
fi

exec "$swiftlint_command" lint --strict --config "$ROOT/.swiftlint.yml"
