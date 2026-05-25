import PencilKit
import SwiftUI

/// Thin SwiftUI wrapper around `PKCanvasView`. Exposes:
/// - a binding to the current `PKDrawing` so the parent view can read or
///   composite it,
/// - a `pencilOnly` toggle (when true, finger input is ignored so the artist
///   can rest a hand on the screen),
/// - automatic `PKToolPicker` show/hide tied to focus.
struct AnnotationCanvas: UIViewRepresentable {
    @Binding var drawing: PKDrawing
    var pencilOnly: Bool = true
    var isToolPickerVisible: Bool = true

    func makeCoordinator() -> Coordinator {
        Coordinator(drawing: $drawing)
    }

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.delegate = context.coordinator
        canvas.drawing = drawing
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.drawingPolicy = pencilOnly ? .pencilOnly : .anyInput
        canvas.alwaysBounceVertical = false
        canvas.alwaysBounceHorizontal = false

        // Show the tool picker on first responder activation so the user can
        // pick ink/marker/eraser without a separate UI.
        let picker = context.coordinator.toolPicker
        picker.setVisible(isToolPickerVisible, forFirstResponder: canvas)
        picker.addObserver(canvas)
        DispatchQueue.main.async {
            canvas.becomeFirstResponder()
        }
        return canvas
    }

    func updateUIView(_ canvas: PKCanvasView, context: Context) {
        canvas.drawingPolicy = pencilOnly ? .pencilOnly : .anyInput
        // Sync drawing in only when the parent has actually swapped it
        // (e.g. Clear). Avoid clobbering in-progress strokes.
        if context.coordinator.lastWrittenDrawing != drawing,
           canvas.drawing != drawing {
            canvas.drawing = drawing
            context.coordinator.lastWrittenDrawing = drawing
        }
        context.coordinator.toolPicker.setVisible(isToolPickerVisible, forFirstResponder: canvas)
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        @Binding var drawing: PKDrawing
        let toolPicker: PKToolPicker = PKToolPicker()
        var lastWrittenDrawing: PKDrawing = PKDrawing()

        init(drawing: Binding<PKDrawing>) {
            self._drawing = drawing
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            lastWrittenDrawing = canvasView.drawing
            drawing = canvasView.drawing
        }
    }
}
