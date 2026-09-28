import UIKit
import XCTest
@testable import Coar

/// Photos of meals and nutrition labels (`.scratch/ai-food-logging/issues/07`): a photo is
/// shrunk before it is sent, its reply becomes one line per food (a label, one line per
/// serving), and a photo that can't be read says so. Seam 2; the model is not called.
@MainActor
final class DescribePhotoTests: XCTestCase {

    private let plateReply = #"{"items":[{"source":"photo","name":"Roast chicken","quantity":1,"unit":"piece","grams":180,"calories":360,"protein":42,"fat":19,"carbs":0,"assumption":"Skin on.","match":null},{"source":"photo","name":"Steamed broccoli","quantity":1,"unit":"cup","grams":90,"calories":30,"protein":2.5,"fat":0.3,"carbs":6,"assumption":"","match":null}]}"#
    private let labelReply = #"{"items":[{"source":"label","name":"Basmati rice","quantity":1,"unit":"serving (100 g)","grams":100,"calories":350,"protein":9,"fat":1,"carbs":76,"assumption":"","match":null}]}"#

    // MARK: Reading a reply

    func test_aPlate_isOneItemPerFood_andALabel_isOneServingReadExactly() throws {
        let plate = try Estimate.photoItems(reply: Data(plateReply.utf8)).map(\.estimate)
        XCTAssertEqual(plate.map(\.name), ["Roast chicken", "Steamed broccoli"])
        XCTAssertEqual(plate.map(\.source), [.photo, .photo])
        XCTAssertEqual(plate.first?.macros, Macros(calories: 360, protein: 42, fat: 19, carbs: 0))

        let label = try XCTUnwrap(Estimate.photoItems(reply: Data(labelReply.utf8)).first?.estimate)
        XCTAssertEqual(label.source, .label)
        XCTAssertEqual(label.portion, "1 × serving (100 g)")
        XCTAssertEqual(label.macros, Macros(calories: 350, protein: 9, fat: 1, carbs: 76))

        XCTAssertThrowsError(try Estimate.photoItems(reply: Data("no".utf8))) { XCTAssertEqual($0 as? Estimate.ReplyError, .unreadable) }
    }

    func test_twoLabelServings_scaleFromTheLabel() throws {
        let label = try XCTUnwrap(Estimate.photoItems(reply: Data(labelReply.utf8)).first?.estimate)
        var edit = DescribeLineEdit(DescribeLine(text: "Basmati rice", state: .filled(label)))
        edit.setQuantity(2)
        XCTAssertEqual(edit.estimate?.macros, Macros(calories: 700, protein: 18, fat: 2, carbs: 152))
        XCTAssertEqual(edit.estimate?.source, .label)
    }

    // MARK: The draft

    func test_aPhoto_replacesItsPlaceholderWithOneLinePerFood_beforeTheEmptyLine() throws {
        var draft = DescribeDraft()
        let empty = try XCTUnwrap(draft.lines.first?.id)
        let photo = draft.addPhoto()
        XCTAssertEqual(draft.lines.map(\.id), [photo, empty], "above the line waiting to be typed in")
        XCTAssertEqual(draft.begin(photo), DescribeDraft.photoPlaceholder)

        let items = try Estimate.photoItems(reply: Data(plateReply.utf8)).map(\.estimate)
        XCTAssertTrue(draft.finishPhoto(photo, result: .success(items)))

        XCTAssertEqual(draft.lines.map(\.text), ["Roast chicken", "Steamed broccoli", ""])
        XCTAssertEqual(draft.filled.count, 2)
        XCTAssertFalse(draft.lines.contains { $0.isPhoto })
    }

    func test_aPhotoWithNoFood_orAFailedRequest_saysSo_andAnImpossibleItemFailsAlone() throws {
        var draft = DescribeDraft()
        var photo = draft.addPhoto()
        _ = draft.begin(photo)
        draft.finishPhoto(photo, result: .success([]))
        XCTAssertEqual(draft.line(photo)?.state, .failed("No food or nutrition label found in the photo."))

        _ = draft.begin(photo)
        draft.finishPhoto(photo, result: .failure(OpenRouterError.offline))
        XCTAssertEqual(draft.line(photo)?.state, .waiting)
        XCTAssertTrue(draft.line(photo)?.isPhoto == true)

        photo = draft.addPhoto()
        _ = draft.begin(photo)
        var items = try Estimate.photoItems(reply: Data(plateReply.utf8)).map(\.estimate)
        items[1].macros.calories = 9_000
        draft.finishPhoto(photo, result: .success(items))
        XCTAssertEqual(draft.filled.map(\.text), ["Roast chicken"])
        guard case .failed = draft.lines.first(where: { $0.text == "Steamed broccoli" })?.state else { return XCTFail() }
    }

    func test_aPhotoNotYetRead_cantBeReadAfterItsSheetCloses() throws {
        var draft = DescribeDraft()
        let photo = draft.addPhoto()
        _ = draft.begin(photo)
        let reopened = try JSONDecoder().decode(DescribeDraft.self, from: JSONEncoder().encode(draft))
        var resumed = reopened
        resumed.resume()
        XCTAssertEqual(resumed.line(photo)?.state, .failed(DescribeDraft.photoGone))
        XCTAssertFalse(resumed.unsent.contains(photo))
    }

    // MARK: The image

    func test_aPhoto_isShrunkTo1024OnItsLongEdge_asJPEG() throws {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 3_000, height: 2_000), format: {
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            return format
        }()).image { context in
            UIColor.orange.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 3_000, height: 2_000))
        }
        let data = try XCTUnwrap(FoodPhoto.jpeg(from: image))
        let decoded = try XCTUnwrap(UIImage(data: data))
        XCTAssertEqual(decoded.size.width * decoded.scale, 1_024)
        XCTAssertEqual((decoded.size.height * decoded.scale).rounded(), 683)
        XCTAssertEqual(data.prefix(2), Data([0xFF, 0xD8]), "JPEG")
    }

    func test_thePhotoSchema_asksForItemsWithASource_andNoTextOnlyFields() throws {
        let properties = try XCTUnwrap(FoodPhotoPrompt.schema["properties"] as? [String: Any])
        let items = try XCTUnwrap(properties["items"] as? [String: Any])
        let item = try XCTUnwrap(items["items"] as? [String: Any])
        let itemProperties = try XCTUnwrap(item["properties"] as? [String: Any])
        XCTAssertNotNil(itemProperties["source"])
        XCTAssertNil(itemProperties["is_food"])
        XCTAssertNil(itemProperties["needs_lookup"])
        XCTAssertEqual(Set(try XCTUnwrap(item["required"] as? [String])), Set(itemProperties.keys), "strict: every field required")
    }
}
