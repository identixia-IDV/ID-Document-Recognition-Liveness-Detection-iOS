import UIKit

/// Gallery still recognition — Front + optional Back vertical stack.
final class GalleryViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    private var frontImage: UIImage?
    private var backImage: UIImage?
    private var frontName = "Front"
    private var backName = "Back (optional)"
    private var pickingBack = false
    private var loadingAlert: UIAlertController?

    private let frontTile = GalleryTile(title: "Front")
    private let backTile = GalleryTile(title: "Back")
    private let frontNameLabel = UILabel()
    private let backNameLabel = UILabel()
    private let recognizeButton = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = IXColor.bg
        title = "From Gallery"
        applyNavAppearance()

        frontTile.onPick = { [weak self] in
            self?.pickingBack = false
            self?.presentPicker()
        }
        frontTile.onClear = { [weak self] in
            self?.frontImage = nil
            self?.frontName = "Front"
            self?.frontTile.setImage(nil)
            self?.frontNameLabel.text = self?.frontName
            self?.updateRecognizeEnabled()
        }
        backTile.onPick = { [weak self] in
            self?.pickingBack = true
            self?.presentPicker()
        }
        backTile.onClear = { [weak self] in
            self?.backImage = nil
            self?.backName = "Back (optional)"
            self?.backTile.setImage(nil)
            self?.backNameLabel.text = self?.backName
        }

        frontNameLabel.text = frontName
        frontNameLabel.textColor = IXColor.muted
        frontNameLabel.font = .systemFont(ofSize: 12)
        frontNameLabel.textAlignment = .center
        frontNameLabel.lineBreakMode = .byTruncatingMiddle

        backNameLabel.text = backName
        backNameLabel.textColor = IXColor.muted
        backNameLabel.font = .systemFont(ofSize: 12)
        backNameLabel.textAlignment = .center
        backNameLabel.lineBreakMode = .byTruncatingMiddle

        recognizeButton.setTitle("Recognize", for: .normal)
        recognizeButton.setTitleColor(.white, for: .normal)
        recognizeButton.backgroundColor = IXColor.accent
        recognizeButton.layer.cornerRadius = 28
        recognizeButton.clipsToBounds = true
        recognizeButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        recognizeButton.addTarget(self, action: #selector(runRecognize), for: .touchUpInside)
        recognizeButton.isEnabled = false
        recognizeButton.alpha = 0.45

        let frontCol = UIStackView(arrangedSubviews: [frontTile, frontNameLabel])
        frontCol.axis = .vertical
        frontCol.spacing = 6

        let backCol = UIStackView(arrangedSubviews: [backTile, backNameLabel])
        backCol.axis = .vertical
        backCol.spacing = 6

        let stack = UIStackView(arrangedSubviews: [frontCol, backCol, recognizeButton])
        stack.axis = .vertical
        stack.spacing = 14
        stack.alignment = .fill
        stack.distribution = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false

        frontTile.heightAnchor.constraint(equalToConstant: 176).isActive = true
        backTile.heightAnchor.constraint(equalToConstant: 176).isActive = true
        recognizeButton.heightAnchor.constraint(equalToConstant: 56).isActive = true

        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
        ])
    }

    private func applyNavAppearance() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = IXColor.bg
        appearance.titleTextAttributes = [.foregroundColor: IXColor.text]
        navigationController?.setNavigationBarHidden(false, animated: false)
        navigationController?.navigationBar.standardAppearance = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance
        navigationController?.navigationBar.tintColor = IXColor.accent
    }

    private func updateRecognizeEnabled() {
        let ok = frontImage != nil
        recognizeButton.isEnabled = ok
        recognizeButton.alpha = ok ? 1 : 0.45
    }

    private func presentPicker() {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.delegate = self
        present(picker, animated: true)
    }

    func imagePickerController(
        _ picker: UIImagePickerController,
        didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
    ) {
        picker.dismiss(animated: true)
        let image: UIImage?
        var name = pickingBack ? "Back" : "Front"
        if let url = info[.imageURL] as? URL {
            image = UIImage.loadForGallery(url: url)
            name = url.lastPathComponent
        } else if let original = info[.originalImage] as? UIImage,
                  let data = original.jpegData(compressionQuality: 0.95) ?? original.pngData() {
            image = UIImage.loadForGallery(data: data)
            name = "Photo"
        } else {
            image = (info[.originalImage] as? UIImage)?.fixOrientation().scaledForGallery()
            name = "Photo"
        }
        guard let image else { return }
        if pickingBack {
            backImage = image
            backName = name
            backTile.setImage(image)
            backNameLabel.text = backName
        } else {
            frontImage = image
            frontName = name
            frontTile.setImage(image)
            frontNameLabel.text = frontName
            updateRecognizeEnabled()
        }
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }

    @objc private func runRecognize() {
        guard let front = frontImage else { return }
        let back = backImage
        recognizeButton.isEnabled = false
        showBusy("Processing image")
        DispatchQueue.global(qos: .userInitiated).async {
            let t0 = CFAbsoluteTimeGetCurrent()
            DocSdkSession.startGallery()
            let status = LicenseStatus.current()
            let deny = status.denyMessage(wantRecognition: AppSettings.wantRecognition, wantAuthenticity: AppSettings.wantAuthenticity)
            let json = DocSDK.recognizeFront(
                front,
                back: back,
                authenticityMode: AppSettings.authenticityMode(licenseAllows: status.authenticity)
            )
            let ms = Int((CFAbsoluteTimeGetCurrent() - t0) * 1000)
            let hasTimeout = json.localizedCaseInsensitiveContains("timeout")
            let hasOcr = json.contains("\"ocr\"")
            let hasMrz = json.contains("\"mrz\"")
            NSLog(
                "DocSDKDemo gallery recognize ms=%d len=%d timeout=%d ocr=%d mrz=%d",
                ms, json.count, hasTimeout ? 1 : 0, hasOcr ? 1 : 0, hasMrz ? 1 : 0
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
                    self.updateRecognizeEnabled()
                    if let deny, !deny.isEmpty {
                        let alert = UIAlertController(title: nil, message: deny, preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                            guard let nav = self.navigationController else { return }
                            nav.pushViewController(ResultViewController(json: json), animated: true)
                        })
                        self.present(alert, animated: true)
                        return
                    }
                    guard let nav = self.navigationController else { return }
                    nav.pushViewController(ResultViewController(json: json), animated: true)
                }
            }
        }
    }

    private func showBusy(_ msg: String) {
        if loadingAlert != nil { return }
        let alert = UIAlertController(title: nil, message: msg, preferredStyle: .alert)
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
}

