import XCTest
import UIKit
import CoreGraphics
@testable import StencilApp

final class ProcreateExporterTests: XCTestCase {

    /// A 2×2 fixture: top row white-on-white, bottom row pure black.
    /// After exporting, the white pixels must become transparent and the
    /// black pixels must stay opaque.
    func testWhitePixelsBecomeTransparent() throws {
        guard let source = makeFixtureImage() else {
            return XCTFail("Could not construct fixture image")
        }
        guard let data = ProcreateExporter.transparentPNG(from: source) else {
            return XCTFail("transparentPNG returned nil")
        }

        // Decode the PNG back into pixels and inspect alpha.
        guard let decoded = UIImage(data: data)?.cgImage else {
            return XCTFail("Could not decode exported PNG")
        }
        let pixels = try readPixels(from: decoded)
        XCTAssertEqual(pixels.count, 4)

        // Pixel layout depends on CG coordinate flip — we just check the set
        // of alpha values. After the export there must be exactly two
        // transparent pixels (the white half) and two opaque pixels (the black
        // half), regardless of orientation.
        let alphas = pixels.map { $0.a }.sorted()
        XCTAssertEqual(alphas, [0, 0, 255, 255],
                       "Exactly the white pixels should have been cleared to alpha=0")
    }

    func testThresholdParameterControlsCutoff() throws {
        // Build a fixture with mid-grey pixels (200). With the default
        // threshold (240) they should remain opaque; with a 150 threshold
        // they should become transparent.
        guard let midGrey = makeUniformGrey(value: 200) else {
            return XCTFail("Could not make grey fixture")
        }
        guard let strictData = ProcreateExporter.transparentPNG(
            from: midGrey,
            whiteThreshold: 240
        ) else {
            return XCTFail("Strict export returned nil")
        }
        guard let looseData = ProcreateExporter.transparentPNG(
            from: midGrey,
            whiteThreshold: 150
        ) else {
            return XCTFail("Loose export returned nil")
        }

        let strictAlphas = try readPixels(from: UIImage(data: strictData)!.cgImage!).map(\.a)
        let looseAlphas  = try readPixels(from: UIImage(data: looseData)!.cgImage!).map(\.a)

        XCTAssertTrue(strictAlphas.allSatisfy { $0 == 255 },
                      "All 200/255 grey pixels should stay opaque at threshold 240")
        XCTAssertTrue(looseAlphas.allSatisfy { $0 == 0 },
                      "All 200/255 grey pixels should become transparent at threshold 150")
    }

    // MARK: - Helpers

    /// Builds a 2x2 image: top row pure white, bottom row pure black.
    private func makeFixtureImage() -> CGImage? {
        let width = 2, height = 2
        let bytesPerPixel = 4
        var pixels = [UInt8](repeating: 0, count: width * height * bytesPerPixel)
        // Row 0 (top in CG space is bottom of array): white
        for x in 0..<width {
            let offset = (0 * width + x) * bytesPerPixel
            pixels[offset]     = 255
            pixels[offset + 1] = 255
            pixels[offset + 2] = 255
            pixels[offset + 3] = 255
        }
        // Row 1: black
        for x in 0..<width {
            let offset = (1 * width + x) * bytesPerPixel
            pixels[offset]     = 0
            pixels[offset + 1] = 0
            pixels[offset + 2] = 0
            pixels[offset + 3] = 255
        }
        return makeCGImage(rgba: pixels, width: width, height: height)
    }

    private func makeUniformGrey(value: UInt8) -> CGImage? {
        let width = 2, height = 2
        let bytesPerPixel = 4
        var pixels = [UInt8](repeating: 0, count: width * height * bytesPerPixel)
        for i in 0..<(width * height) {
            let offset = i * bytesPerPixel
            pixels[offset]     = value
            pixels[offset + 1] = value
            pixels[offset + 2] = value
            pixels[offset + 3] = 255
        }
        return makeCGImage(rgba: pixels, width: width, height: height)
    }

    private func makeCGImage(rgba: [UInt8], width: Int, height: Int) -> CGImage? {
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        guard let space = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        var mutable = rgba
        guard let ctx = CGContext(
            data: &mutable,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: space,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        return ctx.makeImage()
    }

    private struct Pixel { let r, g, b, a: UInt8 }

    private func readPixels(from cg: CGImage) throws -> [Pixel] {
        let width = cg.width, height = cg.height
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        var raw = [UInt8](repeating: 0, count: width * height * bytesPerPixel)
        guard let space = CGColorSpace(name: CGColorSpace.sRGB) else {
            throw NSError(domain: "ProcreateExporterTests", code: -1)
        }
        guard let ctx = CGContext(
            data: &raw,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: space,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw NSError(domain: "ProcreateExporterTests", code: -2)
        }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))

        var out: [Pixel] = []
        for i in 0..<(width * height) {
            let offset = i * bytesPerPixel
            out.append(Pixel(
                r: raw[offset],
                g: raw[offset + 1],
                b: raw[offset + 2],
                a: raw[offset + 3]
            ))
        }
        return out
    }
}
