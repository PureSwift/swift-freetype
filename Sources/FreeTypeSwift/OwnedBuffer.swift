import Foundation

/// A uniquely owned, heap-allocated copy of some bytes, freed when it goes out of scope.
///
/// `FT_New_Memory_Face` reads from its buffer until `FT_Done_Face`, so a face keeps one of
/// these as a stored property: properties are destroyed after the face's `deinit` body
/// runs, which guarantees the bytes outlive `FT_Done_Face`.
struct OwnedBuffer: ~Copyable {
    let count: Int
    private let storage: UnsafeMutableRawPointer

    init(copying data: Data) {
        count = data.count
        // Allocate at least one byte so `baseAddress` is never null, even for empty data.
        storage = .allocate(byteCount: max(data.count, 1), alignment: MemoryLayout<UInt64>.alignment)
        data.copyBytes(to: storage.assumingMemoryBound(to: UInt8.self), count: data.count)
    }

    var baseAddress: UnsafePointer<UInt8> {
        UnsafePointer(storage.assumingMemoryBound(to: UInt8.self))
    }

    deinit {
        storage.deallocate()
    }
}