private final class GalleryTile: UIView {
    var onPick: (() -> Void)?
    var onClear: (() -> Void)?

    private let placeholder = UILabel()
    private let preview = UIImageView()
    private let clearButton = UIButton(type: .system)

    init(title: String) {
        super.init(frame: .zero)
        backgroundColor = IXColor.surface
        layer.cornerRadius = 22
        layer.borderWidth = 1
        layer.borderColor = IXColor.stroke.cgColor
        clipsToBounds = true

        placeholder.text = title
        placeholder.textColor = IXColor.muted
        placeholder.font = .systemFont(ofSize: 13)
        placeholder.textAlignment = .center

        preview.contentMode = .scaleAspectFit
        preview.backgroundColor = .clear
        preview.isHidden = true

        let xConfig = UIImage.SymbolConfiguration(pointSize: 12, weight: .bold)
        clearButton.setImage(UIImage(systemName: "xmark", withConfiguration: xConfig), for: .normal)
        clearButton.tintColor = IXColor.text
        clearButton.backgroundColor = IXColor.surface
        clearButton.layer.cornerRadius = 14
        clearButton.layer.borderWidth = 1
        clearButton.layer.borderColor = IXColor.stroke.cgColor
        clearButton.isHidden = true
        clearButton.addTarget(self, action: #selector(clearTapped), for: .touchUpInside)

        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(pickTapped(_:))))

        [placeholder, preview, clearButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            addSubview($0)
        }

        NSLayoutConstraint.activate([
            placeholder.centerXAnchor.constraint(equalTo: centerXAnchor),
            placeholder.centerYAnchor.constraint(equalTo: centerYAnchor),
            preview.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            preview.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            preview.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            preview.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6),
            clearButton.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            clearButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            clearButton.widthAnchor.constraint(equalToConstant: 28),
            clearButton.heightAnchor.constraint(equalToConstant: 28),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setImage(_ image: UIImage?) {
        preview.image = image
        let has = image != nil
        preview.isHidden = !has
        placeholder.isHidden = has
        clearButton.isHidden = !has
    }

    @objc private func pickTapped(_ gesture: UITapGestureRecognizer) {
        let point = gesture.location(in: self)
        if !clearButton.isHidden, clearButton.frame.insetBy(dx: -8, dy: -8).contains(point) {
            return
        }
        onPick?()
    }

    @objc private func clearTapped() {
        onClear?()
    }
}
