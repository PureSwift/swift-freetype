import CFreeType

/// Glyph metrics.
///
/// Values are in pixels (converted from 26.6 fixed point), or in font units when the glyph
/// was loaded with ``LoadFlags/noScale``.
public struct GlyphMetrics: Hashable, Sendable {
    public var width: Double
    public var height: Double
    public var horizontalBearingX: Double
    public var horizontalBearingY: Double
    public var horizontalAdvance: Double
    public var verticalBearingX: Double
    public var verticalBearingY: Double
    public var verticalAdvance: Double
}

/// A rasterized glyph, copied out of the glyph slot.
///
/// Rows are stored top-to-bottom and tightly packed (no FreeType row padding), regardless of
/// the sign of the source pitch.
public struct GlyphBitmap: Hashable, Sendable {
    public enum PixelMode: Sendable {
        /// 1 bit per pixel, most significant bit first.
        case mono
        /// 8-bit coverage (also used for SDF).
        case gray
        /// 8-bit coverage, three samples per pixel horizontally (RGB subpixels).
        case lcd
        /// 8-bit coverage, three samples per pixel vertically.
        case lcdVertical
        /// Premultiplied 32-bit BGRA color.
        case bgra
    }

    /// Width in pixels of the stored buffer (for LCD modes this includes subpixels).
    public var width: Int
    public var rows: Int
    public var pixelMode: PixelMode
    public var bytesPerRow: Int
    public var pixels: [UInt8]
    /// Offset from the origin to the bitmap's left edge, in pixels.
    public var left: Int
    /// Offset from the baseline to the bitmap's top edge, in pixels (positive is up).
    public var top: Int

    /// Whether any pixel has non-zero coverage.
    public var hasCoverage: Bool {
        pixels.contains { $0 != 0 }
    }
}

/// An immutable snapshot of a glyph slot.
public struct Glyph: Sendable {
    public var index: UInt32
    public var metrics: GlyphMetrics
    /// Advance vector in pixels (font units with ``LoadFlags/noScale``).
    public var advanceX: Double
    public var advanceY: Double
    /// Unhinted horizontal advance in pixels, from the 16.16 `linearHoriAdvance`.
    public var linearHorizontalAdvance: Double
    /// Present when the glyph was rendered, or loaded as a bitmap strike.
    public var bitmap: GlyphBitmap?
    /// Present when the glyph is a vector glyph.
    public var outline: GlyphOutline?
}

extension GlyphBitmap {
    /// Copies the slot's `FT_Bitmap`, honoring `pitch` (which may be negative or padded).
    init?(slot: FT_GlyphSlot) {
        let bitmap = slot.pointee.bitmap
        let width = Int(bitmap.width)
        let rows = Int(bitmap.rows)
        let pitch = Int(bitmap.pitch)

        let mode: PixelMode
        let bytesPerRow: Int
        switch Int32(bitmap.pixel_mode) {
        case 1: (mode, bytesPerRow) = (.mono, (width + 7) / 8)
        case 2: (mode, bytesPerRow) = (.gray, width)
        case 5: (mode, bytesPerRow) = (.lcd, width)
        case 6: (mode, bytesPerRow) = (.lcdVertical, width)
        case 7: (mode, bytesPerRow) = (.bgra, width * 4)
        default: return nil
        }

        var pixels = [UInt8](repeating: 0, count: bytesPerRow * rows)
        if let buffer = bitmap.buffer, bytesPerRow > 0, rows > 0 {
            // `pitch` is the signed offset from one row to the next below it, so the
            // first row is always at `buffer`, even for bottom-up bitmaps.
            let rowLength = min(bytesPerRow, abs(pitch))
            for row in 0..<rows {
                let source = buffer + row * pitch
                for byte in 0..<rowLength {
                    pixels[row * bytesPerRow + byte] = source[byte]
                }
            }
        }

        self.init(
            width: width,
            rows: rows,
            pixelMode: mode,
            bytesPerRow: bytesPerRow,
            pixels: pixels,
            left: Int(slot.pointee.bitmap_left),
            top: Int(slot.pointee.bitmap_top)
        )
    }
}

extension GlyphMetrics {
    init(_ metrics: FT_Glyph_Metrics, divisor: Double) {
        self.init(
            width: Double(metrics.width) / divisor,
            height: Double(metrics.height) / divisor,
            horizontalBearingX: Double(metrics.horiBearingX) / divisor,
            horizontalBearingY: Double(metrics.horiBearingY) / divisor,
            horizontalAdvance: Double(metrics.horiAdvance) / divisor,
            verticalBearingX: Double(metrics.vertBearingX) / divisor,
            verticalBearingY: Double(metrics.vertBearingY) / divisor,
            verticalAdvance: Double(metrics.vertAdvance) / divisor
        )
    }
}
