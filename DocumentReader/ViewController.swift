import UIKit

/// Sample host for DocSDK.
///
/// Init (background thread): getMachineCode → setActivation → initSDK.
/// Replace licenseKey with an … key issued for **your** bundle identifier.
///
/// Home: wide Camera + Gallery / About tiles
class ViewController: UIViewController {
    /// Demo license for bundle id `com.identixia.documentreader.app`.
    private let licenseKey =
        "pyyR2AECGxM88KoV67kjyUExX1uq3nOlD0x6wYmAdcdxHmEAAABH0F0Fpfsrb2kutZhsGTkFIsIlA5yVxSr7oDJ8PdaqJwG8RmkUXj/Iy7rZGrmB76Rk4/wTXtU8RYM8BB7Hfth4YcoiSugRW4gnu9BUvSuXurTLj1d5vrux8px4Zywydd+KZwAwZQIwJKDo8577/v8VeG/+tdQTAMSPt4W/PEIOvFJJSXKaCOwO4wMhoxrtvVmfrlfLwjI1AjEA3rRazlaPTM4Oi21gKYpw6B0ll5MxEyrKdKO7QbUmxwL/if8DfL8ZwBwJI85ByH8X   "

    private let licenseChip = UILabel()
    private let statusChip = UILabel()
    private var sdkReady = false
    private var loadingAlert: UIAlertController?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = IXColor.bg
        navigationController?.setNavigationBarHidden(true, animated: false)
        setupHome()
        activateSDK()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    private func setupHome() {
        licenseChip.text = "License: …"
        licenseChip.textColor = IXColor.text
        licenseChip.font = .systemFont(ofSize: 13)
        licenseChip.numberOfLines = 2
        licenseChip.backgroundColor = IXColor.surface
        licenseChip.layer.cornerRadius = 20
        licenseChip.layer.borderWidth = 1
        licenseChip.layer.borderColor = IXColor.stroke.cgColor
        licenseChip.clipsToBounds = true

        statusChip.text = "Loading…"
        statusChip.textColor = IXColor.onAccent
        statusChip.font = .systemFont(ofSize: 13, weight: .semibold)
        statusChip.textAlignment = .center
        statusChip.backgroundColor = IXColor.statusInfo
        statusChip.layer.cornerRadius = 20
        statusChip.clipsToBounds = true

        let licenseBox = chipBox(licenseChip)
        let statusBox = chipBox(statusChip)

        let topRow = UIStackView(arrangedSubviews: [licenseBox, statusBox])
        topRow.axis = .horizontal
        topRow.spacing = 14
        topRow.alignment = .fill
        topRow.distribution = .fill
        statusBox.setContentHuggingPriority(.required, for: .horizontal)
        statusBox.setContentCompressionResistancePriority(.required, for: .horizontal)

        let camera = makePrimaryTile(
            title: "Camera",
            systemImage: "camera.fill",
            action: #selector(openCamera)
        )

        let gallery = makeSecondaryTile(
            title: "Gallery",
            systemImage: "photo.on.rectangle",
            action: #selector(openGallery)
        )
        let about = makeSecondaryTile(
            title: "About",
            systemImage: "info.circle",
            action: #selector(openAbout)
        )

        let secondaryRow = UIStackView(arrangedSubviews: [gallery, about])
        secondaryRow.axis = .horizontal
        secondaryRow.spacing = 14
        secondaryRow.distribution = .fillEqually
        secondaryRow.heightAnchor.constraint(equalToConstant: 124).isActive = true

        let body = UIStackView(arrangedSubviews: [topRow, camera, secondaryRow])
        body.axis = .vertical
        body.spacing = 14
        body.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(body)

        camera.setContentHuggingPriority(.defaultLow, for: .vertical)
        NSLayoutConstraint.activate([
            body.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            body.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            body.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            body.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            topRow.heightAnchor.constraint(greaterThanOrEqualToConstant: 40),
            statusBox.widthAnchor.constraint(greaterThanOrEqualToConstant: 88),
            camera.heightAnchor.constraint(greaterThanOrEqualToConstant: 248),
        ])
    }

