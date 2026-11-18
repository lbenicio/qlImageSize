#!/bin/bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"

if [[ $# -ne 2 ]]; then
	printf 'Usage: %s VERSION /path/to/signed-notarized.dmg\n' "$0" >&2
	exit 2
fi

version="$1"
dmg_path="$2"
if [[ ! "$version" =~ ^[0-9]+(\.[0-9]+){1,2}$ ]]; then
	printf 'Invalid release version: %s\n' "$version" >&2
	exit 2
fi
if [[ ! -f "$dmg_path" ]]; then
	printf 'DMG not found: %s\n' "$dmg_path" >&2
	exit 1
fi

sha256="$(shasum -a 256 "$dmg_path" | awk '{print $1}')"
if [[ ! "$sha256" =~ ^[0-9a-f]{64}$ ]]; then
	printf 'Could not compute a valid SHA-256 for the DMG.\n' >&2
	exit 1
fi

sed \
	-e "s/__VERSION__/$version/g" \
	-e "s/__SHA256__/$sha256/g" \
	"$repo_root/Casks/lbenicio-qlimagesize.rb.template" > "$repo_root/Casks/lbenicio-qlimagesize.rb"
printf 'Wrote Casks/lbenicio-qlimagesize.rb for version %s (%s).\n' "$version" "$sha256"
