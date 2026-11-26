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
        #expect(!FreeTypeError(.cannotOpenResource).message.isEmpty)
    }
}

@Suite struct ErrorMatchingTests {
    @Test func catchPatternMatchesCode() throws {
        let library = try FreeTypeLibrary()
        var matched = false
        do {
            _ = try library.face(path: "/nonexistent/font.ttf")
        } catch FreeTypeError.cannotOpenResource {
            matched = true
        }
        #expect(matched)
    }

    @Test func catchPatternSkipsOtherCodes() throws {
        let library = try FreeTypeLibrary()
        var outcome = ""
        do {
            // Long enough that FreeType tries each driver and rejects the data.
            _ = try library.face(data: Data(repeating: 0x41, count: 4096))
        } catch FreeTypeError.cannotOpenResource {
            outcome = "wrong"
        } catch FreeTypeError.unknownFileFormat, FreeTypeError.invalidFileFormat {
            // Which of the two depends on the FreeType build and drivers.
            outcome = "fileFormat"
        } catch {
            outcome = "other"
        }
        #expect(outcome == "fileFormat")
    }

    @Test func switchPatternOnConcreteError() {
        let error = FreeTypeError(.invalidGlyphIndex)
        switch error {
        case FreeTypeError.outOfMemory: Issue.record("matched the wrong code")
        case FreeTypeError.invalidGlyphIndex: break
        default: Issue.record("did not match")
        }
    }

    @Test func nonFreeTypeErrorsDoNotMatch() {
        struct Other: Error {}
        let error: any Error = Other()
        #expect(!(FreeTypeError.unknownFileFormat ~= error))
    }

    @Test func rawCodesRoundTrip() {
        #expect(FreeTypeError(code: 0x02) == FreeTypeError(.unknownFileFormat))
        #expect(FreeTypeError(.outOfMemory).code.rawValue == 0x40)
        // Codes without a named member stay matchable by raw value.
        let bytecode = FreeTypeError.Code(rawValue: 0x80)
        #expect(FreeTypeError(code: 0x80).code == bytecode)
    }

    @Test func badFaceIndexIsInvalidArgument() throws {
        let library = try FreeTypeLibrary()
        let path = try fontURL().path
        var matched = false
        do {
            _ = try library.face(path: path, index: 99)
        } catch FreeTypeError.invalidArgument {
            matched = true
        }
        #expect(matched)
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

@Suite struct BitmapStrikeTests {
    // System color font; present on macOS only, and too large to bundle.
    private static let emojiPath = "/System/Library/Fonts/Apple Color Emoji.ttc"

    @Test func scalableFontHasNoStrikes() throws {
        let face = try makeFace(FreeTypeLibrary())
        let strikes = face.bitmapStrikes
        #expect(strikes.isEmpty)
    }

    @Test(.enabled(if: FileManager.default.fileExists(atPath: emojiPath)))
    func colorEmojiLoadsAsBGRA() throws {
        var face = try FreeTypeLibrary().face(path: Self.emojiPath)
        let hasColor = face.hasColor
        let strikes = face.bitmapStrikes
        #expect(hasColor)
        #expect(!strikes.isEmpty)

        try face.selectBitmapStrike(at: 0)
        let glyph = try face.glyph(for: "😀", flags: [.color])
        let bitmap = try #require(glyph.bitmap)
        #expect(bitmap.pixelMode == .bgra)
        #expect(bitmap.bytesPerRow == bitmap.width * 4)
        #expect(bitmap.hasCoverage)
        #expect(glyph.outline == nil)
    }

    @Test func invalidStrikeIndexThrows() throws {
        var face = try makeFace(FreeTypeLibrary())
        #expect(throws: FreeTypeError.self) {
            try face.selectBitmapStrike(at: 0)
        }
    }
}

@Suite struct AdvanceTests {
    @Test func advanceMatchesLinearAdvance() throws {
        var face = try makeFace(FreeTypeLibrary())
        try face.setPixelSize(width: 0, height: 40)
        let index = face.glyphIndex(for: "A")
        let fast = try face.advance(of: index)
        let loaded = try face.glyph(at: index, flags: .noHinting).linearHorizontalAdvance
        #expect(fast > 0)
        #expect(abs(fast - loaded) < 0.01)
    }

