import SwiftUI

/// End-of-carpet summary showing 1–3 staggered stars, a mini tile rating grid, and child-friendly actions.
struct RunSummaryView: View {
    let carpet: Carpet
    let result: RunResult
    let completedRuns: Int
    let targetRepetitions: Int
    let onRestart: () -> Void
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealedStarCount: Int = 0

    private var clampedStars: Int {
        min(max(result.stars, 1), 3)
    }

    private var praiseTitle: String {
        switch clampedStars {
        case 3:
            return "Super gelesen!"
        case 2:
            return "Toll gemacht!"
        default:
            return "Gut geübt!"
        }
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 18) {
                    Text(carpet.motifEmoji)
                        .font(.system(size: 56))

                    HStack(spacing: 12) {
                        ForEach(0..<3, id: \.self) { index in
                            let isEarned = index < clampedStars
                            let isRevealed = index < revealedStarCount

                            Image(systemName: isEarned ? "star.fill" : "star")
                                .font(.system(size: 46))
                                .foregroundStyle(isEarned ? .yellow : Color.secondary.opacity(0.35))
                                .scaleEffect(
                                    reduceMotion
                                        ? 1.0
                                        : (isEarned ? (isRevealed ? 1.0 : 0.6) : 0.95)
                                )
                                .opacity(isEarned ? (isRevealed ? 1.0 : 0.15) : 0.65)
                                .animation(
                                    reduceMotion ? nil : .spring(duration: 0.35, bounce: 0.35),
                                    value: revealedStarCount
                                )
                        }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(clampedStars) von 3 Sternen")

                    Text(praiseTitle)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)

                    Text("Runde \(completedRuns) von \(targetRepetitions)")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Color(.tertiarySystemFill))
                        .clipShape(Capsule())

                    miniTileGrid

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
                    .padding(.top, 4)
                }
                .padding(24)
                .frame(maxWidth: 420)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .shadow(radius: 20)
                .padding(20)
            }
            .scrollIndicators(.hidden)
        }
        .task {
            if reduceMotion {
                revealedStarCount = 3
            } else {
                revealedStarCount = 0
                for step in 1...3 {
                    try? await Task.sleep(for: .milliseconds(150))
                    guard !Task.isCancelled else { return }
                    revealedStarCount = step
                }
            }
        }
    }

    private var miniTileGrid: some View {
        let gridColumns = Array(
            repeating: GridItem(.flexible(), spacing: 6),
            count: max(1, carpet.columns)
        )

        return LazyVGrid(columns: gridColumns, spacing: 6) {
            ForEach(carpet.tiles) { tile in
                let rating = result.ratings[tile.id]

                ZStack(alignment: .topTrailing) {
                    Text(tile.display)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.55)
                        .frame(maxWidth: .infinity, minHeight: 38)
                        .padding(.horizontal, 4)
                        .padding(.top, 4)

                    if let rating {
                        TileRatingBadge(rating: rating, fontSize: 11)
                            .padding(3)
                    }
                }
                .background(
                    (rating?.tileTintColor ?? Color.secondary).opacity(rating != nil ? 0.14 : 0.08)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(
                            (rating?.tileTintColor ?? Color.secondary).opacity(rating != nil ? 0.4 : 0.18),
                            lineWidth: 1
                        )
                )
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
    }
}
