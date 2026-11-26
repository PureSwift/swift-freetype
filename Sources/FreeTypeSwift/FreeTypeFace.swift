import CFreeType
import Foundation

/// An owned `FT_Face`.
///
/// The face retains its ``FreeTypeLibrary`` and serializes every FreeType call through the
/// library's lock. Glyph data is copied out of the shared glyph slot before the lock is
/// released, so the returned values stay valid across later loads.
public final class FreeTypeFace: @unchecked Sendable {
    // Face flag bits (`FT_FACE_FLAG_*`). These are macros with shifts, which Swift doesn't import.
    private enum Flag {
        static let scalable: Int = 1 << 0
        static let fixedWidth: Int = 1 << 2
        static let kerning: Int = 1 << 6
        static let multipleMasters: Int = 1 << 8
        static let glyphNames: Int = 1 << 9
        static let color: Int = 1 << 14
        static let variation: Int = 1 << 15
    }

    public let library: FreeTypeLibrary
    private let face: FT_Face
    /// `FT_New_Memory_Face` faces read directly from this buffer until `FT_Done_Face`, so the
    /// face owns a private copy rather than relying on a `Data` buffer's storage staying put.
    private let fontBytes: UnsafeMutableRawBufferPointer?

    public convenience init(library: FreeTypeLibrary, path: String, index: Int = 0) throws {
        var face: FT_Face?
        try library.withLock {
            try ftTry(FT_New_Face(library.handle, path, FT_Long(index), &face))
        }
        try self.init(library: library, face: face, fontBytes: nil)
    }

    public convenience init(library: FreeTypeLibrary, data: Data, index: Int = 0) throws {
        let bytes = UnsafeMutableRawBufferPointer.allocate(
            byteCount: max(data.count, 1),
            alignment: MemoryLayout<UInt64>.alignment
        )
        data.copyBytes(to: bytes.bindMemory(to: UInt8.self), count: data.count)

        var face: FT_Face?
        let error = library.withLock {
            FT_New_Memory_Face(
                library.handle,
                bytes.baseAddress?.assumingMemoryBound(to: FT_Byte.self),
                FT_Long(data.count),
                FT_Long(index),
                &face
            )
        }
        guard error == 0 else {
            bytes.deallocate()
            throw FreeTypeError(code: error)
        }
        try self.init(library: library, face: face, fontBytes: bytes)
    }

    private init(library: FreeTypeLibrary, face: FT_Face?, fontBytes: UnsafeMutableRawBufferPointer?) throws {
        guard let face else {
            fontBytes?.deallocate()
            throw FreeTypeError(code: 1)
        }
        self.library = library
        self.face = face
        self.fontBytes = fontBytes
    }

    deinit {
        library.withLock {
            _ = FT_Done_Face(face)
        }
        // Only after FT_Done_Face: FreeType may read this buffer until then.
        fontBytes?.deallocate()
    }

    // MARK: - Metadata

    private var flags: Int { Int(face.pointee.face_flags) }

    public var familyName: String {
        face.pointee.family_name.map { String(cString: $0) } ?? ""
    }

    public var styleName: String {
        face.pointee.style_name.map { String(cString: $0) } ?? ""
    }

    public var faceCount: Int { Int(face.pointee.num_faces) }
    public var glyphCount: Int { Int(face.pointee.num_glyphs) }
    public var unitsPerEM: UInt16 { face.pointee.units_per_EM }

    public var isScalable: Bool { flags & Flag.scalable != 0 }
    public var isFixedWidth: Bool { flags & Flag.fixedWidth != 0 }
    public var hasKerning: Bool { flags & Flag.kerning != 0 }
    public var hasColor: Bool { flags & Flag.color != 0 }
    public var hasGlyphNames: Bool { flags & Flag.glyphNames != 0 }
    /// Whether the font has variation axes (OpenType variable fonts and MM/GX fonts).
    public var isVariable: Bool { flags & Flag.multipleMasters != 0 }
    /// Whether the variation coordinates have been changed from the defaults
    /// (`FT_FACE_FLAG_VARIATION`).
    public var hasCustomVariation: Bool { flags & Flag.variation != 0 }

    /// Ascender in font units, independent of the current size.
    public var designAscender: Int { Int(face.pointee.ascender) }
    /// Descender in font units (negative below the baseline).
    public var designDescender: Int { Int(face.pointee.descender) }
    /// Recommended baseline-to-baseline distance in font units.
    public var designLineHeight: Int { Int(face.pointee.height) }

    // MARK: - Sizing and scaled metrics

    /// Sets the size from a point size and resolution. FreeType takes the size in 26.6 points.
    public func setCharSize(
        pointSize: Double,
        horizontalDPI: UInt32 = 72,
        verticalDPI: UInt32 = 72
    ) throws {
        let size = FT_F26Dot6((pointSize * 64).rounded())
        try library.withLock {
            try ftTry(FT_Set_Char_Size(face, size, size, horizontalDPI, verticalDPI))
        }
    }

    /// Sets an exact pixel size.
    public func setPixelSize(width: UInt32, height: UInt32) throws {
        try library.withLock {
            try ftTry(FT_Set_Pixel_Sizes(face, width, height))
        }
    }

    /// Scaled metrics for the current size, in pixels. All zero until a size is set.
    public var ascender: Double { scaledMetric(\.ascender) }
    public var descender: Double { scaledMetric(\.descender) }
    public var lineHeight: Double { scaledMetric(\.height) }
    public var maxAdvance: Double { scaledMetric(\.max_advance) }

