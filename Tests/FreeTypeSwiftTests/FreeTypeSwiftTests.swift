import Foundation
import Testing
@testable import FreeTypeSwift

// `FreeTypeFace` is noncopyable, and `#expect` can't take a noncopyable value, so tests
// read values from the face into locals before asserting on them.

private func fontURL() throws -> URL {
    try #require(Bundle.module.url(forResource: "Inter-Variable", withExtension: "ttf", subdirectory: "Resources"))
}

private func makeFace(_ library: FreeTypeLibrary) throws -> FreeTypeFace {
    try library.face(path: fontURL().path)
}

@Suite struct LibraryTests {
    @Test func initializesAndReportsVersion() throws {
        let library = try FreeTypeLibrary()
        #expect(library.version.major == 2)
    }

    @Test func missingFileThrows() throws {
        let library = try FreeTypeLibrary()
        #expect(throws: FreeTypeError.self) {
            _ = try library.face(path: "/nonexistent/font.ttf")
        }
    }

    @Test func invalidDataThrows() throws {
        let library = try FreeTypeLibrary()
        #expect(throws: FreeTypeError.self) {
            _ = try library.face(data: Data("not a font".utf8))
        }
        #expect(!FreeTypeError(code: 1).message.isEmpty)
    }
}

@Suite struct FaceTests {
    @Test func metadata() throws {
        let face = try makeFace(FreeTypeLibrary())
        let family = face.familyName
        let style = face.styleName
        let unitsPerEM = face.unitsPerEM
        let glyphCount = face.glyphCount
        let isScalable = face.isScalable
        let ascender = face.designAscender
        let descender = face.designDescender
        #expect(family.hasPrefix("Inter"))
        #expect(!style.isEmpty)
        #expect(unitsPerEM == 2048)
        #expect(glyphCount > 100)
        #expect(isScalable)
        #expect(ascender > 0)
        #expect(descender < 0)
    }

    @Test func scaledMetricsFollowSize() throws {
        var face = try makeFace(FreeTypeLibrary())
        let unsized = face.ascender
        #expect(unsized == 0)
        try face.setPixelSize(width: 0, height: 32)
        let at32 = face.ascender
        let descender = face.descender
        let lineHeight = face.lineHeight
        #expect(at32 > 0)
        #expect(descender < 0)
        #expect(lineHeight > at32)

        // 16pt at 144 dpi is 32px.
        var other = try makeFace(FreeTypeLibrary())
        try other.setCharSize(pointSize: 16, horizontalDPI: 144, verticalDPI: 144)
        let otherAscender = other.ascender
        #expect(abs(otherAscender - at32) < 1)
    }

    @Test func characterMap() throws {
        let face = try makeFace(FreeTypeLibrary())
        let a = face.glyphIndex(for: "A")
        let b = face.glyphIndex(for: "B")
        let missing = face.glyphIndex(for: "\u{10FFFF}")
        #expect(a != 0)
        #expect(a != b)
        #expect(missing == 0)
    }

    @Test func loadsFromMemory() throws {
        let data = try Data(contentsOf: fontURL())
        var face = try FreeTypeLibrary().face(data: data)
        let glyphCount = face.glyphCount
        #expect(glyphCount > 100)
        try face.setPixelSize(width: 0, height: 24)
        // Rendering reads font bytes owned by the face.
        let glyph = try face.glyph(for: "g", flags: .render)
        #expect(glyph.bitmap?.hasCoverage == true)
    }

    @Test func faceOutlivesLibraryReference() throws {
        var face = try makeFace(FreeTypeLibrary())
        try face.setPixelSize(width: 0, height: 16)
        let advance = try face.glyph(for: "A").advanceX
        #expect(advance > 0)
    }

    @Test func kerningDoesNotThrow() throws {
        var face = try makeFace(FreeTypeLibrary())
        try face.setPixelSize(width: 0, height: 32)
        let kern = try face.kerning(leftGlyph: face.glyphIndex(for: "A"), rightGlyph: face.glyphIndex(for: "V"))
        #expect(kern.isFinite)
    }
}

@Suite struct GlyphTests {
    @Test func metricsScaleWithSize() throws {
        var face = try makeFace(FreeTypeLibrary())
        try face.setPixelSize(width: 0, height: 20)
        let small = try face.glyph(for: "A", flags: .noHinting).metrics
        try face.setPixelSize(width: 0, height: 40)
        let large = try face.glyph(for: "A", flags: .noHinting).metrics
        #expect(small.horizontalAdvance > 0)
        #expect(abs(large.horizontalAdvance / small.horizontalAdvance - 2) < 0.1)
        #expect(large.height > small.height)
    }

    @Test func noScaleReturnsFontUnits() throws {
        let face = try makeFace(FreeTypeLibrary())
        let glyph = try face.glyph(for: "A", flags: .noScale)
        #expect(glyph.metrics.horizontalAdvance > 100)
        #expect(glyph.metrics.horizontalAdvance == glyph.advanceX)
    }

    @Test func rendersBitmapWithCoverage() throws {
        var face = try makeFace(FreeTypeLibrary())
        try face.setPixelSize(width: 0, height: 48)
        let glyph = try face.glyph(for: "A", flags: .render)
        let bitmap = try #require(glyph.bitmap)
        #expect(bitmap.pixelMode == .gray)
        #expect(bitmap.width > 0 && bitmap.rows > 0)
        #expect(bitmap.pixels.count == bitmap.bytesPerRow * bitmap.rows)
        #expect(bitmap.hasCoverage)
        #expect(bitmap.top > 0)
    }

