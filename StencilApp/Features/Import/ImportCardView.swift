import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

/// Reusable glass card that combines a `PhotosPicker`, drag-and-drop, and a
/// preview of the currently-selected image. Used as the canvas anchor in the
/// editor.
struct ImportCardView: View {
    @Binding var selectedImage: UIImage?
    @Binding var selectedFilename: String?

    @State private var photoItem: PhotosPickerItem?
    @State private var isTargeted = false
    @State private var loadError: String?

    var body: some View {
        VStack(spacing: Spacing.md) {
            preview
            controls
            if let loadError {
                Text(loadError)
                    .font(.footnote)
                    .foregroundStyle(AppColor.danger)
            }
        }
        .padding(Spacing.lg)
        .liquidGlassCard()
        .onChange(of: photoItem) { _, newItem in
            guard let newItem else { return }
            Task { await load(item: newItem) }
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var preview: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .strokeBorder(
                    isTargeted ? AppColor.accent : AppColor.borderSubtle,
                    style: StrokeStyle(lineWidth: isTargeted ? 2 : 1, dash: [6, 6])
                )
                .background(
                    RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                        .fill(AppColor.canvasBackground.opacity(0.6))
                )

            if let selectedImage {
                Image(uiImage: selectedImage)
                    .resizable()
                    .scaledToFit()
                    .padding(Spacing.md)
            } else {
                VStack(spacing: Spacing.sm) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 36, weight: .light))
                        .foregroundStyle(.secondary)
                    Text("Drop a reference image, or pick from Photos")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Spacing.lg)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 240, maxHeight: 360)
        .onDrop(of: [.image], isTargeted: $isTargeted) { providers in
            handleDrop(providers: providers)
        }
    }

    private var controls: some View {
        HStack(spacing: Spacing.md) {
            PhotosPicker(
                selection: $photoItem,
                matching: .images,
                photoLibrary: .shared()
            ) {
                Label(selectedImage == nil ? "Choose photo" : "Replace photo",
                      systemImage: "photo.badge.plus")
                    .frame(maxWidth: .infinity)
            }
            .liquidGlassButton(.prominent)

            if selectedImage != nil {
                Button(role: .destructive) {
                    selectedImage = nil
                    selectedFilename = nil
                    photoItem = nil
                    loadError = nil
                } label: {
                    Label("Clear", systemImage: "trash")
                }
                .liquidGlassButton(.subtle)
            }
        }
    }

    // MARK: - Loading

    private func load(item: PhotosPickerItem) async {
        loadError = nil
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                loadError = "Could not read the selected photo."
                return
            }
            guard data.count <= APILimits.maxImageBytes else {
                loadError = String(
                    format: "Photo is %.1f MB — max is 15 MB.",
                    Double(data.count) / 1_048_576
                )
                return
            }
            guard let image = UIImage(data: data) else {
                loadError = "Selected file is not a supported image format."
                return
            }
            await MainActor.run {
                selectedImage = image
                selectedFilename = item.itemIdentifier ?? "reference.jpg"
            }
        } catch {
            loadError = "Failed to load: \(error.localizedDescription)"
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, error in
            DispatchQueue.main.async {
                if let error {
                    loadError = "Drop failed: \(error.localizedDescription)"
                    return
                }
                guard let data else {
                    loadError = "Dropped item had no data."
                    return
                }
                guard data.count <= APILimits.maxImageBytes else {
                    loadError = String(
                        format: "Dropped image is %.1f MB — max is 15 MB.",
                        Double(data.count) / 1_048_576
                    )
                    return
                }
                guard let image = UIImage(data: data) else {
                    loadError = "Dropped file is not a supported image format."
                    return
                }
                selectedImage = image
                selectedFilename = provider.suggestedName ?? "reference.jpg"
                loadError = nil
            }
        }
        return true
    }
}
