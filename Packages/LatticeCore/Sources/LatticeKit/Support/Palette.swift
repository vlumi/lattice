import Charts
import LatticeCore
import SwiftUI

// The app's colour identities. Both palettes draw from one CVD-validated set
// of categorical slots via paletteRGB, which is why they share a file.

/// Fixed visual identity per scoring pool — colour AND symbol, so identity
/// never rides on colour alone. Colours are categorical slots validated for
/// colour-vision-deficiency separation and both surfaces (dark mode uses
/// its own steps, not an automatic flip). The mapping is per-key and
/// permanent: filtering must never repaint a variant.
enum VariantStyle {
    /// Canonical slot order; unknown keys share the fallback. The 7-colour
    /// display order re-validated (CVD + both surfaces) when 5T+ joined.
    /// Canonical order lives in core (`VariantOrder`) so the duel tier gate
    /// and this share one definition.
    static let order = VariantOrder.canonical

    static func color(for key: String, scheme: ColorScheme) -> Color {
        let dark = scheme == .dark
        switch key {
        case "5T": return rgb(dark ? 0x39_87E5 : 0x2A_78D6)
        case "5T#": return rgb(dark ? 0xD9_5926 : 0xEB_6834)
        case "5T+", "5T+#": return rgb(dark ? 0x90_85E9 : 0x4A_3AA7)
        case "5D": return rgb(dark ? 0x19_9E70 : 0x1B_AF7A)
        case "5D#": return rgb(dark ? 0xC9_8500 : 0xED_A100)
        case "4T": return rgb(dark ? 0xD5_5181 : 0xE8_7BA4)
        case "4D": return rgb(0x00_8300)
        default: return .gray
        }
    }

    static func chartSymbol(for key: String) -> BasicChartSymbolShape {
        switch key {
        case "5T": return .circle
        case "5T#": return .cross
        case "5T+", "5T+#": return .plus
        case "5D": return .square
        case "5D#": return .asterisk
        case "4T": return .triangle
        case "4D": return .diamond
        default: return .pentagon
        }
    }

    /// The SF Symbol twin of the chart symbol, for list rows and badges.
    static func icon(for key: String) -> String {
        switch key {
        case "5T": return "circle.fill"
        case "5T#": return "xmark"
        case "5T+", "5T+#": return "plus"
        case "5D": return "square.fill"
        case "5D#": return "asterisk"
        case "4T": return "triangle.fill"
        case "4D": return "diamond.fill"
        default: return "pentagon.fill"
        }
    }

    private static func rgb(_ value: UInt32) -> Color {
        paletteRGB(value)
    }
}

/// Pass-and-play: each player owns a colour, on board and in chrome — two
/// pens on one sheet. Blue/vermillion is the palette's validated
/// CVD-safe adjacent pair.
enum PlayerStyle {
    static func color(for player: Int, scheme: ColorScheme) -> Color {
        let dark = scheme == .dark
        return player == 1
            ? paletteRGB(dark ? 0x39_87E5 : 0x2A_78D6)
            : paletteRGB(dark ? 0xD9_5926 : 0xEB_6834)
    }
}

func paletteRGB(_ value: UInt32) -> Color {
    Color(
        red: Double((value >> 16) & 0xFF) / 255,
        green: Double((value >> 8) & 0xFF) / 255,
        blue: Double(value & 0xFF) / 255)
}
