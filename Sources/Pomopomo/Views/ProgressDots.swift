import SwiftUI
import PomopomoKit

struct ProgressDots: View {
    let completedCount: Int
    let cycleLength: Int
    let activeIndex: Int?
    let activeProgress: Double

    private let dotSize: CGFloat = 8
    private let activePillWidth: CGFloat = 28
    private let activeGreen = Color(red: 0.35, green: 0.78, blue: 0.45)
    private let inactiveGreen = Color(red: 0.2, green: 0.45, blue: 0.28)

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<cycleLength, id: \.self) { index in
                dot(for: index)
            }
        }
        .animation(.linear(duration: 1), value: activeProgress)
    }

    @ViewBuilder
    private func dot(for index: Int) -> some View {
        if index == activeIndex {
            activePill
        } else if index < completedCount {
            Circle()
                .fill(activeGreen)
                .frame(width: dotSize, height: dotSize)
        } else {
            Circle()
                .fill(inactiveGreen.opacity(0.55))
                .frame(width: dotSize, height: dotSize)
        }
    }

    private var activePill: some View {
        ZStack(alignment: .leading) {
            Capsule()
                .fill(inactiveGreen.opacity(0.55))
            Capsule()
                .fill(activeGreen)
                .frame(width: max(dotSize, activePillWidth * activeProgress))
        }
        .frame(width: activePillWidth, height: dotSize)
        .clipShape(Capsule())
    }
}
