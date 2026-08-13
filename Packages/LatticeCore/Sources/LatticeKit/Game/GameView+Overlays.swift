import LatticeCore
import SwiftUI

/// Modals and overlays presented over the board, plus the keys that dismiss
/// them: the New Game modal, the generating indicator, the challenge popover.
extension GameView {
    @ViewBuilder var overlayDismissKeys: some View {
        if isShowingChallenge {
            HiddenShortcut(key: .escape) { isShowingChallenge = false }
        }
    }

    /// Shown over the board while a seeded start is being generated.
    var generatingOverlay: some View {
        VStack(spacing: 10) {
            ProgressView()
            Text("Generating board…", bundle: .module)
                .font(.subheadline).foregroundStyle(.secondary)
        }
        .padding(20)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    var newGameModal: some View {
        NewGameModal(
            session: session,
            dismiss: { isShowingNewGame = false },
            onVariant: { rules in
                session.newGame(rules: rules)
                camera.reset()
            },
            onRandom: {
                session.newChallenge(seed: SeedCode.randomSeed())
                camera.reset()
            },
            onCode: { seed in
                session.newChallenge(seed: seed)
                camera.reset()
            },
            onScan: scanAction)
    }

    /// The iOS scanner action, if the device supports it (nil otherwise / macOS).
    var scanAction: (() -> Void)? {
        #if os(iOS)
        guard CodeScannerView.isSupported else { return nil }
        return {
            isShowingNewGame = false
            isScanning = true
        }
        #else
        return nil
        #endif
    }
}

// Share-card / export text for the game-over row.
