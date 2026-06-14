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
    targets: [
        .target(
            name: "ImagePetCore",
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
