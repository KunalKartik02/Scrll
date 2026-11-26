import SwiftUI

@main
struct ScrllApp: App {
    @StateObject private var library = PhotoLibrary()
    @StateObject private var progress = ReviewProgressStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(library)
                .environmentObject(progress)
        }
    }
}
