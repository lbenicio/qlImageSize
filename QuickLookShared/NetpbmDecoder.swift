import CoreGraphics
import Foundation

enum NetpbmDecoder {
    private static let maximumDimension = 100_000
    private static let maximumPixelCount = 20_000_000
    private static let maximumFileSize = 256 * 1024 * 1024

    static func decode(url: URL) -> CGImage? {
        guard let data = try? Data(contentsOf: url, options: .mappedIfSafe),
              data.count <= maximumFileSize else { return nil }

        var parser = Parser(bytes: data)
        guard let magic = parser.token(),
              let widthToken = parser.token(),
              let heightToken = parser.token(),
              let width = Int(widthToken), let height = Int(heightToken),
              width > 0, height > 0,
              width <= maximumDimension, height <= maximumDimension,
              width <= maximumPixelCount / height else { return nil }

        let isBitmap = magic == "P1" || magic == "P4"
        let isColor = magic == "P3" || magic == "P6"
        guard ["P1", "P2", "P3", "P4", "P5", "P6"].contains(magic) else { return nil }

        let maxSample: Int
        if isBitmap {
            maxSample = 1
        } else {
            guard let maxToken = parser.token(), let parsedMax = Int(maxToken),
                  (1...65_535).contains(parsedMax) else { return nil }
            maxSample = parsedMax
        }

        let pixelCount = width * height
        let samplesPerPixel = isColor ? 3 : 1
        let sampleCount = pixelCount * samplesPerPixel
        let isBinary = magic == "P4" || magic == "P5" || magic == "P6"
        let binaryStart: Int
        let rowBytes: Int

        if isBinary {
            guard parser.consumeBinarySeparator() else { return nil }
            binaryStart = parser.index
            if magic == "P4" {
                rowBytes = (width + 7) / 8
                guard parser.remaining >= rowBytes * height else { return nil }
            } else {
                rowBytes = 0
                let bytesPerSample = maxSample > 255 ? 2 : 1
                guard sampleCount <= Int.max / bytesPerSample,
                      parser.remaining >= sampleCount * bytesPerSample else { return nil }
            }
        } else {
            binaryStart = 0
            rowBytes = 0
            // Validate the complete ASCII payload before allocating decoded pixels.
            var validationParser = parser
            for _ in 0..<sampleCount {
                guard let token = validationParser.token(), let value = UInt16(token),
                      Int(value) <= maxSample else { return nil }
            }
        }

        var rgb = Data(count: pixelCount * 3)
        var decoded = true
        rgb.withUnsafeMutableBytes { rawBuffer in
            guard let output = rawBuffer.bindMemory(to: UInt8.self).baseAddress else {
                decoded = false
                return
            }

            if magic == "P4" {
                for pixel in 0..<pixelCount {
                    let row = pixel / width
                    let column = pixel % width
                    let byte = parser.bytes[binaryStart + row * rowBytes + column / 8]
                    let sample = Int((byte >> (7 - (column % 8))) & 1)
                    let gray: UInt8 = sample == 0 ? 255 : 0
                    output[pixel * 3] = gray
                    output[pixel * 3 + 1] = gray
                    output[pixel * 3 + 2] = gray
                }
                return
            }

            for sampleIndex in 0..<sampleCount {
                let value: Int
                if isBinary {
                    let bytesPerSample = maxSample > 255 ? 2 : 1
                    let offset = binaryStart + sampleIndex * bytesPerSample
                    if bytesPerSample == 1 {
                        value = Int(parser.bytes[offset])
                    } else {
                        value = Int(parser.bytes[offset]) << 8 | Int(parser.bytes[offset + 1])
                    }
                } else {
                    guard let token = parser.token(), let sample = UInt16(token),
                          Int(sample) <= maxSample else {
                        decoded = false
                        return
                    }
                    value = Int(sample)
                }

                guard value <= maxSample else {
                    decoded = false
                    return
                }

                let pixel = sampleIndex / samplesPerPixel
                let channel = sampleIndex % samplesPerPixel
                let scaled = isBitmap ? (value == 0 ? 255 : 0) : (value * 255 + maxSample / 2) / maxSample
                if isColor {
                    output[pixel * 3 + channel] = UInt8(scaled)
                } else {
                    output[pixel * 3] = UInt8(scaled)
                    output[pixel * 3 + 1] = UInt8(scaled)
                    output[pixel * 3 + 2] = UInt8(scaled)
                }
            }
        }

        guard decoded,
              let provider = CGDataProvider(data: rgb as CFData) else { return nil }
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        return CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 24,
                       bytesPerRow: width * 3, space: colorSpace,
                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
    }

    private struct Parser {
        let bytes: Data
        var index = 0
        var remaining: Int { bytes.count - index }

        mutating func token() -> String? {
            skipWhitespaceAndComments()
            let start = index
            while index < bytes.count && !Self.isWhitespace(bytes[index]) && bytes[index] != 35 {
                index += 1
            }
            guard index > start else { return nil }
            return String(bytes: bytes[start..<index], encoding: .ascii)
        }

        mutating func consumeBinarySeparator() -> Bool {
            guard index < bytes.count, Self.isWhitespace(bytes[index]) else { return false }
            if bytes[index] == 13, index + 1 < bytes.count, bytes[index + 1] == 10 {
                index += 2
            } else {
                index += 1
            }
            return true
        }

        private mutating func skipWhitespaceAndComments() {
            while index < bytes.count {
                if Self.isWhitespace(bytes[index]) {
                    index += 1
                } else if bytes[index] == 35 {
                    while index < bytes.count && bytes[index] != 10 && bytes[index] != 13 { index += 1 }
                } else {
                    break
                }
            }
        }

        private static func isWhitespace(_ byte: UInt8) -> Bool {
            byte == 9 || byte == 10 || byte == 11 || byte == 12 || byte == 13 || byte == 32
        }
    }
}
