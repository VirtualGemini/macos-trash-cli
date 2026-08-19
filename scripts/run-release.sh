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
    fail "required release command is unavailable: $1"
  fi
}

require_environment() {
  variable_name=$1
  eval "variable_value=\${$variable_name:-}"
  if [ -z "$variable_value" ]; then
    fail "required release environment variable is unset: $variable_name"
  fi
}

if [ "$#" -ne 1 ]; then
  echo "usage: $0 <vX.Y.Z>" >&2
  exit 2
fi

tag=$1

if ! printf '%s\n' "$tag" | grep -Eq '^v[0-9]+\.[0-9]+\.[0-9]+$'; then
  echo "error: release tag must use vX.Y.Z" >&2
  exit 1
fi

version=${tag#v}
release_notes="$ROOT/docs/releases/$tag.md"
output_dir=${RELEASE_OUTPUT_DIR:-"$ROOT/.artifacts/releases/$tag"}

for command_name in awk codesign ditto gh git grep lipo make plutil shasum spctl swift xcrun; do
  require_command "$command_name"
done
for variable_name in \
  APPLE_SIGNING_IDENTITY \
  APPLE_NOTARY_KEY_PATH \
  APPLE_NOTARY_KEY_ID \
  APPLE_NOTARY_ISSUER_ID \
  GH_TOKEN; do
  require_environment "$variable_name"
done
if [ ! -f "$APPLE_NOTARY_KEY_PATH" ]; then
  fail "APPLE_NOTARY_KEY_PATH must name a readable App Store Connect API key"
fi

cd "$ROOT"
if [ -n "$(git status --porcelain)" ]; then
  fail "release checkout must have a clean working tree"
fi
head_commit=$(git rev-parse HEAD)
tag_commit=$(git rev-list -n 1 "$tag")
if [ "$head_commit" != "$tag_commit" ]; then
  fail "release tag must resolve to the checked-out commit"
fi
if ! remote_tag_object=$(
  gh api "repos/{owner}/{repo}/git/ref/tags/$tag" --jq '.object.sha'
); then
  fail "release tag must exist as an annotated tag on GitHub"
fi
if ! remote_tag_commit=$(
  gh api "repos/{owner}/{repo}/git/tags/$remote_tag_object" --jq '.object.sha'
); then
  fail "release tag must resolve to a GitHub annotated-tag object"
fi
if ! remote_tag_verified=$(
  gh api "repos/{owner}/{repo}/git/tags/$remote_tag_object" --jq '.verification.verified'
); then
  fail "GitHub could not report the release tag signature state"
fi
if [ "$remote_tag_verified" != true ]; then
  fail "release tag must carry a GitHub-verified cryptographic signature"
fi
if [ "$remote_tag_commit" != "$head_commit" ]; then
  fail "GitHub release tag must resolve to the checked-out commit"
fi
if gh release view "$tag" >/dev/null 2>&1; then
  fail "GitHub Release already exists for $tag"
fi

if ! grep -Eq "^## \\[$version\\] - [0-9]{4}-[0-9]{2}-[0-9]{2}$" CHANGELOG.md; then
  fail "CHANGELOG.md must contain a dated [$version] release heading"
fi
if [ ! -f "$release_notes" ]; then
  fail "release notes are missing: docs/releases/$tag.md"
fi

make ci

work_dir=$(mktemp -d "${TMPDIR:-/tmp}/tc-release.XXXXXX")
trap 'rm -rf "$work_dir"' EXIT HUP INT TERM
package_name="macos-trash-cli-$tag-macos-universal"
package_dir="$work_dir/$package_name"
mkdir -p "$package_dir"
universal_binary="$package_dir/tc"
"$ROOT/scripts/build-universal-release.sh" "$universal_binary"

codesign \
  --force \
  --options runtime \
  --timestamp \
  --sign "$APPLE_SIGNING_IDENTITY" \
  "$universal_binary"
codesign --verify --strict --verbose=2 "$universal_binary"

version_output=$("$universal_binary" --version)
if [ "$version_output" != "tc $version" ]; then
  fail "release executable reports '$version_output' instead of 'tc $version'"
fi

cp LICENSE NOTICE README.md "$package_dir/"
printf '%s\n' "$version" >"$package_dir/VERSION"
mkdir -p "$output_dir"
archive="$output_dir/$package_name.zip"
checksum="$archive.sha256"
submission="$output_dir/macos-trash-cli-$tag-notarization.json"
notary_log="$output_dir/macos-trash-cli-$tag-notarization-log.json"
for artifact in "$archive" "$checksum" "$submission" "$notary_log"; do
  if [ -e "$artifact" ]; then
    fail "release artifact already exists: $artifact"
  fi
done

ditto -c -k --sequesterRsrc --keepParent "$package_dir" "$archive"
xcrun notarytool submit "$archive" \
  --key "$APPLE_NOTARY_KEY_PATH" \
  --key-id "$APPLE_NOTARY_KEY_ID" \
  --issuer "$APPLE_NOTARY_ISSUER_ID" \
  --wait \
  --output-format json >"$submission"

notary_status=$(plutil -extract status raw "$submission")
if [ "$notary_status" != Accepted ]; then
  fail "Apple notarization did not accept the release archive"
fi
submission_id=$(plutil -extract id raw "$submission")
xcrun notarytool log \
  --key "$APPLE_NOTARY_KEY_PATH" \
  --key-id "$APPLE_NOTARY_KEY_ID" \
  --issuer "$APPLE_NOTARY_ISSUER_ID" \
  "$submission_id" >"$notary_log"
notary_issues_type=$(plutil -type issues "$notary_log")
case "$notary_issues_type" in
  '(any)') ;;
  array)
    notary_issue_count=$(plutil -extract issues raw "$notary_log")
    if [ "$notary_issue_count" -ne 0 ]; then
      fail "Apple notarization log contains issues; inspect $notary_log"
    fi
    ;;
  *) fail "Apple notarization log has an unexpected issues field" ;;
esac

spctl --assess --type execute --verbose=4 "$universal_binary"
archive_hash=$(shasum -a 256 "$archive" | awk '{ print $1 }')
printf '%s  %s\n' "$archive_hash" "$(basename "$archive")" >"$checksum"

gh release create "$tag" \
  "$archive#Universal signed and notarized macOS command" \
  "$checksum#SHA-256 checksum" \
  "$submission#Apple notarization submission" \
  "$notary_log#Apple notarization log" \
  --verify-tag \
  --title "macos-trash-cli $tag" \
  --notes-file "$release_notes"

printf 'published %s with architectures: %s\n' "$tag" "$(lipo "$universal_binary" -archs)"
