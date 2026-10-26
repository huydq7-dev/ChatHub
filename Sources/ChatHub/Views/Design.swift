import AppKit
import SwiftUI

#if SWIFT_PACKAGE
    import ChatHubCore
#endif

extension HubAccent {
    var title: String {
        switch self {
        case .iris: tr("Iris")
        case .ocean: tr("Ocean")
        case .emerald: tr("Emerald")
        case .amber: tr("Amber")
        case .rose: tr("Rose")
        case .graphite: tr("Graphite")
        }
    }

    var swatchColor: Color {
        switch self {
        case .iris: Color(red: 0.400, green: 0.322, blue: 0.851)
        case .ocean: Color(red: 0.145, green: 0.388, blue: 0.922)
        case .emerald: Color(red: 0.051, green: 0.580, blue: 0.533)
        case .amber: Color(red: 0.851, green: 0.467, blue: 0.024)
        case .rose: Color(red: 0.882, green: 0.114, blue: 0.282)
        case .graphite: Color(red: 0.322, green: 0.322, blue: 0.357)
        }
    }
}

extension HubDensity {
    var title: String {
        switch self {
        case .compact: tr("Compact")
        case .standard: tr("Default")
        case .comfortable: tr("Comfortable")
        }
    }
}

extension HubTextScale {
    var title: String {
        switch self {
        case .small: tr("Small")
        case .standard: tr("Default")
        case .large: tr("Large")
        }
    }
}

enum HubStyle {
    private static func dynamicColor(
        light: (CGFloat, CGFloat, CGFloat, CGFloat),
        dark: (CGFloat, CGFloat, CGFloat, CGFloat)
    ) -> Color {
        Color(
            nsColor: NSColor(name: nil) { appearance in
                let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                let rgba = isDark ? dark : light
                return NSColor(srgbRed: rgba.0, green: rgba.1, blue: rgba.2, alpha: rgba.3)
            })
    }

    private static var currentAccent: HubAccent {
        let raw = UserDefaults.standard.string(forKey: ChatAppearancePreferences.accentKey) ?? HubAccent.iris.rawValue
        return HubAccent(rawValue: raw) ?? .iris
    }

    static func accentColor(for accent: HubAccent) -> Color {
        switch accent {
        case .iris:
            dynamicColor(light: (0.400, 0.322, 0.851, 1.0), dark: (0.471, 0.384, 0.922, 1.0))
        case .ocean:
            dynamicColor(light: (0.145, 0.388, 0.922, 1.0), dark: (0.231, 0.510, 0.965, 1.0))
        case .emerald:
            dynamicColor(light: (0.051, 0.580, 0.533, 1.0), dark: (0.078, 0.722, 0.651, 1.0))
        case .amber:
            dynamicColor(light: (0.851, 0.467, 0.024, 1.0), dark: (0.961, 0.620, 0.043, 1.0))
        case .rose:
            dynamicColor(light: (0.882, 0.114, 0.282, 1.0), dark: (0.957, 0.247, 0.369, 1.0))
        case .graphite:
            dynamicColor(light: (0.247, 0.247, 0.275, 1.0), dark: (0.443, 0.443, 0.478, 1.0))
        }
    }

    static func accentTextColor(for accent: HubAccent) -> Color {
        switch accent {
        case .iris:
            dynamicColor(light: (0.373, 0.275, 0.737, 1.0), dark: (0.757, 0.671, 1.000, 1.0))
        case .ocean:
            dynamicColor(light: (0.114, 0.306, 0.847, 1.0), dark: (0.576, 0.773, 0.992, 1.0))
        case .emerald:
            dynamicColor(light: (0.059, 0.463, 0.431, 1.0), dark: (0.431, 0.906, 0.718, 1.0))
        case .amber:
            dynamicColor(light: (0.706, 0.325, 0.035, 1.0), dark: (0.988, 0.827, 0.302, 1.0))
        case .rose:
            dynamicColor(light: (0.745, 0.071, 0.235, 1.0), dark: (0.992, 0.643, 0.686, 1.0))
        case .graphite:
            dynamicColor(light: (0.247, 0.247, 0.275, 1.0), dark: (0.831, 0.831, 0.847, 1.0))
        }
    }

