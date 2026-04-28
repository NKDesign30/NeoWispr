import SwiftUI
import AppKit
import CoreText

enum Neon {

    // MARK: - Brand Colors (Forest Emerald)

    static let brandPrimary = Color(hex: 0x2EAB73)
    static let brandBright  = Color(hex: 0x34C788)
    static let brandMint    = Color(hex: 0x3FE39A)   // Logo pulse + Wispr wordmark
    static let brandFaint   = Color(hex: 0x2EAB73, alpha: 0.10)
    static let brandMuted   = Color(hex: 0x2EAB73, alpha: 0.22)

    // MARK: - Logo gradient (F-deep Night)

    static let logoNight1 = Color(hex: 0x0B3A26)
    static let logoNight2 = Color(hex: 0x05201A)
    static let logoNight3 = Color(hex: 0x020F0B)

    // MARK: - Sub-brand accents

    static let wisprBlue    = Color(hex: 0x409CFF)
    static let barAmber     = Color(hex: 0xFFB340)
    static let quillIndigo  = Color(hex: 0x7C8AFF)

    // MARK: - Surfaces (warm dark — never #000)

    static let surfaceBackground = Color(hex: 0x1A1A18)
    static let surfaceCard       = Color.white.opacity(0.04)
    static let surfaceSunken     = Color.white.opacity(0.02)
    static let surfaceElevated   = Color.white.opacity(0.06)
    static let surfaceInput      = Color.white.opacity(0.04)
    static let surfaceRowHover   = Color.white.opacity(0.04)

    // MARK: - Text hierarchy (alpha overlays)

    static let textPrimary    = Color.white.opacity(0.96)
    static let textSecondary  = Color.white.opacity(0.66)
    static let textTertiary   = Color.white.opacity(0.42)
    static let textQuaternary = Color.white.opacity(0.26)
    static let textOnBrand    = Color.white

    // MARK: - Status

    static let statusSuccess = Color(hex: 0x2EAB73)
    static let statusWarning = Color(hex: 0xFFB340)
    static let statusError   = Color(hex: 0xFF6259)
    static let statusInfo    = Color(hex: 0x409CFF)

    // MARK: - Strokes (hairline 0.5)

    static let strokeHairline = Color.white.opacity(0.08)
    static let strokeDefault  = Color.white.opacity(0.14)
    static let strokeStrong   = Color.white.opacity(0.22)
    static let strokeBrand    = Color(hex: 0x2EAB73, alpha: 0.60)
    static let hairlineWidth: CGFloat = 0.5

    // MARK: - Spacing

    enum Space {
        static let s1: CGFloat = 4
        static let s2: CGFloat = 8
        static let s3: CGFloat = 12
        static let s4: CGFloat = 16
        static let s5: CGFloat = 20
        static let s6: CGFloat = 24
        static let s8: CGFloat = 32
        static let s10: CGFloat = 40
        static let s12: CGFloat = 48
    }

    // MARK: - Radius

    enum Radius {
        static let sm: CGFloat = 4
        static let md: CGFloat = 6
        static let lg: CGFloat = 10
        static let xl: CGFloat = 14
        static let xl2: CGFloat = 18
        static let xl3: CGFloat = 22
    }

    // MARK: - Font PostScript names
    //
    // We use PostScript names (not family) so static masters resolve directly.
    // Variable masters (Space Grotesk, Geist Mono, Inter) ship a single PostScript name
    // that exposes weight via the `wght` axis — SwiftUI's `.weight(...)` modifier maps to it.

    enum FontPS {
        static let displayRegular = "DMSerifDisplay-Regular"
        static let displayItalic  = "DMSerifDisplay-Italic"
        static let bodyVariable   = "SpaceGrotesk-Light"   // PS name of the variable master
        static let monoVariable   = "GeistMono-Regular"    // PS name of the variable master
        static let altVariable    = "InterVariable"
    }
}

// MARK: - Font Helpers

extension Font {

    /// Editorial display (DM Serif Display) — hero numbers, section headlines.
    static func neonDisplay(_ size: CGFloat, italic: Bool = false) -> Font {
        let name = italic ? Neon.FontPS.displayItalic : Neon.FontPS.displayRegular
        return .custom(name, size: size)
    }

    /// Body (Space Grotesk Variable) — UI text, labels, copy. Weight via `.weight(...)`.
    static func neonBody(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom(Neon.FontPS.bodyVariable, size: size).weight(weight)
    }

