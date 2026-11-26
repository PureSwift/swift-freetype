import CFreeType
#if canImport(CoreGraphics)
import CoreGraphics
#endif

public struct OutlinePoint: Hashable, Sendable {
    public var x: Double
    public var y: Double
}

/// One segment of a vector outline. Coordinates are y-up.
public enum OutlineElement: Hashable, Sendable {
    case moveTo(OutlinePoint)
    case lineTo(OutlinePoint)
    case quadCurveTo(control: OutlinePoint, to: OutlinePoint)
    case curveTo(control1: OutlinePoint, control2: OutlinePoint, to: OutlinePoint)
    case close
}

/// An axis-aligned box, y-up, in the same units as the outline it came from.
public struct BoundingBox: Hashable, Sendable {
    public var minX: Double
    public var minY: Double
    public var maxX: Double
    public var maxY: Double

    public var width: Double { maxX - minX }
    public var height: Double { maxY - minY }
}

/// A vector glyph outline decomposed into path elements.
public struct GlyphOutline: Hashable, Sendable {
    public var elements: [OutlineElement]
    /// The tight box around the filled shape (`FT_Outline_Get_BBox`). It accounts for the
    /// extrema of curves, so it matches the glyph's ink.
    public var boundingBox: BoundingBox
    /// The box around all points, including off-curve control points (`FT_Outline_Get_CBox`).
    /// Cheaper than ``boundingBox``, and always contains it.
    public var controlBox: BoundingBox
}

/// Collects the callbacks of `FT_Outline_Decompose`.
///
/// An unretained pointer to this object travels through the `user` parameter, so the
/// `@convention(c)` callbacks capture nothing.
final class OutlineBuilder {
    private(set) var elements: [OutlineElement] = []
    private var isOpen = false
    private let divisor: Double

    init(divisor: Double) {
        self.divisor = divisor
    }

    private func point(_ vector: UnsafePointer<FT_Vector>) -> OutlinePoint {
        OutlinePoint(x: Double(vector.pointee.x) / divisor, y: Double(vector.pointee.y) / divisor)
    }

    func moveTo(_ to: UnsafePointer<FT_Vector>) {
        closeContour()
        elements.append(.moveTo(point(to)))
        isOpen = true
    }

    func lineTo(_ to: UnsafePointer<FT_Vector>) {
        elements.append(.lineTo(point(to)))
    }

    func conicTo(_ control: UnsafePointer<FT_Vector>, _ to: UnsafePointer<FT_Vector>) {
        elements.append(.quadCurveTo(control: point(control), to: point(to)))
    }

    func cubicTo(
        _ control1: UnsafePointer<FT_Vector>,
        _ control2: UnsafePointer<FT_Vector>,
        _ to: UnsafePointer<FT_Vector>
    ) {
        elements.append(.curveTo(control1: point(control1), control2: point(control2), to: point(to)))
    }

    /// Decomposition doesn't emit an explicit close, so contours are closed here.
    func closeContour() {
        if isOpen {
            elements.append(.close)
            isOpen = false
        }
    }

    /// Decomposes `outline`, throwing if FreeType reports an error.
    static func decompose(
        _ outline: inout FT_Outline,
        divisor: Double
    ) throws -> GlyphOutline {
        let builder = OutlineBuilder(divisor: divisor)
        var funcs = FT_Outline_Funcs(
            move_to: { to, user in
                guard let to, let user else { return 1 }
                Unmanaged<OutlineBuilder>.fromOpaque(user).takeUnretainedValue().moveTo(to)
                return 0
            },
            line_to: { to, user in
                guard let to, let user else { return 1 }
                Unmanaged<OutlineBuilder>.fromOpaque(user).takeUnretainedValue().lineTo(to)
                return 0
            },
            conic_to: { control, to, user in
                guard let control, let to, let user else { return 1 }
                Unmanaged<OutlineBuilder>.fromOpaque(user).takeUnretainedValue().conicTo(control, to)
                return 0
            },
            cubic_to: { control1, control2, to, user in
                guard let control1, let control2, let to, let user else { return 1 }
                Unmanaged<OutlineBuilder>.fromOpaque(user).takeUnretainedValue()
                    .cubicTo(control1, control2, to)
                return 0
            },
            shift: 0,
            delta: 0
        )
        // `builder` is kept alive by this scope for the duration of the call.
        try withExtendedLifetime(builder) {
            try ftTry(FT_Outline_Decompose(&outline, &funcs, Unmanaged.passUnretained(builder).toOpaque()))
        }
        builder.closeContour()

        var tight = FT_BBox()
        var control = FT_BBox()
        try ftTry(FT_Outline_Get_BBox(&outline, &tight))
        FT_Outline_Get_CBox(&outline, &control)
        func box(_ box: FT_BBox) -> BoundingBox {
            BoundingBox(
                minX: Double(box.xMin) / divisor,
                minY: Double(box.yMin) / divisor,
                maxX: Double(box.xMax) / divisor,
                maxY: Double(box.yMax) / divisor
            )
        }
        return GlyphOutline(elements: builder.elements, boundingBox: box(tight), controlBox: box(control))
    }
}

#if canImport(CoreGraphics)
extension GlyphOutline {
    /// The outline as a `CGPath` (y-up, same units as the outline).
    public var cgPath: CGPath {
        let path = CGMutablePath()
        for element in elements {
            switch element {
            case .moveTo(let p):
                path.move(to: CGPoint(x: p.x, y: p.y))
            case .lineTo(let p):
                path.addLine(to: CGPoint(x: p.x, y: p.y))
            case .quadCurveTo(let c, let p):
                path.addQuadCurve(to: CGPoint(x: p.x, y: p.y), control: CGPoint(x: c.x, y: c.y))
            case .curveTo(let c1, let c2, let p):
                path.addCurve(
                    to: CGPoint(x: p.x, y: p.y),
                    control1: CGPoint(x: c1.x, y: c1.y),
                    control2: CGPoint(x: c2.x, y: c2.y)
                )
            case .close:
                path.closeSubpath()
            }
        }
        return path
    }
}
#endif
