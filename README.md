# swift-freetype

Swift wrapper for FreeType, split into two targets:

- `CFreeType`: system library target exposing the FreeType headers (via `pkg-config` `freetype2`).
- `FreeTypeSwift`: memory-safe wrappers for `FT_Library` and `FT_Face`, with errors mapped to Swift `Error`s.

## Requirements

FreeType must be installed: `brew install freetype` on macOS, `apt install libfreetype6-dev` on Linux.

## Usage

```swift
import FreeTypeSwift

let library = try FreeTypeLibrary()
let face = try library.face(path: "/path/to/font.ttf")
try face.setPixelSize(width: 0, height: 48)

let glyph = try face.glyph(for: "A", flags: .render)
glyph.bitmap?.pixels      // top-to-bottom, tightly packed
glyph.outline?.elements   // move/line/quad/cubic/close; `.cgPath` on Apple platforms

try face.setVariation(["wght": 700])   // variable fonts
```

Metrics and outline coordinates are in pixels, or font units when `.noScale` is used.

Bitmap fonts (e.g. color emoji) need a strike selected instead of a size:

```swift
try face.selectBitmapStrike(at: 0)   // see face.bitmapStrikes
let emoji = try face.glyph(for: "😀", flags: .color)   // bitmap.pixelMode == .bgra
```

## Text measurement and fonts

```swift
// Advances without loading glyphs (unrounded, pixels at the current size)
let widths = try face.advances(of: "Hello".unicodeScalars.map { face.glyphIndex(for: $0) })

// Character maps
face.charMaps                         // [CharMap], with encodings and platform IDs
try face.selectCharMap(.unicode)
face.mappedCharacters()               // every (code, glyph) pair the selected map covers

// Glyph names
face.glyphName(for: face.glyphIndex(for: "A"))   // "A"
face.glyphIndex(named: "space")

// SFNT name table
face.sfntName(.license)               // best match, English Windows names first
face.sfntNames                        // every record, with platform and language IDs
face.postScriptName

// Outline bounds (tight box, and the cheaper control-point box)
try face.glyph(for: "O", flags: .noHinting).outline?.boundingBox

// Variable font named instances
if let bold = face.namedInstances.first(where: { $0.name == "Bold" }) {
    try face.selectNamedInstance(bold)
}
face.variationCoordinates             // ["wght": 700, ...]
try face.resetVariation()
```

## Errors

FreeType failures are thrown as `FreeTypeError` and can be matched by code, like `POSIXError`:

```swift
do {
    let face = try library.face(path: path)
} catch FreeTypeError.cannotOpenResource {
    // file missing or unreadable
} catch FreeTypeError.unknownFileFormat, FreeTypeError.invalidFileFormat {
    // not a usable font
}
```

General-purpose codes are named; any other code is available as `FreeTypeError.Code(rawValue:)`. `message` uses `FT_Error_String`, which is empty unless FreeType was built with error strings (Homebrew's build isn't), in which case it falls back to "FreeType error N".

## Notes

- `FreeTypeFace` is a noncopyable (`~Copyable`) struct: it has a single owner, `FT_Done_Face` runs once, and methods that change size or variation state are `mutating`. To share a face across threads, protect it with a lock.
- Every FreeType call is serialized through the owning library's lock, so one library can safely back faces used on different threads. `FreeTypeLibrary` is a shared, reference-counted class.
- In-memory fonts are copied into a noncopyable `OwnedBuffer` stored in the face, which guarantees the bytes outlive `FT_Done_Face`.
- FreeType only reads the legacy `kern` table. For GPOS kerning, ligatures, or complex scripts, use a shaper such as HarfBuzz.
- Tests bundle Inter (SIL OFL 1.1; see `Tests/FreeTypeSwiftTests/Resources/Inter-OFL.txt`).
- Run `swift test --sanitize=address` to check for memory errors.
