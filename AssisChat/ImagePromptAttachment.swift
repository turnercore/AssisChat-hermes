//
//  ImagePromptAttachment.swift
//  AssisChat
//

import SwiftUI
#if os(iOS)
import UIKit
#endif

#if os(iOS)
enum ImageAttachmentSource: String, Identifiable {
    case camera
    case photoLibrary

    var id: String { rawValue }

    var pickerSourceType: UIImagePickerController.SourceType {
        switch self {
        case .camera:
            return .camera
        case .photoLibrary:
            return .photoLibrary
        }
    }
}

struct ImageAttachmentPicker: UIViewControllerRepresentable {
    let source: ImageAttachmentSource
    let onComplete: (Result<UIImage, Error>) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = source.pickerSourceType
        picker.mediaTypes = ["public.image"]
        picker.allowsEditing = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onComplete: onComplete)
    }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let onComplete: (Result<UIImage, Error>) -> Void

        init(onComplete: @escaping (Result<UIImage, Error>) -> Void) {
            self.onComplete = onComplete
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            picker.dismiss(animated: true)

            guard let image = info[.originalImage] as? UIImage else {
                onComplete(.failure(ImagePromptAttachment.Error.noImage))
                return
            }

            onComplete(.success(image))
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

enum ImagePromptAttachment {
    enum Error: LocalizedError {
        case noImage
        case couldNotEncode
        case tooLarge

        var errorDescription: String? {
            switch self {
            case .noImage:
                return "No image was selected."
            case .couldNotEncode:
                return "The selected image could not be encoded."
            case .tooLarge:
                return "The selected image is too large to attach inline."
            }
        }
    }

    static func block(from image: UIImage) throws -> String {
        let resized = image.resizedForPromptAttachment(maxDimension: 768)
        let qualities: [CGFloat] = [0.62, 0.48, 0.36]

        for quality in qualities {
            guard let data = resized.jpegData(compressionQuality: quality) else {
                throw Error.couldNotEncode
            }

            guard data.count <= 650_000 else { continue }

            let base64 = data.base64EncodedString()
            return """

            Image attachment:
            ```data:image/jpeg;base64
            \(base64)
            ```
            """
        }

        throw Error.tooLarge
    }

    static func isSupportedRemoteImageURL(_ url: URL) -> Bool {
        guard ["http", "https"].contains(url.scheme?.lowercased()) else { return false }
        let imageExtensions = ["jpg", "jpeg", "png", "gif", "webp", "heic"]
        return imageExtensions.contains(url.pathExtension.lowercased())
    }
}

private extension UIImage {
    func resizedForPromptAttachment(maxDimension: CGFloat) -> UIImage {
        let longestSide = max(size.width, size.height)
        guard longestSide > maxDimension else { return self }

        let scale = maxDimension / longestSide
        let targetSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}
#endif
