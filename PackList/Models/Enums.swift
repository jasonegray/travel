import Foundation

enum TravelRegion: String, Codable, CaseIterable {
    case canada, us, europe, japan, asia, other
}

enum TripPurpose: String, Codable, CaseIterable {
    case golf, business, personal, family
}

enum WeatherProfile: String, Codable, CaseIterable {
    case hot, warm, mild, cold, rainy
}

enum TravelCompanion: String, Codable, CaseIterable {
    case solo, spouse, kids, family, colleagues
}

enum ActivityType: String, Codable, CaseIterable {
    case golf, beach, pool, hiking, formalDinner, workout, sightseeing
}

enum TripStatus: String, Codable, CaseIterable {
    case planning, active, completed, archived
}

enum ItemCategory: String, Codable, CaseIterable {
    case clothing, golf, tech, health, meds, hygiene, documents, misc, workoutClothing
}

enum ItemType: String, Codable, CaseIterable {
    case physical, task
}

enum ItemTag: String, Codable, CaseIterable {
    case always, golf, beach, pool, workout, business, formal
    case cold, mild, warm, rainy, tropical
    case longHaul, overnightFlight, flightAccessible, wearOnPlane
    case international, domestic, japan, asia, europe, us, korea, canada
    case longTrip, shortTrip, airbnb
    case family, solo
    case medicalAppointment, injury, workKit
    case interacPhone, interacLaptop, level19Laptop
    case situational, conditional
}

enum PackingLocation: String, Codable, CaseIterable {
    case backpack, carryOn, techPouch, toiletryBag, passportWallet
    case golfBag, flightAccessPouch, checkedBag, wearing, pocket
}

enum TaskTiming: String, Codable, CaseIterable {
    case weekBefore, threeDaysBefore, dayBefore, morningOf
    case atAirport, onPlane, uponArrival
}

enum ItemSource: String, Codable, CaseIterable {
    case imported, user, aiSuggested
}

enum TripItemSource: String, Codable, CaseIterable {
    case generated, manual, aiSuggested, cloned, retrospective
}

enum FeedbackType: String, Codable, CaseIterable {
    case missing, unnecessary, wrongCategory, wrongQuantity, wrongLocation
}

enum SuggestionType: String, Codable, CaseIterable {
    case addItem, removeItem, recategorize, adjustQuantity, flagDuplicate, adjustTiming
}

enum SuggestionStatus: String, Codable, CaseIterable {
    case pending, approved, rejected
}

enum Replaceability: String, Codable, CaseIterable {
    case impossible, veryHard, hard, easy
}
