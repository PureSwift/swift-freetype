import Foundation

/// A summary of one face in a font file, for listing the contents of a collection.
public struct FaceDescription: Hashable, Sendable {
    /// The face's index, as passed to ``FreeTypeLibrary/face(path:index:namedInstance:)``.
    public var index: Int
    public var familyName: String
    public var styleName: String
    public var postScriptName: String?
}

extension FreeTypeLibrary {
    /// Describes every face of a font file; a single element for ordinary fonts and one per face
    /// for collections (`.ttc`). Each face is opened in turn, so this is meant for building font
    /// pickers, not for hot paths.
    public func faceDescriptions(path: String) throws -> [FaceDescription] {
        let first = try face(path: path)
        var descriptions = [Self.describe(first)]
        for index in 1..<max(first.faceCount, 1) {
            descriptions.append(Self.describe(try face(path: path, index: index)))
        }
        return descriptions
    }

    /// Like ``faceDescriptions(path:)`` for in-memory data. Each face opened copies `data`, so
    /// prefer the path-based variant for large collections.
    public func faceDescriptions(data: Data) throws -> [FaceDescription] {
        let first = try face(data: data)
        var descriptions = [Self.describe(first)]
        for index in 1..<max(first.faceCount, 1) {
            descriptions.append(Self.describe(try face(data: data, index: index)))
        }
        return descriptions
    }

    private static func describe(_ face: borrowing FreeTypeFace) -> FaceDescription {
        FaceDescription(
            index: face.faceIndex,
            familyName: face.familyName,
            styleName: face.styleName,
            postScriptName: face.postScriptName
        )
    }
}
