import SwiftUI

struct CarpetReadingView: View {
    @StateObject private var viewModel: CarpetReadingViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var showRestartConfirmation = false
    @State private var showExitConfirmation = false
    @State private var micPulse = false

    init(carpet: Carpet, store: AppStore) {
        _viewModel = StateObject(wrappedValue: CarpetReadingViewModel(carpet: carpet, store: store))
    }

    private var hasProgress: Bool {
        !viewModel.engine.completedTileIDs.isEmpty
    }

    var body: some View {
        let accent = Color(hex: viewModel.carpet.accentHex)

        ZStack {
            ScrollView {
                VStack(spacing: 18) {
                    if viewModel.allowAudioHelp {
                        modePicker
                    }
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
                    earnedStars: viewModel.completedRuns,
                    targetStars: viewModel.carpet.targetRepetitions,
                    onRestart: {
                        viewModel.restartCarpet()
                    },
                    onDismiss: {
                        viewModel.restartCarpet()
                        dismiss()
                    }
                )
            }
        }
        .navigationTitle(viewModel.carpet.title)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(hasProgress)
        .toolbar {
            if hasProgress {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showExitConfirmation = true
                    } label: {
                        Image(systemName: "house.fill")
                    }
                    .accessibilityLabel("Zurück zur Übersicht")
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    if hasProgress {
                        showRestartConfirmation = true
                    } else {
                        viewModel.restartCarpet()
                    }
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                }
                .accessibilityLabel("Leseteppich neu starten")
            }
        }
        .confirmationDialog("Neu starten?", isPresented: $showRestartConfirmation, titleVisibility: .visible) {
            Button("Neu starten", role: .destructive) {
                viewModel.restartCarpet()
            }
            Button("Abbrechen", role: .cancel) {}
        }
        .confirmationDialog("Aufhören?", isPresented: $showExitConfirmation, titleVisibility: .visible) {
            Button("Aufhören", role: .destructive) {
                viewModel.stopAudioAndSpeech()
                dismiss()
            }
            Button("Weiterlesen", role: .cancel) {}
        }
        .onAppear {
            viewModel.onAppear()
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
                }

                // Interactive large Silbenschrift display (tap individual syllables only when audio help is enabled)
                SyllableTextView(
                    syllables: tile.syllables,
                    fontSize: 64,
                    showColors: viewModel.settings.showSyllableColors,
                    showArcs: viewModel.settings.showSyllableArcs,
                    onTapSyllable: viewModel.allowAudioHelp ? { syllable in
                        viewModel.speakSyllable(syllable)
                    } : nil
                )
                .padding(.vertical, 10)

                if viewModel.allowAudioHelp && tile.syllables.count > 1 {
                    Text("Tipp: Tippe auf eine einzelne Silbe, um sie langsam zu hören.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                RecognitionStatusView(
                    status: viewModel.recognitionStatus,
                    audioLevel: viewModel.audioLevel,
                    expectedText: tile.display,
                    accentColor: accent
                )

                HStack(spacing: 14) {
                    if viewModel.allowAudioHelp {
                        Button {
                            viewModel.speakCurrentTile()
                        } label: {
                            Label("Anhören", systemImage: "speaker.wave.2.fill")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .frame(maxWidth: .infinity, minHeight: 64)
                                .background(Color(.tertiarySystemFill))
                                .foregroundStyle(.primary)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                    }

                    if !viewModel.allowAudioHelp || viewModel.mode == .read {
                        let isActive = viewModel.isMicrophoneFlowActive
                        let bgColor = isActive ? Color(hex: "#0E9F6E") : accent

                        Button {
                            viewModel.toggleListening()
                        } label: {
                            Label(
                                isActive ? "Pause" : "Vorlesen",
                                systemImage: isActive ? "stop.circle.fill" : "mic.fill"
                            )
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .frame(maxWidth: .infinity, minHeight: 64)
                            .background(bgColor)
                            .foregroundStyle(Color.contrastingForeground(for: bgColor))
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .scaleEffect(isActive && !reduceMotion && micPulse ? 1.03 : 1.0)
                        .animation(
                            isActive && !reduceMotion
                                ? .easeInOut(duration: 0.9).repeatForever(autoreverses: true)
                                : .default,
                            value: micPulse
                        )
                        .onChange(of: isActive) { _, active in
                            micPulse = active && !reduceMotion
                        }
                        .onAppear {
                            micPulse = isActive && !reduceMotion
                        }
                        .accessibilityLabel(isActive ? "Zuhören stoppen" : "Zuhören starten")
                    }
                }

                if (!viewModel.allowAudioHelp || viewModel.mode == .read)
                    && (viewModel.settings.allowManualConfirm || viewModel.engine.failedAttemptsOnCurrentTile >= 2) {
                    Button {
                        viewModel.confirmCurrentTileManually()
                    } label: {
                        Label("Richtig gelesen – Weiter ✓", systemImage: "checkmark.circle.fill")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(.green)
                            .frame(maxWidth: .infinity, minHeight: 60)
                            .contentShape(Rectangle())
                    }
                }
            }
            .padding(20)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
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
                        .frame(maxWidth: .infinity, minHeight: 60)
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
