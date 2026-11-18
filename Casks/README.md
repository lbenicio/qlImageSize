# Homebrew cask

`lbenicio-qlimagesize.rb.template` is rendered into `lbenicio-qlimagesize.rb` only after a signed and notarized release DMG is built. This keeps the cask's SHA-256 tied to the actual release asset. The release workflow opens a pull request with the generated cask; merge it after publishing the draft GitHub Release.
