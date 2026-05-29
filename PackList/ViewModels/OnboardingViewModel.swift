import Foundation

extension UserDefaults {
    static let onboardingCompletedKey = "onboarding_completed"
}

@Observable
final class OnboardingViewModel {
    var fullName = ""
    var homeAirport = ""

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func flush(to profile: ProfileViewModel) {
        profile.fullName = fullName
        profile.homeAirport = homeAirport
        profile.save()
        defaults.set(true, forKey: UserDefaults.onboardingCompletedKey)
    }
}
