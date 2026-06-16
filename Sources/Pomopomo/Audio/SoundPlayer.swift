import AppKit

@MainActor
final class SoundPlayer {
    static let shared = SoundPlayer()

    private enum SystemSound {
        static let pomoPomoStart = "Glass"
        static let pomoPomoEnd = "Ping"
        static let breakStart = "Submarine"
        static let breakEnd = "Hero"
    }

    func playPomoPomoStarted() {
        play(named: SystemSound.pomoPomoStart)
    }

    func playPomoPomoEnded() {
        play(named: SystemSound.pomoPomoEnd)
    }

    func playBreakStarted() {
        play(named: SystemSound.breakStart)
    }

    func playBreakEnded() {
        play(named: SystemSound.breakEnd)
    }

    private func play(named name: String) {
        guard let sound = NSSound(named: NSSound.Name(name)) else { return }
        sound.play()
    }
}
