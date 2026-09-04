#!/bin/sh
# SPDX-License-Identifier: Apache-2.0

set -eu
ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/../.." && pwd)
TEMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/tc-tool-version-tests.XXXXXX")
trap 'rm -rf "$TEMP_DIR"' EXIT HUP INT TERM
repo="$TEMP_DIR/repo"
mkdir -p "$repo/scripts/lib" "$repo/.github/workflows" "$repo/docs"
cp "$ROOT/scripts/check-tool-versions.sh" "$repo/scripts/"
cp "$ROOT/scripts/lib/tool-versions.sh" "$repo/scripts/lib/"
cp "$ROOT/.tool-versions.lock" "$repo/"
cp "$ROOT/Package.swift" "$repo/"
cp "$ROOT/docs/development.md" "$repo/docs/"
printf '%s\n' 'steps:' '  - uses: "actions/checkout@v4"' >"$repo/.github/workflows/test.yml"
if "$repo/scripts/check-tool-versions.sh" >/dev/null 2>&1; then
  echo "test failure: quoted floating checkout reference was accepted" >&2
  exit 1
fi
sha=$(sed -n 's/^actions-checkout=//p' "$repo/.tool-versions.lock")
printf '%s\n' 'steps:' "  - uses: \"actions/checkout@$sha\"" >"$repo/.github/workflows/test.yml"
"$repo/scripts/check-tool-versions.sh"

cp "$repo/Package.swift" "$TEMP_DIR/Package.swift.ok"
printf '%s\n' '    .package(url: "https://github.com/realm/SwiftLint.git", exact: "0.65.0")' >>"$repo/Package.swift"
if "$repo/scripts/check-tool-versions.sh" >/dev/null 2>&1; then
  echo "test failure: SwiftLint package dependency was accepted" >&2
  exit 1
fi
cp "$TEMP_DIR/Package.swift.ok" "$repo/Package.swift"

cp "$repo/docs/development.md" "$TEMP_DIR/development.md.ok"
swiftlint_version=$(sed -n 's/^swiftlint=//p' "$repo/.tool-versions.lock")
sed "s/SwiftLint $swiftlint_version/SwiftLint 0.0.0/" "$TEMP_DIR/development.md.ok" >"$repo/docs/development.md"
if "$repo/scripts/check-tool-versions.sh" >/dev/null 2>&1; then
  echo "test failure: SwiftLint documentation version drift was accepted" >&2
  exit 1
fi
cp "$TEMP_DIR/development.md.ok" "$repo/docs/development.md"

"$repo/scripts/check-tool-versions.sh"
echo "Tool version tests passed."
