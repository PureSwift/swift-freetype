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

## Notes

- Every FreeType call is serialized through the owning library's lock, so a library and its faces can be shared across threads.
- In-memory fonts are copied and owned by the face, since FreeType reads from the buffer until the face is released.
- FreeType only reads the legacy `kern` table. For GPOS kerning, ligatures, or complex scripts, use a shaper such as HarfBuzz.
- Tests bundle Inter (SIL OFL 1.1; see `Tests/FreeTypeSwiftTests/Resources/Inter-OFL.txt`).
- Run `swift test --sanitize=address` to check for memory errors.
