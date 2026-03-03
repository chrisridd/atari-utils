// Atari (NVDI?) PAL format
//
// Copyright Chris Ridd 2026

import Foundation

public enum PALError: Error {
    case badSignature
    case badSize
}

public struct PAL {
    let palette: [(Int16, Int16, Int16)]

    static let signaturePA01 = "PA01".data(using: .ascii)

    public init(_ data: Data) throws {
        let pos = data.startIndex
        let signature = data[pos..<pos+4]
        if signature != PAL.signaturePA01 {
            throw PALError.badSignature
        }
        let vdiPalette = try readVDIPalette(data[pos+4..<data.endIndex])
        if vdiPalette.count != 256 {
            throw PALError.badSize
        }
        palette = vdiPalette
    }
}

func readVDIPalette(_ data: Data) throws -> [(Int16, Int16, Int16)] {
    var vdiPalette: [(Int16, Int16, Int16)] = []
    var pos = data.startIndex
    while pos < data.endIndex {
        let r = Int16(bigEndian: data[pos..<pos+2].to(type: Int16.self)!)
        pos += 2
        let g = Int16(bigEndian: data[pos..<pos+2].to(type: Int16.self)!)
        pos += 2
        let b = Int16(bigEndian: data[pos..<pos+2].to(type: Int16.self)!)
        pos += 2
        vdiPalette.append((r, g, b))
    }
    return vdiPalette
}
