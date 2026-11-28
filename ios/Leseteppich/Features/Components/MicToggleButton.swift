import SwiftUI

struct MicToggleButton: View {
    let isActive: Bool
    let accent: Color
    let action: () -> Void

    private static let activeColor = Color(hex: "#4338CA")

    var body: some View {
        let bgColor = isActive ? Self.activeColor : accent

        Button(action: action) {
            Group {
                if isActive {
                    Text("⏸ Pause")
                } else {
                    Label("▶︎ Start", systemImage: "mic.fill")
                }
            }
            .font(.system(size: 18, weight: .bold, design: .rounded))
            .frame(maxWidth: .infinity, minHeight: 64)
            .background(bgColor)
            .foregroundStyle(bgColor.contrastingForeground)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel(isActive ? "Pause" : "Vorlesen starten")
    }
}
