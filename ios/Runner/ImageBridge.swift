import Foundation
import PhotosUI
import UIKit

/// The picture side of the device bridge: taking, choosing and pasting a
/// picture, sizing it down and keeping it as a JPEG in the images folder.
final class ImageBridge: NSObject {
  /// The longest edge a kept picture is allowed. Enough for a phone screen,
  /// small enough to keep the folder from swelling.
  private static let longestEdge: CGFloat = 1600

  private var pending: ((String?) -> Void)?

  static var directory: URL {
    let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    let folder = documents.appendingPathComponent("images", isDirectory: true)
    try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    return folder
  }

  /// Sizes the picture down and writes it out. Returns the file name.
  static func keep(_ image: UIImage) -> String? {
    let scale = min(1, longestEdge / max(image.size.width, image.size.height))
    let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    let drawn = UIGraphicsImageRenderer(size: size, format: format).image { _ in
      image.draw(in: CGRect(origin: .zero, size: size))
    }
    guard let data = drawn.jpegData(compressionQuality: 0.85) else { return nil }
    let name = UUID().uuidString.lowercased() + ".jpg"
    do {
      try data.write(to: directory.appendingPathComponent(name), options: .atomic)
      return name
    } catch {
      return nil
    }
  }

  static func delete(_ name: String) {
    try? FileManager.default.removeItem(at: directory.appendingPathComponent(name))
  }

  static func paste() -> String? {
    guard let image = UIPasteboard.general.image else { return nil }
    return keep(image)
  }

  private var presenter: UIViewController? {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    let window = scenes.flatMap { $0.windows }.first { $0.isKeyWindow }
    var top = window?.rootViewController
    while let next = top?.presentedViewController { top = next }
    return top
  }

  /// Puts up the camera or the photo picker and hands back the file name
  /// once a picture has been kept, or null when backed out of.
  func pick(_ source: String, completion: @escaping (String?) -> Void) {
    guard let presenter = presenter else {
      completion(nil)
      return
    }
    pending = completion
    if source == "camera" {
      guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
        finish(nil)
        return
      }
      let camera = UIImagePickerController()
      camera.sourceType = .camera
      camera.delegate = self
      presenter.present(camera, animated: true)
      return
    }
    var configuration = PHPickerConfiguration()
    configuration.filter = .images
    configuration.selectionLimit = 1
    let picker = PHPickerViewController(configuration: configuration)
    picker.delegate = self
    presenter.present(picker, animated: true)
  }

  private func finish(_ name: String?) {
    DispatchQueue.main.async {
      self.pending?(name)
      self.pending = nil
    }
  }
}

extension ImageBridge: PHPickerViewControllerDelegate {
  func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
    picker.dismiss(animated: true)
    guard let provider = results.first?.itemProvider,
      provider.canLoadObject(ofClass: UIImage.self)
    else {
      finish(nil)
      return
    }
    provider.loadObject(ofClass: UIImage.self) { object, _ in
      self.finish((object as? UIImage).flatMap(ImageBridge.keep))
    }
  }
}

extension ImageBridge: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
  func imagePickerController(
    _ picker: UIImagePickerController,
    didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
  ) {
    picker.dismiss(animated: true)
    let image = (info[.editedImage] ?? info[.originalImage]) as? UIImage
    finish(image.flatMap(ImageBridge.keep))
  }

  func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
    picker.dismiss(animated: true)
    finish(nil)
  }
}
