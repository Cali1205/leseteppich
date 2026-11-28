import SwiftUI
import UIKit

struct DiceReadingView: View {
    @StateObject private var viewModel: DiceReadingViewModel
    private let store: AppStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var showRestartConfirmation = false
    @State private var showExitConfirmation = false
    @State private var showModeChangeConfirmation = false
    @State private var pendingTwoPlayerMode: Bool?
    @State private var cellShakeCounts: [String: Int] = [:]

    init(board: DiceBoard, store: AppStore) {
        self.store = store
        _viewModel = StateObject(wrappedValue: DiceReadingViewModel(board: board, store: store))
    }

    private var hasProgress: Bool {
        !viewModel.engine.claimedCells.isEmpty
    }

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 16) {
                    topControls
                    activeReadingPanel
                    treasureBoardGrid
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))

            if viewModel.showWinnerCelebration, let winner = viewModel.engine.winner {
                CelebrationView(
                    emoji: viewModel.board.goalEmoji,
                    title: viewModel.engine.twoPlayerMode
                        ? "\(winner.displayName) hat den Schatz erreicht!"
                        : "Schatz gefunden!",
                    subtitle: viewModel.engine.twoPlayerMode
                        ? "Toll gemacht!"
                        : "Toll! Du hast den Schatz geholt!",
                    earnedStars: 1,
                    targetStars: 1,
                    onRestart: {
                        viewModel.restartGame()
                    },
                    onDismiss: {
                        viewModel.restartGame()
                        dismiss()
                    }
                )
            }
        }
        .navigationTitle("Würfellesen")
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
                        viewModel.restartGame()
                    }
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                }
                .accessibilityLabel("Würfellesen neu starten")
            }
        }
        .confirmationDialog("Neu starten?", isPresented: $showRestartConfirmation, titleVisibility: .visible) {
            Button("Neu starten", role: .destructive) {
                viewModel.restartGame()
            }
            Button("Abbrechen", role: .cancel) {}
        }
        .confirmationDialog("Neu starten?", isPresented: $showModeChangeConfirmation, titleVisibility: .visible) {
            Button("Neu starten", role: .destructive) {
                if let pending = pendingTwoPlayerMode {
                    viewModel.setTwoPlayerMode(pending)
                    pendingTwoPlayerMode = nil
                }
            }
            Button("Abbrechen", role: .cancel) {
                pendingTwoPlayerMode = nil
            }
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

    private var topControls: some View {
        HStack(spacing: 12) {
            Picker(
                "Spieler",
                selection: Binding(
                    get: { viewModel.engine.twoPlayerMode },
                    set: { newValue in
                        guard newValue != viewModel.engine.twoPlayerMode else { return }
                        if hasProgress {
                            pendingTwoPlayerMode = newValue
                            showModeChangeConfirmation = true
                        } else {
                            viewModel.setTwoPlayerMode(newValue)
                        }
                    }
                )
            ) {
                Text("1 Spieler").tag(false)
                Text("2 Spieler").tag(true)
            }
            .pickerStyle(.segmented)

            if viewModel.engine.twoPlayerMode {
                Text("Dran: \(viewModel.engine.currentPlayer.displayName)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(playerColor(viewModel.engine.currentPlayer).opacity(0.18))
                    .foregroundStyle(playerColor(viewModel.engine.currentPlayer))
                    .clipShape(Capsule())
            }
        }
    }

    private var activeReadingPanel: some View {
        let isListening = viewModel.activeCell != nil && viewModel.recognitionStatus == .listening
        let clampedLevel = isListening ? min(max(viewModel.audioLevel, 0), 1) : 0

        return VStack(spacing: 14) {
            if let cell = viewModel.activeCell, let coord = viewModel.engine.activeCoordinate {
                HStack {
                    Label("Spalte \(coord.diceValue)", systemImage: "die.face.\(coord.diceValue).fill")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.orange)
                    Spacer()
                    Text("Stufe \(coord.rowIndex + 1)/\(viewModel.board.rowCount)")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                }

                RebusOrSyllableView(
                    syllables: cell.syllables,
                    rebusSegments: cell.rebusSegments,
                    fontSize: 38,
                    showColors: viewModel.settings.showSyllableColors,
                    showArcs: viewModel.settings.showSyllableArcs
                )
                .padding(.vertical, 8)

                ReadingFeedbackView(
                    status: viewModel.recognitionStatus,
                    audioLevel: viewModel.audioLevel,
                    accentColor: .orange
                )

                if viewModel.recognitionStatus == .needsHelp {
                    NeedsHelpChoicesView(
                        allowAudioHelp: viewModel.allowAudioHelp,
                        accentColor: .orange,
                        onHear: { viewModel.speakActiveCell() },
                        onRetry: { viewModel.retryAfterHelp() },
                        onSkip: { viewModel.skipActiveCell() }
                    )
                } else {
                    HStack(spacing: 12) {
                        if viewModel.allowAudioHelp {
                            Button {
                                viewModel.speakActiveCell()
                            } label: {
                                Label("Anhören", systemImage: "speaker.wave.2.fill")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .frame(maxWidth: .infinity, minHeight: 64)
                                    .background(Color(.tertiarySystemFill))
                                    .foregroundStyle(.primary)
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            }
                            .buttonStyle(PressableButtonStyle())
                        }

                        let isMicActive = viewModel.recognitionStatus == .ready
                            || viewModel.recognitionStatus == .listening
                            || viewModel.recognitionStatus == .evaluating
                            || viewModel.recognitionStatus == .preparingNext

                        MicToggleButton(
                            isActive: isMicActive,
                            accent: .orange,
                            action: { viewModel.toggleListening() }
                        )
                    }
                }

                if viewModel.showsRescueConfirm {
                    Button {
                        viewModel.confirmActiveCell()
                    } label: {
                        Label("Richtig gelesen ✓", systemImage: "checkmark.circle.fill")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(.green)
                            .frame(maxWidth: .infinity, minHeight: 60)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PressableButtonStyle())
                }
            } else {
                HStack(spacing: 14) {
                    Image(systemName: "die.face.\(viewModel.displayedDiceFace).fill")
                        .font(.system(size: 52))
                        .foregroundStyle(.orange)
                        .rotationEffect(.degrees(viewModel.isRolling && !reduceMotion ? 360 : 0))
                        .animation(
                            viewModel.isRolling && !reduceMotion
                                ? .linear(duration: 0.25).repeatForever(autoreverses: false)
                                : .default,
                            value: viewModel.isRolling
                        )

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Wer erreicht zuerst den Schatz?")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                        Text("Würfle und lies das unterste freie Kästchen der Spalte vor.")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 4)

                    Button {
                        viewModel.stopAudioAndSpeech()
                        store.synthesizer.speakText(
                            "Wer erreicht zuerst den Schatz? Würfle und lies das unterste freie Kästchen der Spalte vor.",
                            rate: viewModel.settings.speechRate,
                            voiceIdentifier: viewModel.settings.selectedVoiceIdentifier
                        )
                    } label: {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.orange)
                            .frame(minWidth: 60, minHeight: 60)
                            .background(Color.orange.opacity(0.14))
                            .clipShape(Circle())
                    }
                    .buttonStyle(PressableButtonStyle())
                    .accessibilityLabel("Regeln anhören")
                }

                Button {
                    viewModel.rollDice()
                } label: {
                    Label(viewModel.isRolling ? "Würfelt…" : "Würfeln!", systemImage: "dice.fill")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .frame(maxWidth: .infinity, minHeight: 64)
                        .background(Color.orange)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(PressableButtonStyle())
                .disabled(viewModel.isRolling)
            }
        }
        .padding(18)
        .background(Color(.secondarySystemGroupedBackground))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(
                    isListening
                        ? Color.orange.opacity(reduceMotion ? 0.85 : (0.45 + clampedLevel * 0.55))
                        : Color.clear,
                    lineWidth: isListening ? (reduceMotion ? 3 : (2.5 + clampedLevel * 3.5)) : 0
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(
            color: isListening && !reduceMotion
                ? Color.orange.opacity(0.18 + clampedLevel * 0.32)
                : .black.opacity(0.05),
            radius: isListening && !reduceMotion ? (8 + clampedLevel * 12) : 6,
            y: isListening ? 2 : 3
        )
        .animation(reduceMotion ? .none : .easeOut(duration: 0.1), value: clampedLevel)
    }

    private var treasureBoardGrid: some View {
        let rowsDescending = Array((0..<viewModel.board.rowCount).reversed())

        return VStack(spacing: 8) {
            VStack(spacing: 2) {
                Text(viewModel.board.goalEmoji)
                    .font(.system(size: 40))
                Text(viewModel.board.goalTitle)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.orange)
            }
            .padding(.bottom, 4)

            ForEach(rowsDescending, id: \.self) { rowIndex in
                HStack(spacing: 6) {
                    ForEach(viewModel.board.columns) { column in
                        if column.cells.indices.contains(rowIndex) {
                            let cell = column.cells[rowIndex]
                            let isActive = viewModel.engine.activeCoordinate == DiceCellCoordinate(
                                diceValue: column.diceValue,
                                rowIndex: rowIndex
                            )
                            let owner = viewModel.engine.claimedCells[cell.id]

                            let isNextFree = viewModel.engine.nextFreeRowIndex(in: column.diceValue) == rowIndex

                            Button {
                                if isNextFree {
                                    viewModel.selectColumn(column.diceValue)
                                } else {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    if !reduceMotion {
                                        withAnimation(.easeOut(duration: 0.28)) {
                                            cellShakeCounts[cell.id, default: 0] += 1
                                        }
                                    }
                                }
                            } label: {
                                cellTile(cell: cell, isActive: isActive, owner: owner)
                            }
                            .buttonStyle(PressableButtonStyle())
                            .modifier(LockedCellShakeEffect(animatableData: CGFloat(cellShakeCounts[cell.id, default: 0])))
                            .accessibilityLabel("\(cell.display), Würfel \(column.diceValue)")
                            .accessibilityValue(owner != nil ? "Geschafft" : (isActive ? "Aktuell" : ""))
                            .accessibilityHint(isNextFree ? "" : "Noch gesperrt")
                        }
                    }
                }
            }

            HStack(spacing: 6) {
                ForEach(viewModel.board.columns) { column in
                    let isSelectedColumn = viewModel.engine.activeCoordinate?.diceValue == column.diceValue
                    Button {
                        viewModel.selectColumn(column.diceValue)
                    } label: {
                        Image(systemName: "die.face.\(column.diceValue).fill")
                            .font(.system(size: 26))
                            .frame(maxWidth: .infinity, minHeight: 60)
                            .foregroundStyle(isSelectedColumn ? .orange : .primary)
                            .background(isSelectedColumn ? Color.orange.opacity(0.18) : Color(.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(PressableButtonStyle())
                    .accessibilityLabel("Würfel \(column.diceValue)")
                }
            }
            .padding(.top, 4)
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground).opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func cellTile(cell: DiceCell, isActive: Bool, owner: DicePlayer?) -> some View {
        ZStack {
            Text(cell.display)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.65)
                .padding(4)
                .opacity(owner != nil ? 0.35 : 1.0)

            if let owner {
                Image(systemName: owner == .one ? "checkmark.circle.fill" : "star.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(playerColor(owner))
            }
        }
        .frame(maxWidth: .infinity, minHeight: 60)
        .background(
            owner != nil
                ? playerColor(owner!).opacity(0.16)
                : (isActive ? Color.orange.opacity(0.22) : Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(
                    isActive ? Color.orange : Color.secondary.opacity(0.22),
                    lineWidth: isActive ? 2.5 : 1
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func playerColor(_ player: DicePlayer) -> Color {
        player == .one ? .green : .purple
    }
}

private struct LockedCellShakeEffect: GeometryEffect {
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
