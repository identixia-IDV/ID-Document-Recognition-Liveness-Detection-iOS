// swift-tools-version: 5.9
import PackageDescription

// DocumentReader.xcodeproj keeps linking documentfullsdk.framework beside the project.
// This package is the customer install and is not added to that project.
// Replace the zero checksum after publishing documentfullsdk.xcframework.zip on GitHub Releases.
let package = Package(
    name: "IdentixiaDocumentReader",
    platforms: [.iOS(.v15)],
    products: [
        .library(name: "IdentixiaDocumentReader", targets: ["documentfullsdk"])
    ],
    targets: [
        .binaryTarget(
            name: "documentfullsdk",
            url: "https://github.com/identixia-IDV/ID-Document-Recognition-Liveness-Detection-iOS/releases/latest/download/documentfullsdk.xcframework.zip",
            checksum: "0000000000000000000000000000000000000000000000000000000000000000"
        ),
    ]
)
