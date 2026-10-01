import UIKit

enum AppSettings {
    /// Product capabilities — keep aligned with the Android sibling demo.
    static let wantRecognition = true
    static let wantAuthenticity = true

    static func authenticityMode(licenseAllows: Bool) -> String {
        licenseAllows ? "normal" : "none"
    }
}

/// Session helper for still OCR / MRZ / barcode.
/// Call startGallery immediately before DocSDK.recognize.
enum DocSdkSession {
    @discardableResult
    static func startGallery() -> String {
        DocSDK.startNewSession("{\"scenario\":\"FullProcess\",\"series\":false}")
    }
}
