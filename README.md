# Quick Look Image Size

Quick Look Image Size is a macOS app that provides Quick Look previews and Finder thumbnails for images. It reports image dimensions, DPI when available, file size, and filename in the preview. It can decode WebP, BPG, and Netpbm images in addition to formats handled by ImageIO.

The project also includes a separate Spotlight importer for indexing dimensions and related metadata for WebP, BPG, and Netpbm files.

## Requirements

- macOS 12 or later. The project builds with the macOS 27 SDK and supports both Apple silicon and Intel Macs.
- Xcode 27 or later to build from source.

## Continuous integration

GitHub Actions runs the Netpbm decoder unit tests with coverage, builds the app and Spotlight importer, and uploads an LCOV report to Codecov on pushes and pull requests. Add a repository Actions secret named `CODECOV_TOKEN` to enable authenticated uploads; public repositories can also use Codecov's tokenless upload setting.

Run the same unit tests locally with:

```sh
swift test --enable-code-coverage
```

The old `.qlgenerator` format was removed from current macOS. Quick Look now runs as app extensions embedded in `Quick Look Image Size.app`.

## Build and install Quick Look support

1. Open `qlImageSize.xcodeproj` in Xcode and build the `qlImageSize` scheme.
2. Copy `Quick Look Image Size.app` from the build products to `/Applications` and open it once.
3. In System Settings, open **General → Login Items & Extensions → Quick Look** and enable **Quick Look Image Size**.

Quick Look displays dimensions, DPI when available, file size, and filename in the preview title. Native formats continue to use the system's preview renderer; BPG and Netpbm previews are decoded by the extension.

## Build and install the Spotlight importer

The `mdImageSize` scheme builds the independent `mdImageSize.mdimporter` bundle. Copy it to `~/Library/Spotlight`, then register it and reindex files as needed:

```sh
mkdir -p ~/Library/Spotlight
cp -R path/to/mdImageSize.mdimporter ~/Library/Spotlight/
mdimport -r ~/Library/Spotlight/mdImageSize.mdimporter
mdimport -i /path/to/image.webp
```

The Spotlight importer remains a separate bundle and is not installed by the Homebrew cask.

## Supported formats

- ImageIO formats, including JPEG, PNG, TIFF, HEIC, and WebP.
- BPG, decoded with the bundled universal libbpg archive.
- Netpbm PBM, PGM, and PPM formats, including ASCII and binary variants.

Finder and Quick Look may cache previews and thumbnails. If an image keeps showing an old result after installing an update, refresh the Finder/Quick Look cache or reindex the file with `mdimport`.

## Dependencies

`deps/libbpg/libbpg.a` contains arm64 and x86_64 slices built from libbpg 0.9.8. The corresponding upstream source archive is included at `deps/libbpg/libbpg-0.9.8.tar.gz`; run `./deps/libbpg/build-universal.sh` to rebuild it. See its README for the component license terms.

The app statically links the libbpg decoder. The release includes the corresponding source archive, rebuild script, and LGPL-2.1 license. See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) for license and source details.

## GitHub Releases and Homebrew

Pushing a version tag such as `v3.0` starts the GitHub Actions release workflow on the Xcode 27 runner. It builds a universal app with that version, signs and notarizes the app and DMG, uploads both the DMG and its SHA-256 file to a **draft** GitHub Release, and opens a pull request that updates `Casks/lbenicio-qlimagesize.rb` with that release’s exact checksum.

Before creating a release tag:

1. Set up a GitHub Actions environment named `release`, require approval from a release maintainer, restrict it to protected release tags, and add these secrets:
   - `APPLE_DEVELOPER_ID_P12_BASE64`: base64-encoded Developer ID Application certificate exported as a `.p12` file.
   - `APPLE_DEVELOPER_ID_P12_PASSWORD`: password for that `.p12` file.
   - `APPLE_DEVELOPER_ID_SIGNING_IDENTITY`: full Keychain identity name for the Developer ID Application certificate.
   - `APPLE_NOTARY_API_KEY_BASE64`: base64-encoded App Store Connect API `.p8` key with notarization access.
   - `APPLE_NOTARY_KEY_ID` and `APPLE_NOTARY_ISSUER_ID`: the API key ID and issuer ID.
2. Allow GitHub Actions to create pull requests in the repository settings. The workflow uses its repository-scoped `GITHUB_TOKEN` to create a draft release and the Homebrew cask update pull request.
3. Protect release tags and create them only from reviewed commits. The workflow checks that each tag points to a commit on the default branch before using signing and notarization credentials.
4. Review and publish the draft GitHub Release, then merge the generated cask pull request. Users can then install with:

   ```sh
   brew tap lbenicio/qlimagesize https://github.com/lbenicio/qlImageSize
   brew install --cask lbenicio-qlimagesize
   ```

The cask is generated only after a signed, notarized DMG exists; its SHA-256 is never guessed or disabled. Because this source repository does not use Homebrew's conventional `homebrew-` repository name, the tap command supplies its GitHub URL explicitly. The cask is named with the maintainer prefix to avoid Homebrew cask name collisions. A local unsigned build is for review and must not be published as the release asset. [Homebrew tap documentation](https://docs.brew.sh/Taps) explains this explicit-URL form.

## License

See [LICENSE.txt](LICENSE.txt) for the project license. Third-party components retain their own license terms. The libbpg decoder includes modified FFmpeg code under LGPL-2.1; the upstream BPG page also notes possible HEVC patent claims. License notices do not grant patent rights.
