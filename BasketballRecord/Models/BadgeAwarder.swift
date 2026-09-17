import Foundation

@MainActor
struct BadgeAwarder {
    static func awardBadges(for game: SavedGame, store: AppStore) {}

    static func scanAllGames(store: AppStore) {}
}
