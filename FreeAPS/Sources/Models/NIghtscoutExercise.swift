import Foundation

struct NightscoutExercise: JSON, Hashable, Equatable {
    var duration: Int?
    var eventType: EventType
    var createdAt: Date
    var enteredBy: String?
    var notes: String?
    // var mills: Int

    static let local = "iAPS"

    static let empty = NightscoutExercise(from: "{}")!
    static func == (lhs: NightscoutExercise, rhs: NightscoutExercise) -> Bool {
        (lhs.createdAt) == rhs.createdAt
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(createdAt)
    }
}

extension NightscoutExercise {
    private enum CodingKeys: String, CodingKey {
        case duration
        case eventType
        case createdAt = "created_at"
        case enteredBy
        case notes
        // case mills
    }
}
