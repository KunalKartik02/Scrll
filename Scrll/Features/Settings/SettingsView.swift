import Photos
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var library: PhotoLibrary
    @EnvironmentObject private var progress: ReviewProgressStore

    @State private var showingResetConfirm = false

    private var accessDescription: String {
        switch library.status {
        case .authorized: return "Full Access"
        case .limited: return "Selected Photos"
        case .denied: return "No Access"
        case .restricted: return "Restricted"
        case .notDetermined: return "Not Set"
        @unknown default: return "Unknown"
        }
    }

    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Photo Access") {
                    LabeledContent("Access", value: accessDescription)
                    if library.isLimited {
                        Button("Choose More Photos") {
                            SystemActions.presentLimitedLibraryPicker()
                        }
                    }
                    Button("Change in Settings") {
                        SystemActions.openAppSettings()
                    }
                }

                Section {
                    LabeledContent("Reviewed", value: progress.reviewed.count.counted("item"))
                    Button("Reset Review Progress", role: .destructive) {
                        showingResetConfirm = true
                    }
                    .disabled(progress.reviewed.isEmpty)
                } header: {
                    Text("Review")
                } footer: {
                    Text("Photos you keep are remembered so they're skipped next time. Resetting doesn't change your photos.")
                }

                Section {
                    Label("Free, with no ads or subscriptions", systemImage: "gift")
                    Label("No account and no tracking", systemImage: "person.crop.circle.badge.xmark")
                    Label("Your photos never leave your device", systemImage: "lock.iphone")
                } header: {
                    Text("Privacy")
                }

                Section("About") {
                    LabeledContent("Version", value: appVersion)
                }
            }
            .navigationTitle("Settings")
            .confirmationDialog(
                "Reset review progress?",
                isPresented: $showingResetConfirm,
                titleVisibility: .visible
            ) {
                Button("Reset", role: .destructive) { progress.reset() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Every photo will show up as unreviewed again.")
            }
        }
    }
}
