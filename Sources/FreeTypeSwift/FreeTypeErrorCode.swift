extension FreeTypeError {
    /// A FreeType error code, e.g. `FT_Err_Unknown_File_Format`.
    ///
    /// Codes are matched like `POSIXError`:
    ///
    /// ```swift
    /// do {
    ///     _ = try library.face(path: path)
    /// } catch FreeTypeError.unknownFileFormat {
    ///     // not a font
    /// }
    /// ```
    ///
    /// Only the general-purpose codes are named. Driver-specific codes (for example the
    /// TrueType bytecode errors starting at `0x80`) can be matched with `Code(rawValue:)`.
    public struct Code: RawRepresentable, Hashable, Sendable {
        public var rawValue: Int32

        public init(rawValue: Int32) {
            self.rawValue = rawValue
        }

        /// `FT_Err_Cannot_Open_Resource`
        public static var cannotOpenResource: Code { Code(rawValue: 0x01) }

        /// `FT_Err_Unknown_File_Format`
        public static var unknownFileFormat: Code { Code(rawValue: 0x02) }

        /// `FT_Err_Invalid_File_Format`
        public static var invalidFileFormat: Code { Code(rawValue: 0x03) }

        /// `FT_Err_Invalid_Version`
        public static var invalidVersion: Code { Code(rawValue: 0x04) }

        /// `FT_Err_Lower_Module_Version`
        public static var lowerModuleVersion: Code { Code(rawValue: 0x05) }

        /// `FT_Err_Invalid_Argument`
        public static var invalidArgument: Code { Code(rawValue: 0x06) }

        /// `FT_Err_Unimplemented_Feature`
        public static var unimplementedFeature: Code { Code(rawValue: 0x07) }

        /// `FT_Err_Invalid_Table`
        public static var invalidTable: Code { Code(rawValue: 0x08) }

        /// `FT_Err_Invalid_Offset`
        public static var invalidOffset: Code { Code(rawValue: 0x09) }

        /// `FT_Err_Array_Too_Large`
        public static var arrayTooLarge: Code { Code(rawValue: 0x0A) }

        /// `FT_Err_Missing_Module`
        public static var missingModule: Code { Code(rawValue: 0x0B) }

        /// `FT_Err_Missing_Property`
        public static var missingProperty: Code { Code(rawValue: 0x0C) }

        /// `FT_Err_Invalid_Glyph_Index`
        public static var invalidGlyphIndex: Code { Code(rawValue: 0x10) }

        /// `FT_Err_Invalid_Character_Code`
        public static var invalidCharacterCode: Code { Code(rawValue: 0x11) }

        /// `FT_Err_Invalid_Glyph_Format`
        public static var invalidGlyphFormat: Code { Code(rawValue: 0x12) }

        /// `FT_Err_Cannot_Render_Glyph`
        public static var cannotRenderGlyph: Code { Code(rawValue: 0x13) }

        /// `FT_Err_Invalid_Outline`
        public static var invalidOutline: Code { Code(rawValue: 0x14) }

        /// `FT_Err_Invalid_Composite`
        public static var invalidComposite: Code { Code(rawValue: 0x15) }

        /// `FT_Err_Too_Many_Hints`
        public static var tooManyHints: Code { Code(rawValue: 0x16) }

        /// `FT_Err_Invalid_Pixel_Size`
        public static var invalidPixelSize: Code { Code(rawValue: 0x17) }

        /// `FT_Err_Invalid_SVG_Document`
        public static var invalidSVGDocument: Code { Code(rawValue: 0x18) }

        /// `FT_Err_Invalid_Handle`
        public static var invalidHandle: Code { Code(rawValue: 0x20) }

        /// `FT_Err_Invalid_Library_Handle`
        public static var invalidLibraryHandle: Code { Code(rawValue: 0x21) }

        /// `FT_Err_Invalid_Driver_Handle`
        public static var invalidDriverHandle: Code { Code(rawValue: 0x22) }

        /// `FT_Err_Invalid_Face_Handle`
        public static var invalidFaceHandle: Code { Code(rawValue: 0x23) }

        /// `FT_Err_Invalid_Size_Handle`
        public static var invalidSizeHandle: Code { Code(rawValue: 0x24) }

        /// `FT_Err_Invalid_Slot_Handle`
        public static var invalidSlotHandle: Code { Code(rawValue: 0x25) }

        /// `FT_Err_Invalid_CharMap_Handle`
        public static var invalidCharMapHandle: Code { Code(rawValue: 0x26) }

        /// `FT_Err_Invalid_Cache_Handle`
        public static var invalidCacheHandle: Code { Code(rawValue: 0x27) }

        /// `FT_Err_Invalid_Stream_Handle`
        public static var invalidStreamHandle: Code { Code(rawValue: 0x28) }

        /// `FT_Err_Too_Many_Drivers`
        public static var tooManyDrivers: Code { Code(rawValue: 0x30) }

        /// `FT_Err_Too_Many_Extensions`
        public static var tooManyExtensions: Code { Code(rawValue: 0x31) }

        /// `FT_Err_Out_Of_Memory`
        public static var outOfMemory: Code { Code(rawValue: 0x40) }

        /// `FT_Err_Unlisted_Object`
        public static var unlistedObject: Code { Code(rawValue: 0x41) }

        /// `FT_Err_Cannot_Open_Stream`
        public static var cannotOpenStream: Code { Code(rawValue: 0x51) }

        /// `FT_Err_Invalid_Stream_Seek`
        public static var invalidStreamSeek: Code { Code(rawValue: 0x52) }

        /// `FT_Err_Invalid_Stream_Skip`
        public static var invalidStreamSkip: Code { Code(rawValue: 0x53) }

        /// `FT_Err_Invalid_Stream_Read`
        public static var invalidStreamRead: Code { Code(rawValue: 0x54) }

        /// `FT_Err_Invalid_Stream_Operation`
        public static var invalidStreamOperation: Code { Code(rawValue: 0x55) }

        /// `FT_Err_Invalid_Frame_Operation`
        public static var invalidFrameOperation: Code { Code(rawValue: 0x56) }

        /// `FT_Err_Nested_Frame_Access`
        public static var nestedFrameAccess: Code { Code(rawValue: 0x57) }

        /// `FT_Err_Invalid_Frame_Read`
        public static var invalidFrameRead: Code { Code(rawValue: 0x58) }

        /// `FT_Err_Raster_Uninitialized`
        public static var rasterUninitialized: Code { Code(rawValue: 0x60) }

        /// `FT_Err_Raster_Corrupted`
        public static var rasterCorrupted: Code { Code(rawValue: 0x61) }

        /// `FT_Err_Raster_Overflow`
        public static var rasterOverflow: Code { Code(rawValue: 0x62) }

        /// `FT_Err_Raster_Negative_Height`
        public static var rasterNegativeHeight: Code { Code(rawValue: 0x63) }

        /// `FT_Err_Too_Many_Caches`
        public static var tooManyCaches: Code { Code(rawValue: 0x70) }

    }
}

