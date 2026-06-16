import Foundation

struct BuiltInPetTheme: Identifiable, Equatable {
    let id: String
    let displayName: String
    let description: String
    let defaultFPS: Int

    static let dog = BuiltInPetTheme(
        id: "Dog",
        displayName: "Dog",
        description: "A friendly all-round puppy with balanced motion.",
        defaultFPS: 10
    )

    static let pufferfish = BuiltInPetTheme(
        id: "Pufferfish",
        displayName: "Pufferfish",
        description: "A soft floating puffer with gentler pacing.",
        defaultFPS: 8
    )

    static let squirrel = BuiltInPetTheme(
        id: "Squirrel",
        displayName: "Squirrel",
        description: "A quick-tailed squirrel with slightly snappier motion.",
        defaultFPS: 12
    )

    static let hamster = BuiltInPetTheme(
        id: "Hamster",
        displayName: "Hamster",
        description: "A round hamster that feels cozy and compact.",
        defaultFPS: 9
    )

    static let cat = BuiltInPetTheme(
        id: "Cat",
        displayName: "Cat",
        description: "A warm orange cat with easy idle confidence.",
        defaultFPS: 10
    )

    static let rabbit = BuiltInPetTheme(
        id: "Rabbit",
        displayName: "Rabbit",
        description: "A long-eared rabbit with light, springy movement.",
        defaultFPS: 11
    )

    static let all: [BuiltInPetTheme] = [
        dog,
        pufferfish,
        squirrel,
        hamster,
        cat,
        rabbit
    ]

    static let fallback = dog

    static func theme(named id: String) -> BuiltInPetTheme? {
        all.first { $0.id == id }
    }

    static func resolvedTheme(named id: String) -> BuiltInPetTheme {
        theme(named: id) ?? fallback
    }
}
