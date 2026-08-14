import SwiftUI

@main
struct MemoryMatchApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var session = GameSession(restoring: SavedGame.load())

    var body: some Scene {
        WindowGroup {
            ContentView(session: session)
                .onChange(of: scenePhase) { _, phase in
                    switch phase {
                    case .active:
                        session.moveToForeground()
                    default:
                        session.moveToBackground()
                        SavedGame.save(session)
                    }
                }
        }
    }
}

/// Where the game in progress is kept between launches.
enum SavedGame {
    private static let key = "savedGame"

    static func load() -> Data? {
        UserDefaults.standard.data(forKey: key)
    }

    static func save(_ session: GameSession) {
        guard let data = try? session.encoded() else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
