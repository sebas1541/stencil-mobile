import SwiftUI
import UIKit

/// `UIScrollView`-backed image view that supports pinch-zoom (1x..6x), pan
/// while zoomed, and double-tap to reset. Used by every preview surface
/// (Result, Retouch, Overlay, Export).
struct ZoomableImageView: UIViewRepresentable {
    let image: UIImage
    var minZoom: CGFloat = 1.0
    var maxZoom: CGFloat = 6.0

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.minimumZoomScale = minZoom
        scrollView.maximumZoomScale = maxZoom
        scrollView.bouncesZoom = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.backgroundColor = .clear
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.decelerationRate = .fast

        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = true
        context.coordinator.imageView = imageView
        scrollView.addSubview(imageView)

        let doubleTap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleDoubleTap(_:))
        )
        doubleTap.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(doubleTap)

        return scrollView
    }

    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        let coord = context.coordinator
        if coord.imageView?.image !== image {
            coord.imageView?.image = image
            DispatchQueue.main.async { coord.layout(in: scrollView) }
        }
        DispatchQueue.main.async { coord.layout(in: scrollView) }
    }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        var imageView: UIImageView?

        func layout(in scrollView: UIScrollView) {
            guard let imageView, let image = imageView.image else { return }
            let bounds = scrollView.bounds
            guard bounds.width > 0, bounds.height > 0 else { return }

            // Aspect-fit the image inside the scroll view; then enable pan
            // when zoomed.
            let imageSize = image.size
            let widthScale = bounds.width / imageSize.width
            let heightScale = bounds.height / imageSize.height
            let scale = min(widthScale, heightScale)
            let fittedSize = CGSize(width: imageSize.width * scale,
                                    height: imageSize.height * scale)

            imageView.frame = CGRect(origin: .zero, size: fittedSize)
            scrollView.contentSize = fittedSize
            recenter(scrollView)
        }

        private func recenter(_ scrollView: UIScrollView) {
            guard let imageView else { return }
            let bounds = scrollView.bounds
            let content = imageView.frame.size
            let xPad = max(0, (bounds.width  - content.width)  / 2)
            let yPad = max(0, (bounds.height - content.height) / 2)
            scrollView.contentInset = UIEdgeInsets(top: yPad, left: xPad,
                                                    bottom: yPad, right: xPad)
        }

        // MARK: - UIScrollViewDelegate

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            imageView
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            recenter(scrollView)
        }

        @objc func handleDoubleTap(_ gr: UITapGestureRecognizer) {
            guard let scrollView = gr.view as? UIScrollView else { return }
            if scrollView.zoomScale > scrollView.minimumZoomScale + 0.01 {
                scrollView.setZoomScale(scrollView.minimumZoomScale, animated: true)
            } else {
                let location = gr.location(in: imageView)
                let target = min(scrollView.maximumZoomScale, scrollView.minimumZoomScale * 3)
                let zoomRect = zoomRectForScale(target, center: location, in: scrollView)
                scrollView.zoom(to: zoomRect, animated: true)
            }
        }

        private func zoomRectForScale(_ scale: CGFloat, center: CGPoint,
                                       in scrollView: UIScrollView) -> CGRect {
            let size = scrollView.bounds.size
            let w = size.width / scale
            let h = size.height / scale
            return CGRect(x: center.x - w / 2, y: center.y - h / 2,
                          width: w, height: h)
        }
    }
}
