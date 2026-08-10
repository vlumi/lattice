import LatticeCore
import SwiftUI

extension NearbyDuelView {
    // Shown after the local player finishes: reached the target (with the place
    // they took) or dead-ended. The others keep playing; the standings bar above
    // updates live until the match ends.
    func finishedPanel(reached: Bool, rank: Int?) -> some View {
        VStack(spacing: 8) {
            Image(systemName: reached ? "flag.checkered" : "flag.slash")
                .font(.largeTitle)
                .foregroundStyle(reached ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
            if reached, let rank {
                Text("Reached the target — \(placeLabel(rank))", bundle: .module)
                    .font(.headline)
            } else {
                Text("No moves left", bundle: .module).font(.headline)
            }
            Text("Waiting for the others to finish…", bundle: .module)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func placeLabel(_ rank: Int) -> Text {
        switch rank {
        case 1: return Text("1st", bundle: .module)
        case 2: return Text("2nd", bundle: .module)
        case 3: return Text("3rd", bundle: .module)
        default: return Text("\(rank)th", bundle: .module)
        }
    }
}
