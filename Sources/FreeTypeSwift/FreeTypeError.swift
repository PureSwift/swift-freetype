import CFreeType
import Foundation

/// An error reported by FreeType, wrapping a raw `FT_Error` code.
public struct FreeTypeError: Error, LocalizedError, Hashable, Sendable {
    public let code: Int32

    public init(code: Int32) {
        self.code = code
    }

    /// The FreeType message for this code.
    ///
    /// `FT_Error_String` returns `NULL` unless FreeType was built with
    /// `FT_CONFIG_OPTION_ERROR_STRINGS`, so a generic message is used as a fallback.
    public var message: String {
        if let cString = FT_Error_String(code) {
            return String(cString: cString)
        }
        return "FreeType error \(code)"
    }

    public var errorDescription: String? { message }
}

/// Throws a ``FreeTypeError`` when `code` is non-zero.
@inline(__always)
func ftTry(_ code: FT_Error) throws {
    guard code == 0 else {
        throw FreeTypeError(code: code)
    }
}
