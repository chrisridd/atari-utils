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

    func getRGB(_ index: Int) -> (UInt8, UInt8, UInt8) {
        switch self {
        case let .sttt(xbios):
            let r8 = (xbios[index].0 * 255) / 15;
            let g8 = (xbios[index].1 * 255) / 15;
            let b8 = (xbios[index].2 * 255) / 15;
            return (UInt8(r8), UInt8(g8), UInt8(b8))
        case let .ximg(vdi):
            let r8 = (UInt32(vdi[index].0) * 255) / 1000;
            let g8 = (UInt32(vdi[index].1) * 255) / 1000;
            let b8 = (UInt32(vdi[index].2) * 255) / 1000;
            return (UInt8(r8), UInt8(g8), UInt8(b8))
        case .none:
            return (0, 0, 0)
        }
    }
}

public enum IMGError: Error {
    case unrecognizedPalette(String)
    case invalidColorMode(String)
    case badPaletteSize(String)
}

public struct IMG {
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

    public init(_ data: Data) throws {
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
            let signature = data[pos+16..<pos+20]
            if signature == IMG.signatureSTTT {
                // Next word is the palette size
                let xbiosSize = Int16(bigEndian: data[pos+20..<pos+22].to(type: Int16.self)!)
                if planes <= 8 && xbiosSize != (1 << planes) {
                    throw IMGError.badPaletteSize("STTT palette is \(xbiosSize) and should be \(1 << planes)")
                }
                var headerPos = pos + 22
                var xbiosPalette: [(Int16, Int16, Int16)] = []
                while (headerPos - pos) < headerLength * 2 {
                    let xbios = Int16(bigEndian: data[headerPos..<headerPos+2].to(type: Int16.self)!)
                    let r = (xbios >> 8) & 0x0f
                    let g = (xbios >> 4) & 0x0f
                    let b = (xbios >> 0) & 0x0f
                    headerPos += 2
                    xbiosPalette.append((r, g, b))
                }
                if planes <= 8 && xbiosPalette.count != (1 << planes) {
                    throw IMGError.badPaletteSize("STTT palette is \(xbiosPalette.count) and should be \(1 << planes)")
                }
                palette = .sttt(xbiosPalette)
            } else if signature == IMG.signatureXIMG {
                // Next word is the colour mode, 0 means RGB.
                let colorMode = Int16(bigEndian: data[pos+20..<pos+22].to(type: Int16.self)!)
                if colorMode != 0 {
                    throw IMGError.invalidColorMode("XIMG color mode \(colorMode) is not supported")
                }
                var headerPos = pos + 22
                var ximgPalette: [(Int16, Int16, Int16)] = []
                while (headerPos - pos) < headerLength * 2 {
                    let r = Int16(bigEndian: data[headerPos..<headerPos+2].to(type: Int16.self)!)
                    headerPos += 2
                    let g = Int16(bigEndian: data[headerPos..<headerPos+2].to(type: Int16.self)!)
                    headerPos += 2
                    let b = Int16(bigEndian: data[headerPos..<headerPos+2].to(type: Int16.self)!)
                    headerPos += 2
                    ximgPalette.append((r, g, b))
                }
                if planes <= 8 && ximgPalette.count != (1 << planes) {
                    throw IMGError.badPaletteSize("XIMG palette is \(ximgPalette.count) and should be \(1 << planes)")
                }
                palette = .ximg(ximgPalette)
            } else {
                throw IMGError.unrecognizedPalette("Palette is not XIMG or STTT")
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
