import AppKit
import SwiftUI
import PomodoroKit

struct TimerView: View {
    @Bindable var engine: PomodoroEngine
    @State private var isHovering = false

    var onClose: () -> Void
    var onMore: (NSView) -> Void
    var onTogglePlayPause: () -> Void
    var onSkip: () -> Void

    var body: some View {
        ZStack {
            GlassBackground()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                VStack(spacing: 12) {
                    Text(engine.displayTitle)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.85))

                    Text(TimeFormatters.mmss(from: engine.remainingSeconds))
                        .font(.system(size: 42, weight: .light, design: .default))
                        .foregroundStyle(.white)
                        .monospacedDigit()

                    ProgressDots(
                        completedCount: engine.displayCompletedPomodorosInCycle,
                        cycleLength: Settings.cycleLength,
                        activeIndex: engine.activePomodoroIndexInCycle,
                        activeProgress: engine.currentPomoPomoProgressFraction
                    )
                    .padding(.vertical, 4)
                }
                .allowsHitTesting(false)

                Spacer(minLength: 10)
                    .allowsHitTesting(false)

                ControlsView(
                    isRunning: engine.state == .running,
                    onToggle: onTogglePlayPause,
                    onSkip: onSkip
                )
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 20)

            VStack {
                HStack {
                    HoverButton(symbol: "xmark", isVisible: isHovering, action: onClose)
                    Spacer()
                    MoreMenuButton(isVisible: isHovering, onMore: onMore)
                }
                Spacer()
            }
            .padding(10)
        }
        .frame(width: 280)
        .clipShape(RoundedRectangle(cornerRadius: GlassMetrics.cornerRadius, style: .continuous))
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

private struct HoverButton: View {
    let symbol: String
    let isVisible: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white.opacity(0.9))
                .frame(width: 22, height: 22)
                .background(Color.white.opacity(0.12))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .opacity(isVisible ? 1 : 0)
        .allowsHitTesting(isVisible)
    }
}

private struct MoreMenuButton: View {
    let isVisible: Bool
    let onMore: (NSView) -> Void

    var body: some View {
        MoreMenuAnchor(isVisible: isVisible, onMore: onMore)
            .frame(width: 22, height: 22)
    }
}

private struct MoreMenuAnchor: NSViewRepresentable {
    let isVisible: Bool
    let onMore: (NSView) -> Void

    func makeNSView(context: Context) -> NSButton {
        let button = NSButton(frame: .zero)
        button.bezelStyle = .inline
        button.isBordered = false
        button.image = NSImage(systemSymbolName: "ellipsis", accessibilityDescription: "More")
        button.imagePosition = .imageOnly
        button.contentTintColor = .white
        button.target = context.coordinator
        button.action = #selector(Coordinator.showMenu(_:))
        return button
    }

    func updateNSView(_ nsView: NSButton, context: Context) {
        nsView.alphaValue = isVisible ? 1 : 0
        nsView.isEnabled = isVisible
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onMore: onMore)
    }

    final class Coordinator: NSObject {
        let onMore: (NSView) -> Void

        init(onMore: @escaping (NSView) -> Void) {
            self.onMore = onMore
        }

        @objc func showMenu(_ sender: NSButton) {
            onMore(sender)
        }
    }
}
