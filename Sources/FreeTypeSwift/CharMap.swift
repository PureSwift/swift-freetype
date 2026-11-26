import CFreeType

/// A character map (`FT_CharMap`) of a face.
public struct CharMap: Hashable, Sendable {
    /// A character encoding, mirroring `FT_Encoding`.
    ///
    /// FreeType encodings are four-character tags, so unlisted values stay representable
    /// through `init(rawValue:)`.
    public struct Encoding: RawRepresentable, Hashable, Sendable {
        public var rawValue: UInt32

        public init(rawValue: UInt32) {
            self.rawValue = rawValue
        }

        /// Builds the big-endian tag FreeType uses (`FT_ENC_TAG`) from four ASCII characters.
        init(tag: StaticString) {
            precondition(tag.utf8CodeUnitCount == 4)
            self.rawValue = tag.withUTF8Buffer { $0.reduce(0) { $0 << 8 | UInt32($1) } }
        }

        public static var none: Encoding { Encoding(rawValue: 0) }
        public static var unicode: Encoding { Encoding(tag: "unic") }
        public static var symbol: Encoding { Encoding(tag: "symb") }
        public static var appleRoman: Encoding { Encoding(tag: "armn") }
        public static var adobeStandard: Encoding { Encoding(tag: "ADOB") }
        public static var adobeExpert: Encoding { Encoding(tag: "ADBE") }
        public static var adobeCustom: Encoding { Encoding(tag: "ADBC") }
        public static var adobeLatin1: Encoding { Encoding(tag: "lat1") }
        public static var oldLatin2: Encoding { Encoding(tag: "lat2") }
        public static var sjis: Encoding { Encoding(tag: "sjis") }
        public static var prc: Encoding { Encoding(tag: "gb  ") }
        public static var big5: Encoding { Encoding(tag: "big5") }
        public static var wansung: Encoding { Encoding(tag: "wans") }
        public static var johab: Encoding { Encoding(tag: "joha") }
    }

    /// Position in ``FreeTypeFace/charMaps``.
    public var index: Int
    public var encoding: Encoding
    /// The OpenType/TrueType platform and encoding IDs (for example 3 and 10 for Windows UCS-4).
    public var platformID: UInt16
    public var encodingID: UInt16
}

/// One entry of a character map.
public struct MappedCharacter: Hashable, Sendable {
    /// The character code in the selected encoding.
    public var code: UInt32
    public var glyphIndex: UInt32

    /// The code as a Unicode scalar, meaningful when a Unicode character map is selected.
    public var scalar: Unicode.Scalar? { Unicode.Scalar(code) }
}

extension FreeTypeFace {
    /// All character maps in the face.
    public var charMaps: [CharMap] {
        library.withLock {
            guard let maps = face.pointee.charmaps else { return [] }
            return (0..<Int(face.pointee.num_charmaps)).compactMap { index in
                maps[index].map { CharMap($0, index: index) }
            }
        }
    }

    /// The character map currently used by ``glyphIndex(for:)``, if any.
    public var selectedCharMap: CharMap? {
        library.withLock {
            guard let map = face.pointee.charmap else { return nil }
            return CharMap(map, index: Int(FT_Get_Charmap_Index(map)))
        }
    }

    /// Selects the character map for an encoding. FreeType prefers the best Unicode map when
    /// asking for ``CharMap/Encoding/unicode``. Throws ``FreeTypeError/invalidArgument`` if the
    /// face has no such map.
    public mutating func selectCharMap(_ encoding: CharMap.Encoding) throws {
        try library.withLock {
            try ftTry(FT_Select_Charmap(face, FT_Encoding(rawValue: encoding.rawValue)))
        }
    }

    /// Selects a specific character map by its index in ``charMaps``.
    public mutating func selectCharMap(at index: Int) throws {
        try library.withLock {
            guard let maps = face.pointee.charmaps, index >= 0, index < Int(face.pointee.num_charmaps),
                  let map = maps[index]
            else {
                throw FreeTypeError(.invalidArgument)
            }
            try ftTry(FT_Set_Charmap(face, map))
        }
    }

    /// Every character the selected character map covers, with its glyph, in ascending code order.
    public func mappedCharacters() -> [MappedCharacter] {
        library.withLock {
            var result: [MappedCharacter] = []
            var glyph: FT_UInt = 0
            var code = FT_Get_First_Char(face, &glyph)
            while glyph != 0 {
                result.append(MappedCharacter(code: UInt32(truncatingIfNeeded: code), glyphIndex: glyph))
                code = FT_Get_Next_Char(face, code, &glyph)
            }
            return result
        }
    }
}

extension CharMap {
    init(_ map: FT_CharMap, index: Int) {
        self.init(
            index: index,
            encoding: Encoding(rawValue: map.pointee.encoding.rawValue),
            platformID: map.pointee.platform_id,
            encodingID: map.pointee.encoding_id
        )
    }
}
