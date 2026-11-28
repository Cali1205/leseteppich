import SwiftUI

struct CelebrationView: View {
    let emoji: String
    let title: String
    let subtitle: String
    let earnedStars: Int
    let targetStars: Int
    let onRestart: () -> Void
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animatePop = false

    var body: some View {
        let safeTarget = max(1, targetStars)
        let clampedEarned = min(max(0, earnedStars), safeTarget)

        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                Text("✨ \(emoji) ✨")
                    .font(.system(size: 64))
                    .scaleEffect(reduceMotion ? 1.0 : (animatePop ? 1.08 : 0.82))
                    .animation(
                        reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.55),
                        value: animatePop
                    )

                Text(title)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)

                Text(subtitle)
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                HStack(spacing: 6) {
                    ForEach(0..<safeTarget, id: \.self) { index in
                        let isEarned = index < clampedEarned
                        Image(systemName: isEarned ? "star.fill" : "star")
                            .font(.title2)
                            .foregroundStyle(isEarned ? .yellow : Color.secondary.opacity(0.4))
                    }
                }
                .padding(.vertical, 4)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(clampedEarned) von \(safeTarget) Sternen")

                VStack(spacing: 12) {
                    Button(action: onRestart) {
                        Text("🔁 Nochmal")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .frame(maxWidth: .infinity, minHeight: 60)
                            .background(Color.accentColor)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(PressableButtonStyle())

                    Button(action: onDismiss) {
                        Text("🏠 Zur Karte")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .frame(maxWidth: .infinity, minHeight: 60)
                            .background(Color(.tertiarySystemFill))
                            .foregroundStyle(.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(PressableButtonStyle())
                }
                .padding(.top, 6)
            }
            .padding(28)
            .frame(maxWidth: 380)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .shadow(radius: 20)
            .padding(24)
        }
        .onAppear {
            if !reduceMotion {
                animatePop = true
            }
        }
    }
}