    private func chipBox(_ label: UILabel) -> UIView {
        label.translatesAutoresizingMaskIntoConstraints = false
        let box = UIView()
        box.backgroundColor = label.backgroundColor
        box.layer.cornerRadius = label.layer.cornerRadius
        box.layer.borderWidth = label.layer.borderWidth
        box.layer.borderColor = label.layer.borderColor
        box.clipsToBounds = true
        label.backgroundColor = .clear
        label.layer.borderWidth = 0
        box.addSubview(label)
        box.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: box.topAnchor, constant: 8),
            label.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: 12),
            label.trailingAnchor.constraint(equalTo: box.trailingAnchor, constant: -12),
            label.bottomAnchor.constraint(equalTo: box.bottomAnchor, constant: -8),
        ])
        return box
    }

    private func makePrimaryTile(title: String, systemImage: String, action: Selector) -> UIControl {
        let card = UIControl()
        card.backgroundColor = IXColor.accent
        card.layer.cornerRadius = 22
        card.clipsToBounds = true
        card.addTarget(self, action: action, for: .touchUpInside)
        card.addTarget(self, action: #selector(tileHighlight(_:)), for: [.touchDown, .touchDragEnter])
        card.addTarget(self, action: #selector(tileUnhighlight(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel, .touchDragExit])
        card.translatesAutoresizingMaskIntoConstraints = false

        let icon = UIImageView(image: UIImage(systemName: systemImage))
        icon.tintColor = .white
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false

        let label = UILabel()
        label.text = title
        label.textColor = .white
        label.font = .systemFont(ofSize: 22, weight: .bold)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false

        let col = UIStackView(arrangedSubviews: [icon, label])
        col.axis = .vertical
        col.alignment = .center
        col.spacing = 12
        col.isUserInteractionEnabled = false
        col.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(col)

        NSLayoutConstraint.activate([
            icon.widthAnchor.constraint(equalToConstant: 72),
            icon.heightAnchor.constraint(equalToConstant: 72),
            col.centerXAnchor.constraint(equalTo: card.centerXAnchor),
            col.centerYAnchor.constraint(equalTo: card.centerYAnchor),
        ])
        return card
    }

    private func makeSecondaryTile(title: String, systemImage: String, action: Selector) -> UIControl {
        let card = UIControl()
        card.backgroundColor = IXColor.surface
        card.layer.cornerRadius = 20
        card.layer.borderWidth = 1
        card.layer.borderColor = IXColor.stroke.cgColor
        card.clipsToBounds = true
        card.addTarget(self, action: action, for: .touchUpInside)
        card.addTarget(self, action: #selector(tileHighlight(_:)), for: [.touchDown, .touchDragEnter])
        card.addTarget(self, action: #selector(tileUnhighlight(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel, .touchDragExit])

        let icon = UIImageView(image: UIImage(systemName: systemImage))
        icon.tintColor = IXColor.accent
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false

        let label = UILabel()
        label.text = title
        label.textColor = IXColor.text
        label.font = .systemFont(ofSize: 13, weight: .semibold)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false

        let col = UIStackView(arrangedSubviews: [icon, label])
        col.axis = .vertical
        col.alignment = .center
        col.spacing = 6
        col.isUserInteractionEnabled = false
        col.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(col)

        NSLayoutConstraint.activate([
            icon.widthAnchor.constraint(equalToConstant: 36),
            icon.heightAnchor.constraint(equalToConstant: 36),
            col.centerXAnchor.constraint(equalTo: card.centerXAnchor),
            col.centerYAnchor.constraint(equalTo: card.centerYAnchor),
        ])
        return card
    }

    @objc private func tileHighlight(_ sender: UIControl) {
        sender.alpha = 0.75
    }

    @objc private func tileUnhighlight(_ sender: UIControl) {
        sender.alpha = 1
    }

    private func activateSDK() {
        updateStatus("Loading…", color: IXColor.statusInfo)
        DispatchQueue.global(qos: .userInitiated).async {
            let machine = DocSDK.getMachineCode()
            let act = Int(DocSDK.setActivation(self.licenseKey))
            let initRc = act == 0 ? Int(DocSDK.initSDK()) : act
            self.sdkReady = initRc == 0
            NSLog(
                "DocSDKDemo machine=%@ init=%d ready=%@",
                machine, initRc, self.sdkReady ? "y" : "n"
            )
            DispatchQueue.main.async {
                if self.sdkReady {
                    let label = LicenseStatus.current().label
                    self.licenseChip.text = "License: \(label)"
                    self.updateStatus("Ready", color: IXColor.statusOk)
                    self.maybeSelfTest()
                } else {
                    let msg: String
                    switch initRc {
                    case 1: msg = "Invalid license"
                    case 2: msg = "License expired"
                    case 3: msg = "SDK not activated"
                    case 4: msg = "Initialization failed"
                    case 5: msg = "No database found"
                    case 6: msg = "Database loading error"
                    default: msg = "Not ready"
                    }
                    self.licenseChip.text = "License: —"
                    self.updateStatus(msg, color: IXColor.statusError)
                }
            }
        }
    }

    private func updateStatus(_ text: String, color: UIColor) {
        statusChip.text = text
        statusChip.textColor = IXColor.onAccent
        statusChip.superview?.backgroundColor = color
    }

    private func ensureReady() -> Bool {
        if sdkReady { return true }
        presentAlert("SDK is not ready")
        return false
    }

    @objc private func openCamera() {
        guard ensureReady() else { return }
        let vc = CameraViewController()
        vc.modalPresentationStyle = .fullScreen
        present(vc, animated: true)
    }

    @objc private func openGallery() {
        guard ensureReady() else { return }
        navigationController?.pushViewController(GalleryViewController(), animated: true)
    }

    @objc private func openAbout() {
        navigationController?.pushViewController(AboutViewController(), animated: true)
    }

    private func recognizeAndShow(_ image: UIImage) {
        showBusy("Processing image")
        DispatchQueue.global(qos: .userInitiated).async {
            let t0 = CFAbsoluteTimeGetCurrent()
            DocSdkSession.startGallery()
            let status = LicenseStatus.current()
            let deny = status.denyMessage(wantRecognition: true, wantAuthenticity: true)
            let json = DocSDK.recognize(
                image,
                authenticityMode: AppSettings.authenticityMode(licenseAllows: status.authenticity)
            )
            let ms = Int((CFAbsoluteTimeGetCurrent() - t0) * 1000)
            let hasTimeout = json.localizedCaseInsensitiveContains("timeout")
            let hasOcr = json.contains("\"ocr\"")
            let hasMrz = json.contains("\"mrz\"")
            NSLog(
                "DocSDKDemo recognize ms=%d len=%d timeout=%d ocr=%d mrz=%d head=%@",
                ms, json.count,
                hasTimeout ? 1 : 0,
                hasOcr ? 1 : 0,
                hasMrz ? 1 : 0,
                String(json.prefix(240)) as NSString
            )
            if let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                let meta = docs.appendingPathComponent("last_recognize_meta.txt")
                let body = docs.appendingPathComponent("last_recognize.json")
                let summary =
                    "ms=\(ms) len=\(json.count) timeout=\(hasTimeout) ocr=\(hasOcr) mrz=\(hasMrz)\n"
                    + "head=\(String(json.prefix(400)))\n"
                try? summary.write(to: meta, atomically: true, encoding: .utf8)
                try? json.write(to: body, atomically: true, encoding: .utf8)
            }
            DispatchQueue.main.async {
                self.hideBusy {
                    if let deny, !deny.isEmpty {
                        self.presentAlert(deny)
                    }
                    guard let nav = self.navigationController else { return }
                    nav.pushViewController(ResultViewController(json: json), animated: true)
                }
            }
        }
    }

    /// Hidden self-test: Xcode/env `process_path` = absolute path to a JPEG on device.
    private func maybeSelfTest() {
        guard sdkReady else { return }
        guard let path = ProcessInfo.processInfo.environment["process_path"], !path.isEmpty else { return }
        let url = URL(fileURLWithPath: path)
        guard let image = UIImage.loadForGallery(url: url) else {
            NSLog("DocSDKDemo self-test could not decode %@", path)
            return
        }
        NSLog("DocSDKDemo self-test start path=%@", path)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.recognizeAndShow(image)
        }
    }

    private func showBusy(_ msg: String) {
        if loadingAlert != nil { return }
        let alert = UIAlertController(title: nil, message: "\n\(msg)", preferredStyle: .alert)
        let spinner = UIActivityIndicatorView(style: .large)
        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.color = IXColor.accent
        spinner.startAnimating()
        alert.view.addSubview(spinner)
        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: alert.view.centerXAnchor),
            spinner.topAnchor.constraint(equalTo: alert.view.topAnchor, constant: 16),
        ])
        present(alert, animated: true)
        loadingAlert = alert
    }

    private func hideBusy(completion: (() -> Void)? = nil) {
        guard let alert = loadingAlert else {
            completion?()
            return
        }
        loadingAlert = nil
        alert.dismiss(animated: true, completion: completion)
    }

    private func presentAlert(_ msg: String) {
        let alert = UIAlertController(title: nil, message: msg, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
