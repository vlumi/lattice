import Charts
import LatticeCore
import SwiftUI

/// Finished games over time. "All" (the default) shows every scoring pool
/// at once — each with its fixed colour AND symbol, in the chart, the
/// legend, and the list rows — or filter down to one pool. Rows open
/// replays.
public struct HistoryView: View {
    private let store: LatticeStore
    @Binding private var path: NavigationPath
    @Environment(\.colorScheme) private var colorScheme
    @State private var records: [GameRecord] = []
    /// nil = All.
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
            if let selected = selectedVariant, !presentVariants.contains(selected) {
                selectedVariant = nil
            }
        }
    }

    /// Scoring pools that actually have records, in canonical slot order.
    private var presentVariants: [String] {
        let present = Set(records.map(\.variantKey))
        let ordered = VariantStyle.order.filter(present.contains)
        // Anything stored under a key no longer listed still shows up
        // (defensive).
        return ordered + present.subtracting(ordered).sorted()
    }

    private var filtered: [GameRecord] {
        guard let selectedVariant else { return records }
        return records.filter { $0.variantKey == selectedVariant }
    }

    /// The pools the chart currently shows, in canonical order.
    private var visibleVariants: [String] {
        guard let selectedVariant else { return presentVariants }
        return [selectedVariant]
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 16) {
            if presentVariants.count > 1 {
                Picker(selection: $selectedVariant) {
                    Text("All", bundle: .module).tag(String?.none)
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
                        Label {
                            Text(verbatim: record.variantKey)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        } icon: {
                            Image(systemName: VariantStyle.icon(for: record.variantKey))
                                .font(.caption)
                                .foregroundStyle(
                                    VariantStyle.color(
                                        for: record.variantKey, scheme: colorScheme))
                        }
                        .frame(width: 64, alignment: .leading)
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

    private struct BestSample: Identifiable {
        let date: Date
        let best: Int
        var id: Date { date }
    }

    private struct BestSeries: Identifiable {
        let key: String
        let samples: [BestSample]
        var id: String { key }
    }

    // Scores as symbol-coded points per pool, each pool's running best as a
    // step line in the pool's colour. Colour and symbol scales share the
    // fixed per-key mapping, so the legend carries both.
    private var chart: some View {
        let chronological = filtered.sorted { $0.finishedAt < $1.finishedAt }
        let bests: [BestSeries] = visibleVariants.map { key in
            var best = 0
            let samples = chronological.filter { $0.variantKey == key }.map { record in
                best = max(best, record.score)
                return BestSample(date: record.finishedAt, best: best)
            }
            return BestSeries(key: key, samples: samples)
        }
        return Chart {
            ForEach(chronological) { record in
                PointMark(
                    x: .value("Date", record.finishedAt),
                    y: .value("Score", record.score)
                )
                .foregroundStyle(by: .value("Variant", record.variantKey))
                .symbol(by: .value("Variant", record.variantKey))
            }
            ForEach(bests) { series in
                ForEach(series.samples) { sample in
                    LineMark(
                        x: .value("Date", sample.date),
                        y: .value("Best", sample.best),
                        series: .value("Series", series.key)
                    )
                    .interpolationMethod(.stepEnd)
                    .foregroundStyle(by: .value("Variant", series.key))
                    .opacity(0.45)
                }
            }
        }
        .chartForegroundStyleScale(
            domain: visibleVariants,
            range: visibleVariants.map { VariantStyle.color(for: $0, scheme: colorScheme) }
        )
        .chartSymbolScale(
            domain: visibleVariants,
            range: visibleVariants.map(VariantStyle.chartSymbol(for:))
        )
        .chartLegend(visibleVariants.count > 1 ? .visible : .hidden)
    }
}
