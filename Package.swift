// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "ImagePet",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "ImagePet", targets: ["ImagePet"])
    ],
    dependencies: [
        .package(url: "https://github.com/ainame/Swift-WebP.git", exact: "0.6.1"),
        .package(url: "https://github.com/awxkee/mozjpeg.swift.git", exact: "1.1.3"),
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts.git", exact: "3.0.0")
    ],
    targets: [
        .target(
            name: "ImagePetCore",
            dependencies: [
                .product(name: "WebP", package: "Swift-WebP"),
                .product(name: "mozjpeg", package: "mozjpeg.swift")
            ],
            path: "Sources/ImagePetCore"
        ),
        .executableTarget(
            name: "ImagePet",
            dependencies: [
                "ImagePetCore",
                .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts")
            ],
            path: "Sources/ImagePet",
            resources: [
                .copy("Resources")
            ]
        ),
        .testTarget(
            name: "ImagePetTests",
            dependencies: ["ImagePetCore"],
            path: "Tests/ImagePetTests"
        )
    ]
)
