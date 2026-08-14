import AVFoundation
import UIKit

/// The three sounds the game makes, each a bundled `.wav`.
enum SoundEffect: String, CaseIterable, Hashable {
    case flip, match, win
}

/// Plays the short effects. The session is ambient, so the game never
/// interrupts whatever the player is already listening to, and it goes quiet
/// with the ring switch.
final class SoundPlayer {
    static let shared = SoundPlayer()

    static let sessionCategory: AVAudioSession.Category = .ambient

    /// Where an effect's file sits in the app bundle.
    static func url(for effect: SoundEffect) -> URL? {
        Bundle.main.url(forResource: effect.rawValue, withExtension: "wav")
    }

    /// One player per effect, kept alive so a sound is never cut off by its
    /// own player going away.
    private var players: [SoundEffect: AVAudioPlayer] = [:]

    private init() {
        try? AVAudioSession.sharedInstance().setCategory(Self.sessionCategory)
    }

    func play(_ effect: SoundEffect) {
        guard let player = player(for: effect) else { return }
        player.currentTime = 0
        player.play()
    }

    private func player(for effect: SoundEffect) -> AVAudioPlayer? {
        if let existing = players[effect] { return existing }
        guard let url = Self.url(for: effect),
              let player = try? AVAudioPlayer(contentsOf: url)
        else { return nil }
        player.prepareToPlay()
        players[effect] = player
        return player
    }
}

/// The taps the game gives back: light on a flip, a success note on a match,
/// and the same note again on the win.
enum Haptics {
    static func flip() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func match() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func win() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}
