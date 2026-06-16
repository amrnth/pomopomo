import SwiftUI
import PomopomoKit

struct ControlsView: View {
    let isRunning: Bool
    let onToggle: () -> Void
    let onSkip: () -> Void

    var body: some View {
        HStack(spacing: 20) {
            Button(action: onToggle) {
                Image(systemName: isRunning ? "pause.fill" : "play.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
            .focusable(false)
            .help(isRunning ? "Pause" : "Play")

            Button(action: onSkip) {
                Image(systemName: "forward.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
            .focusable(false)
            .help("Skip")
        }
    }
}
