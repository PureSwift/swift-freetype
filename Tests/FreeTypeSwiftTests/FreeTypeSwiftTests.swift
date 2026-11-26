import Foundation
import Testing
@testable import FreeTypeSwift

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
            try library.face(path: "/nonexistent/font.ttf")
        }
    }

    @Test func invalidDataThrows() throws {
        let library = try FreeTypeLibrary()
        #expect(throws: FreeTypeError.self) {
            try library.face(data: Data("not a font".utf8))
        }
        #expect(!FreeTypeError(code: 1).message.isEmpty)
    }
}

@Suite struct FaceTests {
    @Test func metadata() throws {
        let face = try makeFace(FreeTypeLibrary())
        #expect(face.familyName.hasPrefix("Inter"))
        #expect(!face.styleName.isEmpty)
        #expect(face.unitsPerEM == 2048)
        #expect(face.glyphCount > 100)
        #expect(face.isScalable)
        #expect(face.designAscender > 0)
        #expect(face.designDescender < 0)
    }

    @Test func scaledMetricsFollowSize() throws {
        let face = try makeFace(FreeTypeLibrary())
        #expect(face.ascender == 0)
        try face.setPixelSize(width: 0, height: 32)
        let at32 = face.ascender
        #expect(at32 > 0)
        #expect(face.descender < 0)
        #expect(face.lineHeight > at32)

        // 16pt at 144 dpi is 32px.
        let other = try makeFace(FreeTypeLibrary())
        try other.setCharSize(pointSize: 16, horizontalDPI: 144, verticalDPI: 144)
        #expect(abs(other.ascender - at32) < 1)
    }

    @Test func characterMap() throws {
        let face = try makeFace(FreeTypeLibrary())
        let a = face.glyphIndex(for: "A")
        #expect(a != 0)
        #expect(a != face.glyphIndex(for: "B"))
        #expect(face.glyphIndex(for: "\u{10FFFF}") == 0)
    }

    @Test func loadsFromMemory() throws {
        let data = try Data(contentsOf: fontURL())
        let face = try FreeTypeLibrary().face(data: data)
        #expect(face.glyphCount > 100)
        try face.setPixelSize(width: 0, height: 24)
        // Rendering reads font bytes owned by the face.
        let glyph = try face.glyph(for: "g", flags: .render)
        #expect(glyph.bitmap?.hasCoverage == true)
    }

    @Test func faceOutlivesLibraryReference() throws {
        let face = try makeFace(FreeTypeLibrary())
        try face.setPixelSize(width: 0, height: 16)
        #expect(try face.glyph(for: "A").advanceX > 0)
    }

    @Test func kerningDoesNotThrow() throws {
        let face = try makeFace(FreeTypeLibrary())
        try face.setPixelSize(width: 0, height: 32)
        let kern = try face.kerning(leftGlyph: face.glyphIndex(for: "A"), rightGlyph: face.glyphIndex(for: "V"))
        #expect(kern.isFinite)
    }
}

@Suite struct GlyphTests {
    @Test func metricsScaleWithSize() throws {
        let face = try makeFace(FreeTypeLibrary())
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
        let face = try makeFace(FreeTypeLibrary())
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
        let face = try makeFace(FreeTypeLibrary())
        try face.setPixelSize(width: 0, height: 48)
        let glyph = try face.glyph(for: " ", flags: .render)
        #expect(glyph.bitmap?.hasCoverage != true)
        #expect(glyph.advanceX > 0)
    }

    @Test func renderModes() throws {
        let face = try makeFace(FreeTypeLibrary())
        try face.setPixelSize(width: 0, height: 32)

        let mono = try #require(face.glyph(for: "A", render: .mono).bitmap)
        #expect(mono.pixelMode == .mono)
        #expect(mono.bytesPerRow == (mono.width + 7) / 8)
        #expect(mono.hasCoverage)

        let normal = try #require(face.glyph(for: "A", render: .normal).bitmap)
        let lcd = try #require(face.glyph(for: "A", render: .lcd).bitmap)
        #expect(lcd.pixelMode == .lcd)
        #expect(lcd.width >= normal.width * 2)

        let sdf = try #require(face.glyph(for: "A", render: .sdf).bitmap)
        #expect(sdf.pixelMode == .gray)
        #expect(sdf.hasCoverage)
    }

    @Test func glyphIsUnaffectedByLaterLoads() throws {
        let face = try makeFace(FreeTypeLibrary())
        try face.setPixelSize(width: 0, height: 32)
        let first = try face.glyph(for: "A", flags: .render)
        let snapshot = first.bitmap
        _ = try face.glyph(for: "W", flags: .render)
        #expect(first.bitmap == snapshot)
    }

    @Test func outlineDecomposition() throws {
        let face = try makeFace(FreeTypeLibrary())
        try face.setPixelSize(width: 0, height: 100)
        let outline = try #require(face.glyph(for: "O", flags: .noHinting).outline)

        // "O" has an outer and an inner contour.
        let moves = outline.elements.filter { if case .moveTo = $0 { true } else { false } }
        let closes = outline.elements.filter { $0 == .close }
        #expect(moves.count == 2)
        #expect(closes.count == 2)
        #expect(outline.elements.contains { if case .quadCurveTo = $0 { true } else { false } }
            || outline.elements.contains { if case .curveTo = $0 { true } else { false } })

        // A is straight-sided: lines only, one outer and one inner contour (the counter).
        let a = try #require(face.glyph(for: "A", flags: .noHinting).outline)
        #expect(a.elements.contains { if case .lineTo = $0 { true } else { false } })
    }

    @Test func outlineIsRoughlyGlyphSized() throws {
        let face = try makeFace(FreeTypeLibrary())
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
        let face = try makeFace(FreeTypeLibrary())
        try face.setPixelSize(width: 0, height: 100)
        let path = try #require(face.glyph(for: "A").outline).cgPath
        #expect(!path.isEmpty)
        #expect(path.boundingBox.height > 50)
    }
    #endif
}

@Suite struct VariationTests {
    @Test func listsAxes() throws {
        let face = try makeFace(FreeTypeLibrary())
        #expect(face.isVariable)
        let weight = try #require(face.variationAxes.first { $0.tag == "wght" })
        #expect(weight.minimum < weight.defaultValue)
        #expect(weight.defaultValue < weight.maximum)
        #expect(!face.hasCustomVariation)
        try face.setVariation(["wght": weight.maximum])
        #expect(face.hasCustomVariation)
    }

    @Test func badFaceIndexThrows() throws {
        let library = try FreeTypeLibrary()
        #expect(throws: FreeTypeError.self) {
            try library.face(path: fontURL().path, index: 99)
        }
    }

    @Test func weightChangesAdvance() throws {
        let face = try makeFace(FreeTypeLibrary())
        try face.setPixelSize(width: 0, height: 64)
        let weight = try #require(face.variationAxes.first { $0.tag == "wght" })

        try face.setVariation(["wght": weight.minimum])
        let thin = try face.glyph(for: "m", flags: .noHinting).advanceX
        try face.setVariation(["wght": weight.maximum])
        let black = try face.glyph(for: "m", flags: .noHinting).advanceX
        #expect(black > thin)
    }
}
