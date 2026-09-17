import ImageIO
import UIKit

/// How a picked photo becomes the two encodings the store keeps: a full-size JPEG capped at
/// `imageMaxPixels` on its longest edge (the compare screen, and the CloudKit asset) and a
/// small JPEG the grid shows. Both are drawn afresh, so orientation is baked in and no EXIF
/// or location metadata reaches the store.
enum ProgressPhotoEncoder {

    static let imageMaxPixels: CGFloat = 2048
    static let thumbnailMaxPixels: CGFloat = 400
    private static let imageQuality: CGFloat = 0.85
    private static let thumbnailQuality: CGFloat = 0.7

    struct Encoded {
        let image: Data
        let thumbnail: Data
    }

    /// Nil only for an image that cannot be drawn (no pixels).
    static func encode(_ image: UIImage) -> Encoded? {
        guard let full = image.fitted(within: imageMaxPixels).jpegData(compressionQuality: imageQuality),
              let thumbnail = image.fitted(within: thumbnailMaxPixels).jpegData(compressionQuality: thumbnailQuality)
        else { return nil }
        return Encoded(image: full, thumbnail: thumbnail)
    }

    /// The Day a library photo was taken, from its EXIF `DateTimeOriginal` ("2026:09:13
    /// 18:42:07"): the wall-clock time where the camera was, which is exactly the local Day
    /// ADR 0005 keys by. Nil when the file carries none.
    static func dayTaken(from data: Data) -> Day? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any],
              let taken = exif[kCGImagePropertyExifDateTimeOriginal] as? String
        else { return nil }
        let date = taken.split(separator: " ").first.map(String.init) ?? ""
        return Day(rawValue: date.replacingOccurrences(of: ":", with: "-"))
    }
}

private extension UIImage {
    /// Redrawn at scale 1 so the longest edge is at most `maxPixels`; never enlarged.
    func fitted(within maxPixels: CGFloat) -> UIImage {
        let pixels = CGSize(width: size.width * scale, height: size.height * scale)
        let longest = max(pixels.width, pixels.height)
        let ratio = longest > maxPixels ? maxPixels / longest : 1
        let target = CGSize(width: (pixels.width * ratio).rounded(.down), height: (pixels.height * ratio).rounded(.down))
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: target))
        }
    }
}
