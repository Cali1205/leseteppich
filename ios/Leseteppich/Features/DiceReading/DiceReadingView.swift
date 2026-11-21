import SwiftUI

struct DiceReadingView: View {
    @StateObject private var viewModel: DiceReadingViewModel

    init(board: DiceBoard, store: AppStore) {
        _viewModel = StateObject(wrappedValue: DiceReadingViewModel(board: board, store: store))
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
                    subtitle: "Spalte \(viewModel.engine.winningColumnDiceValue ?? 1) wurde bis ganz nach oben gelesen!",
                    buttonTitle: "Neue Schatzsuche",
                    onContinue: {
                        viewModel.restartGame()
                    }
                )
            }
        }
        .navigationTitle("Würfellesen")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    viewModel.restartGame()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                }
            }
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
                    set: { viewModel.setTwoPlayerMode($0) }
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
        VStack(spacing: 14) {
            if let cell = viewModel.activeCell, let coord = viewModel.engine.activeCoordinate {
                HStack {
                    Label("Spalte \(coord.diceValue)", systemImage: "die.face.\(coord.diceValue).fill")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.orange)
                    Spacer()
                    Text("Stufe \(coord.rowIndex + 1) von \(viewModel.board.rowCount)")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                }

                RebusOrSyllableView(
                    display: cell.display,
                    syllables: cell.syllables,
                    rebusSegments: cell.rebusSegments,
                    fontSize: 38,
                    showColors: viewModel.settings.showSyllableColors,
                    showArcs: viewModel.settings.showSyllableArcs
                )
                .padding(.vertical, 8)

                statusFeedback

                HStack(spacing: 12) {
                    Button {
                        viewModel.speakActiveCell()
                    } label: {
                        Label("Anhören", systemImage: "speaker.wave.2.fill")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color(.tertiarySystemFill))
                            .foregroundStyle(.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }

                    Button {
                        viewModel.toggleListening()
                    } label: {
                        let isListening = viewModel.recognitionStatus == .listening
                        Label(
                            isListening ? "Stopp" : "Vorlesen",
                            systemImage: isListening ? "stop.circle.fill" : "mic.fill"
                        )
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(isListening ? Color.red : Color.orange)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }

                if viewModel.settings.allowManualConfirm {
                    Button {
                        viewModel.confirmActiveCell()
                    } label: {
                        Label("Gelesen & ankreuzen ✓", systemImage: "checkmark.circle.fill")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(.green)
                    }
                }
            } else {
                HStack(spacing: 18) {
                    Image(systemName: "die.face.\(viewModel.displayedDiceFace).fill")
                        .font(.system(size: 52))
                        .foregroundStyle(.orange)
                        .rotationEffect(.degrees(viewModel.isRolling ? 360 : 0))
                        .animation(viewModel.isRolling ? .linear(duration: 0.25).repeatForever(autoreverses: false) : .default, value: viewModel.isRolling)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Wer erreicht zuerst den Schatz?")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                        Text("Würfle und lies das unterste freie Kästchen der Spalte vor.")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }

                Button {
                    viewModel.rollDice()
                } label: {
                    Label(viewModel.isRolling ? "Würfelt..." : "Würfeln!", systemImage: "dice.fill")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.orange)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .disabled(viewModel.isRolling)
            }
        }
        .padding(18)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 6, y: 3)
    }

    @ViewBuilder
    private var statusFeedback: some View {
        switch viewModel.recognitionStatus {
        case .idle:
            EmptyView()
        case .listening:
            AudioLevelView(level: viewModel.audioLevel, isListening: true, accentColor: .orange)
        case .matched(let transcript):
            Label("Super! „\(transcript)“", systemImage: "checkmark.seal.fill")
                .font(.subheadline.bold())
                .foregroundStyle(.green)
        case .retryNeeded(let heard):
            Text("Probier es noch einmal! \(heard.map { "(Gehört: \($0))" } ?? "")")
                .font(.caption.bold())
                .foregroundStyle(.orange)
        case .unavailable(let message):
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var treasureBoardGrid: some View {
        let rowsDescending = Array((0..<viewModel.board.rowCount).reversed())

        return VStack(spacing: 8) {
            // Treasure chest header
            VStack(spacing: 2) {
                Text(viewModel.board.goalEmoji)
                    .font(.system(size: 40))
                Text(viewModel.board.goalTitle)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.orange)
            }
            .padding(.bottom, 4)

            // 6 columns, top row (hardest) down to bottom row (easiest)
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

                            cellTile(cell: cell, isActive: isActive, owner: owner)
                                .onTapGesture {
                                    if viewModel.engine.nextFreeRowIndex(in: column.diceValue) == rowIndex {
                                        viewModel.selectColumn(column.diceValue)
                                    }
                                }
                        }
                    }
                }
            }

            // Dice row at bottom (1..6)
            HStack(spacing: 6) {
                ForEach(viewModel.board.columns) { column in
                    let isSelectedColumn = viewModel.engine.activeCoordinate?.diceValue == column.diceValue
                    Button {
                        viewModel.selectColumn(column.diceValue)
                    } label: {
                        Image(systemName: "die.face.\(column.diceValue).fill")
                            .font(.system(size: 26))
                            .frame(maxWidth: .infinity, minHeight: 38)
                            .foregroundStyle(isSelectedColumn ? .orange : .primary)
                            .background(isSelectedColumn ? Color.orange.opacity(0.18) : Color(.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
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
                .font(.system(size: 11, weight: .semibold, design: .rounded))
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
        .frame(maxWidth: .infinity, minHeight: 46)
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
