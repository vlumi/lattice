import Charts
import LatticeCore
import SwiftUI

/// Finished games over time — one variant at a time (the variants are
/// different games with different score scales): a score chart with the
/// running best, and the games list; rows open replays.
public struct HistoryView: View {
    private let store: LatticeStore
    @Binding private var path: NavigationPath
    @State private var records: [GameRecord] = []
    @State private var selectedVariant: String?

    public init(store: LatticeStore, path: Binding<NavigationPath>) {
        self.store = store
        _path = path
    }

    public var body: some View {
        NavigationStack(path: $path) {
            Group {
                if records.isEmpty {
                    Text("No finished games yet", bundle: .module)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    content
                }
            }
            .padding()
            .navigationDestination(for: GameRecord.self) { record in
                ReplayView(record: record)
            }
        }
        .onAppear {
            records = store.loadRecords()
            // Default to the most recent game's pool.
            if selectedVariant == nil || !presentVariants.contains(selectedVariant ?? "") {
                selectedVariant = records.first?.variantKey
            }
        }
    }

    /// Scoring pools that actually have records, in the canonical display
    /// order — each base variant followed by its seeded form ("5T", "5T#").
    private var presentVariants: [String] {
        let present = Set(records.map(\.variantKey))
        var ordered: [String] = []
        for base in Rules.selectable.map(\.storageKey) {
            if present.contains(base) { ordered.append(base) }
            if present.contains(base + "#") { ordered.append(base + "#") }
        }
        // Anything stored under a key no longer listed still shows up
        // (defensive).
        return ordered + present.subtracting(ordered).sorted()
    }

    private var filtered: [GameRecord] {
        records.filter { $0.variantKey == selectedVariant }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 16) {
            if presentVariants.count > 1 {
                Picker(selection: $selectedVariant) {
                    ForEach(presentVariants, id: \.self) { variant in
                        Text(verbatim: variant).tag(String?.some(variant))
                    }
                } label: {
                    Text("Variant", bundle: .module)
                }
                .pickerStyle(.segmented)
                .fixedSize()
            }
            chart
                .frame(height: 220)
            List(filtered) { record in
                NavigationLink(value: record) {
                    HStack {
                        Text(record.finishedAt, format: .dateTime.year().month().day())
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(verbatim: "\(record.score)")
                            .font(.headline.monospacedDigit())
                    }
                }
            }
            .listStyle(.plain)
        }
    }

    // Chronological scores as points, with the running best as a step line —
    // monochrome like the board; the accent stays reserved for interaction.
    private var chart: some View {
        let chronological = filtered.sorted { $0.finishedAt < $1.finishedAt }
        var best = 0
        let running: [(date: Date, best: Int)] = chronological.map { record in
            best = max(best, record.score)
            return (record.finishedAt, best)
        }
        return Chart {
            ForEach(chronological) { record in
                PointMark(
                    x: .value("Date", record.finishedAt),
                    y: .value("Score", record.score)
                )
                .foregroundStyle(.primary.opacity(0.55))
            }
            ForEach(Array(running.enumerated()), id: \.offset) { _, sample in
                LineMark(
                    x: .value("Date", sample.date),
                    y: .value("Best", sample.best)
                )
                .interpolationMethod(.stepEnd)
                .foregroundStyle(.primary.opacity(0.35))
            }
        }
    }
}
