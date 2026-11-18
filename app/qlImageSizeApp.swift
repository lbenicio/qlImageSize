import SwiftUI

@main
struct QLImageSizeApp: App {
    var body: some Scene {
        WindowGroup {
            VStack(alignment: .leading, spacing: 14) {
                Text("Quick Look Image Size")
                    .font(.title2.weight(.semibold))

                Text("Preview image dimensions, resolution, and file size in the Quick Look title. The extension also creates Finder thumbnails for WebP, BPG, and Netpbm images.")
                    .fixedSize(horizontal: false, vertical: true)

                Text("To enable it, open System Settings → General → Login Items & Extensions → Quick Look, then turn on Quick Look Image Size.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(24)
            .frame(width: 420)
        }
    }
}
