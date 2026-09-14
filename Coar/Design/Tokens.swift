import SwiftUI
import UIKit

// Design tokens from DESIGN.md §3–§6. Each colour and font token is defined once here and
// exposed as both a UIKit and a SwiftUI value, so the two halves cannot drift.
//
// Always spell the SwiftUI forms with the type (`Color.background`, `Color.fill`):
// a leading-dot `.background` / `.fill` in a `ShapeStyle` position resolves to SwiftUI's
// own styles, not to these tokens.

// MARK: - Colour

enum ColorToken {
    // Surfaces
    case background, surface, surfaceRaised, surfaceSunken, fill
    // Text
    case textPrimary, textSecondary, textTertiary
    // Accents (same in both modes)
    case accentGreen, accentAmber, accentBlue, accentOrange, accentPink
    case accentTeal, accentLime, accentLavender, accentCoral

    /// `(dark, light)` sRGB hex values.
    private var hex: (dark: UInt32, light: UInt32) {
        switch self {
        case .background: return (0x0F1115, 0xF3F3F8)
        case .surface: return (0x1A1D24, 0xFFFFFF)
        case .surfaceRaised: return (0x222630, 0xF8F8FC)
        case .surfaceSunken: return (0x14161B, 0xECECF2)
        case .fill: return (0x2A2E38, 0xE6E6EE)
        case .textPrimary: return (0xFFFFFF, 0x111318)
        case .textSecondary: return (0x9AA0AA, 0x7C818C)
        case .textTertiary: return (0x5A606B, 0xB4B8C2)
        case .accentGreen: return (0x4CD48A, 0x4CD48A)
        case .accentAmber: return (0xE9B94C, 0xE9B94C)
        case .accentBlue: return (0x6F8CFF, 0x6F8CFF)
        case .accentOrange: return (0xF2A83B, 0xF2A83B)
        case .accentPink: return (0xF0609C, 0xF0609C)
        case .accentTeal: return (0x3FCFC4, 0x3FCFC4)
        case .accentLime: return (0xB6E857, 0xB6E857)
        case .accentLavender: return (0x8C8DF5, 0x8C8DF5)
        case .accentCoral: return (0xE8735A, 0xE8735A)
        }
    }

    var uiColor: UIColor {
        let hex = hex
        return UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? hex.dark : hex.light)
        }
    }

    var color: Color { Color(uiColor: uiColor) }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }

    static let background = ColorToken.background.uiColor
    static let surface = ColorToken.surface.uiColor
    static let surfaceRaised = ColorToken.surfaceRaised.uiColor
    static let surfaceSunken = ColorToken.surfaceSunken.uiColor
    static let fill = ColorToken.fill.uiColor
    static let textPrimary = ColorToken.textPrimary.uiColor
    static let textSecondary = ColorToken.textSecondary.uiColor
    static let textTertiary = ColorToken.textTertiary.uiColor
    static let accentGreen = ColorToken.accentGreen.uiColor
    static let accentAmber = ColorToken.accentAmber.uiColor
    static let accentBlue = ColorToken.accentBlue.uiColor
    static let accentOrange = ColorToken.accentOrange.uiColor
    static let accentPink = ColorToken.accentPink.uiColor
    static let accentTeal = ColorToken.accentTeal.uiColor
    static let accentLime = ColorToken.accentLime.uiColor
    static let accentLavender = ColorToken.accentLavender.uiColor
    static let accentCoral = ColorToken.accentCoral.uiColor
}

extension Color {
    static let background = ColorToken.background.color
    static let surface = ColorToken.surface.color
    static let surfaceRaised = ColorToken.surfaceRaised.color
    static let surfaceSunken = ColorToken.surfaceSunken.color
    static let fill = ColorToken.fill.color
    static let textPrimary = ColorToken.textPrimary.color
    static let textSecondary = ColorToken.textSecondary.color
    static let textTertiary = ColorToken.textTertiary.color
    static let accentGreen = ColorToken.accentGreen.color
    static let accentAmber = ColorToken.accentAmber.color
    static let accentBlue = ColorToken.accentBlue.color
    static let accentOrange = ColorToken.accentOrange.color
    static let accentPink = ColorToken.accentPink.color
    static let accentTeal = ColorToken.accentTeal.color
    static let accentLime = ColorToken.accentLime.color
    static let accentLavender = ColorToken.accentLavender.color
    static let accentCoral = ColorToken.accentCoral.color
}

// MARK: - Typography (DESIGN.md §5)

enum FontToken {
    case pageTitle, pageSubtitle, sectionHeader, cardTitle, heroNumber, metricNumber, bodyText, label

    /// The text style the token scales with, and its weight. Hero numbers are a fixed 40pt
    /// rounded face scaled by the large-title metrics.
    private var spec: (style: UIFont.TextStyle, weight: UIFont.Weight, fixedSize: CGFloat?, rounded: Bool) {
        switch self {
        case .pageTitle: return (.largeTitle, .bold, nil, false)
        case .pageSubtitle: return (.subheadline, .regular, nil, false)
        case .sectionHeader: return (.title2, .semibold, nil, false)
        case .cardTitle: return (.headline, .semibold, nil, false)
        case .heroNumber: return (.largeTitle, .bold, 40, true)
        case .metricNumber: return (.title3, .semibold, nil, false)
        case .bodyText: return (.body, .regular, nil, false)
        case .label: return (.footnote, .regular, nil, false)
        }
    }

