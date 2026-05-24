import Foundation

extension UserDefaults {
    static let onboardingCompletedKey = "onboarding_completed"
}

@Observable
final class OnboardingViewModel {
    var fullName = ""
    var homeAirport = ""
    var aeroplanNumber = ""
    var aeroplanTier: AeroplanTier = .none
    var bonvoyNumber = ""
    var bonvoyTier: BonvoyTier = .member

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let deviceName = NSFullUserName()
        if !deviceName.isEmpty {
            fullName = deviceName
        }
    }

    func flush(to profile: ProfileViewModel) {
        profile.fullName = fullName
        profile.homeAirport = homeAirport
        profile.aeroplanNumber = aeroplanNumber
        profile.aeroplanTier = aeroplanTier
        profile.bonvoyNumber = bonvoyNumber
        profile.bonvoyTier = bonvoyTier
        profile.save()
        defaults.set(true, forKey: UserDefaults.onboardingCompletedKey)
    }
}
