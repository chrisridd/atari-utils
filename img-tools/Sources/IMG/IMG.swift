// Atari IMG format
//
// Copyright Chris Ridd 2026

import Foundation

extension FixedWidthInteger {
    var dataBigEndian: Data {
        var int = self.bigEndian
        return Data(bytes: &int, count: MemoryLayout<Self>.size)
    }
}

extension Data {
    init<T>(from value: T) {
        self = Swift.withUnsafeBytes(of: value) { Data($0) }
    }

    func to<T>(type: T.Type) -> T? where T: ExpressibleByIntegerLiteral {
        var value: T = 0
        guard count >= MemoryLayout.size(ofValue: value) else { return nil }
        _ = Swift.withUnsafeMutableBytes(of: &value, { copyBytes(to: $0)} )
        return value
    }
}


public enum Palette {
    case none
    case sttt([(Int16, Int16, Int16)]) // 0-15 per channel
    case ximg([(Int16, Int16, Int16)]) // 0-1000 per channel
}

public struct Image {
    let version: Int16
    let headerLength: Int16
    let planes: Int16
    let patternLength: Int16
    let pixelWidth: Int16
    let pixelHeight: Int16
    let imageWidth: Int16
    let imageHeight: Int16
    let palette: Palette

    static let signatureSTTT = "STTT".data(using: .ascii)
    static let signatureXIMG = "XIMG".data(using: .ascii)

    public init(_ data: Data) {
        let pos = data.startIndex
        version = Int16(bigEndian: data[pos..<pos+2].to(type: Int16.self)!)
        headerLength = Int16(bigEndian: data[pos+2..<pos+4].to(type: Int16.self)!)
        planes = Int16(bigEndian: data[pos+4..<pos+6].to(type: Int16.self)!)
        patternLength = Int16(bigEndian: data[pos+6..<pos+8].to(type: Int16.self)!)
        pixelWidth = Int16(bigEndian: data[pos+8..<pos+10].to(type: Int16.self)!)
        pixelHeight = Int16(bigEndian: data[pos+10..<pos+12].to(type: Int16.self)!)
        imageWidth = Int16(bigEndian: data[pos+12..<pos+14].to(type: Int16.self)!)
        imageHeight = Int16(bigEndian: data[pos+14..<pos+16].to(type: Int16.self)!)
        if headerLength == 8 {
            palette = .none
        } else {
            // Should the palettes be normalized somehow, or just kept as-is like now?
            let signature = data[pos+16..<pos+20]
            if signature == Image.signatureSTTT {
                // skip over the palette size, just read until we run out of header
                var headerPos = pos + 22
                var xbiosPalette: [(Int16, Int16, Int16)] = []
                while headerPos < headerLength * 2 {
                    let xbios = Int16(bigEndian: data[headerPos..<headerPos+2].to(type: Int16.self)!)
                    let r = (xbios >> 8) & 0x0f
                    let g = (xbios >> 4) & 0x0f
                    let b = (xbios >> 0) & 0x0f
                    headerPos += 2
                    xbiosPalette.append((r, g, b))
                }
                palette = .sttt(xbiosPalette)
            } else if signature == Image.signatureXIMG {
                // Skip over a color marker word. Hope it is always 0.
                var headerPos = pos + 22
                var ximgPalette: [(Int16, Int16, Int16)] = []
                while headerPos < headerLength * 2 {
                    let r = Int16(bigEndian: data[headerPos..<headerPos+2].to(type: Int16.self)!)
                    headerPos += 2
                    let g = Int16(bigEndian: data[headerPos..<headerPos+2].to(type: Int16.self)!)
                    headerPos += 2
                    let b = Int16(bigEndian: data[headerPos..<headerPos+2].to(type: Int16.self)!)
                    headerPos += 2
                    ximgPalette.append((r, g, b))
                }
                palette = .ximg(ximgPalette)
            } else {
                palette = .none
            }
        }
        print("""
            version: \(version)
            headerLength: \(headerLength) words
            planes: \(planes)
            patternLength: \(patternLength)
            pixelWidth: \(pixelWidth) microns
            pixelHeight: \(pixelHeight) microns
            imageWidth: \(imageWidth) pixels
            imageHeight: \(imageHeight) pixels
            palette: \(palette)
            """)
    }
}