    static func selectedSurface(for accent: HubAccent) -> Color {
        switch accent {
        case .iris:
            dynamicColor(light: (0.925, 0.906, 0.984, 1.0), dark: (0.224, 0.192, 0.275, 1.0))
        case .ocean:
            dynamicColor(light: (0.902, 0.937, 0.992, 1.0), dark: (0.145, 0.204, 0.302, 1.0))
        case .emerald:
            dynamicColor(light: (0.890, 0.961, 0.949, 1.0), dark: (0.129, 0.220, 0.216, 1.0))
        case .amber:
            dynamicColor(light: (0.980, 0.937, 0.882, 1.0), dark: (0.247, 0.196, 0.141, 1.0))
        case .rose:
            dynamicColor(light: (0.988, 0.910, 0.933, 1.0), dark: (0.263, 0.161, 0.204, 1.0))
        case .graphite:
            dynamicColor(light: (0.906, 0.906, 0.925, 1.0), dark: (0.208, 0.208, 0.231, 1.0))
        }
    }

    // Exact light/dark token parity with ChatAppearance.css
    static var accent: Color { accentColor(for: currentAccent) }
    static var accentText: Color { accentTextColor(for: currentAccent) }
    static var selected: Color { selectedSurface(for: currentAccent) }

    static let canvas = dynamicColor(
        light: (0.953, 0.953, 0.961, 1.0),
        dark: (0.125, 0.125, 0.137, 1.0)
    )
    static let surface = dynamicColor(
        light: (1.000, 1.000, 1.000, 1.0),
        dark: (0.157, 0.157, 0.173, 1.0)
    )
    static let card = surface
    static let raised = dynamicColor(
        light: (0.969, 0.969, 0.976, 1.0),
        dark: (0.196, 0.196, 0.216, 1.0)
    )
    static let rail = dynamicColor(
        light: (0.925, 0.925, 0.941, 1.0),
        dark: (0.141, 0.141, 0.153, 1.0)
    )
    static let hover = dynamicColor(
        light: (0.235, 0.176, 0.412, 0.05),
        dark: (1.000, 1.000, 1.000, 0.06)
    )
    static let pressed = dynamicColor(
        light: (0.235, 0.176, 0.412, 0.09),
        dark: (1.000, 1.000, 1.000, 0.10)
    )
    static let border = dynamicColor(
        light: (0.118, 0.118, 0.149, 0.10),
        dark: (1.000, 1.000, 1.000, 0.10)
    )
    static let textPrimary = dynamicColor(
        light: (0.137, 0.137, 0.153, 1.0),
        dark: (0.933, 0.933, 0.949, 1.0)
    )
    static let textSecondary = dynamicColor(
        light: (0.412, 0.412, 0.439, 1.0),
        dark: (0.682, 0.682, 0.722, 1.0)
    )
}

enum HubFont {
    static let hero = Font.system(size: 30, weight: .bold)
    static let pageTitle = Font.system(size: 23, weight: .bold)
    static let modalTitle = Font.system(size: 20, weight: .semibold)
    static let sectionTitle = Font.system(size: 15, weight: .semibold)
    static let brand = Font.system(size: 15, weight: .semibold)
    static let header = Font.system(size: 15, weight: .semibold)
    static let message = Font.system(size: 14.5, weight: .regular)
    static let rowTitle = Font.system(size: 13.5, weight: .semibold)
    static let body = Font.system(size: 13, weight: .regular)
    static let bodyMedium = Font.system(size: 13, weight: .medium)
    static let button = Font.system(size: 13, weight: .semibold)
    static let rowSubtitle = Font.system(size: 12.5, weight: .regular)
    static let caption = Font.system(size: 12, weight: .regular)
    static let captionMedium = Font.system(size: 12, weight: .medium)
    static let meta = Font.system(size: 11, weight: .medium)
    static let badge = Font.system(size: 11, weight: .semibold)
    static let overline = Font.system(size: 10, weight: .bold)
}

