//
//  Platform.swift
//  StreamingChat
//
//  Small cross-platform helpers so the SwiftUI code builds natively on both iOS
//  and macOS. iOS/macOS-specific APIs (UIKit vs AppKit) are isolated here.
//

import SwiftUI
import ImageIO
import UniformTypeIdentifiers

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

// MARK: - Images

extension Image {
    /// Build a SwiftUI `Image` from raw image data on either platform.
    init?(data: Data) {
        #if os(iOS)
        guard let image = UIImage(data: data) else { return nil }
        self.init(uiImage: image)
        #elseif os(macOS)
        guard let image = NSImage(data: data) else { return nil }
        self.init(nsImage: image)
        #endif
    }
}

enum ImageProcessing {
    /// Downscale so the longest side is <= `maxSide` and re-encode as JPEG.
    /// Uses ImageIO, which works identically on iOS and macOS.
    static func downscaledJPEG(from data: Data,
                               maxSide: CGFloat = 1024,
                               quality: CGFloat = 0.7) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxSide
        ]
        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            output, UTType.jpeg.identifier as CFString, 1, nil
        ) else { return nil }
        CGImageDestinationAddImage(
            destination, thumbnail,
            [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary
        )
        guard CGImageDestinationFinalize(destination) else { return nil }
        return output as Data
    }
}

// MARK: - Clipboard

enum Clipboard {
    static func copy(_ string: String) {
        #if os(iOS)
        UIPasteboard.general.string = string
        #elseif os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
        #endif
    }
}

// MARK: - Colors

extension Color {
    /// A subtle secondary surface color available on both platforms.
    static var secondaryBackground: Color {
        #if os(iOS)
        Color(uiColor: .secondarySystemBackground)
        #elseif os(macOS)
        Color(nsColor: .controlBackgroundColor)
        #endif
    }
}
