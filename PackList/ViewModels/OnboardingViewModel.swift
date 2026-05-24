import Foundation
import Contacts

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

    func prefillNameFromMeCard() async {
        let store = CNContactStore()
        let status = CNContactStore.authorizationStatus(for: .contacts)

        let granted: Bool
        if status == .notDetermined {
            do {
                granted = try await store.requestAccess(for: .contacts)
            } catch {
                return
            }
        } else {
            granted = status == .authorized
        }

        guard granted else { return }

        let keys = [CNContactGivenNameKey, CNContactFamilyNameKey] as [CNKeyDescriptor]
        guard let me = try? store.unifiedMeContact(withKeys: keys) else { return }

        let name = [me.givenName, me.familyName]
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        guard !name.isEmpty, fullName.isEmpty else { return }
        fullName = name
    }
}
