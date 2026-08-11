import Foundation
import LatticeCore

/// Race timing. The host is the sole authority, so every device shows the
/// same standings from one clock.
extension NearbyMatch {
    /// Host, race only: stamp the elapsed time the first moment a player's score
    /// reaches the target. One clock (the host's), so times have no cross-device
    /// skew. No-op on guests / lock-step.
    func stampReaches() {
        guard role == .hosting, case .race(let tier) = match?.mode,
            let start = matchStart, let players = match?.players
        else { return }
        let elapsed = Date().timeIntervalSince(start)
        for (tag, state) in players where state.score >= tier && reachTimes[tag] == nil {
            reachTimes[tag] = elapsed
        }
    }

    /// Host: build the final rows. Race ranks finishers by reach-time (ascending)
    /// then non-finishers by score (descending); lock-step keeps the engine's
    /// settled order.
    func rankedRows(order standings: [String]) -> [Standing] {
        let rows = standings.map { tag in
            Standing(
                name: match?.players[tag]?.name ?? tag,
                score: match?.players[tag]?.score ?? 0,
                reachTime: reachTimes[tag])
        }
        guard case .race = match?.mode else { return rows }
        return rows.sorted { a, b in
            switch (a.reachTime, b.reachTime) {
            case (let ta?, let tb?): return ta < tb  // both reached — faster first
            case (.some, .none): return true  // a reached, b didn't
            case (.none, .some): return false
            case (.none, .none): return a.score > b.score  // neither — more moves
            }
        }
    }
}
