import SwiftUI

@main
struct StencilApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .tint(AppColor.accent)
                .background(AppColor.primaryBackground.ignoresSafeArea())
#if DEBUG
                // Launch arg or env var triggers the mock result on the next
                // run loop. Lets the simulator showcase Refine / Annotate /
                // Export without a real microservice.
                .task {
                    let shouldMock = ProcessInfo.processInfo.arguments.contains("--mock-result")
                        || ProcessInfo.processInfo.environment["STENCIL_MOCK_RESULT"] == "1"
                    guard shouldMock else { return }
                    try? await Task.sleep(nanoseconds: 200_000_000)
                    await MainActor.run {
                        // Find the EditorViewModel via a notification — the
                        // RootView listens and forwards to its view model.
                        NotificationCenter.default.post(name: .stencilInjectMock, object: nil)
                    }
                }
#endif
        }
    }
}

extension Notification.Name {
    static let stencilInjectMock = Notification.Name("stencil.debug.injectMockResult")
}
