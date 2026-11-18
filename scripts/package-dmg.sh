#!/bin/bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
	printf 'Usage: %s /path/to/App.app /path/to/output.dmg\n' "$0" >&2
	exit 2
fi

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
app_path="$1"
output_path="$2"

if [[ ! -d "$app_path/Contents" ]]; then
	printf 'App bundle not found: %s\n' "$app_path" >&2
	exit 1
fi

mkdir -p "$(dirname "$output_path")"
work_root="$(mktemp -d "${TMPDIR:-/tmp}/qlImageSize-dmg.XXXXXX")"
trap 'rm -rf "$work_root"' EXIT

staging="$work_root/staging"
mkdir -p "$staging"
ditto "$app_path" "$staging/Quick Look Image Size.app"
ln -s /Applications "$staging/Applications"
cp "$repo_root/THIRD_PARTY_NOTICES.md" "$staging/THIRD_PARTY_NOTICES.md"
cp "$repo_root/deps/libbpg/COPYING.LGPLv2.1" "$staging/COPYING.LGPLv2.1"

hdiutil create -volname "Quick Look Image Size" -srcfolder "$staging" -ov -format UDZO "$output_path"