    private func scaledMetric(_ keyPath: KeyPath<FT_Size_Metrics, FT_Pos>) -> Double {
        library.withLock {
            guard let size = face.pointee.size else { return 0 }
            return Double(size.pointee.metrics[keyPath: keyPath]) / 64
        }
    }

    // MARK: - Character map

    /// Maps a Unicode scalar to a glyph index; `0` means the glyph is missing.
    public func glyphIndex(for scalar: Unicode.Scalar) -> UInt32 {
        library.withLock {
            FT_Get_Char_Index(face, FT_ULong(scalar.value))
        }
    }

    // MARK: - Glyphs

    /// Loads a glyph and copies it out of the glyph slot.
    ///
    /// - Parameters:
    ///   - render: Rasterizes vector glyphs in this mode. When `nil`, vector glyphs are only
    ///     rasterized if `flags` contains ``LoadFlags/render``, in normal mode.
    public func glyph(
        at index: UInt32,
        flags: LoadFlags = .default,
        render: RenderMode? = nil
    ) throws -> Glyph {
        let renderMode = render ?? (flags.contains(.render) ? .normal : nil)
        // Rendering is done explicitly below, after the outline has been captured.
        let loadFlags = flags.subtracting(.render)
        let divisor: Double = flags.contains(.noScale) ? 1 : 64

        return try library.withLock {
            try ftTry(FT_Load_Glyph(face, index, loadFlags.rawValue))
            guard let slot = face.pointee.glyph else {
                throw FreeTypeError(code: 1)
            }

            var outline: GlyphOutline?
            if slot.pointee.format == FT_GLYPH_FORMAT_OUTLINE {
                outline = try OutlineBuilder.decompose(&slot.pointee.outline, divisor: divisor)
                if let renderMode {
                    try ftTry(FT_Render_Glyph(slot, renderMode.raw))
                }
            }

            let bitmap = slot.pointee.format == FT_GLYPH_FORMAT_BITMAP ? GlyphBitmap(slot: slot) : nil

            return Glyph(
                index: index,
                metrics: GlyphMetrics(slot.pointee.metrics, divisor: divisor),
                advanceX: Double(slot.pointee.advance.x) / divisor,
                advanceY: Double(slot.pointee.advance.y) / divisor,
                linearHorizontalAdvance: Double(slot.pointee.linearHoriAdvance) / 65536,
                bitmap: bitmap,
                outline: outline
            )
        }
    }

    /// Convenience for loading the glyph for a Unicode scalar.
    public func glyph(
        for scalar: Unicode.Scalar,
        flags: LoadFlags = .default,
        render: RenderMode? = nil
    ) throws -> Glyph {
        try glyph(at: glyphIndex(for: scalar), flags: flags, render: render)
    }

    // MARK: - Kerning

    /// Kerning between two glyphs, in pixels (font units for ``KerningMode/unscaled``).
    /// This only reads the legacy `kern` table; use a shaper for GPOS kerning.
    public func kerning(
        leftGlyph: UInt32,
        rightGlyph: UInt32,
        mode: KerningMode = .default
    ) throws -> Double {
        var delta = FT_Vector()
        try library.withLock {
            try ftTry(FT_Get_Kerning(face, leftGlyph, rightGlyph, mode.rawValue, &delta))
        }
        return Double(delta.x) / (mode == .unscaled ? 1 : 64)
    }

    // MARK: - Variable fonts

    /// The design axes of a variable font, or an empty array for other fonts.
    public var variationAxes: [VariationAxis] {
        library.withLock {
            var variations: UnsafeMutablePointer<FT_MM_Var>?
            guard FT_Get_MM_Var(face, &variations) == 0, let variations else { return [] }
            defer { FT_Done_MM_Var(library.handle, variations) }

            return (0..<Int(variations.pointee.num_axis)).map { index in
                let axis = variations.pointee.axis[index]
                return VariationAxis(
                    tag: VariationAxis.string(fromTag: UInt32(truncatingIfNeeded: axis.tag)),
                    name: axis.name.map { String(cString: $0) } ?? "",
                    minimum: Double(axis.minimum) / 65536,
                    defaultValue: Double(axis.def) / 65536,
                    maximum: Double(axis.maximum) / 65536
                )
            }
        }
    }

    /// Sets variable font axes by tag (e.g. `["wght": 700]`). Axes not mentioned keep their
    /// current value, and values are clamped by FreeType to each axis range.
    public func setVariation(_ values: [String: Double]) throws {
        let axes = variationAxes
        guard !axes.isEmpty else {
            throw FreeTypeError(code: 6) // Invalid_Argument
        }
        try library.withLock {
            var coordinates = [FT_Fixed](repeating: 0, count: axes.count)
            try ftTry(FT_Get_Var_Design_Coordinates(face, FT_UInt(axes.count), &coordinates))
            for (index, axis) in axes.enumerated() {
                if let value = values[axis.tag] {
                    coordinates[index] = FT_Fixed((value * 65536).rounded())
                }
            }
            try ftTry(FT_Set_Var_Design_Coordinates(face, FT_UInt(axes.count), &coordinates))
        }
    }
}

/// An axis of a variable font.
public struct VariationAxis: Hashable, Sendable {
    /// Four-character OpenType tag such as `wght`, `wdth`, `slnt`.
    public var tag: String
    public var name: String
    public var minimum: Double
    public var defaultValue: Double
    public var maximum: Double

    static func string(fromTag tag: UInt32) -> String {
        let bytes = [24, 16, 8, 0].map { UInt8(truncatingIfNeeded: tag >> $0) }
        return String(decoding: bytes, as: UTF8.self)
    }
}
