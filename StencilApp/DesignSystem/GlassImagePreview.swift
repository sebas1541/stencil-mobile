import SwiftUI
import UIKit

/// Standard preview frame: glass card + canvas background + a `ZoomableImageView`
/// inside. Falls back to a `ProgressView` when `image` is `nil`.
struct GlassImagePreview: View {
    let image: UIImage?
    var height: CGFloat = 360
    var allowZoom: Bool = true

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .fill(AppColor.canvasBackground)

            if let image {
                Group {
                    if allowZoom {
                        ZoomableImageView(image: image)
                    } else {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                    }
                }
                .padding(Spacing.md)
                .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
            } else {
                ProgressView()
                    .controlSize(.large)
                    .tint(AppColor.accent)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .liquidGlassCard()
    }
}
