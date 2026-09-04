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
  echo "usage: $0 <vX.Y.Z[-beta.N]>" >&2
  exit 2
fi

tag=$1

if ! printf '%s\n' "$tag" | grep -Eq '^v[0-9]+\.[0-9]+\.[0-9]+(-beta\.[0-9]+)?$'; then
  echo "error: release tag must use vX.Y.Z or vX.Y.Z-beta.N" >&2
  exit 1
fi

version=${tag#v}
is_prerelease=false
case "$tag" in
  *-beta.*) is_prerelease=true ;;
esac
if [ "$is_prerelease" = true ]; then
  prerelease_args="--prerelease"
else
  prerelease_args=""
fi
release_notes="$ROOT/docs/releases/$tag.md"
output_dir=${RELEASE_OUTPUT_DIR:-"$ROOT/.artifacts/releases/$tag"}

for command_name in awk ditto gh git grep lipo make shasum swift tar xcrun; do
  require_command "$command_name"
done
require_environment GH_TOKEN

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

version_output=$("$universal_binary" --version)
if [ "$version_output" != "tc $version" ]; then
  fail "release executable reports '$version_output' instead of 'tc $version'"
fi

cp LICENSE NOTICE README.md "$package_dir/"
printf '%s\n' "$version" >"$package_dir/VERSION"
mkdir -p "$output_dir"
archive_zip="$output_dir/$package_name.zip"
archive_tar="$output_dir/$package_name.tar.gz"
checksum_zip="$archive_zip.sha256"
checksum_tar="$archive_tar.sha256"
for artifact in "$archive_zip" "$checksum_zip" "$archive_tar" "$checksum_tar"; do
  if [ -e "$artifact" ]; then
    fail "release artifact already exists: $artifact"
  fi
done

ditto -c -k --sequesterRsrc --keepParent "$package_dir" "$archive_zip"
tar -czf "$archive_tar" -C "$work_dir" "$package_name"

archive_zip_hash=$(shasum -a 256 "$archive_zip" | awk '{ print $1 }')
printf '%s  %s\n' "$archive_zip_hash" "$(basename "$archive_zip")" >"$checksum_zip"
archive_tar_hash=$(shasum -a 256 "$archive_tar" | awk '{ print $1 }')
printf '%s  %s\n' "$archive_tar_hash" "$(basename "$archive_tar")" >"$checksum_tar"

# shellcheck disable=SC2086 # Intentional conditional prerelease flag.
gh release create "$tag" \
  "$archive_zip#Universal unsigned macOS command (zip)" \
  "$checksum_zip#SHA-256 checksum (zip)" \
  "$archive_tar#Universal unsigned macOS command (tar.gz)" \
  "$checksum_tar#SHA-256 checksum (tar.gz)" \
  $prerelease_args --verify-tag \
  --title "macos-trash-cli $tag" \
  --notes-file "$release_notes"

printf 'published %s with architectures: %s\n' "$tag" "$(lipo "$universal_binary" -archs)"
printf 'zip: %s  sha256 %s\n' "$archive_zip" "$archive_zip_hash"
printf 'tar.gz: %s  sha256 %s\n' "$archive_tar" "$archive_tar_hash"

# Optional Homebrew Tap bump (source-build formula). Prereleases never touch the tap;
# the tap tracks stable releases only.
tap_dir=${HOMEBREW_TAP_DIR:-}
tap_repo=${HOMEBREW_TAP_GITHUB_REPO:-VirtualGemini/homebrew-tap}
if [ "$is_prerelease" = true ]; then
  printf 'skipping tap bump for prerelease %s; tap tracks stable releases\n' "$tag" >&2
  printf '     zip sha256: %s\n' "$archive_zip_hash" >&2
  printf '     tar.gz sha256: %s\n' "$archive_tar_hash" >&2
elif [ -n "$tap_dir" ]; then
  if [ ! -d "$tap_dir/.git" ]; then
    echo "warning: HOMEBREW_TAP_DIR does not look like a git repo: $tap_dir" >&2
  elif [ -n "$(git -C "$tap_dir" status --porcelain)" ]; then
    echo "warning: tap repo has a dirty working tree; skipping automatic bump: $tap_dir" >&2
  else
    formula_path="$tap_dir/Formula/macos-trash-cli.rb"
    if [ ! -f "$formula_path" ]; then
      echo "warning: formula not found at $formula_path; skipping automatic bump" >&2
    else
      # Prefer zip sha for formula url; keep tar url commented alternative.
      if grep -q 'sha256' "$formula_path"; then
        # Use awk to replace first sha256 occurrence; keep file formatting stable.
        tmp_formula=$(mktemp "${TMPDIR:-/tmp}/tc-formula.XXXXXX")
        awk -v h="$archive_zip_hash" 'BEGIN{c=0} /sha256/ && c==0 {sub(/"[a-f0-9]{64}"/, "\"" h "\""); c=1} {print}' "$formula_path" >"$tmp_formula" && mv "$tmp_formula" "$formula_path"
      fi
      # Update url and version if template contains them.
      if grep -q 'url "https://github.com/.*archive/refs/tags/' "$formula_path"; then
        tmp_formula=$(mktemp "${TMPDIR:-/tmp}/tc-formula.XXXXXX")
        awk -v t="$tag" '{gsub(/v[0-9]+\.[0-9]+\.[0-9]+\.tar\.gz/, t ".tar.gz"); print}' "$formula_path" >"$tmp_formula" && mv "$tmp_formula" "$formula_path"
      fi
      git -C "$tap_dir" add "$formula_path"
      if git -C "$tap_dir" diff --cached --quiet; then
        echo "tap formula already up to date; no commit needed" >&2
      elif ! git -C "$tap_dir" commit -m "macos-trash-cli $tag"; then
        echo "warning: tap formula commit failed; GitHub Release above remains published" >&2
      elif ! git -C "$tap_dir" push origin HEAD; then
        echo "warning: tap push failed; GitHub Release above remains published (repo: $tap_repo)" >&2
      else
        printf 'pushed tap bump for %s to %s\n' "$tag" "$tap_repo" >&2
      fi
    fi
  fi
else
  printf 'tip: set HOMEBREW_TAP_DIR to auto-push Formula bump (repo: %s)\n' "$tap_repo" >&2
  printf '     zip sha256: %s\n' "$archive_zip_hash" >&2
  printf '     tar.gz sha256: %s\n' "$archive_tar_hash" >&2
fi
