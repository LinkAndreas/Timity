import Foundation
import ImageIO
import SwiftUI
import UniformTypeIdentifiers

/// Scales event photos with ImageIO, which works the same in the app, the
/// widgets and on the Watch, and never decodes more pixels than it shows.
nonisolated enum ImageProcessing {
    /// The longest side of a stored photo, in pixels.
    static let storedMaxPixelSize: CGFloat = 2048

    /// `data` as an image of at most `maxPixelSize` pixels on its longest side,
    /// cached so lists don't decode photos on every redraw.
    static func image(from data: Data?, maxPixelSize: CGFloat) -> Image? {
        cgImage(from: data, maxPixelSize: maxPixelSize).map { Image(decorative: $0, scale: 1) }
    }

    /// `image(from:maxPixelSize:)` as pixels, for when its size matters too.
    static func cgImage(from data: Data?, maxPixelSize: CGFloat) -> CGImage? {
        guard let data else { return nil }
        let key = "\(data.count)-\(data.hashValue)-\(Int(maxPixelSize))" as NSString
        if let cached = cache.object(forKey: key) {
            return cached.image
        }
        guard let cgImage = thumbnail(from: data, maxPixelSize: maxPixelSize) else { return nil }
        cache.setObject(CachedImage(image: cgImage), forKey: key)
        return cgImage
    }

    /// A picked photo made ready for storage and iCloud: upright, at most
    /// `storedMaxPixelSize` pixels, and JPEG compressed.
    static func preparedForStorage(_ data: Data) -> Data? {
        guard let cgImage = thumbnail(from: data, maxPixelSize: storedMaxPixelSize) else { return nil }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil) else {
            return nil
        }
        let options = [kCGImageDestinationLossyCompressionQuality: 0.85] as CFDictionary
        CGImageDestinationAddImage(destination, cgImage, options)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return output as Data
    }

    /// `preparedForStorage(_:)` in the background, for a photo the user just picked.
    @concurrent
    static func prepareForStorage(_ data: Data) async -> Data? {
        preparedForStorage(data)
    }

    static func thumbnail(from data: Data, maxPixelSize: CGFloat) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: max(1, Int(maxPixelSize)),
        ] as CFDictionary
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options)
    }

    nonisolated private final class CachedImage {
        let image: CGImage
        init(image: CGImage) { self.image = image }
    }

    // NSCache is thread-safe; it just isn't marked Sendable.
    nonisolated(unsafe) private static let cache: NSCache<NSString, CachedImage> = {
        let cache = NSCache<NSString, CachedImage>()
        cache.countLimit = 120
        return cache
    }()
}
