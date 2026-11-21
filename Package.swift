// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "qlImageSizeUnitTests",
    platforms: [.macOS(.v12)],
    targets: [
        .target(
            name: "NetpbmDecoder",
            path: "QuickLookShared",
            exclude: [
                "ImageDecoder.h",
                "ImageDecoder.m",
                "ImageLoading.swift",
                "QuickLookExtensions.entitlements",
                "qlImageSize-Bridging-Header.h",
            ],
            sources: ["NetpbmDecoder.swift"]
        ),
        .testTarget(
            name: "NetpbmDecoderTests",
            dependencies: ["NetpbmDecoder"],
            path: "Tests/NetpbmDecoderTests"
        ),
    ],
    swiftLanguageVersions: [.v5]
)
