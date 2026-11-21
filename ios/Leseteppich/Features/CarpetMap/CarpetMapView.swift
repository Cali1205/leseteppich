import SwiftUI

struct CarpetMapView: View {
    @EnvironmentObject private var store: AppStore
    @State private var showParentGate = false
    @State private var showParentArea = false

    private let columns = [
        GridItem(.adaptive(minimum: 155, maximum: 220), spacing: 16)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    headerBanner

                    if let board = store.diceBoards.first {
                        diceReadingBanner(board: board)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Meine Leseteppiche")
                            .font(.system(size: 24, weight: .bold, design: .rounded))

                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(store.allCarpets) { carpet in
                                NavigationLink(value: carpet) {
                                    CarpetCardView(
                                        carpet: carpet,
                                        progress: store.progress(for: carpet.id)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    if let error = store.loadError {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Leseteppich")
            .navigationDestination(for: Carpet.self) { carpet in
                CarpetReadingView(carpet: carpet, store: store)
            }
            .navigationDestination(for: DiceBoard.self) { board in
                DiceReadingView(board: board, store: store)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showParentGate = true
                    } label: {
                        Label("Eltern", systemImage: "gearshape.fill")
                            .labelStyle(.titleAndIcon)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                    }
                }
            }
            .sheet(isPresented: $showParentGate) {
                ParentalGateView {
                    showParentGate = false
                    showParentArea = true
                }
                .presentationDetents([.medium])
            }
            .sheet(isPresented: $showParentArea) {
                ParentAreaView()
                    .environmentObject(store)
            }
        }
    }

    private var headerBanner: some View {
        let totalStars = store.allCarpets.reduce(0) { partial, carpet in
            partial + min(store.progress(for: carpet.id).completedRuns, carpet.targetRepetitions)
        }
        let maxStars = store.allCarpets.reduce(0) { $0 + $1.targetRepetitions }

        return HStack(spacing: 16) {
            Text("🪄")
                .font(.system(size: 42))

            VStack(alignment: .leading, spacing: 4) {
                Text("Hallo Lesestar!")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                Text("Tippe auf einen Leseteppich und lies laut vor.")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                    Text("\(totalStars)/\(maxStars)")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                }
                Text("Sterne")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .padding(18)
        .background(
            LinearGradient(
                colors: [Color(hex: "#EAF4FF"), Color(hex: "#FFF6E9")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func diceReadingBanner(board: DiceBoard) -> some View {
        NavigationLink(value: board) {
            HStack(spacing: 16) {
                Text("🎲")
                    .font(.system(size: 40))

                VStack(alignment: .leading, spacing: 4) {
                    Text("Würfellesen – Schatzsuche")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                    Text("Würfle und klettere bis zur Schatztruhe! (\(store.persistedData.diceWinsCount)x gewonnen)")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text("🏆")
                    .font(.system(size: 34))
            }
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.orange.opacity(0.45), lineWidth: 2)
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: .black.opacity(0.04), radius: 6, y: 3)
        }
        .buttonStyle(.plain)
    }
}

private struct CarpetCardView: View {
    let carpet: Carpet
    let progress: CarpetProgress

    var body: some View {
        let accent = Color(hex: carpet.accentHex)
        let stars = min(progress.completedRuns, carpet.targetRepetitions)
        let isMastered = stars >= carpet.targetRepetitions

        VStack(spacing: 10) {
            HStack {
                Text("#\(carpet.order)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(accent.opacity(0.14))
                    .clipShape(Capsule())

                Spacer()

                Text(carpet.focusLetters.joined(separator: " "))
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(accent)
                    .clipShape(Capsule())
            }

            Text(carpet.motifEmoji)
                .font(.system(size: 48))
                .opacity(stars > 0 ? 1.0 : 0.78)
                .padding(.vertical, 2)

            VStack(spacing: 2) {
                Text(carpet.title)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(carpet.motifName)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            // "So oft habe ich gelesen: 5 boxes/stars"
            HStack(spacing: 4) {
                ForEach(0..<carpet.targetRepetitions, id: \.self) { idx in
                    Image(systemName: idx < stars ? "star.fill" : "star")
                        .font(.system(size: 14))
                        .foregroundStyle(idx < stars ? .yellow : Color.secondary.opacity(0.35))
                }
            }
            .padding(.top, 2)
        }
        .padding(14)
        .background(
            isMastered
                ? accent.opacity(0.12)
                : Color(.secondarySystemGroupedBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(isMastered ? accent : Color.clear, lineWidth: 2)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 6, y: 3)
    }
}
