import CFreeType
import Foundation

/// An owned `FT_Library` instance.
///
/// `FT_Library` holds allocator state and is not thread-safe, and every `FT_Face` created
/// from it shares that state. All access is therefore serialized through ``withLock(_:)``,
/// and each ``FreeTypeFace`` retains its library so `FT_Done_Face` always runs before
/// `FT_Done_FreeType`.
public final class FreeTypeLibrary: @unchecked Sendable {
    let handle: FT_Library
    private let lock = NSLock()

    public init() throws {
        var library: FT_Library?
        try ftTry(FT_Init_FreeType(&library))
        guard let library else {
            throw FreeTypeError(code: 1)
        }
        self.handle = library
    }

    deinit {
        FT_Done_FreeType(handle)
    }

    /// The FreeType version this package is linked against.
    public var version: (major: Int, minor: Int, patch: Int) {
        var major: FT_Int = 0
        var minor: FT_Int = 0
        var patch: FT_Int = 0
        lock.withLock {
            FT_Library_Version(handle, &major, &minor, &patch)
        }
        return (Int(major), Int(minor), Int(patch))
    }

    /// Runs `body` while holding the library lock. The lock is not recursive.
    func withLock<T>(_ body: () throws -> T) rethrows -> T {
        try lock.withLock(body)
    }

    /// Opens a face from a font file.
    public func face(path: String, index: Int = 0) throws -> FreeTypeFace {
        try FreeTypeFace(library: self, path: path, index: index)
    }

    /// Opens a face from in-memory font data. The bytes are copied and owned by the face.
    public func face(data: Data, index: Int = 0) throws -> FreeTypeFace {
        try FreeTypeFace(library: self, data: data, index: index)
    }
}
