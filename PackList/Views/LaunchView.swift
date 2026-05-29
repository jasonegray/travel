import SwiftUI
import UIKit

struct LaunchView: View {
    @State private var contentOpacity: Double = 0

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Image("LaunchLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 27, style: .continuous))
                    .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 4)

                Text("PackList")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
            }
            .opacity(contentOpacity)
            .task {
                withAnimation(.easeIn(duration: 0.3)) {
                    contentOpacity = 1
                }
            }
        }
    }
}
