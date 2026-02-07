//
//  CameraCoordinator.swift
//  PostFit (MomCare)
//
//  UIImagePickerController coordinator for food camera
//

import SwiftUI
import UIKit

// MARK: - Camera Coordinator

class CameraCoordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
    let onImageCaptured: (UIImage) -> Void
    let onDismiss: () -> Void

    init(onImageCaptured: @escaping (UIImage) -> Void, onDismiss: @escaping () -> Void) {
        self.onImageCaptured = onImageCaptured
        self.onDismiss = onDismiss
    }

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        if let image = info[.originalImage] as? UIImage {
            onImageCaptured(image)
        }
        picker.dismiss(animated: true)
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        onDismiss()
        picker.dismiss(animated: true)
    }
}

// MARK: - Camera Picker

struct CameraPicker: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let onImageCaptured: (UIImage) -> Void

    func makeCoordinator() -> CameraCoordinator {
        CameraCoordinator(
            onImageCaptured: onImageCaptured,
            onDismiss: { isPresented = false }
        )
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()

        // Check if camera is available, fallback to photo library
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            picker.sourceType = .camera
            #if DEBUG
            print("📷 [Camera] Using camera source")
            #endif
        } else if UIImagePickerController.isSourceTypeAvailable(.photoLibrary) {
            picker.sourceType = .photoLibrary
            #if DEBUG
            print("📷 [Camera] Camera not available, using photo library")
            #endif
        } else {
            #if DEBUG
            print("❌ [Camera] No image source available!")
            #endif
            // Still set to photo library as fallback
            picker.sourceType = .photoLibrary
        }

        picker.delegate = context.coordinator
        picker.allowsEditing = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {
        // No updates needed
    }
}
