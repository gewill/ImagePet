// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "ImagePet",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "imagepet", targets: ["ImagePetCLI"])
    ],
    dependencies: [
        .package(url: "https://github.com/ainame/Swift-WebP.git", exact: "0.6.1"),
        .package(url: "https://github.com/awxkee/mozjpeg.swift.git", exact: "1.1.3"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", exact: "1.3.1")
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
            name: "ImagePetCLI",
            dependencies: [
                "ImagePetCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            path: "Sources/ImagePetCLI"
        ),
        .testTarget(
            name: "ImagePetTests",
            dependencies: ["ImagePetCore"],
            path: "Tests/ImagePetTests"
        )
    ]
)
