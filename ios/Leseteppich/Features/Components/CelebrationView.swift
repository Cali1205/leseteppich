import SwiftUI

struct CelebrationView: View {
    let emoji: String
    let title: String
    let subtitle: String
    let buttonTitle: String
    let onContinue: () -> Void

    @State private var animatePop = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                Text("✨ \(emoji) ✨")
                    .font(.system(size: 64))
                    .scaleEffect(animatePop ? 1.08 : 0.82)
                    .animation(.spring(response: 0.5, dampingFraction: 0.55), value: animatePop)

                Text(title)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)

                Text(subtitle)
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                HStack(spacing: 6) {
                    ForEach(0..<5, id: \.self) { _ in
                        Image(systemName: "star.fill")
                            .font(.title2)
                            .foregroundStyle(.yellow)
                    }
                }
                .padding(.vertical, 4)

                Button(action: onContinue) {
                    Text(buttonTitle)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
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
            animatePop = true
        }
    }
}
