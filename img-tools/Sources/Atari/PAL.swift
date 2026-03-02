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
        var pos = data.startIndex
        let signature = data[pos..<pos+4]
        if signature != PAL.signaturePA01 {
            throw PALError.badSignature
        }
        var vdiPalette: [(Int16, Int16, Int16)] = []
        pos += 4
        while pos < data.endIndex {
            let r = Int16(bigEndian: data[pos..<pos+2].to(type: Int16.self)!)
            pos += 2
            let g = Int16(bigEndian: data[pos..<pos+2].to(type: Int16.self)!)
            pos += 2
            let b = Int16(bigEndian: data[pos..<pos+2].to(type: Int16.self)!)
            pos += 2
            vdiPalette.append((r, g, b))
        }
        if vdiPalette.count != 256 {
            throw PALError.badSize
        }
        palette = vdiPalette
    }
}
