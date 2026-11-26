import Photos
import SwiftUI

struct RootView: View {
    @EnvironmentObject private var library: PhotoLibrary
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            switch library.status {
            case .authorized, .limited:
                MainTabView()
            case .notDetermined:
                OnboardingView()
            default:
                AccessDeniedView()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                library.refreshStatus()
            }
        }
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            LibraryView()
                .tabItem { Label("Library", systemImage: "photo.on.rectangle") }
            ReviewHomeView()
                .tabItem { Label("Review", systemImage: "hand.draw") }
            AlbumsView()
                .tabItem { Label("Albums", systemImage: "square.stack") }
            CleanupView()
                .tabItem { Label("Clean Up", systemImage: "sparkles") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
    }
}
