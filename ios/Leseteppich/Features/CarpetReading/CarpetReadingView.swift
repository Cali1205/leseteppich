import SwiftUI

struct CarpetReadingView: View {
    @StateObject private var viewModel: CarpetReadingViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var showRestartConfirmation = false
    @State private var showExitConfirmation = false

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

            if viewModel.showCelebration, let result = viewModel.lastRunResult {
                RunSummaryView(
                    carpet: viewModel.carpet,
                    result: result,
                    completedRuns: viewModel.completedRuns,
                    targetRepetitions: viewModel.carpet.targetRepetitions,
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
                            .frame(minWidth: 60, minHeight: 60)
                            .contentShape(Rectangle())
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
            let isListening = viewModel.recognitionStatus == .listening

            VStack(spacing: 16) {
                HStack {
                    Text("\(viewModel.carpet.motifEmoji) \(viewModel.engine.activeIndex + 1)/\(viewModel.carpet.tiles.count)")
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
                    Text("Tippe auf eine Silbe")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                ReadingFeedbackView(
                    status: viewModel.recognitionStatus,
                    audioLevel: viewModel.audioLevel,
                    accentColor: accent
                )

                if viewModel.recognitionStatus == .needsHelp {
                    NeedsHelpChoicesView(
                        allowAudioHelp: viewModel.allowAudioHelp,
                        accentColor: accent,
                        onHear: { viewModel.speakCurrentTile() },
                        onRetry: { viewModel.retryAfterHelp() },
                        onSkip: { viewModel.skipCurrentTile() }
                    )
                } else {
                    HStack(spacing: 14) {
                        if viewModel.allowAudioHelp {
                            Button {
                                viewModel.speakCurrentTile()
                            } label: {
                                Label("Anhören", systemImage: "speaker.wave.2.fill")
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                    .frame(maxWidth: .infinity, minHeight: 72)
                                    .background(Color(.tertiarySystemFill))
                                    .foregroundStyle(.primary)
                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            }
                            .buttonStyle(PressableButtonStyle())
                        }

                        if !viewModel.allowAudioHelp || viewModel.mode == .read {
                            MicToggleButton(
                                isActive: viewModel.isMicrophoneFlowActive,
                                accent: accent,
                                action: { viewModel.toggleListening() }
                            )
                        }
                    }
                }

                if (!viewModel.allowAudioHelp || viewModel.mode == .read)
                    && viewModel.showsRescueConfirm {
                    Button {
                        viewModel.confirmCurrentTileManually()
                    } label: {
                        Label("Richtig gelesen ✓", systemImage: "checkmark.circle.fill")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(.green)
                            .frame(maxWidth: .infinity, minHeight: 60)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PressableButtonStyle())
                }
            }
            .padding(20)
            .background(Color(.secondarySystemGroupedBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(isListening ? accent.opacity(0.75) : Color.clear, lineWidth: isListening ? 2.5 : 0)
            )
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
        }
    }

    private func carpetGrid(accent: Color) -> some View {
        let gridColumns = Array(repeating: GridItem(.flexible(), spacing: 10), count: viewModel.carpet.columns)

        return LazyVGrid(columns: gridColumns, spacing: 10) {
            ForEach(Array(viewModel.carpet.tiles.enumerated()), id: \.element.id) { index, tile in
                let isActive = index == viewModel.engine.activeIndex
                let rating = viewModel.ratings[tile.id]
                let isDone = rating != nil || viewModel.engine.completedTileIDs.contains(tile.id)
                let tileColor = rating?.tileTintColor ?? (isDone ? Color.green : Color.secondary)

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
                        .frame(maxWidth: .infinity, minHeight: 64)
                        .padding(.horizontal, 6)

                        if let rating {
                            TileRatingBadge(rating: rating, fontSize: 15)
                                .padding(6)
                                .id(rating)
                                .transition(
                                    reduceMotion
                                        ? .opacity
                                        : .scale(scale: 0.6).combined(with: .opacity)
                                )
                        } else if isDone {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 15))
                                .foregroundStyle(.green)
                                .padding(6)
                        }
                    }
                    .background(
                        isActive
                            ? accent.opacity(0.18)
                            : (isDone ? tileColor.opacity(0.14) : Color(.secondarySystemGroupedBackground))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(
                                isActive ? accent : (isDone ? tileColor.opacity(0.55) : Color.secondary.opacity(0.18)),
                                lineWidth: isActive ? 3.5 : 1.2
                            )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .scaleEffect(isActive && !reduceMotion ? 1.03 : 1.0)
                    .shadow(color: isActive ? accent.opacity(0.22) : .clear, radius: 5, y: 2)
                    .animation(
                        reduceMotion ? .easeOut(duration: 0.2) : .spring(duration: 0.35, bounce: 0.35),
                        value: rating
                    )
                    .animation(
                        reduceMotion ? .easeOut(duration: 0.2) : .spring(duration: 0.35, bounce: 0.35),
                        value: isActive
                    )
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityLabel(tile.display)
                .accessibilityValue(rating?.accessibilityText ?? (isActive ? "Aktuell" : (isDone ? "Geschafft" : "")))
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
