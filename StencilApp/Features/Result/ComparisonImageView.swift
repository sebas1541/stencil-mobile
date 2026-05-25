import SwiftUI
import UIKit

/// Side-by-side image comparison with a draggable vertical handle that
/// reveals the "after" image over the "before". Same UX as the TattooStencilPro
/// reference screenshots.
///
/// The implementation lays both images inside an `Image(...).scaledToFit()` so
/// they share an aspect-fit frame. The "after" image is masked by a rectangle
/// whose width is driven by the drag handle's position.
struct ComparisonImageView: View {
    let before: UIImage
    let after: UIImage

    /// Position of the divider as a fraction of the available width (0…1).
    @State private var splitFraction: CGFloat = 0.5

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                // Background: the "before" image fills the frame.
                Image(uiImage: before)
                    .resizable()
                    .scaledToFit()
                    .frame(width: proxy.size.width, height: proxy.size.height)

                // Foreground: the "after" image, masked to the left half.
                Image(uiImage: after)
                    .resizable()
                    .scaledToFit()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .mask(alignment: .leading) {
                        Rectangle()
                            .frame(
                                width: max(0, proxy.size.width * splitFraction),
                                height: proxy.size.height
                            )
                    }

                // Divider line + handle.
                handle(in: proxy.size)
            }
            .contentShape(Rectangle())
            .gesture(dragGesture(in: proxy.size))
        }
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        .accessibilityLabel("Comparison")
        .accessibilityValue("\(Int(splitFraction * 100))% revealed")
    }

    // MARK: - Handle

    @ViewBuilder
    private func handle(in size: CGSize) -> some View {
        let x = max(0, min(size.width, size.width * splitFraction))
        ZStack {
            Rectangle()
                .fill(AppColor.accent.opacity(0.85))
                .frame(width: 2, height: size.height)
                .shadow(color: AppColor.accent.opacity(0.4), radius: 4)

            Circle()
                .fill(AppColor.accent)
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: "arrow.left.and.right")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(.white)
                )
                .shadow(color: AppColor.accent.opacity(0.45), radius: 6, x: 0, y: 2)
        }
        .position(x: x, y: size.height / 2)
    }

    // MARK: - Gesture

    private func dragGesture(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let location = value.location.x
                let next = max(0, min(1, location / size.width))
                splitFraction = next
            }
    }
}
