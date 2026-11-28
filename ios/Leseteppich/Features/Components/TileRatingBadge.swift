import SwiftUI

/// Rating badge displayed on carpet grid tiles and the end-of-run summary mini grid.
struct TileRatingBadge: View {
    let rating: TileRating
    var fontSize: CGFloat = 15

    var body: some View {
        Group {
            switch rating {
            case .firstTry:
                Text("⭐")
                    .font(.system(size: fontSize))
                    .accessibilityLabel("Beim ersten Mal")
            case .afterRetry:
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: fontSize, weight: .bold))
                    .foregroundStyle(.green)
                    .accessibilityLabel("Nach Üben geschafft")
            case .practiced:
                Text("💪")
                    .font(.system(size: fontSize))
                    .accessibilityLabel("Geübt")
            }
        }
    }
}

extension TileRating {
    var tileTintColor: Color {
        switch self {
        case .firstTry:
            return Color(hex: "#EAB308")
        case .afterRetry:
            return .green
        case .practiced:
            return .orange
        }
    }

    var accessibilityText: String {
        switch self {
        case .firstTry: return "Beim ersten Mal"
        case .afterRetry: return "Mit Nochmal geschafft"
        case .practiced: return "Geübt"
        }
    }
}
