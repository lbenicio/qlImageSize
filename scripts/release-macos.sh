#!/bin/bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"

if [[ $# -ne 2 ]]; then
	printf 'Usage: %s VERSION /path/to/output.dmg\n' "$0" >&2
	exit 2
fi

version="$1"
output_dmg="$2"
if [[ ! "$version" =~ ^[0-9]+(\.[0-9]+){1,2}$ ]]; then
	printf 'Invalid release version: %s\n' "$version" >&2
	exit 2
fi

work_root="$(mktemp -d "${TMPDIR:-/tmp}/qlImageSize-release.XXXXXX")"
trap 'rm -rf "$work_root"' EXIT

derived_data="$work_root/DerivedData"
xcodebuild \
	-quiet \
	-project "$repo_root/qlImageSize.xcodeproj" \
	-scheme qlImageSize \
	-configuration Release \
	-sdk macosx \
	-destination 'generic/platform=macOS' \
	-derivedDataPath "$derived_data" \
	ARCHS='arm64 x86_64' \
	ONLY_ACTIVE_ARCH=NO \
	MARKETING_VERSION="$version" \
	CURRENT_PROJECT_VERSION="$version" \
	CODE_SIGNING_ALLOWED=NO \
	build

app_path="$derived_data/Build/Products/Release/Quick Look Image Size.app"
if [[ ! -d "$app_path/Contents" ]]; then
	printf 'Build did not produce the expected app bundle: %s\n' "$app_path" >&2
	exit 1
fi

mkdir -p "$app_path/Contents/Resources"
cp "$repo_root/THIRD_PARTY_NOTICES.md" "$app_path/Contents/Resources/ThirdPartyNotices.md"
cp "$repo_root/deps/libbpg/COPYING.LGPLv2.1" "$app_path/Contents/Resources/COPYING.LGPLv2.1"

# Ad-hoc signatures preserve the app and extension entitlements without embedding a
# Developer ID certificate, Team ID, or Apple account identity.
entitlements="$repo_root/QuickLookShared/QuickLookExtensions.entitlements"
shopt -s nullglob
extensions=("$app_path"/Contents/PlugIns/*.appex)
if [[ ${#extensions[@]} -eq 0 ]]; then
	printf 'No embedded Quick Look extensions were found in the app.\n' >&2
	exit 1
fi

for extension in "${extensions[@]}"; do
	codesign --force --sign - --entitlements "$entitlements" "$extension"
done
codesign --force --sign - --entitlements "$entitlements" "$app_path"
codesign --verify --deep --strict --verbose=2 "$app_path"

for bundle in "$app_path" "${extensions[@]}"; do
	executable="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$bundle/Contents/Info.plist")"
	lipo -verify_arch arm64 "$bundle/Contents/MacOS/$executable"
	lipo -verify_arch x86_64 "$bundle/Contents/MacOS/$executable"

	signature_info="$(codesign --display --verbose=4 "$bundle" 2>&1 || true)"
	if grep -q '^Authority=' <<< "$signature_info"; then
		printf 'Unexpected certificate identity found in %s.\n' "$bundle" >&2
		exit 1
	fi
	team_identifier="$(sed -n 's/^TeamIdentifier=//p' <<< "$signature_info")"
	if [[ -n "$team_identifier" && "$team_identifier" != 'not set' ]]; then
		printf 'Unexpected Team ID found in %s.\n' "$bundle" >&2
		exit 1
	fi
done

"$repo_root/scripts/package-dmg.sh" "$app_path" "$output_dmg"
shasum -a 256 "$output_dmg" > "$output_dmg.sha256"
