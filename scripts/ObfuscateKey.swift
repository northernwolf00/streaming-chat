#!/usr/bin/env swift
//
// ObfuscateKey.swift — turns an API key into XOR-obfuscated bytes so it never
// appears as plaintext in source or in the compiled binary's string table.
//
// Usage:
//   swift scripts/ObfuscateKey.swift "sk-or-v1-...."
//
// Paste the printed `pad` and `obfuscated` arrays into Sources/Services/APIKey.swift.
//

import Foundation

guard CommandLine.arguments.count == 2 else {
    FileHandle.standardError.write(Data("Usage: swift scripts/ObfuscateKey.swift \"<API_KEY>\"\n".utf8))
    exit(1)
}

let key = Array(CommandLine.arguments[1].utf8)
var pad = [UInt8]()
for _ in key { pad.append(UInt8.random(in: 0...255)) }
let obfuscated = zip(key, pad).map { $0 ^ $1 }

func format(_ name: String, _ bytes: [UInt8]) -> String {
    let body = bytes.map { String($0) }.joined(separator: ", ")
    return "    private static let \(name): [UInt8] = [\n        \(body)\n    ]"
}

print(format("pad", pad))
print(format("obfuscated", obfuscated))
