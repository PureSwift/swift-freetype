import CFreeType
import Foundation

/// A named instance of a variable font, such as "Bold" or "Condensed Light".
public struct NamedInstance: Hashable, Sendable {
    /// The 1-based index FreeType uses (`FT_Set_Named_Instance`).
    public var index: Int
    public var name: String
    /// Axis values by tag, e.g. `["wght": 700]`.
    public var coordinates: [String: Double]
}

extension FreeTypeFace {
    /// The named instances of a variable font, or an empty array for other fonts.
    public var namedInstances: [NamedInstance] {
        library.withLock {
            withMMVar { variations -> [NamedInstance] in
                let axes = VariationAxis.axes(in: variations)
                return (0..<Int(variations.pointee.num_namedstyles)).map { offset in
                    let style = variations.pointee.namedstyle[offset]
                    let coordinates = (0..<axes.count).map { Double(style.coords[$0]) / 65536 }
                    // `strid` is a name table ID; 0xFFFF means the instance has no name.
                    let name = UInt16(exactly: style.strid).flatMap { unlockedSfntName(id: $0) }
                    return NamedInstance(
                        index: offset + 1,
                        name: name ?? "Instance \(offset + 1)",
                        coordinates: Dictionary(
                            zip(axes.map(\.tag), coordinates),
                            uniquingKeysWith: { first, _ in first }
                        )
                    )
                }
            } ?? []
        }
    }

    /// Applies a named instance's axis values.
    public mutating func selectNamedInstance(_ instance: NamedInstance) throws {
        try library.withLock {
            try ftTry(FT_Set_Named_Instance(face, FT_UInt(instance.index)))
        }
    }

    /// Sets every axis back to its default value.
    ///
    /// This sets the coordinates explicitly. `FT_Set_Named_Instance` with index 0 is documented
    /// to leave named-instance access, but it does not reset the design coordinates.
    public mutating func resetVariation() throws {
        try library.withLock {
            let defaults = withMMVar { variations in
                VariationAxis.axes(in: variations).map { FT_Fixed(($0.defaultValue * 65536).rounded()) }
            } ?? []
            guard !defaults.isEmpty else {
                throw FreeTypeError(.invalidArgument)
            }
            var coordinates = defaults
            try ftTry(FT_Set_Var_Design_Coordinates(face, FT_UInt(coordinates.count), &coordinates))
        }
    }

    /// The current design coordinates by axis tag, or an empty dictionary for non-variable fonts.
    public var variationCoordinates: [String: Double] {
        library.withLock {
            let axes = withMMVar { VariationAxis.axes(in: $0) } ?? []
            guard !axes.isEmpty else { return [:] }
            var raw = [FT_Fixed](repeating: 0, count: axes.count)
            guard FT_Get_Var_Design_Coordinates(face, FT_UInt(axes.count), &raw) == 0 else { return [:] }
            return Dictionary(
                zip(axes.map(\.tag), raw.map { Double($0) / 65536 }),
                uniquingKeysWith: { first, _ in first }
            )
        }
    }
}
