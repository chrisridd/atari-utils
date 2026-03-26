// Atari IMG format
//
// Copyright Chris Ridd 2026

import Foundation
import CoreGraphics

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


/// A model representing the palette present in an ```IMG``` file.
public enum Palette {
    /// No palette is present.
    case none
    /// An XBIOS palette is present, as used by IMG files with the "STTT" extension.
    case xbios([(Int16, Int16, Int16)]) // 0-15 per channel, or 0-7?
    /// A VDI palette is present, as used by IMG files with the "XIMG" extension.
    case vdi([(Int16, Int16, Int16)]) // 0-1000 per channel
    /// A monochrome image is present.
    case mono([(UInt8, UInt8, UInt8)]) // 0-255 per channel

    func getRGB(_ index: Int) -> (UInt8, UInt8, UInt8) {
        switch self {
        case let .xbios(xbios):
            let r8 = (xbios[index].0 * 255) / 15;
            let g8 = (xbios[index].1 * 255) / 15;
            let b8 = (xbios[index].2 * 255) / 15;
            return (UInt8(r8), UInt8(g8), UInt8(b8))
        case let .vdi(vdi):
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

/// Errors that can be thrown by ```IMG``` functions.
public enum IMGError: Error {
    /// The palette format is not recognized. Only `XIMG` and `STTT` palettes are recognized.
    case unrecognizedPalette(String)
    /// Only palettes with RGB colours are recognized.
    case invalidColorMode(String)
    /// The palette is encoded with the wrong size for the number of bits per pixel.
    case badPaletteSize(String)
    /// The image could not be turned by ```CoreGraphics``` into a PNG.
    case cannotCreatePNG(String)
    /// The IMG could not be turned into a ```CGImage```.
    case cannotCreateImage(String)
    /// The data is incomplete/truncated
    case missingData(String)
}

/// A model representing an IMG file.
///
/// IMG files can contain indexed colour images, which are between 1 and 8 bits per pixel. They can contain Falcon-style "HiColor" images
/// which are 15 bits per pixel, and they can contain more standard "TrueColor" images which are 24 bits per pixel. However the most
/// common kind is monochrome 1 bit per pixel.
///
/// The IMG format was originally developed by Digital Research Inc (DRI) but it has been extended in a few different ways
/// over time by Atari application developers. The most common kinds of extension encode a colour palette, which is needed to correctly
/// display most images between 1 and 8 bits per pixel.
///
/// Truly monochrome (black/white) images don't need a colour palette. By definition, HiColor and TrueColor images don't need a colour palette.
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
    let rawPixels: [[UInt32]] // either indexes (planes <= 8) or actual RGB

    static let signatureSTTT = "STTT".data(using: .ascii)
    static let signatureXIMG = "XIMG".data(using: .ascii)

    init(version: Int16, headerLength: Int16, planes: Int16, patternLength: Int16, pixelWidth: Int16, pixelHeight: Int16, imageWidth: Int16, imageHeight: Int16, palette: Palette, rawPixels: [[UInt32]]) {
        self.version = version
        self.headerLength = headerLength
        self.planes = planes
        self.patternLength = patternLength
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.imageWidth = imageWidth
        self.imageHeight = imageHeight
        self.palette = palette
        self.rawPixels = rawPixels
    }

    /// Construct an IMG instance from PNG data
    ///
    /// - Parameter pngData: PNG-encoded data
    public init(pngData: Data) throws {
        version = 1
        patternLength = 2
        pixelWidth = 85
        pixelHeight = 85

        guard let image = CGImage.fromPNGData(pngData) else { throw IMGError.cannotCreateImage("reading PNG failed") }
        guard let bytes = image.toBytes() else { throw IMGError.cannotCreateImage("converting to bytes") }
        imageWidth = Int16(image.width)
        imageHeight = Int16(image.height)

        // Compute the palette
        // need rgb -> index Dictionary
        // need vdi array in same order
        var scanlines: [[UInt32]] = []
        var uniqueColours: [UInt32: UInt32] = [:]
        var uniqueVDIPalette: [(Int16, Int16, Int16)] = []
        var pos = 0
        while pos < bytes.count {
            // pos[0] = alpha (ignore)
            let rgb =
                UInt32(bytes[pos + 1]) << 16 |
                UInt32(bytes[pos + 2]) << 8 |
                UInt32(bytes[pos + 3]) << 0
            if uniqueColours[rgb] == nil {
                let r16 = (UInt32(bytes[pos + 1]) * 1000) / 255
                let g16 = (UInt32(bytes[pos + 2]) * 1000) / 255
                let b16 = (UInt32(bytes[pos + 3]) * 1000) / 255
                uniqueColours[rgb] = UInt32(uniqueVDIPalette.count)
                uniqueVDIPalette.append((Int16(r16), Int16(g16), Int16(b16)))
                print("Adding uniqueColors[\(String(format: "%06x", rgb))] - palette(\(r16), \(g16), \(b16))")
            }
            pos += 4
        }
        // for b/w monochrome, need to make sure the palette is in the right order so
        // that the rawPixels make sense as-is
        if uniqueColours.count == 2 {
            print("monochrome palette \(uniqueVDIPalette)")
            print("monochrome map \(uniqueColours)")
            let entry0Black = uniqueVDIPalette[0].0 == 0 && uniqueVDIPalette[0].1 == 0 && uniqueVDIPalette[0].2 == 0
            let entry1Black = uniqueVDIPalette[1].0 == 0 && uniqueVDIPalette[1].0 == 0 && uniqueVDIPalette[1].2 == 0
            if entry0Black && !entry1Black {
                print("black + white")
            } else if !entry0Black && entry1Black {
                print("white + black")
                uniqueVDIPalette = [(Int16(0), Int16(0), Int16(0)), (Int16(1000), Int16(1000), Int16(1000))]
                uniqueColours = [ 0xffffff: 0, 0x000000: 1]
                print("updated palette \(uniqueVDIPalette)")
                print("updated map \(uniqueColours)")
            } else {
                print("coloured")
            }
        }
        (planes, palette, headerLength) = IMG.buildPalette(uniqueVDIPalette)

        pos = 0
        for _ in 0..<imageHeight {
            var scanline: [UInt32] = []
            for _ in 0..<imageWidth {
                let rgb =
                    UInt32(bytes[pos + 1]) << 16 |
                    UInt32(bytes[pos + 2]) << 8 |
                    UInt32(bytes[pos + 3]) << 0
                switch palette {
                case .none:
                    scanline.append(rgb)
                case .vdi, .mono:
                    scanline.append(uniqueColours[rgb]!)
//                    print("appending \(String(format: "%06x", rgb)) -> \(uniqueColours[rgb]!)")
                default:
                    throw IMGError.unrecognizedPalette("Only allowing TrueColour and VDI palettes for now.")
                }
                pos += 4
            }
            scanlines.append(scanline)
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

    static func getPixelRGB(_ pixel: UInt32) -> (UInt8, UInt8, UInt8) {
        let rchannel = (pixel >> 16) & 0xFF
        let gchannel = (pixel >> 8) & 0xFF
        let bchannel = (pixel >> 0) & 0xFF
        return (UInt8(rchannel), UInt8(gchannel), UInt8(bchannel))
    }

    /// Convert the image into a PNG
    ///
    /// -Returns: an encoded PNG
    public func toPNG() throws -> Data {
        var raw: [UInt8] = Array(repeating: 0, count: Int(imageWidth) * Int(imageHeight) * 3)
        var i = 0
        for row in rawPixels {
            for pixel in row {
                let (r, g, b) = if planes <= 8 {
                    palette.getRGB(Int(pixel & 0xFF))
                } else {
                    IMG.getPixelRGB(pixel)
                }
                raw[i + 0] = r
                raw[i + 1] = g
                raw[i + 2] = b
                i += 3
            }
        }

        guard let image = CGImage.fromBytes(raw, imageWidth: Int(imageWidth), imageHeight: Int(imageHeight)) else { throw IMGError.cannotCreatePNG("Error creating CGImage") }

        guard let data = image.toPNGData() else { throw IMGError.cannotCreatePNG("Error creating PNG") }

        return data
    }

}

/// importing from IMG files
extension IMG {
    /// Create an instance from encoded IMG data
    ///
    /// - Parameter data: a whole IMG file
    /// - Throws: an ``IMGError`` if the IMG file used an unknown palette
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
            // a bit of a hack for image generation
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
                palette = .xbios(xbiosPalette)
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
                palette = .vdi(ximgPalette)
            } else {
                throw IMGError.unrecognizedPalette("Palette is not XIMG or STTT")
            }
        }

        var pixelPos = data.startIndex + Int(headerLength) * 2
        var scanlines: [[UInt32]] = []
        var y = 0
        while y < imageHeight {
            var repeatCount = 1
            guard pixelPos < data.endIndex else { throw IMGError.missingData("No data for row \(y)") }
//            print("y=\(y) decoding from \(pixelPos) to \(data.endIndex)", terminator: "")
            if data[pixelPos] == 0x00 {
                guard pixelPos + 2 < data.endIndex else { throw IMGError.missingData("Incomplete replication block on row \(y)") }
                if data[pixelPos + 1] == 0x00 && data[pixelPos + 2] == 0xff {
                    // replication count
                    repeatCount = Int(data[pixelPos+3])
//                    print(" repeat x\(repeatCount)", terminator: "")
                    pixelPos += 4
                }
            }
//            print("")
            var pixels: [UInt32] = Array(repeating: 0, count: Int(imageWidth))
            // Or `in (0..<planes).reversed()` ?
            for plane in 0..<planes {
                pixelPos = try IMG.decodeScanline(data[pixelPos..<data.endIndex], patternLength: patternLength, pixels: &pixels, value: 1 << plane)
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

    /// Determine the number of image planes, the VDI palette, and the new header size for the encoded palette
    static func buildPalette(_ uniqueVDIPalette: [(Int16, Int16, Int16)]) -> (Int16, Palette, Int16) {
        let planes: Int16 = switch uniqueVDIPalette.count {
        case 32768...Int.max: 24
        case 257...32767: 16
        case 129...256: 8
        case 65...128: 7
        case 33...64: 6
        case 17...32: 5
        case 9...16: 4
        case 5...8: 3
        case 3...4: 2
        default: 1
        }

        if planes > 8 {
            return (planes, .none, 8)
        }

        if planes == 1 {
            return (planes, .mono([(0, 0, 0), (0xff, 0xff, 0xff)]), 8)
        }

        // palette should be 2**planes in size, pad if necessary
        var vdi: [(Int16, Int16, Int16)] = uniqueVDIPalette
        let paletteSize = 1 << planes
        while vdi.count < paletteSize {
            vdi.append((0, 0, 0))
        }

        return (planes, .vdi(vdi), 8 + 3 + Int16(vdi.count * 3))
    }

    static func decodeScanline(_ data: Data, patternLength: Int16, pixels: inout [UInt32], value: UInt32) throws -> Int {
        var x = 0
        var pos = data.startIndex
        while x < pixels.count {
            guard pos + 0 < data.endIndex else { throw IMGError.missingData("Row incomplete \(x) needs \(pixels.count)") }
            // each kind of repeat could overrun the pixels width, which is "OK". marisa.img is a good case.
//            print("pos=\(pos) x=\(x) pixels.count=\(pixels.count) end=\(data.endIndex)", terminator: " ")
            if data[pos] == 0x80 {
                // literal bit string
                guard pos + 1 < data.endIndex else { throw IMGError.missingData("Literal incomplete") }
                let count = Int(data[pos+1])
//                print("literal \(count)")
                pos += 2
                var loopPos = pos
                guard pos + count - 1 < data.endIndex else { throw IMGError.missingData("Literal data incomplete") }
                literalLoop: for _ in 0..<count {
                    let byte = data[loopPos]
//                    print("literal byte \(String(byte, radix: 16, uppercase: false))")
                    loopPos += 1
                    if x == pixels.count { break literalLoop }
                    pixels[x] += (byte & 0x80 != 0 ? value : 0)
//                    print("pixels[\(x)] += \(byte & 0x80 != 0 ? value : 0)")
                    x += 1
                    if x == pixels.count { break literalLoop }
                    pixels[x] += (byte & 0x40 != 0 ? value : 0)
//                    print("pixels[\(x)] += \(byte & 0x40 != 0 ? value : 0)")
                    x += 1
                    if x == pixels.count { break literalLoop }
                    pixels[x] += (byte & 0x20 != 0 ? value : 0)
//                    print("pixels[\(x)] += \(byte & 0x20 != 0 ? value : 0)")
                    x += 1
                    if x == pixels.count { break literalLoop }
                    pixels[x] += (byte & 0x10 != 0 ? value : 0)
//                    print("pixels[\(x)] += \(byte & 0x10 != 0 ? value : 0)")
                    x += 1
                    if x == pixels.count { break literalLoop }
                    pixels[x] += (byte & 0x08 != 0 ? value : 0)
//                    print("pixels[\(x)] += \(byte & 0x08 != 0 ? value : 0)")
                    x += 1
                    if x == pixels.count { break literalLoop }
                    pixels[x] += (byte & 0x04 != 0 ? value : 0)
//                    print("pixels[\(x)] += \(byte & 0x04 != 0 ? value : 0)")
                    x += 1
                    if x == pixels.count { break literalLoop }
                    pixels[x] += (byte & 0x02 != 0 ? value : 0)
//                    print("pixels[\(x)] += \(byte & 0x02 != 0 ? value : 0)")
                    x += 1
                    if x == pixels.count { break literalLoop }
                    pixels[x] += (byte & 0x01 != 0 ? value : 0)
//                    print("pixels[\(x)] += \(byte & 0x01 != 0 ? value : 0)")
                    x += 1
                }
                // ensure pos is correct even if we exited the loop early
                pos += count
            } else if data[pos] == 0x00 {
                // pattern run
                guard pos + 1 < data.endIndex else { throw IMGError.missingData("Pattern incomplete") }
                let count = Int(data[pos+1])
//                print("pattern \(count)")
                var pattern: [UInt32] = []
                pos += 2
                guard pos + 1 < data.endIndex else { throw IMGError.missingData("Pattern incomplete") }
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
//                print("solid \(count)")
                let pixel = data[pos] & 0x80 != 0 ? value : 0
                let nextX = x + count * 8
                solidLoop: for _ in 0..<count {
                    for _ in 0..<8 {
                        if x == pixels.count { break solidLoop }
                        pixels[x] += pixel
//                        print("pixels[\(x)] += \(pixel) [solid]")
                        x += 1
                    }
                }
                pos += 1
                x = nextX
//                print("now x=\(x) and pos=\(pos)")
            }
        }
        return pos
    }
}

/// exporting to IMG files
extension IMG {
    public func toIMG() throws -> Data {
        var imgData = try buildHeader()

        var y = 0
        while y < rawPixels.count {
            let planelines = splitScanline(y)
            let repeatCount = repeatCount(y)
            if repeatCount != 1 {
                imgData.append(UInt8(0x00))
                imgData.append(UInt8(0x00))
                imgData.append(UInt8(0xff))
                imgData.append(UInt8(repeatCount))
            }

            for planeline in planelines {
                imgData.append(compressPlaneline(planeline))
            }

            y += repeatCount
        }

        return imgData
    }

    // FIXME actually compress
    func compressPlaneline(_ planeline: [UInt8]) -> Data {
        let tokens = IMG.compress(planeline)
        let bytes = IMG.encode(tokens, input: planeline)
        return Data(bytes)
    }

    func repeatCount(_ y: Int) -> Int {
        var count = 1
        for repeatY in (y + 1)..<rawPixels.count {
            if rawPixels[y] == rawPixels[repeatY] {
                count += 1
            } else {
                break
            }
            // The repeat count is held in one byte
            if count == 0xff {
                break
            }
        }
        return count
    }

    func buildHeader() throws -> Data {
        var header = Data()
        header.append(version.dataBigEndian)
        header.append(headerLength.dataBigEndian)
        header.append(planes.dataBigEndian)
        header.append(patternLength.dataBigEndian)
        header.append(pixelWidth.dataBigEndian)
        header.append(pixelHeight.dataBigEndian)
        header.append(imageWidth.dataBigEndian)
        header.append(imageHeight.dataBigEndian)
        // this ought to be in the Palette type
        switch palette {
        case let .vdi(vdi):
            header.append(IMG.signatureXIMG!)
            header.append(UInt16(0).dataBigEndian) // 0 means RGB
            for entry in vdi {
                header.append(entry.0.dataBigEndian)
                header.append(entry.1.dataBigEndian)
                header.append(entry.2.dataBigEndian)
            }
            return header
        case let .xbios(xbios):
            header.append(IMG.signatureSTTT!)
            header.append(Int16(xbios.count).dataBigEndian)
            for entry in xbios {
                let rgb: Int16 =
                    (entry.0 << 8) & 0b1111_0000_0000 |
                    (entry.1 << 4) & 0b0000_1111_0000 |
                    (entry.2 << 0) & 0b0000_0000_1111
                header.append(rgb.dataBigEndian)
            }
            return header
        case .mono:
            return header
        case .none:
            return header
        }
    }

    func splitScanline(_ y: Int) -> [[UInt8]] {
        // split each scanline up into multiple planes
        var planelines: [[UInt8]] = []
        for plane in 0..<planes {
            let planeMask = UInt32(1 << plane)
            // for each plane, set a bit for each pixel
            var byteMask: UInt8 = 0
            var planeBytes: [UInt8] = [ ]
            for pixel in rawPixels[y] {
                if byteMask == 0 {
                    // Add a new byte, and start writing from the left-most bit
                    planeBytes.append(0)
                    byteMask = 1 << 7
                }
                if pixel & planeMask != 0 {
                    let lastIndex = planeBytes.count - 1
                    planeBytes[lastIndex] |= byteMask
                }
                byteMask >>= 1
            }
            planelines.append(planeBytes)
        }
        return planelines
    }
}

enum Token {
    case literal(start: Int, length: Int)
    case zeroRun(value: UInt8, length: Int)          // 0x00 or 0xFF
    case pairRun(start: Int, length: Int)            // ABABAB...
}

extension IMG {
    static func compress(_ input: [UInt8]) -> [Token] {
        let n = input.count
        if n == 0 { return [] }

        var dp = Array(repeating: Int.max, count: n + 1)
        var choice = Array<Token?>(repeating: nil, count: n)

        dp[n] = 0

        for i in stride(from: n - 1, through: 0, by: -1) {

            var bestCost = Int.max
            var bestToken: Token? = nil

            // --------------------------------------------------
            // 1. Literal runs (1...255)
            // --------------------------------------------------
//            print("Literal run from \(i)?")
            let maxLiteral = min(255, n - i)
            for length in 1...maxLiteral {
                let cost = 2 + length + dp[i + length]
                if cost < bestCost {
                    bestCost = cost
                    bestToken = .literal(start: i, length: length)
                }
            }

            // --------------------------------------------------
            // 2. 0x00 / 0xFF runs (<=127)
            // --------------------------------------------------
//            print("Solid run from \(i)?")
            let byte = input[i]
            if byte == 0x00 || byte == 0xFF {
                var runLength = 1
                while runLength < 127 &&
                      i + runLength < n &&
                      input[i + runLength] == byte {
                    runLength += 1
                }

                let cost = 2 + dp[i + runLength]
                if cost < bestCost {
                    bestCost = cost
                    bestToken = .zeroRun(value: byte, length: runLength)
                }
            }

            // --------------------------------------------------
            // 3. 2-byte repeating pattern (ABABAB...)
            // --------------------------------------------------
//            print("Pattern run from \(i)?")
            if i + 3 < n {
                let a = input[i]
                let b = input[i + 1]

                var runLength = 2
                while runLength <= 255 &&
                      i + runLength + 1 < n &&
                      input[i + runLength] == a &&
                      input[i + runLength + 1] == b {
                    runLength += 2
                }

                if runLength >= 4 {
                    let cost = 4 + dp[i + runLength]
                    if cost < bestCost {
                        bestCost = cost
                        bestToken = .pairRun(start: i, length: runLength)
                    }
                }
            }

            dp[i] = bestCost
            choice[i] = bestToken
        }

        // --------------------------------------------------
        // Reconstruct optimal token sequence
        // --------------------------------------------------
//        print("Optimising tokens")
        var tokens: [Token] = []
        var index = 0

        while index < n {
            guard let token = choice[index] else { break }
            tokens.append(token)

            switch token {
            case .literal(_, let length),
                 .zeroRun(_, let length),
                 .pairRun(_, let length):
                index += length
            }
        }
//        print("tokens are \(tokens)")
        return tokens
    }

    static func encode(_ tokens: [Token], input: [UInt8]) -> [UInt8] {
        var output: [UInt8] = []

        for token in tokens {
            switch token {

            case .literal(let start, let length):
                output.append(0x80)          // example literal marker
                output.append(UInt8(length))
                output.append(contentsOf: input[start..<start+length])

            case .zeroRun(let value, let length):
                output.append(UInt8(length) | (value == 0x00 ? 0x00 : 0x80))

            case .pairRun(let start, let length):
                output.append(0x00)
                output.append(UInt8(length / 2)) // number of repeats
                output.append(input[start])
                output.append(input[start + 1])
            }
        }

        return output
    }
}
