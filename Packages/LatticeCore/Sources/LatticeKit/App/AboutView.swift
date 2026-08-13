import SwiftUI

/// App "About": icon, version, credits and links — reached from Settings on
/// both platforms, and from the macOS app menu. Adapted from Donpa's
/// `AboutView` (plumbing kept in sync with the sibling app), minus its
/// Japanese-name handling: Lattice isn't localized yet.
struct AboutView: View {
    /// The build's git commit, stamped into the bundled plist at build time by
    /// Scripts/embed-commit-sha.sh. "-dirty" means it was built off uncommitted
    /// changes; absent on a build made before that phase existed.
    private var commitSHA: String? {
        Bundle.main.infoDictionary?["GitCommitSHA"] as? String
    }

    private var versionString: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "—"
        let build = info?["CFBundleVersion"] as? String ?? "—"
        return "\(short) (\(build))"
    }

    var body: some View {
        VStack(spacing: 16) {
            appIcon
                .frame(width: 88, height: 88)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: .black.opacity(0.25), radius: 8, y: 3)

            Text(verbatim: "Lattice Five").font(.title2.bold())

            // What the game is, in the game's own words — not a genre blurb.
            Text("Join five dots in a row. Again, and again, and again.", bundle: .module)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Text("Version \(versionString)", bundle: .module)
                .font(.footnote.monospacedDigit().weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Capsule().fill(.tint.opacity(0.15)))
                .overlay(Capsule().strokeBorder(.tint.opacity(0.3), lineWidth: 1))

            if let sha = commitSHA {
                Text(verbatim: sha)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.tertiary)
            }

            VStack(spacing: 6) {
                Text(verbatim: "© 2026 Ville Misaki").font(.footnote)
                Link(destination: URL(string: "https://lattice.misaki.fi")!) {
                    Label {
                        Text(verbatim: "lattice.misaki.fi")
                    } icon: {
                        Image(systemName: "globe")
                    }
                    .font(.footnote)
                }
                Link(destination: URL(string: "https://github.com/vlumi/lattice")!) {
                    Label {
                        Text(verbatim: "github.com/vlumi/lattice")
                    } icon: {
                        Image(systemName: "link")
                    }
                    .font(.footnote)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    /// The app icon, dug out of the bundle — the `AppIcon` asset set isn't
    /// directly loadable as a UI image.
    @ViewBuilder private var appIcon: some View {
        #if os(macOS)
        if let image = NSApplication.shared.applicationIconImage {
            Image(nsImage: image).resizable()
        } else {
            placeholderIcon
        }
        #else
        if let image = uiAppIcon {
            Image(uiImage: image).resizable()
        } else {
            placeholderIcon
        }
        #endif
    }

    private var placeholderIcon: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(.secondary.opacity(0.2))
            .overlay(
                Image(systemName: "square.grid.2x2")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary))
    }

    #if os(iOS)
    private var uiAppIcon: UIImage? {
        guard
            let icons = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any],
            let primary = icons["CFBundlePrimaryIcon"] as? [String: Any],
            let files = primary["CFBundleIconFiles"] as? [String],
            let name = files.last
        else { return nil }
        return UIImage(named: name)
    }
    #endif
}

/// `AboutView` as a presentable sheet: title bar, Done, and Esc to close —
/// the same chrome as the macOS Settings sheet.
struct AboutSheet: View {
    let dismiss: () -> Void

    @ScaledMetric(relativeTo: .body) private var paneWidth: CGFloat = 380

    var body: some View {
        SheetChrome(title: Text("About", bundle: .module), dismiss: dismiss) {
            ScrollView {
                AboutView().padding(20)
            }
        }
        #if os(macOS)
        .frame(width: paneWidth, height: 520)
        #endif
    }
}

/// The how-to-play reference as its own sheet — reached from the macOS Help
/// menu (⌘?) and the iOS Settings row, NOT via About: About is a dead end
/// (version, credits), not a hub.
struct HowToPlaySheet: View {
    let dismiss: () -> Void

    @ScaledMetric(relativeTo: .body) private var paneWidth: CGFloat = 460
    @State private var showingKeys = false

    var body: some View {
        SheetChrome(title: Text("How to play", bundle: .module), dismiss: dismiss) {
            #if os(macOS)
            HowToPlayView(onKeyboard: { showingKeys = true })
            #else
            HowToPlayView()
            #endif
        }
        .overlay {
            if showingKeys {
                KeyboardCheatsheet(dismiss: { showingKeys = false })
            }
        }
        #if os(macOS)
        .frame(width: paneWidth, height: 620)
        #endif
    }
}

/// Shared sheet chrome: a title bar with Done, plus Esc to close.
private struct SheetChrome<Content: View>: View {
    let title: Text
    let dismiss: () -> Void
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                title.font(.headline)
                Spacer()
                Button(action: dismiss) {
                    Text("Done", bundle: .module)
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            Divider()
            content
        }
        .background(
            Button(action: dismiss) { Color.clear.frame(width: 1, height: 1) }
                .keyboardShortcut(.escape, modifiers: [])
                .opacity(0)
        )
    }
}