    @Test func batchMatchesIndividualAdvances() throws {
        var face = try makeFace(FreeTypeLibrary())
        try face.setPixelSize(width: 0, height: 24)
        let indices = "Hello".unicodeScalars.map { face.glyphIndex(for: $0) }
        let batch = try face.advances(of: indices)
        let individual = try indices.map { try face.advance(of: $0) }
        #expect(batch == individual)
        let none = try face.advances(of: [])
        #expect(none.isEmpty)
    }

    @Test func noScaleAdvanceIsInFontUnits() throws {
        let face = try makeFace(FreeTypeLibrary())
        let index = face.glyphIndex(for: "A")
        let units = try face.advance(of: index, flags: [.noScale])
        let loaded = try face.glyph(at: index, flags: .noScale).advanceX
        #expect(units == loaded)
        #expect(units > 100)
    }

    @Test func invalidGlyphIndexThrows() throws {
        var face = try makeFace(FreeTypeLibrary())
        try face.setPixelSize(width: 0, height: 24)
        #expect(throws: FreeTypeError.self) {
            _ = try face.advance(of: 0xFFFF_FFF0)
        }
    }
}

@Suite struct CharMapTests {
    @Test func listsUnicodeCharMap() throws {
        let face = try makeFace(FreeTypeLibrary())
        let maps = face.charMaps
        let selectedMap = face.selectedCharMap
        let selected = try #require(selectedMap)
        #expect(!maps.isEmpty)
        #expect(maps.contains { $0.encoding == .unicode })
        #expect(selected.encoding == .unicode)
        #expect(maps[selected.index] == selected)
    }

    @Test func encodingTagsMatchFreeType() {
        #expect(CharMap.Encoding.unicode.rawValue == 0x756E_6963) // 'unic'
        #expect(CharMap.Encoding.none.rawValue == 0)
        #expect(CharMap.Encoding.prc.rawValue == 0x6762_2020) // 'gb  '
    }

    @Test func selectingMissingEncodingThrows() throws {
        var face = try makeFace(FreeTypeLibrary())
        #expect(throws: FreeTypeError.self) {
            try face.selectCharMap(.adobeCustom)
        }
        var matched = false
        do {
            try face.selectCharMap(at: 999)
        } catch FreeTypeError.invalidArgument {
            matched = true
        }
        #expect(matched)
    }

    @Test func selectingByIndexAndEncoding() throws {
        var face = try makeFace(FreeTypeLibrary())
        let maps = face.charMaps
        let last = try #require(maps.last)
        try face.selectCharMap(at: last.index)
        let selectedByIndex = face.selectedCharMap
        #expect(selectedByIndex == last)
        try face.selectCharMap(.unicode)
        let selectedByEncoding = face.selectedCharMap
        #expect(selectedByEncoding?.encoding == .unicode)
    }

    @Test func enumeratesMappedCharacters() throws {
        let face = try makeFace(FreeTypeLibrary())
        let mapped = face.mappedCharacters()
        let a = face.glyphIndex(for: "A")
        #expect(mapped.count > 100)
        #expect(mapped.map(\.code) == mapped.map(\.code).sorted())
        #expect(mapped.allSatisfy { $0.glyphIndex != 0 })
        #expect(mapped.contains { $0.scalar == "A" && $0.glyphIndex == a })
        #expect(!mapped.contains { $0.code == 0x10FFFF })
    }
}

@Suite struct OutlineBoundsTests {
    @Test func boundingBoxMatchesMetrics() throws {
        var face = try makeFace(FreeTypeLibrary())
        try face.setPixelSize(width: 0, height: 100)
        let glyph = try face.glyph(for: "H", flags: .noHinting)
        let box = try #require(glyph.outline).boundingBox
        #expect(abs(box.maxY - glyph.metrics.horizontalBearingY) < 1)
        #expect(abs(box.minX - glyph.metrics.horizontalBearingX) < 1)
        #expect(abs(box.width - glyph.metrics.width) < 1)
        #expect(abs(box.height - glyph.metrics.height) < 1)
    }

