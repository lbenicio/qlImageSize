import CoreGraphics
import Foundation
import XCTest
@testable import NetpbmDecoder

final class NetpbmDecoderTests: XCTestCase {
    func testP1ASCIIParsesCommentsAndMapsBlackAndWhite() throws {
        let image = try decode("P1\n# sample image\n2 2\n0 1\n1 0\n")

        XCTAssertEqual(image.width, 2)
        XCTAssertEqual(image.height, 2)
        XCTAssertEqual(try rgbBytes(image), [255, 255, 255, 0, 0, 0, 0, 0, 0, 255, 255, 255])
    }

    func testP2ASCIIScalesGrayscaleSamples() throws {
        let image = try decode("P2\n3 1\n15\n0 7 15\n")

        XCTAssertEqual(try rgbBytes(image), [0, 0, 0, 119, 119, 119, 255, 255, 255])
    }

    func testP3ASCIIReadsColorSamples() throws {
        let image = try decode("P3\n2 1\n255\n1 2 3 255 127 0\n")

        XCTAssertEqual(try rgbBytes(image), [1, 2, 3, 255, 127, 0])
    }

    func testP4BinaryHonorsRowPadding() throws {
        let image = try decode("P4\n3 1\n", payload: [0b1010_0000])

        XCTAssertEqual(try rgbBytes(image), [0, 0, 0, 255, 255, 255, 0, 0, 0])
    }

    func testP5BinaryTreatsOnlyTheHeaderSeparatorAsWhitespace() throws {
        let image = try decode("P5\n3 1\n255\n", payload: [32, 128, 255])

        XCTAssertEqual(try rgbBytes(image), [32, 32, 32, 128, 128, 128, 255, 255, 255])
    }

    func testP6BinaryReadsSixteenBitSamples() throws {
        let image = try decode("P6\n1 1\n65535\n", payload: [0, 0, 0x80, 0, 0xff, 0xff])

        XCTAssertEqual(try rgbBytes(image), [0, 128, 255])
    }

    func testRejectsUnsupportedMagic() throws {
        XCTAssertNil(try decodeIfValid("P7\n1 1\n255\n0\n"))
    }

    func testRejectsInvalidDimensionsAndPixelCount() throws {
        let invalidHeaders = [
            "P6\n0 1\n255\n",
            "P6\n1 0\n255\n",
            "P6\n-1 1\n255\n",
            "P6\n5000 5000\n255\n",
        ]

        for header in invalidHeaders {
            XCTAssertNil(try decodeIfValid(header), "Expected rejection for: \(header.debugDescription)")
        }
    }

    func testRejectsOverflowingDimensionToken() throws {
        XCTAssertNil(try decodeIfValid("P6\n999999999999999999999999999999 1\n255\n"))
    }

    func testRejectsInvalidMaximumSampleValue() throws {
        XCTAssertNil(try decodeIfValid("P5\n1 1\n65536\n\u{0000}"))
        XCTAssertNil(try decodeIfValid("P5\n1 1\n0\n\u{0000}"))
    }

    func testRejectsTruncatedBinaryPayloads() throws {
        XCTAssertNil(try decodeIfValid("P6\n1 1\n255\n", payload: [0, 1]))
        XCTAssertNil(try decodeIfValid("P4\n9 2\n", payload: [0xff, 0xff]))
    }

    func testRejectsBinaryAndASCIIValuesAboveMaximum() throws {
        XCTAssertNil(try decodeIfValid("P5\n1 1\n1\n", payload: [2]))
        XCTAssertNil(try decodeIfValid("P2\n1 1\n1\n2\n"))
    }

    func testRejectsMissingBinaryHeaderSeparator() throws {
        XCTAssertNil(try decodeIfValid("P5\n1 1\n255"))
    }

    func testRejectsIncompleteASCIIChannels() throws {
        XCTAssertNil(try decodeIfValid("P3\n1 1\n255\n1 2\n"))
    }

    private func decode(_ header: String, payload: [UInt8] = []) throws -> CGImage {
        guard let image = try decodeIfValid(header, payload: payload) else {
            XCTFail("Expected valid Netpbm image")
            throw TestError.invalidImage
        }
        return image
    }

    private func decodeIfValid(_ header: String, payload: [UInt8] = []) throws -> CGImage? {
        var data = Data(header.utf8)
        data.append(contentsOf: payload)

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("netpbm-\(UUID().uuidString).pnm")
        defer { try? FileManager.default.removeItem(at: url) }
        try data.write(to: url)
        return NetpbmDecoder.decode(url: url)
    }

    private func rgbBytes(_ image: CGImage) throws -> [UInt8] {
        guard let provider = image.dataProvider,
              let providerData = provider.data else {
            throw TestError.missingImageData
        }
        return Array(providerData as Data)
    }

    private enum TestError: Error {
        case invalidImage
        case missingImageData
    }
}
