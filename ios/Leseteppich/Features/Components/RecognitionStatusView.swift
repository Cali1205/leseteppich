import SwiftUI

struct RecognitionStatusView: View {
    let status: SpeechRecognitionStatus
    let audioLevel: Double
    let expectedText: String
    let accentColor: Color

    var body: some View {
        switch status {
        case .idle:
            EmptyView()
        case .listening:
            VStack(spacing: 6) {
                AudioLevelView(level: audioLevel, isListening: true, accentColor: accentColor)
                Label("Ich höre zu!", systemImage: "mic.fill")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(accentColor)
            }
        case .preparingNext:
            HStack(spacing: 8) {
                ProgressView()
                    .tint(accentColor)
                Text("Gleich geht’s weiter…")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(accentColor)
            }
            .padding(.vertical, 6)
        case .matched:
            Label("Super! \(expectedText)", systemImage: "checkmark.seal.fill")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.green)
                .padding(.vertical, 4)
        case .retryNeeded:
            Label("Nochmal!", systemImage: "arrow.clockwise.circle.fill")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.orange)
                .padding(.vertical, 4)
        case .unavailable(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}
