import CoreGraphics
import ImageIO
import Quartz
import UniformTypeIdentifiers

final class PreviewProvider: QLPreviewProvider, QLPreviewingController {
    func providePreview(for request: QLFilePreviewRequest) async throws -> QLPreviewReply {
        let url = request.fileURL
        let usesCustomDecoder = ["bpg", "pbm", "pgm", "ppm"].contains(url.pathExtension.lowercased())
        var customBitmap: NSBitmapImageRep?
        let metadata: ImageMetadata
        if let imageMetadata = try? ImageLoading.metadata(at: url) {
            metadata = imageMetadata
        } else if usesCustomDecoder {
            let bitmap = try ImageLoading.bitmap(at: url)
            customBitmap = bitmap
            metadata = ImageMetadata(width: bitmap.pixelsWide, height: bitmap.pixelsHigh, dpi: nil)
        } else {
            throw CocoaError(.fileReadCorruptFile)
        }

        let fileSize = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map { ByteCountFormatter.string(fromByteCount: Int64($0), countStyle: .file) } ?? "Unknown size"
        let resolution = metadata.dpi.map { " (\(Int($0.rounded())) dpi)" } ?? ""
        let title = "\(metadata.width) × \(metadata.height) px\(resolution) • \(fileSize) • \(url.lastPathComponent)"

        if usesCustomDecoder {
            let bitmap = try customBitmap ?? ImageLoading.bitmap(at: url)
            guard let png = bitmap.representation(using: .png, properties: [:]) else {
                throw CocoaError(.fileReadCorruptFile)
            }
            let reply = QLPreviewReply(dataOfContentType: .png,
                                       contentSize: CGSize(width: CGFloat(metadata.width), height: CGFloat(metadata.height))) { _ in
                png
            }
            reply.title = title
            return reply
        }

        let reply = QLPreviewReply(fileURL: url)
        reply.title = title
        return reply
    }
}