enum HubSpace {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 20
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
    static let searchHeight: CGFloat = 36
    static let rowHeight: CGFloat = 46
    static let accountRowHeight: CGFloat = 52
}

enum HubRadius {
    static let sm: CGFloat = 8
    static let control: CGFloat = 10
    static let row: CGFloat = 12
    static let card: CGFloat = 16
    static let hero: CGFloat = 20
    static let pill: CGFloat = 999
}

extension ChatService {
    /// Harmonized ChatHub palette: distinct enough to identify, unified in saturation and tone.
    var color: Color {
        switch self {
        case .telegram: Color(red: 0.24, green: 0.54, blue: 0.88)
        case .zalo: Color(red: 0.22, green: 0.44, blue: 0.90)
        case .messenger: Color(red: 0.44, green: 0.34, blue: 0.89)
        case .whatsapp: Color(red: 0.18, green: 0.60, blue: 0.48)
        case .discord: Color(red: 0.36, green: 0.38, blue: 0.86)
        case .custom: Color(red: 0.40, green: 0.43, blue: 0.54)
        }
    }

    var symbol: String {
        switch self {
        case .telegram: "paperplane.fill"
        case .zalo: "bubble.left.fill"
        case .messenger: "bolt.horizontal.fill"
        case .whatsapp: "phone.fill"
        case .discord: "gamecontroller.fill"
        case .custom: "globe"
        }
    }

    var description: String {
        switch self {
        case .telegram: tr("Messages, groups & channels")
        case .zalo: tr("Closer to your everyday")
        case .messenger: tr("Your Facebook conversations")
        case .whatsapp: tr("Keep your people close")
        case .discord: tr("Your communities, together")
        case .custom: tr("Bring another web chat")
        }
    }
}

@MainActor
private enum ServiceIconCache {
    private static var images: [ChatService: NSImage] = [:]

    static func image(for service: ChatService) -> NSImage? {
        if let cached = images[service] { return cached }
        guard service != .custom else { return nil }
        #if SWIFT_PACKAGE
            let bundle = Bundle.module
        #else
            let bundle = Bundle.main
        #endif
        guard let url = bundle.url(forResource: "icon-\(service.rawValue)", withExtension: "png"),
            let image = NSImage(contentsOf: url)
        else { return nil }
        images[service] = image
        return image
    }
}

struct ServiceIcon: View {
    let service: ChatService
    var size: CGFloat = 36
    var branded = true

    private var baseColor: Color { branded ? service.color : HubStyle.accent }

    var body: some View {
        let radius = size * 0.25
        if let nsImage = ServiceIconCache.image(for: service) {
            Image(nsImage: nsImage)
                .resizable()
                .interpolation(.high)
                .antialiased(true)
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .strokeBorder(.white.opacity(0.14), lineWidth: 1)
                }
                .accessibilityHidden(true)
        } else {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(baseColor.gradient)
                .overlay {
                    Image(systemName: service.symbol)
                        .font(.system(size: size * 0.43, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .strokeBorder(.white.opacity(0.18), lineWidth: 1)
                }
                .frame(width: size, height: size)
                .accessibilityHidden(true)
        }
    }
}

struct HubMark: View {
    var size: CGFloat = 36
    @AppStorage(ChatAppearancePreferences.accentKey) private var accentRaw = HubAccent.iris.rawValue

    private var accent: HubAccent { HubAccent(rawValue: accentRaw) ?? .iris }

    var body: some View {
        let radius = size * 0.28
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(HubStyle.accentColor(for: accent).gradient)
            .overlay {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: size * 0.45, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(.white.opacity(0.20), lineWidth: 1)
            }
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

struct CardSurface: ViewModifier {
    var radius: CGFloat = HubRadius.card
    var elevated = false

    func body(content: Content) -> some View {
        content
            .background(
                elevated ? HubStyle.raised : HubStyle.surface,
                in: RoundedRectangle(cornerRadius: radius, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(HubStyle.border, lineWidth: 1)
            )
    }
}

struct HubInputFieldSurface: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, HubSpace.sm)
            .frame(minHeight: HubSpace.searchHeight)
            .liquidGlassCard(cornerRadius: HubRadius.control)
    }
}

struct HubBadge: View {
    let text: String
    var prominent = false