    @Test func spaceHasNoCoverage() throws {
        var face = try makeFace(FreeTypeLibrary())
        try face.setPixelSize(width: 0, height: 48)
        let glyph = try face.glyph(for: " ", flags: .render)
        #expect(glyph.bitmap?.hasCoverage != true)
        #expect(glyph.advanceX > 0)
    }

    @Test func renderModes() throws {
        var face = try makeFace(FreeTypeLibrary())
        try face.setPixelSize(width: 0, height: 32)

        let monoGlyph = try face.glyph(for: "A", render: .mono)
        let mono = try #require(monoGlyph.bitmap)
        #expect(mono.pixelMode == .mono)
        #expect(mono.bytesPerRow == (mono.width + 7) / 8)
        #expect(mono.hasCoverage)

        let normalGlyph = try face.glyph(for: "A", render: .normal)
        let lcdGlyph = try face.glyph(for: "A", render: .lcd)
        let normal = try #require(normalGlyph.bitmap)
        let lcd = try #require(lcdGlyph.bitmap)
        #expect(lcd.pixelMode == .lcd)
        #expect(lcd.width >= normal.width * 2)

        let sdfGlyph = try face.glyph(for: "A", render: .sdf)
        let sdf = try #require(sdfGlyph.bitmap)
        #expect(sdf.pixelMode == .gray)
        #expect(sdf.hasCoverage)
    }

    @Test func glyphIsUnaffectedByLaterLoads() throws {
        var face = try makeFace(FreeTypeLibrary())
        try face.setPixelSize(width: 0, height: 32)
        let first = try face.glyph(for: "A", flags: .render)
        let snapshot = first.bitmap
        _ = try face.glyph(for: "W", flags: .render)
        #expect(first.bitmap == snapshot)
    }

    @Test func outlineDecomposition() throws {
        var face = try makeFace(FreeTypeLibrary())
        try face.setPixelSize(width: 0, height: 100)
        let oGlyph = try face.glyph(for: "O", flags: .noHinting)
        let outline = try #require(oGlyph.outline)

        // "O" has an outer and an inner contour.
        let moves = outline.elements.filter { if case .moveTo = $0 { true } else { false } }
        let closes = outline.elements.filter { $0 == .close }
        #expect(moves.count == 2)
        #expect(closes.count == 2)
        #expect(outline.elements.contains { if case .quadCurveTo = $0 { true } else { false } }
            || outline.elements.contains { if case .curveTo = $0 { true } else { false } })

        // A is straight-sided: lines only, one outer and one inner contour (the counter).
        let aGlyph = try face.glyph(for: "A", flags: .noHinting)
        let a = try #require(aGlyph.outline)
        #expect(a.elements.contains { if case .lineTo = $0 { true } else { false } })
    }

    @Test func outlineIsRoughlyGlyphSized() throws {
        var face = try makeFace(FreeTypeLibrary())
        try face.setPixelSize(width: 0, height: 100)
        let glyph = try face.glyph(for: "H", flags: .noHinting)
        let outline = try #require(glyph.outline)
        let ys = outline.elements.compactMap { element -> Double? in
            if case .lineTo(let p) = element { p.y } else { nil }
        }
        let height = try #require(ys.max())
        #expect(abs(height - glyph.metrics.horizontalBearingY) < 1)
    }

    #if canImport(CoreGraphics)
    @Test func cgPathIsNonEmpty() throws {
        var face = try makeFace(FreeTypeLibrary())
        try face.setPixelSize(width: 0, height: 100)
        let glyph = try face.glyph(for: "A")
        let path = try #require(glyph.outline).cgPath
        #expect(!path.isEmpty)
        #expect(path.boundingBox.height > 50)
    }
    #endif
}

@Suite struct VariationTests {
    @Test func listsAxes() throws {
        var face = try makeFace(FreeTypeLibrary())
        let isVariable = face.isVariable
        let axes = face.variationAxes
        let weight = try #require(axes.first { $0.tag == "wght" })
        #expect(isVariable)
        #expect(weight.minimum < weight.defaultValue)
        #expect(weight.defaultValue < weight.maximum)

        let customBefore = face.hasCustomVariation
        try face.setVariation(["wght": weight.maximum])
        let customAfter = face.hasCustomVariation
        #expect(!customBefore)
        #expect(customAfter)
    }

    @Test func badFaceIndexThrows() throws {
        let library = try FreeTypeLibrary()
        #expect(throws: FreeTypeError.self) {
            _ = try library.face(path: fontURL().path, index: 99)
        }
    }

    @Test func weightChangesAdvance() throws {
        var face = try makeFace(FreeTypeLibrary())
        try face.setPixelSize(width: 0, height: 64)
        let axes = face.variationAxes
        let weight = try #require(axes.first { $0.tag == "wght" })

        try face.setVariation(["wght": weight.minimum])
        let thin = try face.glyph(for: "m", flags: .noHinting).advanceX
        try face.setVariation(["wght": weight.maximum])
        let black = try face.glyph(for: "m", flags: .noHinting).advanceX
        #expect(black > thin)
    }
}
