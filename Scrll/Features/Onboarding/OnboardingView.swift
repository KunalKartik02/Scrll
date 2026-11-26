import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var library: PhotoLibrary
    @State private var isRequesting = false

    var body: some View {
        VStack(spacing: 28) {
            Spacer(minLength: 20)

            Image(systemName: "photo.stack")
                .font(.system(size: 64, weight: .regular))
                .foregroundStyle(Color.accentColor)
                .accessibilityHidden(true)

            VStack(spacing: 8) {
                Text("Welcome to Tidyroll")
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
                Text("A calm, free way to sort your camera roll.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: 18) {
                FeatureRow(
                    symbol: "hand.draw",
                    title: "Swipe to sort",
                    detail: "Go month by month. Swipe right to keep, left to delete."
                )
                FeatureRow(
                    symbol: "square.stack",
                    title: "Organize into albums",
                    detail: "Select photos and file them into new or existing albums."
                )
                FeatureRow(
                    symbol: "sparkles",
                    title: "Free up space",
                    detail: "Find duplicates, screenshots and long videos."
                )
                FeatureRow(
                    symbol: "lock.shield",
                    title: "Private by design",
                    detail: "No accounts, no ads, no uploads. Everything stays on your iPhone."
                )
            }
            .padding(.horizontal, 8)

            Spacer(minLength: 20)

            Button {
                isRequesting = true
                Task {
                    await library.requestAccess()
                    isRequesting = false
                }
            } label: {
                Group {
                    if isRequesting {
                        ProgressView()
                    } else {
                        Text("Allow Photo Access")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isRequesting)

            Text("Deleted photos go to Recently Deleted, where you can recover them for 30 days.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
    }
}

private struct FeatureRow: View {
    let symbol: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(Color.accentColor)
                .frame(width: 32)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct AccessDeniedView: View {
    @EnvironmentObject private var library: PhotoLibrary

    var body: some View {
        ContentUnavailableView {
            Label("Photo Access Needed", systemImage: "lock.square.stack")
        } description: {
            if library.status == .restricted {
                Text("Photo access is restricted on this device, for example by Screen Time or a device profile.")
            } else {
                Text("Tidyroll can't see your photos. Turn on access in Settings → Tidyroll → Photos.")
            }
        } actions: {
            if library.status != .restricted {
                Button("Open Settings") {
                    SystemActions.openAppSettings()
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
}
