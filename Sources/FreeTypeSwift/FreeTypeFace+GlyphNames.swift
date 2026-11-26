import CFreeType

extension FreeTypeFace {
    /// The PostScript name of a glyph, such as `"A"` or `"space"`.
    ///
    /// Returns `nil` when the font has no glyph names (see ``hasGlyphNames``), when the index is
    /// out of range, or when the glyph is unnamed.
    public func glyphName(for glyphIndex: UInt32) -> String? {
        // Glyph names are at most 255 bytes in the `post` table; leave room for the terminator.
        var buffer = [CChar](repeating: 0, count: 256)
        let error = library.withLock {
            FT_Get_Glyph_Name(face, glyphIndex, &buffer, FT_UInt(buffer.count))
        }
        guard error == 0 else { return nil }
        let bytes = buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
        return bytes.isEmpty ? nil : String(decoding: bytes, as: UTF8.self)
    }

    /// The glyph index for a PostScript glyph name; `0` means no glyph has that name, matching
    /// ``glyphIndex(for:)``. Always `0` for fonts without glyph names.
    public func glyphIndex(named name: String) -> UInt32 {
        library.withLock {
            FT_Get_Name_Index(face, name)
        }
    }
}
