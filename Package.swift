// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "swift-freetype",
    products: [
        .library(
            name: "FreeTypeSwift",
            targets: ["FreeTypeSwift"]
        ),
    ],
    targets: [
        // Raw C interop: exposes the FreeType headers through a shim header and module map.
        .systemLibrary(
            name: "CFreeType",
            pkgConfig: "freetype2",
            providers: [
                .brew(["freetype"]),
                .apt(["libfreetype6-dev"]),
            ]
        ),
        // Safe Swift wrapper.
        .target(
            name: "FreeTypeSwift",
            dependencies: ["CFreeType"]
        ),
        .testTarget(
            name: "FreeTypeSwiftTests",
            dependencies: ["FreeTypeSwift"],
            resources: [
                .copy("Resources"),
            ]
        ),
    ]
)
