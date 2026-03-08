// CGImage extensions
//
// Copyright Chris Ridd 2026

import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import Foundation

extension CGImage {
    public static func fromBytes(_ raw: [UInt8], imageWidth: Int, imageHeight: Int) -> CGImage? {
        let pixelData = Data(raw)
        let provider = CGDataProvider(data: pixelData as CFData)!
        let bitmap = CGBitmapInfo(alpha: .none, component: .integer, byteOrder: .orderDefault)
        return CGImage(width: imageWidth,
                       height: imageHeight,
                       bitsPerComponent: 8,
                       bitsPerPixel: 24,
                       bytesPerRow: imageWidth * 3,
                       space: CGColorSpaceCreateDeviceRGB(),
                       bitmapInfo: bitmap,
                       provider: provider,
                       decode: nil,
                       shouldInterpolate: false,
                       intent: .defaultIntent)
    }
}

extension CGImage {
    public static func fromPNGData() -> CGImage? {
        return nil
    }
}

extension CGImage {
    public func toBytes() -> Data? {
        return nil
    }
}

extension CGImage {
    public func toPNGData() -> Data? {
        let cfdata = CFDataCreateMutable(nil, 0)!
        guard let destination = CGImageDestinationCreateWithData(cfdata, String(describing: UTType.png) as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, self, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return cfdata as Data
    }
}
