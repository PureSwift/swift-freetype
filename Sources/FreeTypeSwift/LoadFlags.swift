import CFreeType

/// Flags for loading a glyph, mirroring `FT_LOAD_*`.
public struct LoadFlags: OptionSet, Sendable {
    public let rawValue: Int32

    public init(rawValue: Int32) {
        self.rawValue = rawValue
    }

    public static let `default`: LoadFlags = []
    /// Don't scale; metrics and outlines are returned in font units.
    public static let noScale = LoadFlags(rawValue: 1 << 0)
    public static let noHinting = LoadFlags(rawValue: 1 << 1)
    /// Render the glyph after loading (normal mode unless a mode is given explicitly).
    public static let render = LoadFlags(rawValue: 1 << 2)
    public static let noBitmap = LoadFlags(rawValue: 1 << 3)
    public static let verticalLayout = LoadFlags(rawValue: 1 << 4)
    public static let forceAutohint = LoadFlags(rawValue: 1 << 5)
    public static let cropBitmap = LoadFlags(rawValue: 1 << 6)
    public static let pedantic = LoadFlags(rawValue: 1 << 7)
    public static let ignoreGlobalAdvanceWidth = LoadFlags(rawValue: 1 << 9)
    public static let noRecurse = LoadFlags(rawValue: 1 << 10)
    public static let ignoreTransform = LoadFlags(rawValue: 1 << 11)
    public static let monochrome = LoadFlags(rawValue: 1 << 12)
    public static let linearDesign = LoadFlags(rawValue: 1 << 13)
    public static let noAutohint = LoadFlags(rawValue: 1 << 15)
    /// Load color bitmaps (e.g. emoji) as BGRA when available.
    public static let color = LoadFlags(rawValue: 1 << 20)
    public static let computeMetrics = LoadFlags(rawValue: 1 << 21)
    public static let bitmapMetricsOnly = LoadFlags(rawValue: 1 << 22)
}

/// Rasterization mode, mirroring `FT_Render_Mode`.
public enum RenderMode: Sendable {
    /// 8-bit anti-aliased coverage.
    case normal
    case light
    /// 1-bit monochrome.
    case mono
    /// Horizontal RGB subpixel rendering (bitmap is three times as wide).
    case lcd
    /// Vertical RGB subpixel rendering (bitmap is three times as tall).
    case lcdVertical
    /// 8-bit signed distance field.
    case sdf

    var raw: FT_Render_Mode {
        switch self {
        case .normal: FT_RENDER_MODE_NORMAL
        case .light: FT_RENDER_MODE_LIGHT
        case .mono: FT_RENDER_MODE_MONO
        case .lcd: FT_RENDER_MODE_LCD
        case .lcdVertical: FT_RENDER_MODE_LCD_V
        case .sdf: FT_RENDER_MODE_SDF
        }
    }
}

/// Kerning distance mode, mirroring `FT_Kerning_Mode`.
public enum KerningMode: UInt32, Sendable {
    /// Grid-fitted, in pixels.
    case `default` = 0
    /// Not grid-fitted, in pixels.
    case unfitted = 1
    /// Unscaled, in font units.
    case unscaled = 2
}
