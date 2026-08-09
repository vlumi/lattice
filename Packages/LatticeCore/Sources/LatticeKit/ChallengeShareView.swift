import LatticeCore
import SwiftUI

/// The challenge hand-off: scan the QR (it's the universal link), share the
/// link, or read the code aloud — three transports for the same seed.
struct ChallengeShareView: View {
    let code: String
    let url: URL
    let dismiss: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            if let qr = QRCode.image(for: url.absoluteString) {
                qr
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
                    .frame(width: 180, height: 180)
                    .accessibilityLabel(Text("Challenge QR code", bundle: .module))
            }
            Text(verbatim: code)
                .font(.title3.monospaced().weight(.semibold))
                .textSelection(.enabled)
            ShareLink(item: url) {
                Label {
                    Text("Share Challenge", bundle: .module)
                } icon: {
                    Image(systemName: "square.and.arrow.up")
                }
            }
            // Esc lives on the parent (see overlayDismissKeys); this is the
            // click affordance.
            Button(action: dismiss) {
                Text("Done", bundle: .module)
            }
        }
    }
}
