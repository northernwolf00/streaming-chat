//
//  APIKey.swift
//  StreamingChat
//
//  The OpenRouter API key is XOR-obfuscated so it never appears as plaintext in
//  source or in the compiled binary's string table. It is reconstructed at
//  runtime by XOR-ing `obfuscated` with `pad` (same length — effectively a
//  one-time pad). This is obfuscation, not encryption: it defeats trivial
//  `strings` scanning, which is what the task requires.
//
//  To set the real key:
//    swift scripts/ObfuscateKey.swift "sk-or-v1-...."
//  then paste the printed `pad` and `obfuscated` arrays below.
//

import Foundation

enum APIKey {
    // NOTE: placeholder key is "sk-or-v1-REPLACE_WITH_REAL_OPENROUTER_KEY".
    // Replace both arrays with the output of scripts/ObfuscateKey.swift.
    private static let pad: [UInt8] = [
        247, 100, 113, 127, 227, 113, 92, 111, 115, 24, 126, 222, 220, 191, 100, 197, 118, 26, 177, 167, 236, 196, 189, 195, 48, 99, 117, 52, 180, 162, 117, 185, 12, 222, 230, 221, 14, 184, 252, 178, 215
    ]
    private static let obfuscated: [UInt8] = [
        132, 15, 92, 16, 145, 92, 42, 94, 94, 74, 59, 142, 144, 254, 39, 128, 41, 77, 248, 243, 164, 155, 239, 134, 113, 47, 42, 123, 228, 231, 59, 235, 67, 139, 178, 152, 92, 231, 183, 247, 142
    ]

    /// The reconstructed OpenRouter API key.
    static var openRouter: String {
        let bytes = zip(obfuscated, pad).map { $0 ^ $1 }
        return String(decoding: bytes, as: UTF8.self)
    }

    /// True while the placeholder key is still in place (no real key configured).
    static var isPlaceholder: Bool {
        openRouter.contains("REPLACE_WITH_REAL")
    }
}
