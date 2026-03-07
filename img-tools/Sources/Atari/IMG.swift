// Atari IMG format
//
// Copyright Chris Ridd 2026

import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

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
    case sttt([(Int16, Int16, Int16)]) // 0-15 per channel, or 0-7?
    case ximg([(Int16, Int16, Int16)]) // 0-1000 per channel
    case mono([(UInt8, UInt8, UInt8)]) // 0-255 per channel

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
        case let .mono(rgb):
            return (rgb[index].0, rgb[index].1, rgb[index].2)
        case .none:
            return (0, 0, 0)
        }
    }
}

public enum IMGError: Error {
    case unrecognizedPalette(String)
    case invalidColorMode(String)
    case badPaletteSize(String)
    case cannotCreatePNG(String)
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
    let rawPixels: [[UInt32]]

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
            if planes == 1 {
                // fake a palette of white+black
                palette = .mono([(UInt8(255), UInt8(255), UInt8(255)),
                                 (UInt8(0), UInt8(0), UInt8(0))])
            } else {
                palette = .none
            }
        } else {
            let signature = data[pos+16..<pos+20]
            if signature == IMG.signatureSTTT {
                // Next word is the palette size
                let xbiosSize = Int16(bigEndian: data[pos+20..<pos+22].to(type: Int16.self)!)
                if planes <= 8 && xbiosSize != (1 << planes) {
                    throw IMGError.badPaletteSize("STTT palette is \(xbiosSize) and should be \(1 << planes)")
                }
                var palettePos = pos + 22
                let paletteEnd = data.startIndex + Int(headerLength) * 2
                var xbiosPalette: [(Int16, Int16, Int16)] = []
                while palettePos < paletteEnd {
                    let xbios = Int16(bigEndian: data[palettePos..<palettePos+2].to(type: Int16.self)!)
                    let r = (xbios >> 8) & 0x0f
                    let g = (xbios >> 4) & 0x0f
                    let b = (xbios >> 0) & 0x0f
                    palettePos += 2
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
                let paletteStart = pos + 22
                let paletteEnd = data.startIndex + Int(headerLength) * 2
                let ximgPalette = try readVDIPalette(data[paletteStart..<paletteEnd])
                if planes <= 8 && ximgPalette.count != (1 << planes) {
                    throw IMGError.badPaletteSize("XIMG palette is \(ximgPalette.count) and should be \(1 << planes)")
                }
                palette = .ximg(ximgPalette)
            } else {
                throw IMGError.unrecognizedPalette("Palette is not XIMG or STTT")
            }
        }

        var pixelPos = data.startIndex + Int(headerLength) * 2
        var scanlines: [[UInt32]] = []
        var y = 0
        while y < imageHeight {
            var repeatCount = 1
            #if DEBUG
            print("y=\(y) decoding from \(pixelPos) to \(data.endIndex)", terminator: "")
            #endif
            if data[pixelPos] == 0x00 && data[pixelPos+1] == 0x00 && data[pixelPos+2] == 0xff {
                // replication count
                repeatCount = Int(data[pixelPos+3])
                #if DEBUG
                print(" repeat x\(repeatCount)", terminator: "")
                #endif
                pixelPos += 4
            }
            #if DEBUG
            print("")
            #endif
            var pixels: [UInt32] = Array(repeating: 0, count: Int(imageWidth))
            // Or `in (0..<planes).reversed()` ?
            for plane in 0..<planes {
                pixelPos = IMG.decodeScanline(data[pixelPos..<data.endIndex], patternLength: patternLength, pixels: &pixels, value: 1 << plane)
            }
            for _ in 0..<repeatCount {
                scanlines.append(pixels)
            }
            y += repeatCount
        }
        rawPixels = scanlines

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

    static func decodeScanline(_ data: Data, patternLength: Int16, pixels: inout [UInt32], value: UInt32) -> Int {
        var x = 0
        var pos = data.startIndex
        while x < pixels.count {
            // each kind of repeat could overrun the pixels width, which is "OK". marisa.img is a good case.
            #if DEBUG
            print("pos=\(pos) x=\(x) pixels.count=\(pixels.count)", terminator: " ")
            #endif
            if data[pos] == 0x80 {
                // literal bit string
                let count = Int(data[pos+1])
                #if DEBUG
                print("literal \(count)")
                #endif
                pos += 2
                var loopPos = pos
                literalLoop: for _ in 0..<count {
                    let byte = data[loopPos]
                    #if DEBUG
                    print("literal byte \(String(byte, radix: 16, uppercase: false))")
                    #endif
                    loopPos += 1
                    if x == pixels.count { break literalLoop }
                    pixels[x] += (byte & 0x80 != 0 ? value : 0)
                    #if DEBUG
                    print("pixels[\(x)] += \(byte & 0x80 != 0 ? value : 0)")
                    #endif
                    x += 1
                    if x == pixels.count { break literalLoop }
                    pixels[x] += (byte & 0x40 != 0 ? value : 0)
                    #if DEBUG
                    print("pixels[\(x)] += \(byte & 0x40 != 0 ? value : 0)")
                    #endif
                    x += 1
                    if x == pixels.count { break literalLoop }
                    pixels[x] += (byte & 0x20 != 0 ? value : 0)
                    #if DEBUG
                    print("pixels[\(x)] += \(byte & 0x20 != 0 ? value : 0)")
                    #endif
                    x += 1
                    if x == pixels.count { break literalLoop }
                    pixels[x] += (byte & 0x10 != 0 ? value : 0)
                    #if DEBUG
                    print("pixels[\(x)] += \(byte & 0x10 != 0 ? value : 0)")
                    #endif
                    x += 1
                    if x == pixels.count { break literalLoop }
                    pixels[x] += (byte & 0x08 != 0 ? value : 0)
                    #if DEBUG
                    print("pixels[\(x)] += \(byte & 0x08 != 0 ? value : 0)")
                    #endif
                    x += 1
                    if x == pixels.count { break literalLoop }
                    pixels[x] += (byte & 0x04 != 0 ? value : 0)
                    #if DEBUG
                    print("pixels[\(x)] += \(byte & 0x04 != 0 ? value : 0)")
                    #endif
                    x += 1
                    if x == pixels.count { break literalLoop }
                    pixels[x] += (byte & 0x02 != 0 ? value : 0)
                    #if DEBUG
                    print("pixels[\(x)] += \(byte & 0x02 != 0 ? value : 0)")
                    #endif
                    x += 1
                    if x == pixels.count { break literalLoop }
                    pixels[x] += (byte & 0x01 != 0 ? value : 0)
                    #if DEBUG
                    print("pixels[\(x)] += \(byte & 0x01 != 0 ? value : 0)")
                    #endif
                    x += 1
                }
                // ensure pos is correct even if we exited the loop early
                pos += count
            } else if data[pos] == 0x00 {
                // pattern run
                let count = Int(data[pos+1])
                #if DEBUG
                print("pattern \(count)")
                #endif
                var pattern: [UInt32] = []
                pos += 2
                for _ in 0..<patternLength {
                    let byte = data[pos]
                    pattern.append(byte & 0x80 != 0 ? value : 0)
                    pattern.append(byte & 0x40 != 0 ? value : 0)
                    pattern.append(byte & 0x20 != 0 ? value : 0)
                    pattern.append(byte & 0x10 != 0 ? value : 0)
                    pattern.append(byte & 0x08 != 0 ? value : 0)
                    pattern.append(byte & 0x04 != 0 ? value : 0)
                    pattern.append(byte & 0x02 != 0 ? value : 0)
                    pattern.append(byte & 0x01 != 0 ? value : 0)
                    pos += 1
                }
                patternLoop: for _ in 0..<count {
                    for i in pattern {
                        if x == pixels.count { break patternLoop }
                        pixels[x] += i
                        x += 1
                    }
                }
            } else {
                // solid run
                let count = Int(data[pos] & 0x7f)
                #if DEBUG
                print("solid \(count)")
                #endif
                let pixel = data[pos] & 0x80 != 0 ? value : 0
                let nextX = x + count * 8
                solidLoop: for _ in 0..<count {
                    for _ in 0..<8 {
                        if x == pixels.count { break solidLoop }
                        pixels[x] += pixel
                        #if DEBUG
                        print("pixels[\(x)] += \(pixel) [solid]")
                        #endif
                        x += 1
                    }
                }
                pos += 1
                x = nextX
                #if DEBUG
                print("now x=\(x) and pos=\(pos)")
                #endif
            }
        }
        return pos
    }

    func uniquePixels() -> [UInt32: Int] {
        var counts: [UInt32:Int] = [:]
        for row in rawPixels {
            for pixel in row {
                let count = counts[pixel] ?? 0
                counts[pixel] = count + 1
            }
        }
        return counts
    }

    public func toPNG() throws -> Data {
        var raw: [UInt8] = Array(repeating: 0, count: Int(imageWidth) * Int(imageHeight) * 3)
        var i = 0
        for row in rawPixels {
            for pixel in row {
                let index = Int(pixel & 0xFF)
                let (r, g, b) = palette.getRGB(index)
                raw[i + 0] = r
                raw[i + 1] = g
                raw[i + 2] = b
                i += 3
            }
        }
        let pixelData = Data(raw)
        // fill in pixelData!
        let provider = CGDataProvider(data: pixelData as CFData)!
        let bitmap = CGBitmapInfo(alpha: .none, component: .integer, byteOrder: .orderDefault)
        if let image = CGImage(width: Int(imageWidth),
                               height: Int(imageHeight),
                               bitsPerComponent: 8,
                               bitsPerPixel: 24,
                               bytesPerRow: Int(imageWidth) * 3,
                               space: CGColorSpaceCreateDeviceRGB(),
                               bitmapInfo: bitmap,
                               provider: provider,
                               decode: nil,
                               shouldInterpolate: false,
                               intent: .defaultIntent) {
            // convert to PNG
            print("Created image OK")
            let cfdata = CFDataCreateMutable(nil, 0)!
            if let destination = CGImageDestinationCreateWithData(cfdata, String(describing: UTType.png) as CFString, 1, nil) {
                CGImageDestinationAddImage(destination, image, nil)
                if CGImageDestinationFinalize(destination) {
                    return cfdata as Data
                }
            }
            throw IMGError.cannotCreatePNG("CGImageDestination creation failed")
        }
        print("Failed to create image")
        throw IMGError.cannotCreatePNG("CGImage creation failed")
    }
}