    @Test func controlBoxContainsBoundingBox() throws {
        var face = try makeFace(FreeTypeLibrary())
        try face.setPixelSize(width: 0, height: 100)
        let glyph = try face.glyph(for: "O", flags: .noHinting)
        let outline = try #require(glyph.outline)
        let tight = outline.boundingBox
        let control = outline.controlBox
        #expect(control.minX <= tight.minX && control.minY <= tight.minY)
        #expect(control.maxX >= tight.maxX && control.maxY >= tight.maxY)
    }

    @Test func emptyOutlineHasEmptyBox() throws {
        var face = try makeFace(FreeTypeLibrary())
        try face.setPixelSize(width: 0, height: 100)
        let glyph = try face.glyph(for: " ", flags: .noHinting)
        let outline = try #require(glyph.outline)
        #expect(outline.boundingBox.width == 0 && outline.boundingBox.height == 0)
    }
}

@Suite struct NamedInstanceTests {
    @Test func listsNamedInstances() throws {
        let face = try makeFace(FreeTypeLibrary())
        let instances = face.namedInstances
        let weights = face.variationAxes.first { $0.tag == "wght" }
        #expect(instances.count > 1)
        #expect(instances.map(\.index) == Array(1...instances.count))
        #expect(instances.allSatisfy { $0.coordinates["wght"] != nil })
        // Names come from the name table, not the "Instance N" fallback.
        #expect(instances.allSatisfy { !$0.name.hasPrefix("Instance ") })
        #expect(instances.contains { $0.name == "Bold" })
        let axis = try #require(weights)
        #expect(instances.allSatisfy {
            ($0.coordinates["wght"] ?? 0) >= axis.minimum && ($0.coordinates["wght"] ?? 0) <= axis.maximum
        })
    }

    @Test func selectingInstanceSetsCoordinates() throws {
        var face = try makeFace(FreeTypeLibrary())
        let instances = face.namedInstances
        let bold = try #require(instances.first { $0.name == "Bold" })
        try face.selectNamedInstance(bold)
        let coordinates = face.variationCoordinates
        #expect(coordinates["wght"] == bold.coordinates["wght"])
        #expect(coordinates["wght"] == 700)
    }

    @Test func resetVariationRestoresDefaults() throws {
        var face = try makeFace(FreeTypeLibrary())
        let axes = face.variationAxes
        let weight = try #require(axes.first { $0.tag == "wght" })
        let instances = face.namedInstances
        let black = try #require(instances.max { ($0.coordinates["wght"] ?? 0) < ($1.coordinates["wght"] ?? 0) })
        try face.selectNamedInstance(black)
        let heavy = face.variationCoordinates["wght"]
        try face.resetVariation()
        let restored = face.variationCoordinates["wght"]
        #expect(heavy == weight.maximum)
        #expect(restored == weight.defaultValue)
    }

    @Test func instanceChangesGlyphMetrics() throws {
        var face = try makeFace(FreeTypeLibrary())
        try face.setPixelSize(width: 0, height: 64)
        let instances = face.namedInstances
        let thin = try #require(instances.min { ($0.coordinates["wght"] ?? 0) < ($1.coordinates["wght"] ?? 0) })
        let black = try #require(instances.max { ($0.coordinates["wght"] ?? 0) < ($1.coordinates["wght"] ?? 0) })
        try face.selectNamedInstance(thin)
        let thinAdvance = try face.advance(of: face.glyphIndex(for: "m"))
        try face.selectNamedInstance(black)
        let blackAdvance = try face.advance(of: face.glyphIndex(for: "m"))
        #expect(blackAdvance > thinAdvance)
    }

    @Test func nonVariableCoordinatesAreEmptyAndSelectionThrows() throws {
        // Bitmap-only emoji fonts aren't variable; skip quietly where unavailable.
        let path = "/System/Library/Fonts/Apple Color Emoji.ttc"
        guard FileManager.default.fileExists(atPath: path) else { return }
        var face = try FreeTypeLibrary().face(path: path)
        let coordinates = face.variationCoordinates
        let instances = face.namedInstances
        #expect(coordinates.isEmpty)
        #expect(instances.isEmpty)
        #expect(throws: FreeTypeError.self) {
            try face.selectNamedInstance(NamedInstance(index: 1, name: "x", coordinates: [:]))
        }
    }
}