    var uiFont: UIFont {
        let spec = spec
        let metrics = UIFontMetrics(forTextStyle: spec.style)
        let baseSize = spec.fixedSize ?? UIFont.preferredFont(
            forTextStyle: spec.style,
            compatibleWith: UITraitCollection(preferredContentSizeCategory: .large)
        ).pointSize
        var font = UIFont.systemFont(ofSize: baseSize, weight: spec.weight)
        if spec.rounded {
            var descriptor = font.fontDescriptor
            descriptor = descriptor.withDesign(.rounded) ?? descriptor
            descriptor = descriptor.addingAttributes([
                .featureSettings: [[
                    UIFontDescriptor.FeatureKey.type: kNumberSpacingType,
                    UIFontDescriptor.FeatureKey.selector: kMonospacedNumbersSelector,
                ]],
            ])
            font = UIFont(descriptor: descriptor, size: baseSize)
        }
        return metrics.scaledFont(for: font)
    }

    var font: Font {
        let spec = spec
        if let size = spec.fixedSize {
            return Font.system(size: size, weight: Font.Weight(spec.weight), design: spec.rounded ? .rounded : .default)
                .monospacedDigit()
        }
        return Font.system(Font.TextStyle(spec.style), weight: Font.Weight(spec.weight))
    }
}

extension UIFont {
    static var pageTitle: UIFont { FontToken.pageTitle.uiFont }
    static var pageSubtitle: UIFont { FontToken.pageSubtitle.uiFont }
    static var sectionHeader: UIFont { FontToken.sectionHeader.uiFont }
    static var cardTitle: UIFont { FontToken.cardTitle.uiFont }
    static var heroNumber: UIFont { FontToken.heroNumber.uiFont }
    static var metricNumber: UIFont { FontToken.metricNumber.uiFont }
    static var bodyText: UIFont { FontToken.bodyText.uiFont }
    static var label: UIFont { FontToken.label.uiFont }
}

extension Font {
    static var pageTitle: Font { FontToken.pageTitle.font }
    static var pageSubtitle: Font { FontToken.pageSubtitle.font }
    static var sectionHeader: Font { FontToken.sectionHeader.font }
    static var cardTitle: Font { FontToken.cardTitle.font }
    static var heroNumber: Font { FontToken.heroNumber.font }
    static var metricNumber: Font { FontToken.metricNumber.font }
    static var bodyText: Font { FontToken.bodyText.font }
    static var label: Font { FontToken.label.font }
}

private extension Font.Weight {
    init(_ weight: UIFont.Weight) {
        switch weight {
        case .bold: self = .bold
        case .semibold: self = .semibold
        case .medium: self = .medium
        default: self = .regular
        }
    }
}

private extension Font.TextStyle {
    init(_ style: UIFont.TextStyle) {
        switch style {
        case .largeTitle: self = .largeTitle
        case .title1: self = .title
        case .title2: self = .title2
        case .title3: self = .title3
        case .headline: self = .headline
        case .subheadline: self = .subheadline
        case .footnote: self = .footnote
        case .caption1: self = .caption
        case .caption2: self = .caption2
        default: self = .body
        }
    }
}

// MARK: - Shape and spacing (DESIGN.md §4)

enum Metrics {
    static let radiusCard: CGFloat = 24
    static let radiusInner: CGFloat = 16
    static let radiusTile: CGFloat = 8

    static let spaceEdge: CGFloat = 20
    static let spaceCard: CGFloat = 16
    static let spaceInner: CGFloat = 16
    static let spaceTight: CGFloat = 8
    static let spaceSection: CGFloat = 28
}

// MARK: - Elevation (DESIGN.md §6)

enum Elevation {
    struct Shadow {
        let color: UIColor
        let opacity: Float
        let offset: CGSize
        /// Design blur value; a `CALayer.shadowRadius` is half of it.
        let blur: CGFloat
    }

    /// Card shadow for a given appearance.
    static func cardShadow(for style: UIUserInterfaceStyle) -> Shadow {
        switch style {
        case .dark:
            return Shadow(color: .black, opacity: 0.40, offset: CGSize(width: 0, height: 8), blur: 24)
        default:
            return Shadow(color: UIColor(hex: 0x8A8AB0), opacity: 0.12, offset: CGSize(width: 0, height: 8), blur: 24)
        }
    }

    /// Bloom: the accent-coloured second shadow on filled dots, active chart points, and
    /// ring end-caps; light mode lowers it. Appears with `bloomFade`, never pops.
    static func bloomOpacity(for style: UIUserInterfaceStyle) -> Double {
        style == .dark ? 0.55 : 0.30
    }
    static let bloomFade: TimeInterval = 0.2

    /// The 1pt inner top highlight on dark cards; clear in light mode.
    static let cardHighlight = UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor.white.withAlphaComponent(0.06) : .clear
    }
}
