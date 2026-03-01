// Shared utility functions
//
// Copyright Chris Ridd 2026

import Foundation

struct StandardError: TextOutputStream, Sendable {
    private static let handle = FileHandle.standardError

    public func write(_ string: String) {
        Self.handle.write(Data(string.utf8))
    }
}

public func eprint(_ str : String) {
    var stderr = StandardError()
    print(str, to: &stderr)
}
