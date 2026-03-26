// Atari IMG compression tests
//
// Copyright Chris Ridd 2026
import Testing
import Foundation
@testable import Atari

func compressAndUncompress(_ original: [UInt8]) throws {
    let tokens = IMG.compress(original)
    let compressed = IMG.encode(tokens, input: original)

    var pixels: [UInt32] = Array(repeating: 0, count: original.count * 8)
    let _ = try IMG.decodeScanline(Data(compressed), patternLength: 2, pixels: &pixels, value: 1)
    #expect(pixels.count == original.count * 8)
    for i in 0..<original.count {
        #expect(pixels[i * 8 + 0] == (original[i] & 0x80 != 0 ? 1 : 0))
        #expect(pixels[i * 8 + 1] == (original[i] & 0x40 != 0 ? 1 : 0))
        #expect(pixels[i * 8 + 2] == (original[i] & 0x20 != 0 ? 1 : 0))
        #expect(pixels[i * 8 + 3] == (original[i] & 0x10 != 0 ? 1 : 0))
        #expect(pixels[i * 8 + 4] == (original[i] & 0x08 != 0 ? 1 : 0))
        #expect(pixels[i * 8 + 5] == (original[i] & 0x04 != 0 ? 1 : 0))
        #expect(pixels[i * 8 + 6] == (original[i] & 0x02 != 0 ? 1 : 0))
        #expect(pixels[i * 8 + 7] == (original[i] & 0x01 != 0 ? 1 : 0))
    }
}

@Test func testCompression() throws {
    try compressAndUncompress([0, 1, 2, 3, 4, 5])
    try compressAndUncompress([0, 0, 0, 0, 0, 0])
    try compressAndUncompress([0, 1, 0, 1, 0, 1])
}
