// Convert PNG files to Atari IMG files
//
// Copyright Chris Ridd 2026

import Foundation
import Utils

@main
struct png2img {
    static func usage(_ reason: String?) {
        let name = CommandLine.arguments.first!
        eprint("Usage: \(name) [-h] [-8|-4|-2|-1] [-n|-g|-p <palettefile>] <file>...")
        if let reason = reason {
            eprint(reason)
        }
        exit(EXIT_FAILURE)
    }

    static func help() {
        let name = CommandLine.arguments.first!
        eprint("""
            Usage: \(name) [-h] [-8|-4|-2|-1] [-n|-g|-p <palettefile>] <file>...

            Arguments:
            -h, --help     Output this help.
            -8             Force output to be 8bpp.
            -4             Force output to be 4bpp.
            -2             Force output to be 2bpp.
            -1             Force output to be 1bpp.
            -n, --nvdi     Remap to the NVDI palette.
            -g, --gem      Remap to the GEM palette.
            -p, --palette  Remap to the colours in the provided 'PAL' file.
            """);
        exit(EXIT_SUCCESS)
    }

    enum Planes {
        case planes1, planes2, planes4, planes8
        case minimal
    }

    enum Remapping {
        case nvdi
        case gem
        case palette(String)
        case none
    }

    static func main() throws {
        let args = CommandLine.arguments
        var planes = Planes.minimal
        var filenames: [String] = []
        var wantPalette = false
        var remap = Remapping.none
        var capturing = false

        for index in 1..<args.count {
            let arg = args[index]

            if capturing {
                filenames.append(arg)
                continue
            }

            if wantPalette {
                remap = .palette(arg)
                wantPalette = false
                continue
            }

            if arg == "-8" {
                planes = .planes8
            } else if arg == "-4" {
                planes = .planes4
            } else if arg == "-2" {
                planes = .planes2
            } else if arg == "-1" {
                planes = .planes1
            } else if arg == "-p" || arg == "--palette" {
                wantPalette = true
            } else if arg == "-n" || arg == "--nvdi" {
                remap = .nvdi
            } else if arg == "-g" || arg == "--gem" {
                remap = .gem
            } else if arg == "-h" || arg == "--help" {
                help()
            } else if arg == "--" {
                // capture from next arg onwards
                capturing = true
            } else if arg.hasPrefix("-") {
                // anything else is an invalid argument
                usage("Invalid argument \(arg)")
            } else {
                // capture from this arg onwards
                capturing = true
                filenames.append(arg)
            }
        }
        if wantPalette {
            usage("-p but unspecified palette file")
        }
        if filenames.isEmpty {
            usage("Unspecified filenames")
        }
        print("OK! \(filenames)")
        print("From args \(args)")
        if planes == .minimal {
            print("Use minimal planes")
        } else {
            print("Convert to \(planes)")
        }
        switch remap {
        case .nvdi: print("Remap to NVDI")
        case .gem: print("Remap to GEM")
        case .palette(let str): print("Remap to file \(str)")
        case .none: print("No remapping")
        }
    }
}
