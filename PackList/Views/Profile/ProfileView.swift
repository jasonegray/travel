import SwiftUI
import Contacts
import UserNotifications

struct ProfileView: View {
    @Environment(ProfileViewModel.self) private var vm
    @State private var showAirportPicker = false
    @State private var showResetConfirmation = false
    @State private var contactsStatus: CNAuthorizationStatus = .notDetermined
    @State private var notificationsStatus: UNAuthorizationStatus = .notDetermined

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

                // MARK: Section 2 — Lists
                Section("Lists") {
                    NavigationLink(destination: MasterListView()) {
                        Label("Master List", systemImage: "list.bullet.rectangle")
                    }
                }

                // MARK: Section 3 — Permissions
                Section("Permissions") {
                    PermissionRow(name: "Contacts",
                                  systemImage: "person.crop.circle",
                                  status: contactsStatus.permissionLabel,
                                  isGranted: contactsStatus.isGranted)
                    PermissionRow(name: "Notifications",
                                  systemImage: "bell",
                                  status: notificationsStatus.permissionLabel,
                                  isGranted: notificationsStatus.isGranted)
                }

                // MARK: Section 4 — App
                Section("App") {
                    Picker("Appearance", selection: $vm.appearance) {
                        ForEach(AppearancePreference.allCases, id: \.self) { pref in
                            Text(pref.rawValue).tag(pref)
                        }
                    }
                    .onChange(of: vm.appearance) { vm.save() }
                    Button("Reset Setup Wizard") {
                        showResetConfirmation = true
                    }
                    .foregroundStyle(.orange)
                    .accessibilityIdentifier("resetOnboardingButton")
                }

                // MARK: Section 5 — About
                Section("About") {
                    LabeledContent("Version", value: appVersion)
                    LabeledContent("Build", value: buildNumber)
                }
            }
            .navigationTitle("Profile")
            .confirmationDialog(
                "Reset Setup Wizard?",
                isPresented: $showResetConfirmation,
                titleVisibility: .visible
            ) {
                Button("Reset", role: .destructive) {
                    vm.resetOnboarding()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("The setup wizard will show again on next launch.")
            }
        }
        .task {
            contactsStatus = CNContactStore.authorizationStatus(for: .contacts)
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            notificationsStatus = settings.authorizationStatus
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
    }
}

// MARK: - Permission row

private struct PermissionRow: View {
    let name: String
    let systemImage: String
    let status: String
    let isGranted: Bool

    var body: some View {
        Button {
            // Already granted → nothing to change in Settings. Acknowledge the
            // tap with a subtle haptic instead of a jarring app-switch to Settings.
            guard !isGranted else {
                HapticManager.selectionChanged()
                return
            }
            guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
            UIApplication.shared.open(url)
        } label: {
            LabeledContent {
                HStack(spacing: 6) {
                    Text(status)
                        .foregroundStyle(.secondary)
                    if isGranted {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }
            } label: {
                Label(name, systemImage: systemImage)
                    .foregroundStyle(.primary)
            }
        }
        .foregroundStyle(.primary)
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

    private var needsDoneButton: Bool {
        keyboardType == .numberPad || keyboardType == .phonePad
    }

    var body: some View {
        LabeledContent(label) {
            TextField(placeholder, text: $text)
                .multilineTextAlignment(.trailing)
                .autocorrectionDisabled()
                .textInputAutocapitalization(capitalization)
                .keyboardType(keyboardType)
                .toolbar {
                    if needsDoneButton {
                        ToolbarItemGroup(placement: .keyboard) {
                            Spacer()
                            Button("Done") {
                                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                            }
                        }
                    }
                }
        }
    }
}

// MARK: - Permission status labels

private extension CNAuthorizationStatus {
    var permissionLabel: String {
        switch self {
        case .authorized:    return "Granted"
        case .denied:        return "Denied"
        case .restricted:    return "Restricted"
        case .notDetermined: return "Not Set"
        @unknown default:    return "Unknown"
        }
    }

    var isGranted: Bool { self == .authorized }
}

private extension UNAuthorizationStatus {
    var permissionLabel: String {
        switch self {
        case .authorized:    return "Granted"
        case .denied:        return "Denied"
        case .provisional:   return "Provisional"
        case .ephemeral:     return "Ephemeral"
        case .notDetermined: return "Not Set"
        @unknown default:    return "Unknown"
        }
    }

    var isGranted: Bool { self == .authorized }
}