// Forwarding members so the codes read as `FreeTypeError.unknownFileFormat`, like `POSIXError.ENOENT`.
extension FreeTypeError {
    public static var cannotOpenResource: Code { .cannotOpenResource }
    public static var unknownFileFormat: Code { .unknownFileFormat }
    public static var invalidFileFormat: Code { .invalidFileFormat }
    public static var invalidVersion: Code { .invalidVersion }
    public static var lowerModuleVersion: Code { .lowerModuleVersion }
    public static var invalidArgument: Code { .invalidArgument }
    public static var unimplementedFeature: Code { .unimplementedFeature }
    public static var invalidTable: Code { .invalidTable }
    public static var invalidOffset: Code { .invalidOffset }
    public static var arrayTooLarge: Code { .arrayTooLarge }
    public static var missingModule: Code { .missingModule }
    public static var missingProperty: Code { .missingProperty }
    public static var invalidGlyphIndex: Code { .invalidGlyphIndex }
    public static var invalidCharacterCode: Code { .invalidCharacterCode }
    public static var invalidGlyphFormat: Code { .invalidGlyphFormat }
    public static var cannotRenderGlyph: Code { .cannotRenderGlyph }
    public static var invalidOutline: Code { .invalidOutline }
    public static var invalidComposite: Code { .invalidComposite }
    public static var tooManyHints: Code { .tooManyHints }
    public static var invalidPixelSize: Code { .invalidPixelSize }
    public static var invalidSVGDocument: Code { .invalidSVGDocument }
    public static var invalidHandle: Code { .invalidHandle }
    public static var invalidLibraryHandle: Code { .invalidLibraryHandle }
    public static var invalidDriverHandle: Code { .invalidDriverHandle }
    public static var invalidFaceHandle: Code { .invalidFaceHandle }
    public static var invalidSizeHandle: Code { .invalidSizeHandle }
    public static var invalidSlotHandle: Code { .invalidSlotHandle }
    public static var invalidCharMapHandle: Code { .invalidCharMapHandle }
    public static var invalidCacheHandle: Code { .invalidCacheHandle }
    public static var invalidStreamHandle: Code { .invalidStreamHandle }
    public static var tooManyDrivers: Code { .tooManyDrivers }
    public static var tooManyExtensions: Code { .tooManyExtensions }
    public static var outOfMemory: Code { .outOfMemory }
    public static var unlistedObject: Code { .unlistedObject }
    public static var cannotOpenStream: Code { .cannotOpenStream }
    public static var invalidStreamSeek: Code { .invalidStreamSeek }
    public static var invalidStreamSkip: Code { .invalidStreamSkip }
    public static var invalidStreamRead: Code { .invalidStreamRead }
    public static var invalidStreamOperation: Code { .invalidStreamOperation }
    public static var invalidFrameOperation: Code { .invalidFrameOperation }
    public static var nestedFrameAccess: Code { .nestedFrameAccess }
    public static var invalidFrameRead: Code { .invalidFrameRead }
    public static var rasterUninitialized: Code { .rasterUninitialized }
    public static var rasterCorrupted: Code { .rasterCorrupted }
    public static var rasterOverflow: Code { .rasterOverflow }
    public static var rasterNegativeHeight: Code { .rasterNegativeHeight }
    public static var tooManyCaches: Code { .tooManyCaches }
}

/// Enables `catch FreeTypeError.unknownFileFormat` and `case FreeTypeError.outOfMemory` patterns.
public func ~= (match: FreeTypeError.Code, error: any Error) -> Bool {
    (error as? FreeTypeError)?.code == match
}

public func ~= (match: FreeTypeError.Code, error: FreeTypeError) -> Bool {
    error.code == match
}
