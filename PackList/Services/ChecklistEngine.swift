import Foundation

struct ChecklistEngine {

    // MARK: - Public API

    func generateItems(for session: TripSession, from masterItems: [MasterItem]) -> [TripItem] {
        let active = activeTags(for: session)
        let nights = tripNights(for: session)

        // 1. Filter
        var included = masterItems.filter { shouldInclude($0, activeTags: active) }

        // 4. Dependency resolution (runs until stable)
        included = resolveDependencies(included: included, from: masterItems)

        // 3 + 5. Quantity + convert to TripItem
        return included.map { makeTripItem(from: $0, session: session, nights: nights, activeTags: active) }
    }

    // MARK: - Tag derivation (internal for testability)

    func activeTags(for session: TripSession) -> Set<ItemTag> {
        var tags = Set<ItemTag>()

        // Weather
        switch session.weather {
        case .hot, .warm: tags.insert(.warm)
        case .cold:       tags.insert(.cold)
        case .rainy:      tags.insert(.rainy)
        case .mild:       break
        }

        // Activities
        if session.activities.contains(.golf) { tags.insert(.golf) }
        if session.activities.contains(.beach) || session.activities.contains(.pool) {
            tags.formUnion([.beach, .pool])
        }
        if session.activities.contains(.workout) { tags.insert(.workout) }
        if session.activities.contains(.conference) { tags.formUnion([.conference, .business]) }

        // Trip context
        if session.business { tags.insert(.business) }
        if session.companions.contains(.kids) || session.companions.contains(.family) {
            tags.insert(.family)
        }

        // Region
        switch session.region {
        case .japan:  tags.formUnion([.japan, .asia, .international])
        case .asia:   tags.formUnion([.asia, .international])
        case .europe: tags.formUnion([.europe, .international])
        case .us:     tags.insert(.us)
        case .canada, .other: break
        }

        // Devices
        if session.interacPhone  { tags.insert(.interacPhone) }
        if session.interacLaptop { tags.insert(.interacLaptop) }

        // Medical
        if session.hasMedicalAppointment { tags.insert(.medicalAppointment) }

        // Duration
        if tripNights(for: session) > 5 { tags.insert(.longTrip) }

        // Flight items: only when flying. Long haul: only when flying international.
        if session.isFlyingTrip {
            tags.insert(.flightAccessible)
            if session.region != .canada && session.region != .us {
                tags.insert(.longHaul)
            }
        }

        return tags
    }

    func tripNights(for session: TripSession) -> Int {
        Calendar.current.dateComponents([.day],
            from: session.departureDate,
            to: session.returnDate).day ?? 0
    }

    // MARK: - Quantity resolution (internal for testability)

    func resolveQuantity(
        for item: MasterItem,
        nights: Int,
        activeTags: Set<ItemTag>,
        laundryAvailable: Bool
    ) -> Int {
        for rule in item.quantityRules {
            guard rule.contextTags.allSatisfy({ activeTags.contains($0) }) else { continue }
            if let required = rule.laundryAvailable, required != laundryAvailable { continue }
            return applyFormula(rule.formula, nights: nights)
        }
        return item.defaultQuantity
    }

    func applyFormula(_ formula: QuantityFormula, nights: Int) -> Int {
        switch formula {
        case .fixed(let n):
            return n
        case .halfDays(let roundUp):
            let half = Double(nights) / 2.0
            return roundUp ? Int(ceil(half)) : Int(floor(half))
        case .perDay:
            return nights
        case .custom(let base, let perDay, let roundUp):
            let total = Double(base) + Double(nights) * perDay
            return roundUp ? Int(ceil(total)) : Int(floor(total))
        }
    }

    // MARK: - Private helpers

    private func shouldInclude(_ item: MasterItem, activeTags: Set<ItemTag>) -> Bool {
        item.isAlwaysInclude
            || item.tags.contains(.always)
            || item.tags.contains(where: activeTags.contains)
    }

    private func resolveDependencies(included: [MasterItem], from allItems: [MasterItem]) -> [MasterItem] {
        var result = included
        var includedIds = Set(result.map(\.id))
        var changed = true
        while changed {
            changed = false
            for item in result {
                for candidate in allItems
                    where candidate.requiredByItemId == item.id && !includedIds.contains(candidate.id) {
                    result.append(candidate)
                    includedIds.insert(candidate.id)
                    changed = true
                }
            }
        }
        return result
    }

    private func makeTripItem(
        from item: MasterItem,
        session: TripSession,
        nights: Int,
        activeTags: Set<ItemTag>
    ) -> TripItem {
        let loc = item.packingLocation ?? .carryOn
        let resolvedLocation = (session.carryOnOnly && loc == .checkedBag) ? .carryOn : loc
        return TripItem(
            tripId: session.id,
            masterItemId: item.id,
            name: item.name,
            category: item.category,
            itemType: item.itemType,
            quantity: resolveQuantity(
                for: item,
                nights: nights,
                activeTags: activeTags,
                laundryAvailable: session.laundryAvailable
            ),
            packingLocation: resolvedLocation,
            flightAccessible: item.flightAccessible,
            recommendedTiming: item.recommendedTiming,
            source: .generated
        )
    }
}
