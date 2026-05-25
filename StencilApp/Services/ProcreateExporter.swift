import CoreGraphics
import Foundation
import UIKit

/// Renders the "transparent Procreate PNG" — every pixel whose RGB are all
/// above the threshold (default 240) gets alpha=0; everything else stays
/// opaque. Mirrors `app/pipeline/export.py.export_for_procreate`.
enum ProcreateExporter {
    static func transparentPNG(from source: CGImage, whiteThreshold: UInt8 = 240) -> Data? {
        let width = source.width
        let height = source.height
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8

        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        var rawPixels = [UInt8](repeating: 0, count: width * height * bytesPerPixel)

        guard let ctx = CGContext(
            data: &rawPixels,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        ctx.draw(source, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Sweep: where R,G,B all exceed the threshold, zero the alpha.
        let pixelCount = width * height
        for i in 0..<pixelCount {
            let offset = i * bytesPerPixel
            let r = rawPixels[offset]
            let g = rawPixels[offset + 1]
            let b = rawPixels[offset + 2]
            if r > whiteThreshold, g > whiteThreshold, b > whiteThreshold {
                rawPixels[offset]     = 0
                rawPixels[offset + 1] = 0
                rawPixels[offset + 2] = 0
                rawPixels[offset + 3] = 0
            }
            // Else: leave RGBA as-is.
        }

        guard let outCG = ctx.makeImage() else { return nil }
        return UIImage(cgImage: outCG).pngData()
    }
}
