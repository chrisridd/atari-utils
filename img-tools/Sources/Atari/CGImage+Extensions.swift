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

// untested
extension CGImage {
    public static func fromPNGData(_ data: Data) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }
}

// untested
extension CGImage {
    public func toBytes() -> [UInt8]? {
        var pixels = [UInt8](repeating: 0, count: self.width * self.height * 3)
        guard let context = CGContext(data: &pixels,
                                      width: self.width,
                                      height: self.height,
                                      bitsPerComponent: 8,
                                      bytesPerRow: self.width * 3,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: 0) else { return nil }
        context.draw(self, in: CGRect(x: 0, y: 0, width: self.width, height: self.height))
        return pixels
    }
}

extension CGImage {
    public func toPNGData() -> Data? {
        let data = CFDataCreateMutable(nil, 0)!
        guard let destination = CGImageDestinationCreateWithData(data, String(describing: UTType.png) as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, self, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }
}
