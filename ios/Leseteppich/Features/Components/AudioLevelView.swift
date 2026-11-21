import SwiftUI

struct AudioLevelView: View {
    let level: Double
    let isListening: Bool
    let accentColor: Color

    private let weights: [Double] = [0.45, 0.8, 1.0, 0.8, 0.45]

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<weights.count, id: \.self) { index in
                let height = isListening
                    ? max(8, 8 + CGFloat(level * weights[index]) * 30)
                    : 8
                Capsule()
                    .fill(isListening ? accentColor : Color.secondary.opacity(0.25))
                    .frame(width: 6, height: height)
                    .animation(.easeOut(duration: 0.1), value: height)
            }
        }
        .frame(height: 38)
        .accessibilityHidden(true)
    }
}
