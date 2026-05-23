import Foundation
import os.log

private let logger = Logger(subsystem: "com.packlist", category: "ProfileViewModel")

enum AppearancePreference: String, CaseIterable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"
}

enum AeroplanTier: String, CaseIterable {
    case none = "None"
    case elite35k = "Elite 35K"
    case elite50k = "Elite 50K"
    case elite75k = "Elite 75K"
    case superElite = "Super Elite"
}

enum BonvoyTier: String, CaseIterable {
    case member = "Member"
    case silverElite = "Silver Elite"
    case goldElite = "Gold Elite"
    case platinumElite = "Platinum Elite"
    case titaniumElite = "Titanium Elite"
}

@Observable
final class ProfileViewModel {

    private let defaults: UserDefaults

    var fullName: String = ""
    var homeAirport: String = ""
    var aeroplanNumber: String = ""
    var aeroplanTier: AeroplanTier = .none
    var bonvoyNumber: String = ""
    var bonvoyTier: BonvoyTier = .member
    var appearance: AppearancePreference = .system

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        fullName = defaults.string(forKey: "profile_full_name") ?? ""
        homeAirport = defaults.string(forKey: "profile_home_airport") ?? ""
        aeroplanNumber = defaults.string(forKey: "profile_aeroplan_number") ?? ""
        aeroplanTier = AeroplanTier(rawValue: defaults.string(forKey: "profile_aeroplan_tier") ?? "") ?? .none
        bonvoyNumber = defaults.string(forKey: "profile_bonvoy_number") ?? ""
        bonvoyTier = BonvoyTier(rawValue: defaults.string(forKey: "profile_bonvoy_tier") ?? "") ?? .member
        appearance = AppearancePreference(rawValue: defaults.string(forKey: "profile_appearance") ?? "") ?? .system
    }

    func save() {
        defaults.set(fullName, forKey: "profile_full_name")
        defaults.set(homeAirport, forKey: "profile_home_airport")
        defaults.set(aeroplanNumber, forKey: "profile_aeroplan_number")
        defaults.set(aeroplanTier.rawValue, forKey: "profile_aeroplan_tier")
        defaults.set(bonvoyNumber, forKey: "profile_bonvoy_number")
        defaults.set(bonvoyTier.rawValue, forKey: "profile_bonvoy_tier")
        defaults.set(appearance.rawValue, forKey: "profile_appearance")
    }
}
