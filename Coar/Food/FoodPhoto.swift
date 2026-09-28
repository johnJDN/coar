import UIKit

/// A photo as the photo model is sent it (spec "Photos"): shrunk to 1,024 points on its long
/// edge and encoded as JPEG at 0.7, in memory only. Never written to disk.
enum FoodPhoto {

    static let longEdge: CGFloat = 1_024

    static func jpeg(from image: UIImage) -> Data? {
        let size = image.size
        let scale = min(1, longEdge / max(size.width, size.height, 1))
        let target = CGSize(width: (size.width * scale).rounded(), height: (size.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        return resized.jpegData(compressionQuality: 0.7)
    }
}
