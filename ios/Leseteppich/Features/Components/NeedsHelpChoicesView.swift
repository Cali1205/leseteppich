import SwiftUI

/// Big child-friendly choice buttons shown when the auto-loop pauses after 2 failed attempts.
struct NeedsHelpChoicesView: View {
    let allowAudioHelp: Bool
    let accentColor: Color
    let onHear: () -> Void
    let onRetry: () -> Void
    let onSkip: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            if allowAudioHelp {
                choiceButton(
                    icon: "👂",
                    title: "Hör mal",
                    foreground: .blue,
                    background: Color.blue.opacity(0.14),
                    accessibilityLabel: "Hör mal",
                    action: onHear
                )
            }

            choiceButton(
                icon: "🔁",
                title: "Nochmal",
                foreground: accentColor.contrastingForeground,
                background: accentColor,
                accessibilityLabel: "Nochmal",
                action: onRetry
            )

            choiceButton(
                icon: "➜",
                title: "Weiter",
                foreground: .primary,
                background: Color(.tertiarySystemFill),
                accessibilityLabel: "Weiter",
                action: onSkip
            )
        }
    }

    private func choiceButton(
        icon: String,
        title: String,
        foreground: Color,
        background: Color,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(icon)
                    .font(.system(size: 28))
                Text(title)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity, minHeight: 76)
            .padding(.horizontal, 6)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel(accessibilityLabel)
    }
}
