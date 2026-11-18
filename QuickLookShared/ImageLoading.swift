import AppKit
import CoreGraphics
import Foundation

struct ImageMetadata {
    let width: Int
    let height: Int
    let dpi: Double?
}

enum ImageLoading {
    static func bitmap(at url: URL) throws -> NSBitmapImageRep {
        let ext = url.pathExtension.lowercased()
        if ["pbm", "pgm", "ppm"].contains(ext) {
            guard let image = NetpbmDecoder.decode(url: url) else {
                throw CocoaError(.fileReadCorruptFile)
            }
            return NSBitmapImageRep(cgImage: image)
        }

        guard let image = ImageDecoder.bitmapRepresentation(at: url) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        return image
    }

    static func metadata(at url: URL) throws -> ImageMetadata {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let widthNumber = properties[kCGImagePropertyPixelWidth] as? NSNumber,
              let heightNumber = properties[kCGImagePropertyPixelHeight] as? NSNumber else {
            throw CocoaError(.fileReadCorruptFile)
        }

        let width64 = widthNumber.int64Value
        let height64 = heightNumber.int64Value
        guard width64 > 0, height64 > 0,
              let width = Int(exactly: width64), let height = Int(exactly: height64) else {
            throw CocoaError(.fileReadCorruptFile)
        }

        let dpiValue = (properties[kCGImagePropertyDPIWidth] as? NSNumber)?.doubleValue
        let dpi = dpiValue.flatMap { $0.isFinite && (0.0...100_000.0).contains($0) ? $0 : nil }
        return ImageMetadata(width: width, height: height, dpi: dpi)
    }

    static func thumbnail(at url: URL, maximumPixelSize: Int) throws -> CGImage {
        let ext = url.pathExtension.lowercased()
        if ["pbm", "pgm", "ppm"].contains(ext) {
            guard let image = NetpbmDecoder.decode(url: url) else {
                throw CocoaError(.fileReadCorruptFile)
            }
            return image
        }

        guard let image = ImageDecoder.thumbnailRepresentation(at: url, maximumPixelSize: maximumPixelSize) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        return image
    }
}
