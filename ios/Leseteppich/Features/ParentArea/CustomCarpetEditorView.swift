import SwiftUI

struct CustomCarpetEditorView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    @State private var title: String = "Eigener Leseteppich"
    @State private var focusLettersText: String = "W"
    @State private var motifEmoji: String = "☁️"
    @State private var motifName: String = "Wolke"
    @State private var accentHex: String = "#3498DB"
    @State private var wordsInput: String = """
    wa, wi, wo, we
    Wa, Wi, Wo, We
    Wol|ke, Wal, Win|ter, Was|ser
    Wa|gen, Wie|se, Wel|le, Wun|der
    """
    @State private var validationMessage: String?

    private let motifPresets: [(String, String, String)] = [
        ("☁️", "Wolke", "#3498DB"),
        ("🦌", "Reh", "#A67C52"),
        ("🍦", "Eis", "#E84393"),
        ("🏠", "Haus", "#E67E22"),
        ("⏰", "Uhr", "#16A085"),
        ("🪶", "Feder", "#8E44AD"),
        ("🎩", "Hut", "#2C3E50"),
        ("🍋", "Zitrone", "#B7791F"),
        ("🌳", "Baum", "#27AE60"),
        ("📖", "Buch", "#2980B9")
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("Grunddaten") {
                    TextField("Titel (z. B. Leseteppich 9)", text: $title)
                    TextField("Neue Laute (z. B. W oder Ei)", text: $focusLettersText)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(motifPresets, id: \.0) { emoji, name, hex in
                                Button {
                                    motifEmoji = emoji
                                    motifName = name
                                    accentHex = hex
                                } label: {
                                    VStack(spacing: 2) {
                                        Text(emoji).font(.title2)
                                        Text(name).font(.caption2)
                                    }
                                    .padding(8)
                                    .background(motifEmoji == emoji ? Color.accentColor.opacity(0.2) : Color(.tertiarySystemFill))
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section {
                    TextEditor(text: $wordsInput)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 140)
                } header: {
                    Text("Wörter & Silben (mit Komma oder Zeilenumbruch trennen)")
                } footer: {
                    Text("Tipp: Trenne Silben mit einem senkrechten Strich „|“, z. B. Ni|na, To|ma|te, Ses|sel. Empfohlen: 16 Felder für ein 4×4-Raster.")
                }

                if let validationMessage {
                    Section {
                        Text(validationMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Neuer Leseteppich")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") { saveCarpet() }
                }
            }
        }
    }

    private func saveCarpet() {
        let rawTokens = wordsInput
            .components(separatedBy: CharacterSet(charactersIn: ",;\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard rawTokens.count >= 4 else {
            validationMessage = "Bitte gib mindestens 4 Laute, Silben oder Wörter ein."
            return
        }

        let carpetID = "custom_\(UUID().uuidString.prefix(8))"
        let tiles: [ReadingTile] = rawTokens.enumerated().map { idx, token in
            let parts = token.split(separator: "|").map(String.init).filter { !$0.isEmpty }
            let syllables = parts.isEmpty ? [token] : parts
            let display = syllables.joined()
            return ReadingTile(
                id: "\(carpetID)_\(idx + 1)",
                display: display,
                syllables: syllables,
                spokenText: display,
                ipa: nil,
                isSinglePhoneme: display.count == 1,
                acceptedTranscriptions: [display.lowercased()]
            )
        }

        let letters = focusLettersText
            .split(whereSeparator: { $0 == "," || $0 == " " })
            .map(String.init)
            .filter { !$0.isEmpty }

        let nextOrder = (store.allCarpets.map(\.order).max() ?? 0) + 1
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let newCarpet = Carpet(
            id: carpetID,
            order: nextOrder,
            title: trimmedTitle.isEmpty ? "Leseteppich \(nextOrder)" : trimmedTitle,
            subtitle: "Eigener Leseteppich",
            focusLetters: letters.isEmpty ? ["★"] : letters,
            motifEmoji: motifEmoji,
            motifName: motifName,
            accentHex: accentHex,
            targetRepetitions: 5,
            columns: 4,
            tiles: tiles,
            isCustom: true
        )

        store.addCustomCarpet(newCarpet)
        dismiss()
    }
}
