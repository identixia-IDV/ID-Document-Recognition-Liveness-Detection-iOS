import AVFoundation
import UIKit

/// Live preview using DocSDK.locateDocument (bounds + type score, no OCR).
/// User taps Capture when ready, then recognize.
final class CameraViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    private let session = AVCaptureSession()
    private let cameraView = UIView()
    private let guideView = DocumentGuideView()
    private let percentLabel = UILabel()
    private let hintLabel = UILabel()
    private let captureButton = UIButton(type: .system)
    private let closeButton = UIButton(type: .system)
    private let processQueue = DispatchQueue(label: "docsdk.camera")
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var locating = false
    private var captured = false
    private var latestStill: UIImage?
    private var lastStillUpdateMs: TimeInterval = 0
    private let stillLock = NSLock()
    private var previewSize: CGSize = .zero

    // TEMPORARY CROP PREVIEW — start
    // Delete only this block when asked to "Delete temporary preview".
    private let cropPreviewLabel: UILabel = {
        let label = UILabel()
        label.text = "Crop preview (temporary)"
        label.textColor = .white
        label.font = .systemFont(ofSize: 11, weight: .bold)
        label.textAlignment = .right
        label.isHidden = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    private let cropPreviewView: UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleAspectFit
        view.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        view.layer.borderColor = UIColor(red: 245 / 255, green: 158 / 255, blue: 11 / 255, alpha: 1).cgColor
        view.layer.borderWidth = 2
        view.clipsToBounds = true
        view.isHidden = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    // TEMPORARY CROP PREVIEW — end

    private let showThreshold = 50
    private let highThreshold = 85
    private let keepCaptureMin = 50
    private let locateMaxEdge: CGFloat = 480

    init() {
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        let topBar = UIView()
        topBar.translatesAutoresizingMaskIntoConstraints = false

        let closeConfig = UIImage.SymbolConfiguration(pointSize: 16, weight: .bold)
        closeButton.setImage(UIImage(systemName: "xmark", withConfiguration: closeConfig), for: .normal)
        closeButton.tintColor = IXColor.text
        closeButton.backgroundColor = IXColor.surface
        closeButton.layer.cornerRadius = 24
        closeButton.clipsToBounds = true
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        closeButton.translatesAutoresizingMaskIntoConstraints = false

        topBar.addSubview(closeButton)

        cameraView.translatesAutoresizingMaskIntoConstraints = false
        guideView.translatesAutoresizingMaskIntoConstraints = false

        percentLabel.text = "0%"
        percentLabel.textColor = IXColor.text
        percentLabel.font = .systemFont(ofSize: 15, weight: .bold)
        percentLabel.textAlignment = .center
        percentLabel.backgroundColor = IXColor.surface
        percentLabel.layer.cornerRadius = 20
        percentLabel.clipsToBounds = true
        percentLabel.translatesAutoresizingMaskIntoConstraints = false

        hintLabel.text = "Align the ID inside the frame"
        hintLabel.textColor = .white
        hintLabel.font = .systemFont(ofSize: 13)
        hintLabel.textAlignment = .center
        hintLabel.numberOfLines = 0
        hintLabel.translatesAutoresizingMaskIntoConstraints = false

        captureButton.setTitle("Capture", for: .normal)
        captureButton.setTitleColor(.white, for: .normal)
        captureButton.backgroundColor = IXColor.accent
        captureButton.layer.cornerRadius = 32
        captureButton.clipsToBounds = true
        captureButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .bold)
        captureButton.addTarget(self, action: #selector(onCapture), for: .touchUpInside)
        captureButton.isEnabled = false
        captureButton.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(topBar)
        view.addSubview(cameraView)
        cameraView.addSubview(guideView)
        cameraView.addSubview(percentLabel)
        // TEMPORARY CROP PREVIEW — start
        // Delete only this block when asked to "Delete temporary preview".
        cameraView.addSubview(cropPreviewLabel)
        cameraView.addSubview(cropPreviewView)
        // TEMPORARY CROP PREVIEW — end
        view.addSubview(hintLabel)
        view.addSubview(captureButton)

        NSLayoutConstraint.activate([
            topBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            topBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            topBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            topBar.heightAnchor.constraint(equalToConstant: 56),

            closeButton.leadingAnchor.constraint(equalTo: topBar.leadingAnchor),
            closeButton.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 48),
            closeButton.heightAnchor.constraint(equalToConstant: 48),

            cameraView.topAnchor.constraint(equalTo: topBar.bottomAnchor),
            cameraView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            cameraView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            cameraView.bottomAnchor.constraint(equalTo: hintLabel.topAnchor),

            guideView.topAnchor.constraint(equalTo: cameraView.topAnchor),
            guideView.leadingAnchor.constraint(equalTo: cameraView.leadingAnchor),
            guideView.trailingAnchor.constraint(equalTo: cameraView.trailingAnchor),
            guideView.bottomAnchor.constraint(equalTo: cameraView.bottomAnchor),

            percentLabel.topAnchor.constraint(equalTo: cameraView.topAnchor, constant: 12),
            percentLabel.centerXAnchor.constraint(equalTo: cameraView.centerXAnchor),
            percentLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 72),
            percentLabel.heightAnchor.constraint(equalToConstant: 36),

            hintLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            hintLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            hintLabel.bottomAnchor.constraint(equalTo: captureButton.topAnchor, constant: -8),

            captureButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            captureButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            captureButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            captureButton.heightAnchor.constraint(equalToConstant: 64),

            // TEMPORARY CROP PREVIEW — start
            // Delete only this block when asked to "Delete temporary preview".
            cropPreviewView.trailingAnchor.constraint(equalTo: cameraView.trailingAnchor, constant: -12),
            cropPreviewView.bottomAnchor.constraint(equalTo: cameraView.bottomAnchor, constant: -12),
            cropPreviewView.widthAnchor.constraint(equalToConstant: 148),
            cropPreviewView.heightAnchor.constraint(equalToConstant: 104),
            cropPreviewLabel.trailingAnchor.constraint(equalTo: cropPreviewView.trailingAnchor),
            cropPreviewLabel.bottomAnchor.constraint(equalTo: cropPreviewView.topAnchor, constant: -4),
            // TEMPORARY CROP PREVIEW — end
        ])

        requestCamera()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewSize = cameraView.bounds.size
        previewLayer?.frame = cameraView.bounds
        if let conn = previewLayer?.connection, conn.isVideoOrientationSupported {
            conn.videoOrientation = .portrait
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        processQueue.async { self.session.stopRunning() }
    }

    private func requestCamera() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            startCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { ok in
                DispatchQueue.main.async {
                    if ok { self.startCamera() } else { self.finishDenied() }
                }
            }
        default:
            finishDenied()
        }
    }

    private func finishDenied() {
        let alert = UIAlertController(title: nil, message: "Camera permission is required", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in self.dismiss(animated: true) })
        present(alert, animated: true)
    }

    private func startCamera() {
        session.beginConfiguration()
        session.sessionPreset = .hd1280x720
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            session.commitConfiguration()
            return
        }
        session.addInput(input)
        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        output.setSampleBufferDelegate(self, queue: processQueue)
        output.alwaysDiscardsLateVideoFrames = true
        if session.canAddOutput(output) { session.addOutput(output) }
        if let conn = output.connection(with: .video), conn.isVideoOrientationSupported {
            conn.videoOrientation = .portrait
        }
        session.commitConfiguration()

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        preview.frame = cameraView.bounds
        if let conn = preview.connection, conn.isVideoOrientationSupported {
            conn.videoOrientation = .portrait
        }
        cameraView.layer.insertSublayer(preview, at: 0)
        previewLayer = preview
        processQueue.async { self.session.startRunning() }
    }

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        if captured { return }
        if locating { return }
        locating = true
        defer { locating = false }

        guard let image = Self.image(from: sampleBuffer)?.fixOrientation() else { return }
        let viewSize = previewSize.width > 1 ? previewSize : cameraView.bounds.size
        guard let cropped = Self.cropToGuide(
            image,
            viewSize: viewSize,
            previewSize: CGSize(width: 1280, height: 720)
        ) else { return }
        let locateBmp = cropped.scaled(maxEdge: locateMaxEdge)
        let locateJson = DocSDK.locateDocument(locateBmp)
        let scorePct = ResultParser.documentPercent(locateJson)
        let cornersLocate = ResultParser.documentCorners(locateJson)
        let high = scorePct >= highThreshold

        if scorePct >= keepCaptureMin {
            let now = Date().timeIntervalSince1970 * 1000
            if high || now - lastStillUpdateMs > 500 {
                stillLock.lock()
                latestStill = cropped
                stillLock.unlock()
                lastStillUpdateMs = now
            }
        }

        let viewCorners: [CGPoint]? = {
            guard scorePct >= showThreshold, let corners = cornersLocate else { return nil }
            return Self.mapCropCornersToGuide(
                corners,
                cropSize: cropped.size,
                locateSize: locateBmp.size,
                viewSize: viewSize
            )
        }()

        DispatchQueue.main.async {
            if self.captured { return }
            self.percentLabel.text = "\(scorePct)%"
            if let viewCorners {
                self.guideView.setDetectedCorners(viewCorners)
            } else {
                self.guideView.clearDetection()
            }
            self.guideView.locked = high
            self.captureButton.isEnabled = scorePct >= self.keepCaptureMin
            self.captureButton.alpha = self.captureButton.isEnabled ? 1 : 0.45
            self.hintLabel.text = scorePct >= self.keepCaptureMin
                ? "Ready — tap Capture or keep holding"
                : "Align the ID inside the frame"
            // TEMPORARY CROP PREVIEW — start
            // Delete only this block when asked to "Delete temporary preview".
            self.stillLock.lock()
            let preview = self.latestStill
            self.stillLock.unlock()
            self.cropPreviewView.image = preview
            self.cropPreviewView.isHidden = preview == nil
            self.cropPreviewLabel.isHidden = preview == nil
            // TEMPORARY CROP PREVIEW — end
        }
    }

    @objc private func onCapture() {
        stillLock.lock()
        let still = latestStill
        stillLock.unlock()
        guard let still else { return }
        beginRecognize(still)
    }

    @objc private func closeTapped() {
        dismiss(animated: true)
    }

    private func beginRecognize(_ still: UIImage) {
        if captured { return }
        captured = true
        DispatchQueue.main.async {
            self.captureButton.isEnabled = false
            self.captureButton.alpha = 0.45
            self.hintLabel.text = "Reading document…"
        }
        processQueue.async {
            self.session.stopRunning()
            DocSdkSession.startGallery()
            let status = LicenseStatus.current()
            let deny = status.denyMessage(wantRecognition: true, wantAuthenticity: true)
            let json = DocSDK.recognize(
                still,
                authenticityMode: AppSettings.authenticityMode(licenseAllows: status.authenticity)
            )
            DispatchQueue.main.async {
                guard let nav = self.presentingViewController as? UINavigationController else {
                    self.dismiss(animated: true)
                    return
                }
                let openResult = {
                    nav.pushViewController(ResultViewController(json: json), animated: false)
                    self.dismiss(animated: true)
                }
                if let deny, !deny.isEmpty {
                    let alert = UIAlertController(title: nil, message: deny, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in openResult() })
                    self.present(alert, animated: true)
                } else {
                    openResult()
                }
            }
        }
    }

    /// Preview-FOV slice, then overlay fraction of the cover-visible region.
    private static func cropToGuide(
        _ image: UIImage,
        viewSize: CGSize,
        previewSize: CGSize = .zero
    ) -> UIImage? {
        let guide = DocumentGuideView.passportGuideRect(in: CGRect(origin: .zero, size: viewSize))
        guard let cg = image.cgImage else { return nil }
        let pixelW = CGFloat(cg.width)
        let pixelH = CGFloat(cg.height)
        guard pixelW > 8, pixelH > 8, viewSize.width > 1, viewSize.height > 1 else {
            return nil
        }
        let map = mappingImageSize(imageW: pixelW, imageH: pixelH, preview: previewSize)
        let ox = (pixelW - map.width) / 2
        let oy = (pixelH - map.height) / 2
        let scale = max(viewSize.width / map.width, viewSize.height / map.height)
        let dx = (viewSize.width - map.width * scale) / 2
        let dy = (viewSize.height - map.height * scale) / 2
        let visLeft = (0 - dx) / scale
        let visTop = (0 - dy) / scale
        let visW = viewSize.width / scale
        let visH = viewSize.height / scale
        var crop = CGRect(
            x: visLeft + visW * (guide.minX / viewSize.width) + ox,
            y: visTop + visH * (guide.minY / viewSize.height) + oy,
            width: visW * (guide.width / viewSize.width),
            height: visH * (guide.height / viewSize.height)
        ).integral
        crop = crop.intersection(CGRect(x: 0, y: 0, width: cg.width, height: cg.height))
        guard crop.width >= 32, crop.height >= 32, let cut = cg.cropping(to: crop) else {
            return nil
        }
        return UIImage(cgImage: cut, scale: 1, orientation: .up)
    }

    private static func mappingImageSize(
        imageW: CGFloat,
        imageH: CGFloat,
        preview: CGSize
    ) -> CGSize {
        guard preview.width > 1, preview.height > 1 else {
            return CGSize(width: imageW, height: imageH)
        }
        let displayed = preview.width > preview.height
            ? CGSize(width: preview.height, height: preview.width)
            : preview
        let displayAspect = displayed.width / displayed.height
        let imageAspect = imageW / imageH
        if abs(displayAspect - imageAspect) < 0.01 {
            return CGSize(width: imageW, height: imageH)
        }
        if displayAspect > imageAspect {
            return CGSize(width: imageW, height: imageW / displayAspect)
        }
        return CGSize(width: imageH * displayAspect, height: imageH)
    }

    private static func mapCropCornersToGuide(
        _ corners: [CGPoint],
        cropSize: CGSize,
        locateSize: CGSize,
        viewSize: CGSize
    ) -> [CGPoint]? {
        guard corners.count >= 4,
              cropSize.width > 1, cropSize.height > 1,
              viewSize.width > 1, viewSize.height > 1 else { return nil }
        let guide = DocumentGuideView.passportGuideRect(in: CGRect(origin: .zero, size: viewSize))
        let sx = cropSize.width / max(locateSize.width, 1)
        let sy = cropSize.height / max(locateSize.height, 1)
        return corners.map {
            let cx = $0.x * sx
            let cy = $0.y * sy
            return CGPoint(
                x: guide.minX + cx * guide.width / cropSize.width,
                y: guide.minY + (cropSize.height - cy) * guide.height / cropSize.height
            )
        }
    }

    private static func image(from sampleBuffer: CMSampleBuffer) -> UIImage? {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }
        let ci = CIImage(cvPixelBuffer: pixelBuffer)
        let ctx = CIContext()
        guard let cg = ctx.createCGImage(ci, from: ci.extent) else { return nil }
        let w = CVPixelBufferGetWidth(pixelBuffer)
        let h = CVPixelBufferGetHeight(pixelBuffer)
        let orientation: UIImage.Orientation = w > h ? .right : .up
        return UIImage(cgImage: cg, scale: 1, orientation: orientation)
    }
}
