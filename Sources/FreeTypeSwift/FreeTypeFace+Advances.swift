import CFreeType

extension FreeTypeFace {
    /// The horizontal advance of a glyph without copying the glyph out of the slot.
    ///
    /// This wraps `FT_Get_Advance`, which is much cheaper than ``glyph(at:flags:render:)`` for
    /// text measurement. With the default ``LoadFlags/noHinting`` it is a fast path that returns
    /// the unrounded advance; hinting flags make FreeType load and grid-fit the glyph first.
    ///
    /// - Returns: The advance in pixels (font units with ``LoadFlags/noScale``), or the
    ///   vertical advance with ``LoadFlags/verticalLayout``.
    public func advance(of glyphIndex: UInt32, flags: LoadFlags = .noHinting) throws -> Double {
        var raw: FT_Fixed = 0
        try library.withLock {
            try ftTry(FT_Get_Advance(face, glyphIndex, flags.rawValue, &raw))
        }
        return Double(raw) / Self.advanceDivisor(flags)
    }

    /// The advances of several glyphs, in the same order and units as ``advance(of:flags:)``.
    /// The library lock is taken once for the whole batch.
    public func advances(of glyphIndices: [UInt32], flags: LoadFlags = .noHinting) throws -> [Double] {
        var raw = [FT_Fixed](repeating: 0, count: glyphIndices.count)
        try library.withLock {
            for (offset, glyphIndex) in glyphIndices.enumerated() {
                try ftTry(FT_Get_Advance(face, glyphIndex, flags.rawValue, &raw[offset]))
            }
        }
        let divisor = Self.advanceDivisor(flags)
        return raw.map { Double($0) / divisor }
    }

    /// `FT_Get_Advance` returns 16.16 fixed point when scaling, and plain font units otherwise.
    private static func advanceDivisor(_ flags: LoadFlags) -> Double {
        flags.contains(.noScale) ? 1 : 65536
    }
}
