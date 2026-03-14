// Atari IMG format tests
//
// Copyright Chris Ridd 2026

import Testing
import Foundation
@testable import Atari

func buildIMG(rawPixels: [[UInt32]], planes: Int16, palette: Palette) -> IMG {
    return IMG(version: 0,
               headerLength: 0,
               planes: planes,
               patternLength: 2,
               pixelWidth: 99,
               pixelHeight: 99,
               imageWidth: 3,
               imageHeight: 1,
               palette: palette,
               rawPixels: rawPixels)
}

@Test func roundtripMonoShort() throws {
    // three indexed pixels
    let rawPixels: [UInt32] = [ UInt32(0), UInt32(1), UInt32(0)]

    let test = buildIMG(rawPixels: [rawPixels], planes: 1, palette: Palette.none)

    let planes = test.splitScanline(0)
    #expect(planes.count == 1)
    #expect(planes[0].count == 1)
    #expect(planes[0][0] == 64)
}

@Test func roundtrip4Short() throws {
    // three indexed pixels
    let rawPixels: [UInt32] = [ UInt32(0b1111), UInt32(0b1110)]

    let vdi: [(Int16, Int16, Int16)] = [
        (0, 0, 0),
        (1000, 0, 0),
        (0, 1000, 0),
        (0, 0, 1000),
        (1000, 1000, 0),
        (0, 1000, 1000),
        (1000, 0, 1000),
        (1000, 1000, 1000)
    ]
    let test = buildIMG(rawPixels: [rawPixels], planes: 4, palette: Palette.ximg(vdi))

    let planes = test.splitScanline(0)
    #expect(planes.count == 4)
    for p in 0..<4 {
        #expect(planes[p].count == 1)
    }
    #expect(planes[0][0] == 0x80)
    #expect(planes[1][0] == 0xc0)
    #expect(planes[2][0] == 0xc0)
    #expect(planes[3][0] == 0xc0)
}
