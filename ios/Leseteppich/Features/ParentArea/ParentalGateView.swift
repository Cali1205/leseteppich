import SwiftUI

struct ParentalGateView: View {
    let onUnlock: () -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var factorA = Int.random(in: 3...8)
    @State private var factorB = Int.random(in: 3...7)
    @State private var answerText = ""
    @State private var wrongAttempt = false
    @FocusState private var isAnswerFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 46))
                        .foregroundStyle(Color.accentColor)

                    Text("Elternbereich")
                        .font(.system(size: 24, weight: .bold, design: .rounded))

                    Text("Bitte löse kurz diese Aufgabe:")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text("\(factorA) × \(factorB) = ?")
                        .font(.system(size: 32, weight: .bold, design: .rounded))

                    TextField("Ergebnis", text: $answerText)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                        .multilineTextAlignment(.center)
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .frame(maxWidth: 160)
                        .focused($isAnswerFocused)
                        .onChange(of: answerText) { _, newValue in
                            let trimmed = newValue.trimmingCharacters(in: .whitespaces)
                            if !trimmed.isEmpty {
                                wrongAttempt = false
                            }
                            if Int(trimmed) == factorA * factorB {
                                onUnlock()
                            }
                        }

                    if wrongAttempt {
                        Text("Nicht ganz richtig – versuche es noch einmal.")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    Button {
                        checkAnswer()
                    } label: {
                        Text("Öffnen")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .frame(maxWidth: 200)
                            .padding(.vertical, 12)
                            .background(Color.accentColor)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(24)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
            }
            .task {
                try? await Task.sleep(for: .milliseconds(300))
                isAnswerFocused = true
            }
        }
        .presentationDetents([.large])
    }

    private func checkAnswer() {
        if Int(answerText.trimmingCharacters(in: .whitespaces)) == factorA * factorB {
            onUnlock()
        } else {
            wrongAttempt = true
            answerText = ""
            rerollFactors()
            isAnswerFocused = true
        }
    }

    private func rerollFactors() {
        factorA = .random(in: 3...8)
        factorB = .random(in: 3...7)
    }
}
