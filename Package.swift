// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "macoswheels",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(name: "WheelProtocol",   targets: ["WheelProtocol"]),
        .library(name: "WheelRegistry",   targets: ["WheelRegistry"]),
        .library(name: "Drivers",         targets: ["Drivers"]),
        .library(name: "HIDDescriptors",  targets: ["HIDDescriptors"]),
        .library(name: "FFBNormalizer",   targets: ["FFBNormalizer"]),
        .library(name: "ConfigPlane",     targets: ["ConfigPlane"]),
        .executable(name: "macoswheels",  targets: ["CLI"]),
    ],
    targets: [
        .target(name: "WheelProtocol"),
        .target(name: "WheelRegistry",  dependencies: ["WheelProtocol"]),
        .target(name: "Drivers",        dependencies: ["WheelProtocol", "WheelRegistry"]),
        .target(name: "HIDDescriptors", dependencies: ["WheelProtocol"]),
        .target(name: "FFBNormalizer",  dependencies: ["WheelProtocol", "HIDDescriptors"]),
        .target(name: "ConfigPlane",    dependencies: ["WheelProtocol"]),
        .executableTarget(name: "CLI",  dependencies: ["WheelProtocol", "WheelRegistry", "ConfigPlane"]),

        .testTarget(name: "WheelProtocolTests",
                    dependencies: ["WheelProtocol", "WheelRegistry", "Drivers"]),
        .testTarget(name: "FFBNormalizerTests",
                    dependencies: ["FFBNormalizer", "WheelProtocol", "HIDDescriptors"]),
        .testTarget(name: "DescriptorTests",
                    dependencies: ["HIDDescriptors", "WheelProtocol"]),
        .testTarget(name: "CLITests",
                    dependencies: ["CLI", "ConfigPlane"]),
    ]
)
