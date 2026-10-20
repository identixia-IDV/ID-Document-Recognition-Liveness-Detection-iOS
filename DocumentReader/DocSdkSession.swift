import UIKit

enum AppSettings {
    /// Product capabilities — keep aligned with the Android sibling demo.
    static let wantRecognition = true
    static let wantAuthenticity = true

    static func authenticityMode(licenseAllows: Bool) -> String {
        licenseAllows ? "normal" : "none"
    }
}

/// Session helper for still OCR / MRZ / barcode (+ authenticity when licensed).
/// Camera guide crops include margins — pass alreadyCropped=false so the engine
/// re-detects (Android CameraActivity). Gallery full-frame picks also use false.
enum DocSdkSession {
    @discardableResult
    static func startGallery() -> String {
        DocumentFullSDK.startNewSession("{\"scenario\":\"FullProcess\",\"series\":false}")
    }

    /// - Returns: (json, optional user-facing deny message)
    static func recognize(
        front: UIImage,
        back: UIImage? = nil,
        alreadyCropped: Bool = false
    ) -> (String, String?) {
        let status = LicenseStatus.current()
        let wantAuth = true
        let deny = status.denyMessage(
            wantRecognition: true,
            wantAuthenticity: wantAuth
        )
        let mode = (wantAuth && status.authenticity) ? "normal" : "none"
        startGallery()
        let json = DocumentFullSDK.recognizeFront(
            front,
            back: back,
            authenticityMode: mode,
            alreadyCropped: alreadyCropped
        )
        return (json, deny)
    }
}
