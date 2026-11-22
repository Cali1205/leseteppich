import SwiftUI
import UIKit

public extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&int)
        let r, g, b: Double
        if cleaned.count == 6 {
            r = Double((int >> 16) & 0xFF) / 255.0
            g = Double((int >> 8) & 0xFF) / 255.0
            b = Double(int & 0xFF) / 255.0
        } else {
            r = 0.15
            g = 0.49
            b = 0.88
        }
        self.init(red: r, green: g, blue: b)
    }

    /// Returns `.black` or `.white` depending on the perceptual luminance of `color`.
    static func contrastingForeground(for color: Color) -> Color {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
        let luminance = 0.299 * r + 0.587 * g + 0.114 * b
        return luminance > 0.6 ? .black : .white
    }
}

/// Draws a curved syllable arc (Silbenbogen) underneath a syllable,
/// mirroring the reading method taught in German 1st grade.
struct SyllableArcShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + 2, y: rect.minY + 1))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - 2, y: rect.minY + 1),
            control: CGPoint(x: rect.midX, y: rect.maxY + 4)
        )
        return path
    }
}

/// Renders German Silbenschrift (two-color syllables + optional Silbenbögen arcs).
struct SyllableTextView: View {
    let syllables: [String]
    let fontSize: CGFloat
    let showColors: Bool
    let showArcs: Bool
    var onTapSyllable: ((String) -> Void)? = nil

    private let primarySyllableColor = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0x5A / 255.0, green: 0xA9 / 255.0, blue: 0xFA / 255.0, alpha: 1)
            : UIColor(red: 0x1B / 255.0, green: 0x6E / 255.0, blue: 0xC2 / 255.0, alpha: 1)
    })
    private let secondarySyllableColor = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0xFF / 255.0, green: 0x7B / 255.0, blue: 0x6B / 255.0, alpha: 1)
            : UIColor(red: 0xD9 / 255.0, green: 0x4A / 255.0, blue: 0x38 / 255.0, alpha: 1)
    })

    var body: some View {
        if onTapSyllable == nil {
            syllableRow
                .accessibilityElement(children: .combine)
                .accessibilityLabel(syllables.joined())
        } else {
            syllableRow
        }
    }

    private var syllableRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: showArcs && syllables.count > 1 ? 3 : 0) {
            ForEach(Array(syllables.enumerated()), id: \.offset) { index, syllable in
                let color = syllableColor(for: index)
                VStack(spacing: 2) {
                    Text(syllable)
                        .font(.system(size: fontSize, weight: .semibold, design: .rounded))
                        .foregroundStyle(color)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)

                    if showArcs && syllables.count > 1 {
                        SyllableArcShape()
                            .stroke(color.opacity(0.85), style: StrokeStyle(lineWidth: max(2, fontSize * 0.06), lineCap: .round))
                            .frame(height: max(6, fontSize * 0.18))
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    onTapSyllable?(syllable)
                }
                .accessibilityAddTraits(onTapSyllable != nil ? .isButton : [])
            }
        }
    }

    private func syllableColor(for index: Int) -> Color {
        guard showColors && syllables.count > 1 else {
            return .primary
        }
        return index.isMultiple(of: 2) ? primarySyllableColor : secondarySyllableColor
    }
}

/// Renders either regular Silbenschrift or a Rebus sentence with inline icons (e.g. "Tim ❤️ Salat.").
struct RebusOrSyllableView: View {
    let syllables: [String]
    let rebusSegments: [RebusSegment]?
    let fontSize: CGFloat
    let showColors: Bool
    let showArcs: Bool

    var body: some View {
        if let segments = rebusSegments, !segments.isEmpty {
            HStack(spacing: 4) {
                ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                    if let text = segment.text {
                        Text(text)
                            .font(.system(size: fontSize, weight: .semibold, design: .rounded))
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                            .minimumScaleFactor(0.6)
                    }
                    if let emoji = segment.emoji {
                        Text(emoji)
                            .font(.system(size: fontSize * 1.15))
                            .accessibilityLabel(segment.spokenWord ?? emoji)
                    }
                }
            }
        } else {
            SyllableTextView(
                syllables: syllables,
                fontSize: fontSize,
                showColors: showColors,
                showArcs: showArcs
            )
        }
    }
}