    /// Mono (Geist Mono Variable) — eyebrows, timestamps, code. Weight via `.weight(...)`.
    static func neonMono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom(Neon.FontPS.monoVariable, size: size).weight(weight)
    }

    // MARK: - Pre-composed signatures from the design system

    static var neonDisplayHeroXL: Font  { neonDisplay(96) }
    static var neonDisplayHero: Font    { neonDisplay(72) }
    static var neonDisplayStat: Font    { neonDisplay(44) }
    static var neonDisplayWindow: Font  { neonDisplay(32) }
    static var neonDisplaySection: Font { neonDisplay(24) }

    static var neonBodyXL: Font    { neonBody(18) }
    static var neonBody15: Font    { neonBody(15) }
    static var neonBodyDefault: Font { neonBody(14) }
    static var neonBodySm: Font    { neonBody(12) }
    static var neonBodyButton: Font { neonBody(13, weight: .medium) }

    static var neonEyebrow: Font   { neonMono(11, weight: .medium) }
    static var neonMonoMeta: Font  { neonMono(11) }
    static var neonMonoTime: Font  { neonMono(11) }
    static var neonMonoCode: Font  { neonMono(13) }
}

// MARK: - Color hex initializer

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}

// MARK: - Font Registration

enum NeonFontRegistrar {

    /// Registers all bundled font files with CoreText so `.custom(...)` resolves.
    /// Call once at app launch (idempotent — duplicates are silently ignored).
    ///
    /// SPM packs resources into `Bundle.module` (a sub-bundle named
    /// `NeoWispr_NeoWispr.bundle` inside `Bundle.main`). We try both that and
    /// `Bundle.main` directly so the call works whether the build is via
    /// `swift run`, the bundled `.app`, or anything in between.
    static func register() {
        let files = [
            "DMSerifDisplay-Regular",
            "DMSerifDisplay-Italic",
            "SpaceGrotesk-Variable",
            "InterVariable",
            "GeistMono-Variable",
        ]
        let bundles = candidateBundles()
        NSLog("[NeonFonts] candidate bundles:")
        for b in bundles { NSLog("[NeonFonts]   \(b.bundlePath)") }

        var registered = 0
        for name in files {
            var found = false
            for bundle in bundles {
                let url = bundle.url(forResource: name, withExtension: "ttf", subdirectory: "Fonts")
                    ?? bundle.url(forResource: name, withExtension: "ttf")
                guard let url else { continue }
                var error: Unmanaged<CFError>?
                let ok = CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
                if ok {
                    registered += 1
                    NSLog("[NeonFonts] OK \(name) → \(url.lastPathComponent)")
                } else if let e = error?.takeRetainedValue() {
                    NSLog("[NeonFonts] FAIL \(name): \(CFErrorCopyDescription(e) as String? ?? "?")")
                }
                found = true
                break
            }
            if !found { NSLog("[NeonFonts] MISSING \(name).ttf in any bundle") }
        }
        NSLog("[NeonFonts] registered \(registered)/\(files.count) fonts total")

        // Sanity check — print what CoreText now reports for the families we expect.
        for family in ["DM Serif Display", "Space Grotesk", "Geist Mono", "Inter Variable"] {
            let members = (CTFontManagerCopyAvailableFontFamilyNames() as? [String]) ?? []
            NSLog("[NeonFonts] family present? '\(family)' = \(members.contains(family))")
        }
    }

    private static func candidateBundles() -> [Bundle] {
        var bundles: [Bundle] = [.main, .module]
        // Sub-bundle that build-app.sh ditto-copies into Contents/Resources.
        if let subURL = Bundle.main.url(forResource: "NeoWispr_NeoWispr", withExtension: "bundle"),
           let sub = Bundle(url: subURL) {
            bundles.append(sub)
        }
        return bundles
    }
}

// MARK: - Eyebrow text modifier (mono, uppercase, tracked)

struct NeonEyebrow: ViewModifier {
    var color: Color = Neon.textTertiary
    func body(content: Content) -> some View {
        content
            .font(.neonEyebrow)
            .tracking(0.88)
            .textCase(.uppercase)
            .foregroundStyle(color)
    }
}

extension View {
    func neonEyebrow(color: Color = Neon.textTertiary) -> some View {
        modifier(NeonEyebrow(color: color))
    }
}

// MARK: - Hairline border helper

struct NeonHairlineBorder: ViewModifier {
    var radius: CGFloat
    var color: Color = Neon.strokeHairline
    func body(content: Content) -> some View {
        content.overlay(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .stroke(color, lineWidth: Neon.hairlineWidth)
        )
    }
}

extension View {
    func neonHairline(radius: CGFloat = Neon.Radius.xl, color: Color = Neon.strokeHairline) -> some View {
        modifier(NeonHairlineBorder(radius: radius, color: color))
    }
}

// MARK: - Settings section header (display, brand-tone)

extension Text {
    /// Editorial section header used inside SwiftUI `Form` `Section { } header: { ... }`.
    func neonSectionHeader() -> some View {
        self.font(.neonDisplay(16))
            .foregroundStyle(Neon.textPrimary)
            .textCase(nil)
    }
}

// MARK: - Settings shell — dark surface + grouped form on Settings scenes

struct NeonSettingsShell<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .background(Neon.surfaceBackground)
    }
}
