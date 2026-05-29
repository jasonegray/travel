import SwiftUI

struct OnboardingView: View {
    @State private var vm = OnboardingViewModel()
    @State private var currentStep = 0
    @Environment(ProfileViewModel.self) private var profile
    let onFinish: (_ createFirstTrip: Bool) -> Void

    private let stepCount = 3  // steps 1–3 tracked by dots (welcome has no dots)

    var body: some View {
        ZStack(alignment: .top) {
            TabView(selection: $currentStep) {
                WelcomeStep(
                    onGetStarted: { advance() },
                    onSkip: { finish(createTrip: false) }
                )
                .tag(0)

                NameStep(
                    name: $vm.fullName,
                    onContinue: { advance() },
                    onSkip: { finish(createTrip: false) }
                )
                .tag(1)

                AirportStep(
                    airport: $vm.homeAirport,
                    onContinue: { advance() },
                    onSkip: { finish(createTrip: false) }
                )
                .tag(2)

                DoneStep(onCreateFirstTrip: { finish(createTrip: true) })
                    .tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()

            if currentStep > 0 {
                OnboardingStepDots(total: stepCount, current: currentStep - 1)
                    .padding(.top, 16)
            }
        }
    }

    private func advance() {
        withAnimation(.easeInOut(duration: 0.25)) {
            currentStep = min(currentStep + 1, 3)
        }
    }

    private func finish(createTrip: Bool) {
        vm.flush(to: profile)
        onFinish(createTrip)
    }
}

// MARK: - Step dots

private struct OnboardingStepDots: View {
    let total: Int
    let current: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<total, id: \.self) { i in
                Circle()
                    .fill(i == current ? Color.primary : Color.secondary.opacity(0.3))
                    .frame(width: i == current ? 8 : 6, height: i == current ? 8 : 6)
                    .animation(.easeInOut(duration: 0.2), value: current)
            }
        }
    }
}

// MARK: - Step shell

private struct OnboardingStepShell<Content: View>: View {
    let title: String
    var subtitle: String? = nil
    let onContinue: () -> Void
    let onSkip: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .font(.title2)
                        .fontWeight(.bold)
                    if let sub = subtitle {
                        Text(sub)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.bottom, 32)

                content()

                Spacer(minLength: 40)
            }
            .padding(.horizontal, 24)
            .padding(.top, 72)
            .padding(.bottom, 24)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 12) {
                Button(action: onContinue) {
                    Text("Continue")
                        .font(.body)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.primary, in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(Color(UIColor.systemBackground))
                }

                Button(action: onSkip) {
                    Text("Skip")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
            .background(.background)
        }
    }
}

// MARK: - Step 1: Welcome

private struct WelcomeStep: View {
    let onGetStarted: () -> Void
    let onSkip: () -> Void

    @ViewBuilder private var appIcon: some View {
        if let icons = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any],
           let primaryIcon = icons["CFBundlePrimaryIcon"] as? [String: Any],
           let iconFiles = primaryIcon["CFBundleIconFiles"] as? [String],
           let lastIcon = iconFiles.last,
           let icon = UIImage(named: lastIcon) {
            Image(uiImage: icon)
                .resizable()
                .frame(width: 120, height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 26))
                .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(.blue.gradient)
                    .frame(width: 88, height: 88)
                    .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
                Image(systemName: "suitcase.fill")
                    .font(.system(size: 38, weight: .medium))
                    .foregroundStyle(.white)
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 20) {
                appIcon

                VStack(spacing: 8) {
                    Text("PackList")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Text("Smart packing. Every trip.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(spacing: 12) {
                Button(action: onGetStarted) {
                    Text("Get Started")
                        .font(.body)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.primary, in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(Color(UIColor.systemBackground))
                }

                Button(action: onSkip) {
                    Text("Skip Setup")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Step 2: Name

private struct NameStep: View {
    @Binding var name: String
    let onContinue: () -> Void
    let onSkip: () -> Void

    var body: some View {
        OnboardingStepShell(
            title: "Your name",
            subtitle: "Used when sharing trip details with your emergency contact",
            onContinue: onContinue,
            onSkip: onSkip
        ) {
            TextField("Full name", text: $name)
                .textContentType(.name)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .font(.body)
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .background(.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
        }
    }
}

// MARK: - Step 3: Home airport

private struct AirportStep: View {
    @Binding var airport: String
    let onContinue: () -> Void
    let onSkip: () -> Void
    @State private var showPicker = false

    var body: some View {
        OnboardingStepShell(
            title: "Home airport",
            subtitle: "Your usual departure airport",
            onContinue: onContinue,
            onSkip: onSkip
        ) {
            Button {
                showPicker = true
            } label: {
                HStack {
                    Text(airport.isEmpty ? "Search city or airport code" : airport)
                        .foregroundStyle(airport.isEmpty ? .secondary : .primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.tertiary)
                        .font(.caption)
                }
                .font(.body)
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .background(.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
            }
            .sheet(isPresented: $showPicker) {
                AirportSearchView(selected: $airport)
            }
        }
    }
}

// MARK: - Step 4: Done

private struct DoneStep: View {
    let onCreateFirstTrip: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 20) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.green)

                VStack(spacing: 8) {
                    Text("You're all set")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("You are ready to pack")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button(action: onCreateFirstTrip) {
                Text("Create your first trip")
                    .font(.body)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.primary, in: RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(Color(UIColor.systemBackground))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
