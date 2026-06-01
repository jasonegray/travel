import SwiftUI

// Pattern C — brief non-blocking banner for reversible mutation failures (save, update, delete).
// Attaches to any view via .toast(message:). Auto-dismisses after 3 seconds.
struct ToastModifier: ViewModifier {
    @Binding var message: String?

    func body(content: Content) -> some View {
        content.overlay(alignment: .top) {
            if let msg = message {
                ToastBanner(message: msg)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                message = nil
                            }
                        }
                    }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: message)
    }
}

private struct ToastBanner: View {
    let message: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(.white)
            Text(message)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(.systemGray), in: Capsule())
        .padding(.horizontal)
        .padding(.top, 8)
    }
}

extension View {
    func toast(message: Binding<String?>) -> some View {
        modifier(ToastModifier(message: message))
    }
}
