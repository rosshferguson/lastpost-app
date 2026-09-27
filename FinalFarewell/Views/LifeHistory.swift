//
//  LifeHistory.swift
//  FinalFarewell
//
//  Data model for the guided life history prompts.
//  Stored in UserDefaults as JSON — no SwiftData schema change needed.
//
//  To access from anywhere:
//    let history = LifeHistory.load(forUserId: user.id)
//    history.save(forUserId: user.id)
//

import Foundation

struct LifeHistory: Codable {

    // MARK: - Prompts

    /// Where were you born, and where did you grow up?
    var origins: String = ""

    /// Tell us about your family — parents, siblings, and the people who shaped you.
    var family: String = ""

    /// What did you do for work? What were you most proud of professionally?
    var career: String = ""

    /// What were your greatest passions, hobbies, or interests?
    var passions: String = ""

    /// What moments in your life meant the most to you?
    var memorablemoments: String = ""

    /// What do you most want people to remember about you?
    var legacy: String = ""

    /// Is there anything else you'd like your loved ones to know?
    var finalThoughts: String = ""

    // MARK: - Persistence

    private static func key(forUserId userId: UUID) -> String {
        "ff_life_history_\(userId.uuidString)"
    }

    static func load(forUserId userId: UUID) -> LifeHistory {
        guard
            let data = UserDefaults.standard.data(forKey: key(forUserId: userId)),
            let history = try? JSONDecoder().decode(LifeHistory.self, from: data)
        else {
            return LifeHistory()
        }
        return history
    }

    func save(forUserId userId: UUID) {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: LifeHistory.key(forUserId: userId))
    }

    // MARK: - Helpers

    /// True if any prompt has been answered.
    var hasAnyContent: Bool {
        [origins, family, career, passions, memorablemoments, legacy, finalThoughts]
            .contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    /// Number of prompts answered.
    var completedCount: Int {
        [origins, family, career, passions, memorablemoments, legacy, finalThoughts]
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .count
    }

    static let totalPrompts = 7
}
