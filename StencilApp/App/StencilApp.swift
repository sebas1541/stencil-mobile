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
                    let args = ProcessInfo.processInfo.arguments
                    let env = ProcessInfo.processInfo.environment

                    let shouldMockResult = args.contains("--mock-result")
                        || env["STENCIL_MOCK_RESULT"] == "1"
                    let shouldMockGenerating = args.contains("--mock-generating")
                        || env["STENCIL_MOCK_GENERATING"] == "1"

                    guard shouldMockResult || shouldMockGenerating else { return }
                    try? await Task.sleep(nanoseconds: 200_000_000)
                    await MainActor.run {
                        if shouldMockGenerating {
                            NotificationCenter.default.post(name: .stencilInjectMockGenerating, object: nil)
                        }
                        if shouldMockResult {
                            NotificationCenter.default.post(name: .stencilInjectMock, object: nil)
                        }
                    }
                }
#endif
        }
    }
}

extension Notification.Name {
    static let stencilInjectMock = Notification.Name("stencil.debug.injectMockResult")
    static let stencilInjectMockGenerating = Notification.Name("stencil.debug.injectMockGenerating")
}
