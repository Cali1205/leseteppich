import SwiftUI

struct MicToggleButton: View {
    let isActive: Bool
    let accent: Color
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var micPulse = false

    private static let activeColor = Color(hex: "#4338CA")

    var body: some View {
        let bgColor = isActive ? Self.activeColor : accent

        Button(action: action) {
            Label(
                isActive ? "Vorlesen stoppen" : "Vorlesen starten",
                systemImage: isActive ? "waveform" : "mic.fill"
            )
            .font(.system(size: 18, weight: .bold, design: .rounded))
            .frame(maxWidth: .infinity, minHeight: 64)
            .background(bgColor)
            .foregroundStyle(bgColor.contrastingForeground)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .scaleEffect(isActive && !reduceMotion && micPulse ? 1.03 : 1.0)
        .animation(
            isActive && !reduceMotion
                ? .easeInOut(duration: 0.9).repeatForever(autoreverses: true)
                : .default,
            value: micPulse
        )
        .onChange(of: isActive) { _, active in
            micPulse = active && !reduceMotion
        }
        .onAppear {
            micPulse = isActive && !reduceMotion
        }
    }
}
