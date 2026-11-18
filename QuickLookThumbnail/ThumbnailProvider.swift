import CoreGraphics
import QuickLookThumbnailing

final class ThumbnailProvider: QLThumbnailProvider {
    override func provideThumbnail(for request: QLFileThumbnailRequest, _ handler: @escaping (QLThumbnailReply?, Error?) -> Void) {
        do {
            let maximumPixelSize = max(1, Int(max(request.maximumSize.width, request.maximumSize.height).rounded(.up)))
            let image = try ImageLoading.thumbnail(at: request.fileURL, maximumPixelSize: maximumPixelSize)
            let reply = QLThumbnailReply(contextSize: request.maximumSize, drawing: { context in
                let bounds = CGRect(origin: .zero, size: request.maximumSize)
                let scale = min(bounds.width / CGFloat(image.width), bounds.height / CGFloat(image.height))
                let size = CGSize(width: CGFloat(image.width) * scale, height: CGFloat(image.height) * scale)
                let rect = CGRect(x: (bounds.width - size.width) / 2, y: (bounds.height - size.height) / 2,
                                  width: size.width, height: size.height)
                context.draw(image, in: rect)
                return true
            })
            handler(reply, nil)
        } catch {
            handler(nil, error)
        }
    }
}
