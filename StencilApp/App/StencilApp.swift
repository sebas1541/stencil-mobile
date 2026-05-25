import SwiftUI

@main
struct StencilApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .tint(AppColor.accent)
                .background(AppColor.primaryBackground.ignoresSafeArea())
        }
    }
}
