import Foundation

struct QuantityRule: Codable {
    var contextTags: [ItemTag]
    var laundryAvailable: Bool?
    var formula: QuantityFormula
}

enum QuantityFormula: Codable {
    case fixed(Int)
    case halfDays(roundUp: Bool)
    case perDay
    case custom(base: Int, perDay: Double, roundUp: Bool)
}
