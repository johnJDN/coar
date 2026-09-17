import PhotosUI
import UIKit
import UniformTypeIdentifiers

/// A photo the user picked and the Day it belongs to: today for a capture; for a library
/// photo, the Day it was taken when the file says so, else today.
struct PickedPhoto {
    let image: UIImage
    let day: Day
}

/// Presents the camera (`UIImagePickerController`, the only camera UI UIKit offers) or the
/// photo library (`PHPickerViewController`, which needs no permission) over a screen and
/// hands back one `PickedPhoto`, or nil when the user cancels. Owned by the presenting screen.
final class ProgressPhotoPicker: NSObject {

    static var isCameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    private weak var presenter: UIViewController?
    private var completion: ((PickedPhoto?) -> Void)?

    init(presenter: UIViewController) {
        self.presenter = presenter
    }

    func presentCamera(completion: @escaping (PickedPhoto?) -> Void) {
        self.completion = completion
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.delegate = self
        presenter?.present(picker, animated: true)
    }

    func presentLibrary(completion: @escaping (PickedPhoto?) -> Void) {
        self.completion = completion
        var configuration = PHPickerConfiguration()
        configuration.filter = .images
        configuration.selectionLimit = 1
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        presenter?.present(picker, animated: true)
    }

    private func finish(_ picked: PickedPhoto?) {
        let completion = completion
        self.completion = nil
        completion?(picked)
    }
}

extension ProgressPhotoPicker: UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        let image = info[.originalImage] as? UIImage
        picker.dismiss(animated: true) { [weak self] in
            self?.finish(image.map { PickedPhoto(image: $0, day: .today()) })
        }
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true) { [weak self] in self?.finish(nil) }
    }
}

extension ProgressPhotoPicker: PHPickerViewControllerDelegate {

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        guard let provider = results.first?.itemProvider,
              provider.hasItemConformingToTypeIdentifier(UTType.image.identifier)
        else {
            picker.dismiss(animated: true) { [weak self] in self?.finish(nil) }
            return
        }
        // The original bytes, so the EXIF date survives to key the Day; decoded off the main thread.
        provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { [weak self] data, _ in
            let picked = data.flatMap { data -> PickedPhoto? in
                guard let image = UIImage(data: data) else { return nil }
                return PickedPhoto(image: image, day: ProgressPhotoEncoder.dayTaken(from: data) ?? .today())
            }
            DispatchQueue.main.async {
                picker.dismiss(animated: true) { self?.finish(picked) }
            }
        }
    }
}
