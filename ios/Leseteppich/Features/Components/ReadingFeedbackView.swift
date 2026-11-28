import SwiftUI
import UIKit

/// Fixed-height, icon-first status panel that shows the child what is happening at every moment.
struct ReadingFeedbackView: View {
    let status: SpeechRecognitionStatus
    let audioLevel: Double
    let accentColor: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var retryShakeCount: Int = 0
    @State private var matchedPop: Bool = false
    @State private var readyPop: Bool = false

    private var clampedLevel: Double {
        min(max(audioLevel, 0), 1)
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(backgroundColor)

            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(borderColor, lineWidth: 2)

            stateContent
                .id(statusKey)
                .transition(stateTransition)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 148)
        .modifier(RetryShakeEffect(animatableData: CGFloat(retryShakeCount)))
        .animation(
            reduceMotion
                ? .easeOut(duration: 0.2)
                : .spring(duration: 0.26, bounce: 0.22),
            value: statusKey
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText(for: status))
        .onChange(of: status) { _, newStatus in
            handleStatusChange(newStatus)
        }
    }

    private var stateTransition: AnyTransition {
        if reduceMotion {
            return .opacity
        }
        return .scale(scale: 0.9).combined(with: .opacity)
    }

    @ViewBuilder
    private var stateContent: some View {
        switch status {
        case .idle:
            VStack(spacing: 6) {
                Text("🎤")
                    .font(.system(size: 56))
                Text("Los geht’s")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
            }

        case .ready:
            VStack(spacing: 6) {
                Text("👉")
                    .font(.system(size: 56))
                    .scaleEffect(reduceMotion ? 1.0 : (readyPop ? 1.0 : 0.9))
                Text("Lies vor!")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.blue)
            }

        case .listening:
            VStack(spacing: 8) {
                ZStack {
                    if !reduceMotion {
                        Circle()
                            .stroke(accentColor.opacity(0.25 + clampedLevel * 0.55), lineWidth: 3)
                            .frame(width: 70, height: 70)
                            .scaleEffect(1.0 + clampedLevel * 0.35)
                            .animation(.easeOut(duration: 0.08), value: clampedLevel)

                        Circle()
                            .fill(accentColor.opacity(0.08 + clampedLevel * 0.16))
                            .frame(width: 68, height: 68)
                            .scaleEffect(1.0 + clampedLevel * 0.18)
                            .animation(.easeOut(duration: 0.08), value: clampedLevel)
                    } else {
                        Circle()
                            .stroke(accentColor.opacity(0.6), lineWidth: 3)
                            .frame(width: 70, height: 70)
                    }

                    Text("👂")
                        .font(.system(size: 56))
                }

                HStack(spacing: 10) {
                    Text("Ich höre…")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(accentColor)

                    AudioLevelView(
                        level: clampedLevel,
                        isListening: true,
                        accentColor: accentColor
                    )
                    .scaleEffect(0.75)
                    .frame(height: 24)
                }
            }

        case .evaluating:
            VStack(spacing: 8) {
                Text("🤔")
                    .font(.system(size: 56))
                HStack(spacing: 8) {
                    Text("Moment…")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.indigo)
                    EvaluatingDotsView(color: .indigo, reduceMotion: reduceMotion)
                }
            }

        case .matched:
            VStack(spacing: 6) {
                Text("⭐")
                    .font(.system(size: 60))
                    .scaleEffect(reduceMotion ? 1.0 : (matchedPop ? 1.12 : 0.85))
                Text("Super!")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.green)
            }

        case .retryNeeded(let reason):
            let spec = retryVisualSpec(for: reason)
            VStack(spacing: 6) {
                Text(spec.emoji)
                    .font(.system(size: 56))
                Text(spec.label)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.orange)
            }

        case .needsHelp:
            VStack(spacing: 6) {
                Text("💪")
                    .font(.system(size: 56))
                Text("Probier’s so:")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.orange)
            }

        case .preparingNext:
            VStack(spacing: 6) {
                Image(systemName: "arrow.right.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.blue)
                Text("Weiter…")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.blue)
            }

        case .unavailable(let message):
            VStack(spacing: 6) {
                Image(systemName: "mic.slash.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.orange)
                Text(message.isEmpty ? "Kein Mikrofon" : message)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
            }
        }
    }

    private func retryVisualSpec(for reason: RetryReason) -> (emoji: String, label: String) {
        switch reason {
        case .heardNothing:
            return ("🔊", "Lauter!")
        case .close:
            return ("🟠", "Fast! Nochmal")
        case .wrong:
            return ("🔁", "Nochmal")
        }
    }

    private var backgroundColor: Color {
        switch status {
        case .idle:
            return Color(.tertiarySystemFill).opacity(0.6)
        case .ready, .preparingNext:
            return Color.blue.opacity(0.11)
        case .listening:
            return accentColor.opacity(0.12)
        case .evaluating:
            return Color.indigo.opacity(0.11)
        case .matched:
            return Color.green.opacity(0.14)
        case .retryNeeded, .needsHelp:
            return Color.orange.opacity(0.13)
        case .unavailable:
            return Color(.tertiarySystemFill).opacity(0.75)
        }
    }

    private var borderColor: Color {
        switch status {
        case .idle, .unavailable:
            return Color.secondary.opacity(0.18)
        case .ready, .preparingNext:
            return Color.blue.opacity(0.35)
        case .listening:
            return accentColor.opacity(0.45)
        case .evaluating:
            return Color.indigo.opacity(0.35)
        case .matched:
            return Color.green.opacity(0.45)
        case .retryNeeded, .needsHelp:
            return Color.orange.opacity(0.45)
        }
    }

    private var statusKey: String {
        switch status {
        case .idle: return "idle"
        case .ready: return "ready"
        case .listening: return "listening"
        case .evaluating: return "evaluating"
        case .matched: return "matched"
        case .retryNeeded(let reason): return "retry_\(reason)"
        case .needsHelp: return "needsHelp"
        case .preparingNext: return "preparingNext"
        case .unavailable(let message): return "unavailable_\(message)"
        }
    }

    private func handleStatusChange(_ newStatus: SpeechRecognitionStatus) {
        readyPop = false
        matchedPop = false

        if !reduceMotion {
            switch newStatus {
            case .ready:
                withAnimation(.spring(duration: 0.28, bounce: 0.3)) {
                    readyPop = true
                }
            case .matched:
                withAnimation(.spring(duration: 0.35, bounce: 0.3)) {
                    matchedPop = true
                }
            case .retryNeeded:
                withAnimation(.easeOut(duration: 0.28)) {
                    retryShakeCount += 1
                }
            default:
                break
            }
        }

        let announcement = accessibilityText(for: newStatus)
        if !announcement.isEmpty {
            UIAccessibility.post(notification: .announcement, argument: announcement)
        }
    }

    private func accessibilityText(for status: SpeechRecognitionStatus) -> String {
        switch status {
        case .idle:
            return "Los geht’s"
        case .ready:
            return "Lies vor!"
        case .listening:
            return "Ich höre zu"
        case .evaluating:
            return "Moment, ich prüfe"
        case .matched:
            return "Super!"
        case .retryNeeded(let reason):
            switch reason {
            case .heardNothing: return "Lauter! Bitte nochmal vorlesen"
            case .close: return "Fast! Nochmal vorlesen"
            case .wrong: return "Nochmal vorlesen"
            }
        case .needsHelp:
            return "Probier’s so"
        case .preparingNext:
            return "Weiter"
        case .unavailable(let message):
            return message.isEmpty ? "Kein Mikrofon verfügbar" : message
        }
    }
}

private struct EvaluatingDotsView: View {
    let color: Color
    let reduceMotion: Bool

    @State private var pulse = false

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                    .opacity(reduceMotion ? 0.75 : (pulse ? 1.0 : 0.25))
                    .scaleEffect(reduceMotion ? 1.0 : (pulse ? 1.15 : 0.85))
                    .animation(
                        reduceMotion
                            ? nil
                            : .easeInOut(duration: 0.45)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.15),
                        value: pulse
                    )
            }
        }
        .onAppear {
            if !reduceMotion {
                pulse = true
            }
        }
    }
}

private struct RetryShakeEffect: GeometryEffect {
    var amount: CGFloat = 6
    var shakesPerUnit: CGFloat = 4
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(
            CGAffineTransform(
                translationX: amount * sin(animatableData * .pi * shakesPerUnit),
                y: 0
            )
        )
    }
}
