import Charts
import LatticeCore
import SwiftUI

/// Finished games over time: a score chart with the running best, and the
/// recent-games list. Read-only over the stored records; rows become replay
/// entry points when the viewer lands.
public struct HistoryView: View {
    private let store: LatticeStore
    @State private var records: [GameRecord] = []

    public init(store: LatticeStore) {
        self.store = store
    }

    public var body: some View {
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
        .onAppear { records = store.loadRecords() }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 16) {
            chart
                .frame(height: 220)
            List(records) { record in
                HStack {
                    Text(record.finishedAt, format: .dateTime.year().month().day())
                        .foregroundStyle(.secondary)
                    Text(verbatim: record.rules.storageKey)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.quaternary, in: Capsule())
                    Spacer()
                    Text(verbatim: "\(record.score)")
                        .font(.headline.monospacedDigit())
                }
            }
            .listStyle(.plain)
        }
    }

    // Chronological scores as points, with the running best as a step line —
    // monochrome like the board; the accent stays reserved for interaction.
    private var chart: some View {
        let chronological = records.sorted { $0.finishedAt < $1.finishedAt }
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
