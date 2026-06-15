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
        .package(url: "https://github.com/ainame/Swift-WebP.git", exact: "0.6.1")
    ],
    targets: [
        .target(
            name: "ImagePetCore",
            dependencies: [
                .product(name: "WebP", package: "Swift-WebP")
            ],
            path: "Sources/ImagePetCore"
        ),
        .executableTarget(
            name: "ImagePet",
            dependencies: ["ImagePetCore"],
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
