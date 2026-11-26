import CFreeType
import Foundation

/// A record of the SFNT `name` table: a localized string such as the family name or license.
public struct SfntName: Hashable, Sendable {
    /// A name identifier (OpenType `nameID`). Unlisted IDs stay representable through
    /// `init(rawValue:)`; IDs 256 and above are font-specific, e.g. variation axis names.
    public struct ID: RawRepresentable, Hashable, Sendable {
        public var rawValue: UInt16

        public init(rawValue: UInt16) {
            self.rawValue = rawValue
        }

        public static var copyright: ID { ID(rawValue: 0) }
        public static var family: ID { ID(rawValue: 1) }
        public static var subfamily: ID { ID(rawValue: 2) }
        public static var uniqueIdentifier: ID { ID(rawValue: 3) }
        public static var fullName: ID { ID(rawValue: 4) }
        public static var version: ID { ID(rawValue: 5) }
        public static var postScriptName: ID { ID(rawValue: 6) }
        public static var trademark: ID { ID(rawValue: 7) }
        public static var manufacturer: ID { ID(rawValue: 8) }
        public static var designer: ID { ID(rawValue: 9) }
        public static var description: ID { ID(rawValue: 10) }
        public static var vendorURL: ID { ID(rawValue: 11) }
        public static var designerURL: ID { ID(rawValue: 12) }
        public static var license: ID { ID(rawValue: 13) }
        public static var licenseURL: ID { ID(rawValue: 14) }
        public static var typographicFamily: ID { ID(rawValue: 16) }
        public static var typographicSubfamily: ID { ID(rawValue: 17) }
        public static var compatibleFullName: ID { ID(rawValue: 18) }
        public static var sampleText: ID { ID(rawValue: 19) }
        public static var postScriptCIDFindfontName: ID { ID(rawValue: 20) }
        public static var wwsFamily: ID { ID(rawValue: 21) }
        public static var wwsSubfamily: ID { ID(rawValue: 22) }
        public static var lightBackgroundPalette: ID { ID(rawValue: 23) }
        public static var darkBackgroundPalette: ID { ID(rawValue: 24) }
        public static var variationsPostScriptNamePrefix: ID { ID(rawValue: 25) }
    }

    public var id: ID
    /// OpenType platform ID: 0 Unicode, 1 Macintosh, 3 Windows.
    public var platformID: UInt16
    public var encodingID: UInt16
    /// Platform-specific language ID. For Windows this is an LCID such as `0x409` (en-US);
    /// for Macintosh it is a Mac language code where `0` is English. IDs of `0x8000` and above
    /// refer to the table's language tags and are not resolved here.
    public var languageID: UInt16
    public var string: String

    /// Whether the record is in English, judged by the platform's language ID. Unicode-platform
    /// records carry no language, so they report `false`.
    public var isEnglish: Bool {
        switch platformID {
        case 3: languageID & 0x3FF == 0x09
        case 1: languageID == 0
        default: false
        }
    }
}

extension FreeTypeFace {
    /// Every decodable record of the SFNT `name` table; empty for non-SFNT fonts. Records using
    /// encodings that aren't Unicode or Mac Roman are skipped.
    public var sfntNames: [SfntName] {
        library.withLock {
            (0..<FT_Get_Sfnt_Name_Count(face)).compactMap { unlockedSfntRecord(at: $0) }
        }
    }

    /// The best string for a name ID, preferring English Windows names, then other Windows names,
    /// then Unicode-platform and Macintosh names. Use ``sfntNames`` to pick a specific language.
    public func sfntName(_ id: SfntName.ID) -> String? {
        library.withLock { unlockedSfntName(id: id.rawValue) }
    }

    /// The PostScript name of the face (`FT_Get_Postscript_Name`), which also works for fonts
    /// without an SFNT `name` table.
    public var postScriptName: String? {
        library.withLock {
            FT_Get_Postscript_Name(face).map { String(cString: $0) }
        }
    }

    /// Looks up the preferred string for a name ID. The caller must hold the library lock.
    func unlockedSfntName(id: UInt16) -> String? {
        var best: (rank: Int, string: String)?
        for index in 0..<FT_Get_Sfnt_Name_Count(face) {
            guard let record = unlockedSfntRecord(at: index), record.id.rawValue == id else { continue }
            let rank = Self.rank(of: record)
            if rank < (best?.rank ?? .max) {
                best = (rank, record.string)
            }
        }
        return best?.string
    }

    /// Lower is better.
    private static func rank(of record: SfntName) -> Int {
        switch record.platformID {
        case 3: record.languageID == 0x409 ? 0 : (record.isEnglish ? 1 : 2)
        case 0: 3
        default: record.isEnglish ? 4 : 5
        }
    }

    private func unlockedSfntRecord(at index: UInt32) -> SfntName? {
        var name = FT_SfntName()
        guard FT_Get_Sfnt_Name(face, index, &name) == 0, let pointer = name.string else { return nil }
        let bytes = Array(UnsafeBufferPointer(start: pointer, count: Int(name.string_len)))

        let string: String?
        switch (name.platform_id, name.encoding_id) {
        case (3, _), (0, _): // Windows and Unicode platforms are UTF-16BE
            string = Self.decodeUTF16BE(bytes)
        case (1, 0): // Macintosh Roman
            string = String(bytes: bytes, encoding: .macOSRoman)
        default:
            string = nil
        }
        return string.map {
            SfntName(
                id: SfntName.ID(rawValue: name.name_id),
                platformID: name.platform_id,
                encodingID: name.encoding_id,
                languageID: name.language_id,
                string: $0
            )
        }
    }

    private static func decodeUTF16BE(_ bytes: [UInt8]) -> String {
        let units = stride(from: 0, to: bytes.count - 1, by: 2).map {
            UInt16(bytes[$0]) << 8 | UInt16(bytes[$0 + 1])
        }
        return String(decoding: units, as: UTF16.self)
    }
}
