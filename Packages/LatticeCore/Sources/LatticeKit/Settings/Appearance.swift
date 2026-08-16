import SwiftUI

/// User-chosen appearance. `.system` follows the device setting.
///
/// Worth having beyond taste: capturing the App Store's dark screenshot
/// otherwise means leaving the app to change the system appearance, which on a
/// Mac is a trip through System Settings.
public enum AppearancePreference: String, CaseIterable, Identifiable, Sendable {
    case system
    case light
    case dark

    public static let defaultsKey = "lattice.appearance"

    public var id: String { rawValue }

    public var label: LocalizedStringKey {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    /// The scheme to force on the SwiftUI hierarchy, or nil to follow the system.
    public var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    /// The concrete scheme to render with. `.preferredColorScheme(nil)` on a
    /// live sheet goes inert WITHOUT releasing the previously-forced value, so
    /// sheets must always be handed a concrete scheme — `.system` resolves to
    /// whatever the OS is currently showing.
    public func resolvedScheme(systemFallback: ColorScheme) -> ColorScheme {
        switch self {
        case .light: return .light
        case .dark: return .dark
        case .system:
            #if canImport(AppKit)
            // macOS: the ambient colorScheme is unreliable beneath a sibling
            // `.preferredColorScheme`, so ask AppKit what's actually on screen.
            let match = NSApp?.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua])
            return match == .darkAqua ? .dark : .light
            #else
            return systemFallback
            #endif
        }
    }
}

extension View {
    /// A `.sheet` pinned to the app's chosen appearance.
    ///
    /// Sheets present in a FRESH environment that doesn't inherit the
    /// presenter's `.preferredColorScheme`, so without this a sheet follows the
    /// system and ignores a Light/Dark override — most visibly the macOS
    /// Settings sheet, which is where the setting itself lives.
    public func appearanceSheet<C: View>(
        isPresented: Binding<Bool>, @ViewBuilder content: @escaping () -> C
    ) -> some View {
        modifier(AppearanceSheet(isPresented: isPresented, sheet: content))
    }
}

/// The presenter's `@Environment(\.colorScheme)` already reflects whatever the
/// app forces, so resolve the concrete scheme HERE and pin it on the content.
private struct AppearanceSheet<C: View>: ViewModifier {
    @AppStorage(AppearancePreference.defaultsKey) private var appearance = AppearancePreference
        .system
    @Environment(\.colorScheme) private var systemScheme
    let isPresented: Binding<Bool>
    @ViewBuilder let sheet: () -> C

    func body(content: Content) -> some View {
        content.sheet(isPresented: isPresented) {
            sheet().preferredColorScheme(
                appearance.resolvedScheme(systemFallback: systemScheme))
        }
    }
}
