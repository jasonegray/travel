import SwiftUI

// Pattern A — shown when a .task { await vm.load() } fails.
// Use instead of a generic empty state so load failure is distinguishable from "no data yet".
struct LoadErrorState: View {
    var message: String = "Something went wrong loading your data."
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)

            VStack(spacing: 6) {
                Text("Couldn't Load Your Data")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button("Try Again", action: onRetry)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

            Spacer()
        }
        .padding(.horizontal)
    }
}
