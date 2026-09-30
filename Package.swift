// swift-tools-version: 5.9
import PackageDescription

// DocumentReader.xcodeproj keeps linking docsdk.framework beside the project.
// This package is the customer install and is not added to that project.
let package = Package(
    name: "IdentixiaDocumentReader",
    platforms: [.iOS(.v15)],
    products: [
        .library(name: "IdentixiaDocumentReader", targets: ["docsdk"])
    ],
    targets: [
        .binaryTarget(
            name: "docsdk",
            url: "https://github.com/identixia-IDV/ID-Document-Recognition-Liveness-Detection-iOS/releases/latest/download/docsdk.xcframework.zip",
            checksum: "0000000000000000000000000000000000000000000000000000000000000000"
        ),
    ]
)
