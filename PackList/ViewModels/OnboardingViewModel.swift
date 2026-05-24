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
        if fullName.isEmpty {
            prefillNameIfAvailable()
        }
    }

    private func prefillNameIfAvailable() {
        let store = CNContactStore()
        store.requestAccess(for: .contacts) { granted, _ in
            guard granted else { return }
            let keys = [CNContactGivenNameKey, CNContactFamilyNameKey] as [CNKeyDescriptor]
            let request = CNContactFetchRequest(keysToFetch: keys)
            try? store.enumerateContacts(with: request) { contact, stop in
                let full = [contact.givenName, contact.familyName]
                    .filter { !$0.isEmpty }.joined(separator: " ")
                if !full.isEmpty {
                    DispatchQueue.main.async {
                        if self.fullName.isEmpty { self.fullName = full }
                    }
                    stop.pointee = true
                }
            }
        }
    }

    func flush(to profile: ProfileViewModel) {
        profile.fullName = fullName
        profile.homeAirport = homeAirport.uppercased()
        profile.aeroplanNumber = aeroplanNumber
        profile.aeroplanTier = aeroplanTier
        profile.bonvoyNumber = bonvoyNumber
        profile.bonvoyTier = bonvoyTier
        profile.save()
        defaults.set(true, forKey: UserDefaults.onboardingCompletedKey)
    }
}