    var body: some View {
        Text(text)
            .font(HubFont.badge)
            .monospacedDigit()
            .foregroundStyle(prominent ? .white : HubStyle.textSecondary)
            .padding(.horizontal, HubSpace.xs)
            .padding(.vertical, 3)
            .liquidGlassCapsule(tint: prominent ? HubStyle.accent : nil)
    }
}

struct HubButtonStyle: ButtonStyle {
    var prominent = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(HubFont.button)
            .padding(.horizontal, HubSpace.md)
            .padding(.vertical, 9)
            .foregroundStyle(prominent ? .white : HubStyle.textPrimary)
            .background(
                prominent
                    ? HubStyle.accent
                    : (configuration.isPressed ? HubStyle.pressed : HubStyle.raised),
                in: RoundedRectangle(cornerRadius: HubRadius.control, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: HubRadius.control, style: .continuous)
                    .strokeBorder(prominent ? .white.opacity(0.14) : HubStyle.border, lineWidth: 1)
            }
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            .contentShape(RoundedRectangle(cornerRadius: HubRadius.control, style: .continuous))
    }
}

// MARK: - Liquid Glass Design System (macOS 26+ Native with Graceful Fallback)

struct LiquidGlassCapsuleModifier: ViewModifier {
    var tint: Color? = nil
    var interactive: Bool = false

    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            if let tint {
                if interactive {
                    content.glassEffect(.regular.tint(tint).interactive(), in: .capsule)
                } else {
                    content.glassEffect(.regular.tint(tint), in: .capsule)
                }
            } else {
                if interactive {
                    content.glassEffect(.regular.interactive(), in: .capsule)
                } else {
                    content.glassEffect(.regular, in: .capsule)
                }
            }
        } else {
            if let tint {
                content
                    .background(tint, in: Capsule())
                    .overlay {
                        Capsule().strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
                    }
            } else {
                content
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay {
                        Capsule().strokeBorder(HubStyle.border, lineWidth: 1)
                    }
            }
        }
    }
}

struct LiquidGlassCardModifier: ViewModifier {
    var cornerRadius: CGFloat = HubRadius.card
    var tint: Color? = nil
    var interactive: Bool = false

    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            if let tint {
                if interactive {
                    content.glassEffect(.regular.tint(tint).interactive(), in: shape)
                } else {
                    content.glassEffect(.regular.tint(tint), in: shape)
                }
            } else {
                if interactive {
                    content.glassEffect(.regular.interactive(), in: shape)
                } else {
                    content.glassEffect(.regular, in: shape)
                }
            }
        } else {
            let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            if let tint {
                content
                    .background(tint.opacity(0.08), in: shape)
                    .background(.ultraThinMaterial, in: shape)
                    .overlay {
                        shape.strokeBorder(tint.opacity(0.35), lineWidth: 1)
                    }
            } else {
                content
                    .background(.ultraThinMaterial, in: shape)
                    .overlay {
                        shape.strokeBorder(HubStyle.border, lineWidth: 1)
                    }
            }
        }
    }
}

struct HubGlassContainer<Content: View>: View {
    var spacing: CGFloat = 20.0
    @ViewBuilder var content: () -> Content

    init(spacing: CGFloat = 20.0, @ViewBuilder content: @escaping () -> Content) {
        self.spacing = spacing
        self.content = content
    }

    var body: some View {
        if #available(macOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) {
                content()
            }
        } else {
            content()
        }
    }
}

extension View {
    func liquidGlassCapsule(tint: Color? = nil, interactive: Bool = false) -> some View {
        modifier(LiquidGlassCapsuleModifier(tint: tint, interactive: interactive))
    }

    func liquidGlassCard(
        cornerRadius: CGFloat = HubRadius.card,
        tint: Color? = nil,
        interactive: Bool = false
    ) -> some View {
        modifier(LiquidGlassCardModifier(cornerRadius: cornerRadius, tint: tint, interactive: interactive))
    }
}
