import ImageIO
import UIKit
import UniformTypeIdentifiers
import XCTest
@testable import Coar

/// Seam 2 (pure): how a picked photo becomes what the store keeps, and which Day a library
/// photo belongs to (ADR 0005: the local Day where it was taken, read from its EXIF date).
final class ProgressPhotoEncoderTests: XCTestCase {

    func test_dayTaken_readsTheExifDateAsTheLocalDay() {
        let data = Self.jpeg(exifDateTimeOriginal: "2026:09:13 23:42:07")

        XCTAssertEqual(ProgressPhotoEncoder.dayTaken(from: data), Day(year: 2026, month: 9, day: 13))
    }

    func test_dayTaken_withoutAnExifDate_isNil() {
        XCTAssertNil(ProgressPhotoEncoder.dayTaken(from: Self.jpeg(exifDateTimeOriginal: nil)))
        XCTAssertNil(ProgressPhotoEncoder.dayTaken(from: Data("not an image".utf8)))
    }

    func test_dayTaken_withAMalformedExifDate_isNil() {
        XCTAssertNil(ProgressPhotoEncoder.dayTaken(from: Self.jpeg(exifDateTimeOriginal: "2026:02:31 10:00:00")))
        XCTAssertNil(ProgressPhotoEncoder.dayTaken(from: Self.jpeg(exifDateTimeOriginal: "yesterday")))
    }

    func test_encode_capsTheImageAndThumbnailOnTheirLongestEdge() throws {
        let tall = UIGraphicsImageRenderer(size: CGSize(width: 3000, height: 4000)).image { _ in }

        let encoded = try XCTUnwrap(ProgressPhotoEncoder.encode(tall))

        let image = try XCTUnwrap(UIImage(data: encoded.image))
        let thumbnail = try XCTUnwrap(UIImage(data: encoded.thumbnail))
        XCTAssertEqual(image.size.height * image.scale, ProgressPhotoEncoder.imageMaxPixels)
        XCTAssertEqual(image.size.width * image.scale, 1536)
        XCTAssertEqual(thumbnail.size.height * thumbnail.scale, ProgressPhotoEncoder.thumbnailMaxPixels)
        XCTAssertLessThan(encoded.thumbnail.count, encoded.image.count)
    }

    func test_encode_neverEnlargesASmallImage() throws {
        let small = UIGraphicsImageRenderer(size: CGSize(width: 100, height: 50)).image { _ in }

        let encoded = try XCTUnwrap(ProgressPhotoEncoder.encode(small))

        let image = try XCTUnwrap(UIImage(data: encoded.image))
        XCTAssertEqual(image.size.width * image.scale, 100 * small.scale)
    }

    /// A tiny JPEG carrying (or not) an EXIF `DateTimeOriginal`.
    private static func jpeg(exifDateTimeOriginal: String?) -> Data {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4)).image { _ in }
        let data = NSMutableData()
        let destination = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil)!
        var properties: [CFString: Any] = [:]
        if let exifDateTimeOriginal {
            properties[kCGImagePropertyExifDictionary] = [kCGImagePropertyExifDateTimeOriginal: exifDateTimeOriginal]
        }
        CGImageDestinationAddImage(destination, image.cgImage!, properties as CFDictionary)
        CGImageDestinationFinalize(destination)
        return data as Data
    }
}
