import SwiftUI

struct ProfileView: View {
    @Environment(ProfileViewModel.self) private var vm
    @State private var onboardingResetConfirmed = false
    @State private var showAirportPicker = false

    var body: some View {
        @Bindable var vm = vm
        NavigationStack {
            Form {
                // MARK: Section 1 — Personal
                Section("Personal") {
                    ProfileRow("Full name", text: $vm.fullName, placeholder: "Your name",
                               capitalization: .words)
                        .onChange(of: vm.fullName) { vm.save() }
                    Button { showAirportPicker = true } label: {
                        LabeledContent("Home airport") {
                            Text(vm.homeAirport.isEmpty ? "Search" : vm.homeAirport)
                                .foregroundStyle(vm.homeAirport.isEmpty ? .secondary : .primary)
                        }
                    }
                    .foregroundStyle(.primary)
                    .sheet(isPresented: $showAirportPicker, onDismiss: { vm.save() }) {
                        AirportSearchView(selected: $vm.homeAirport)
                    }
                }

                // MARK: Section 2 — Air Canada
                Section("Air Canada") {
                    ProfileRow("Aeroplan number", text: $vm.aeroplanNumber,
                               placeholder: "e.g. 123456789", keyboardType: .numberPad)
                        .onChange(of: vm.aeroplanNumber) { vm.save() }
                    Picker("Status tier", selection: $vm.aeroplanTier) {
                        ForEach(AeroplanTier.allCases, id: \.self) { tier in
                            Text(tier.rawValue).tag(tier)
                        }
                    }
                    .onChange(of: vm.aeroplanTier) { vm.save() }
                }

                // MARK: Section 3 — Marriott Bonvoy
                Section("Marriott Bonvoy") {
                    ProfileRow("Bonvoy number", text: $vm.bonvoyNumber,
                               placeholder: "e.g. 123456789", keyboardType: .numberPad)
                        .onChange(of: vm.bonvoyNumber) { vm.save() }
                    Picker("Status tier", selection: $vm.bonvoyTier) {
                        ForEach(BonvoyTier.allCases, id: \.self) { tier in
                            Text(tier.rawValue).tag(tier)
                        }
                    }
                    .onChange(of: vm.bonvoyTier) { vm.save() }
                }

                // MARK: Section 4 — Lists
                Section("Lists") {
                    NavigationLink(destination: MasterListView()) {
                        Label("Master List", systemImage: "list.bullet.rectangle")
                    }
                }

                // MARK: Section 5 — App
                Section {
                    Picker("Appearance", selection: $vm.appearance) {
                        ForEach(AppearancePreference.allCases, id: \.self) { pref in
                            Text(pref.rawValue).tag(pref)
                        }
                    }
                    .onChange(of: vm.appearance) { vm.save() }
                    LabeledContent("Version", value: appVersion)
                    LabeledContent("Build", value: buildNumber)
                    Button("Reset Setup Wizard") {
                        vm.resetOnboarding()
                        onboardingResetConfirmed = true
                    }
                    .foregroundStyle(.orange)
                    .accessibilityIdentifier("resetOnboardingButton")
                } header: {
                    Text("App")
                } footer: {
                    if onboardingResetConfirmed {
                        Text("Setup wizard will show on next launch")
                    }
                }
            }
            .navigationTitle("Profile")
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
    }
}

// MARK: - Profile text field row

private struct ProfileRow: View {
    let label: String
    @Binding var text: String
    let placeholder: String
    var capitalization: TextInputAutocapitalization = .characters
    var keyboardType: UIKeyboardType = .default

    init(_ label: String, text: Binding<String>, placeholder: String = "",
         capitalization: TextInputAutocapitalization = .characters,
         keyboardType: UIKeyboardType = .default) {
        self.label = label
        _text = text
        self.placeholder = placeholder
        self.capitalization = capitalization
        self.keyboardType = keyboardType
    }

    var body: some View {
        LabeledContent(label) {
            TextField(placeholder, text: $text)
                .multilineTextAlignment(.trailing)
                .autocorrectionDisabled()
                .textInputAutocapitalization(capitalization)
                .keyboardType(keyboardType)
        }
    }
}
