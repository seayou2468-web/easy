import SwiftUI
import UniformTypeIdentifiers

struct FolderPicker: UIViewControllerRepresentable {
    let onPicked: (URL) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        AppLogger.log("ENTER makeUIViewController")
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.folder], asCopy: true)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {
        AppLogger.log("ENTER updateUIViewController")
    }

    func makeCoordinator() -> Coordinator {
        AppLogger.log("ENTER makeCoordinator")
        return Coordinator(onPicked: onPicked)
    }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPicked: (URL) -> Void
        init(onPicked: @escaping (URL) -> Void) { self.onPicked = onPicked }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            AppLogger.log("ENTER documentPicker")
            guard let url = urls.first else { return }
            let normalized = url.standardizedFileURL
            _ = normalized.startAccessingSecurityScopedResource()
            onPicked(normalized)
        }
    }
}
