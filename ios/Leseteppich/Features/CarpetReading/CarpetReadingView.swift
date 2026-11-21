import SwiftUI

struct CarpetReadingView: View {
    @StateObject private var viewModel: CarpetReadingViewModel
    @Environment(\.dismiss) private var dismiss

    init(carpet: Carpet, store: AppStore) {
        _viewModel = StateObject(wrappedValue: CarpetReadingViewModel(carpet: carpet, store: store))
    }

    var body: some View {
        let accent = Color(hex: viewModel.carpet.accentHex)

        ZStack {
            ScrollView {
                VStack(spacing: 18) {
                    modePicker
                    focusCard(accent: accent)
                    carpetGrid(accent: accent)
                    repetitionsFooter(accent: accent)
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))

            if viewModel.showCelebration {
                CelebrationView(
                    emoji: viewModel.carpet.motifEmoji,
                    title: "Super gelesen!",
                    subtitle: "Du hast \(viewModel.carpet.title) komplett geschafft und einen neuen Stern gesammelt!",
                    buttonTitle: "Noch einmal oder weiter",
                    onContinue: {
                        viewModel.restartCarpet()
                        dismiss()
                    }
                )
            }
        }
        .navigationTitle(viewModel.carpet.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    viewModel.restartCarpet()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                }
                .accessibilityLabel("Leseteppich neu starten")
            }
        }
        .onDisappear {
            viewModel.stopAudioAndSpeech()
        }
    }

    private var modePicker: some View {
        Picker("Modus", selection: $viewModel.mode) {
            ForEach(ReadingMode.allCases) { mode in
                Text(mode.title).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .onChange(of: viewModel.mode) { _, _ in
            viewModel.stopAudioAndSpeech()
            viewModel.recognitionStatus = .idle
        }
    }

    @ViewBuilder
    private func focusCard(accent: Color) -> some View {
        if let tile = viewModel.activeTile {
            VStack(spacing: 16) {
                HStack {
                    Text("\(viewModel.carpet.motifEmoji) Feld \(viewModel.engine.activeIndex + 1) von \(viewModel.carpet.tiles.count)")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                    Spacer()
                    if tile.isSinglePhoneme {
                        Text("Einzellaut")
                            .font(.caption.bold())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(accent.opacity(0.15))
                            .foregroundStyle(accent)
                            .clipShape(Capsule())
                    }
                }

                // Interactive large Silbenschrift display (tap individual syllables to hear them!)
                SyllableTextView(
                    syllables: tile.syllables,
                    fontSize: 64,
                    showColors: viewModel.settings.showSyllableColors,
                    showArcs: viewModel.settings.showSyllableArcs,
                    onTapSyllable: { syllable in
                        viewModel.speakSyllable(syllable)
                    }
                )
                .padding(.vertical, 10)

                if tile.syllables.count > 1 {
                    Text("Tipp: Tippe auf eine einzelne Silbe, um sie langsam zu hören.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                statusBanner(accent: accent)

                HStack(spacing: 14) {
                    // Vorlesen / Anhören button
                    Button {
                        viewModel.speakCurrentTile()
                    } label: {
                        Label("Anhören", systemImage: "speaker.wave.2.fill")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color(.tertiarySystemFill))
                            .foregroundStyle(.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }

                    if viewModel.mode == .read {
                        // Mikrofon button
                        Button {
                            viewModel.toggleListening()
                        } label: {
                            let isListening = viewModel.recognitionStatus == .listening
                            Label(
                                isListening ? "Stopp" : "Vorlesen",
                                systemImage: isListening ? "stop.circle.fill" : "mic.fill"
                            )
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(isListening ? Color.red : accent)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                    }
                }

                if viewModel.mode == .read && (viewModel.settings.allowManualConfirm || viewModel.engine.failedAttemptsOnCurrentTile >= 2) {
                    Button {
                        viewModel.confirmCurrentTileManually()
                    } label: {
                        Label("Richtig gelesen – Weiter ✓", systemImage: "checkmark.circle.fill")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(.green)
                            .padding(.top, 2)
                    }
                }
            }
            .padding(20)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
        }
    }

    @ViewBuilder
    private func statusBanner(accent: Color) -> some View {
        switch viewModel.recognitionStatus {
        case .idle:
            EmptyView()
        case .listening:
            VStack(spacing: 6) {
                AudioLevelView(level: viewModel.audioLevel, isListening: true, accentColor: accent)
                Text("Ich höre zu – lies laut vor!")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(accent)
            }
        case .matched(let transcript):
            Label("Super! Erkannt: „\(transcript)“", systemImage: "checkmark.seal.fill")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.green)
                .padding(.vertical, 4)
        case .retryNeeded(let heard):
            VStack(spacing: 4) {
                Text("Fast! Probier es noch einmal oder hör es dir kurz an.")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.center)
                if let heard, !heard.isEmpty {
                    Text("(Gehört: „\(heard)“)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        case .unavailable(let message):
            Text(message)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private func carpetGrid(accent: Color) -> some View {
        let gridColumns = Array(repeating: GridItem(.flexible(), spacing: 10), count: viewModel.carpet.columns)

        return LazyVGrid(columns: gridColumns, spacing: 10) {
            ForEach(Array(viewModel.carpet.tiles.enumerated()), id: \.element.id) { index, tile in
                let isActive = index == viewModel.engine.activeIndex
                let isDone = viewModel.engine.completedTileIDs.contains(tile.id)

                Button {
                    viewModel.selectTile(at: index)
                } label: {
                    ZStack(alignment: .topTrailing) {
                        SyllableTextView(
                            syllables: tile.syllables,
                            fontSize: 22,
                            showColors: viewModel.settings.showSyllableColors,
                            showArcs: false
                        )
                        .frame(maxWidth: .infinity, minHeight: 58)
                        .padding(.horizontal, 6)

                        if isDone {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 15))
                                .foregroundStyle(.green)
                                .padding(6)
                        }
                    }
                    .background(
                        isDone
                            ? Color.green.opacity(0.14)
                            : (isActive ? accent.opacity(0.15) : Color(.secondarySystemGroupedBackground))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(
                                isActive ? accent : (isDone ? Color.green.opacity(0.5) : Color.secondary.opacity(0.18)),
                                lineWidth: isActive ? 3 : 1.2
                            )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func repetitionsFooter(accent: Color) -> some View {
        let count = viewModel.completedRuns
        let target = viewModel.carpet.targetRepetitions

        return HStack(spacing: 12) {
            Text("So oft habe ich gelesen:")
                .font(.system(size: 16, weight: .semibold, design: .rounded))

            HStack(spacing: 8) {
                ForEach(0..<target, id: \.self) { idx in
                    Image(systemName: idx < count ? "checkmark.square.fill" : "square")
                        .font(.system(size: 22))
                        .foregroundStyle(idx < count ? accent : Color.secondary.opacity(0.45))
                }
            }

            Spacer()

            Text(viewModel.carpet.motifEmoji)
                .font(.system(size: 28))
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
