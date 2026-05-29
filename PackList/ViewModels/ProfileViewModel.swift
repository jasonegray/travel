import Foundation

enum AppearancePreference: String, CaseIterable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"
}

@Observable
final class ProfileViewModel {

    private let defaults: UserDefaults

    var fullName: String = ""
    var homeAirport: String = ""
    var appearance: AppearancePreference = .system

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        fullName = defaults.string(forKey: "profile_full_name") ?? ""
        homeAirport = defaults.string(forKey: "profile_home_airport") ?? ""
        appearance = AppearancePreference(rawValue: defaults.string(forKey: "profile_appearance") ?? "") ?? .system
    }

    func save() {
        defaults.set(fullName, forKey: "profile_full_name")
        defaults.set(homeAirport, forKey: "profile_home_airport")
        defaults.set(appearance.rawValue, forKey: "profile_appearance")
    }

    func resetOnboarding() {
        defaults.set(false, forKey: UserDefaults.onboardingCompletedKey)
    }
}
