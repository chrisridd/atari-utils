// Convert Atari IMG files to PNG files
//
// Copyright Chris Ridd 2026

import Foundation
import Utils

@main
struct img2png {
    static func usage(_ reason: String?) {
        let name = CommandLine.arguments.first!
        eprint("Usage: \(name) [-h] <file>...")
        if let reason = reason {
            eprint(reason)
        }
        exit(EXIT_FAILURE)
    }

    static func help() {
        let name = CommandLine.arguments.first!
        eprint("""
            Usage: \(name) [-h] <file>...

            Arguments:
            -h, --help     Output this help.
            """);
        exit(EXIT_SUCCESS)
    }

    static func getArguments() -> [String] {
        let args = CommandLine.arguments
        var filenames: [String] = []
        var capturing = false

        for index in 1..<args.count {
            let arg = args[index]

            if capturing {
                filenames.append(arg)
                continue
            }

            if arg == "-h" || arg == "--help" {
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
        if filenames.isEmpty {
            usage("Unspecified filenames")
        }
        return filenames
    }

    static func main() throws {
        let filenames = getArguments()
        print("OK! \(filenames)")
    }
}
