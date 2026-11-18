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

for name in APPLE_DEVELOPER_ID_P12_BASE64 APPLE_DEVELOPER_ID_P12_PASSWORD APPLE_DEVELOPER_ID_SIGNING_IDENTITY APPLE_NOTARY_API_KEY_BASE64 APPLE_NOTARY_KEY_ID APPLE_NOTARY_ISSUER_ID; do
	if [[ -z "${!name:-}" ]]; then
		printf 'Missing required GitHub Actions secret: %s\n' "$name" >&2
		exit 1
	fi
done

work_root="$(mktemp -d "${TMPDIR:-/tmp}/qlImageSize-release.XXXXXX")"
keychain_path="$work_root/release.keychain-db"
keychain_password="$(openssl rand -hex 24)"
previous_keychains=()
while IFS= read -r old_keychain; do
	[[ -n "$old_keychain" ]] && previous_keychains+=("$old_keychain")
done < <(security list-keychains -d user | sed 's/^ *"//; s/"$//')
previous_keychain="$(security default-keychain -d user | tr -d '"')"

cleanup() {
	if [[ -n "$previous_keychain" ]]; then
		security default-keychain -d user -s "$previous_keychain" >/dev/null 2>&1 || true
	fi
	if [[ ${#previous_keychains[@]} -gt 0 ]]; then
		security list-keychains -d user -s "${previous_keychains[@]}" >/dev/null 2>&1 || true
	fi
	security delete-keychain "$keychain_path" >/dev/null 2>&1 || true
	rm -rf "$work_root"
}
trap cleanup EXIT

derived_data="$work_root/DerivedData"
xcodebuild \
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

certificate_path="$work_root/developer-id.p12"
notary_key_path="$work_root/notary-api-key.p8"
printf '%s' "$APPLE_DEVELOPER_ID_P12_BASE64" | base64 -D > "$certificate_path"
printf '%s' "$APPLE_NOTARY_API_KEY_BASE64" | base64 -D > "$notary_key_path"
chmod 600 "$certificate_path" "$notary_key_path"

security create-keychain -p "$keychain_password" "$keychain_path"
security set-keychain-settings -lut 21600 "$keychain_path"
security unlock-keychain -p "$keychain_password" "$keychain_path"
security import "$certificate_path" -k "$keychain_path" -P "$APPLE_DEVELOPER_ID_P12_PASSWORD" -T /usr/bin/codesign
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$keychain_password" "$keychain_path" >/dev/null
if [[ ${#previous_keychains[@]} -gt 0 ]]; then
	security list-keychains -d user -s "$keychain_path" "${previous_keychains[@]}"
else
	security list-keychains -d user -s "$keychain_path"
fi
security default-keychain -d user -s "$keychain_path"

entitlements="$repo_root/QuickLookShared/QuickLookExtensions.entitlements"
shopt -s nullglob
extensions=("$app_path"/Contents/PlugIns/*.appex)
if [[ ${#extensions[@]} -eq 0 ]]; then
	printf 'No embedded Quick Look extensions were found in the app.\n' >&2
	exit 1
fi

for extension in "${extensions[@]}"; do
	codesign --force --options runtime --timestamp --entitlements "$entitlements" --sign "$APPLE_DEVELOPER_ID_SIGNING_IDENTITY" "$extension"
done
codesign --force --options runtime --timestamp --entitlements "$entitlements" --sign "$APPLE_DEVELOPER_ID_SIGNING_IDENTITY" "$app_path"
codesign --verify --deep --strict --verbose=2 "$app_path"

for bundle in "$app_path" "${extensions[@]}"; do
	executable="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$bundle/Contents/Info.plist")"
	lipo -verify_arch arm64 "$bundle/Contents/MacOS/$executable"
	lipo -verify_arch x86_64 "$bundle/Contents/MacOS/$executable"
done

app_zip="$work_root/Quick-Look-Image-Size-${version}.zip"
ditto -c -k --sequesterRsrc --keepParent "$app_path" "$app_zip"
xcrun notarytool submit "$app_zip" --key "$notary_key_path" --key-id "$APPLE_NOTARY_KEY_ID" --issuer "$APPLE_NOTARY_ISSUER_ID" --wait
xcrun stapler staple "$app_path"
xcrun stapler validate "$app_path"

"$repo_root/scripts/package-dmg.sh" "$app_path" "$output_dmg"
codesign --force --timestamp --sign "$APPLE_DEVELOPER_ID_SIGNING_IDENTITY" "$output_dmg"
xcrun notarytool submit "$output_dmg" --key "$notary_key_path" --key-id "$APPLE_NOTARY_KEY_ID" --issuer "$APPLE_NOTARY_ISSUER_ID" --wait
xcrun stapler staple "$output_dmg"
xcrun stapler validate "$output_dmg"
shasum -a 256 "$output_dmg" > "$output_dmg.sha256"
