import UIKit

final class AboutViewController: UIViewController {
    private let machineLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = IXColor.bg
        title = "About"
        applyNavAppearance()

        let logo = UIButton(type: .custom)
        logo.setImage(UIImage(named: "IdentixiaLogo")?.withRenderingMode(.alwaysOriginal), for: .normal)
        logo.imageView?.contentMode = .scaleAspectFit
        logo.contentHorizontalAlignment = .fill
        logo.contentVerticalAlignment = .fill
        logo.adjustsImageWhenHighlighted = true
        logo.accessibilityLabel = "Identixia"
        logo.addTarget(self, action: #selector(openSite), for: .touchUpInside)
        logo.translatesAutoresizingMaskIntoConstraints = false

        let licenseLabel = UILabel()
        licenseLabel.text = "License: …"
        licenseLabel.textColor = IXColor.text
        licenseLabel.font = .systemFont(ofSize: 13)
        licenseLabel.numberOfLines = 0
        let licenseCard = surfaceCard(licenseLabel)

        let logoWrap = UIView()
        logoWrap.addSubview(logo)
        NSLayoutConstraint.activate([
            logo.leadingAnchor.constraint(equalTo: logoWrap.leadingAnchor),
            logo.trailingAnchor.constraint(equalTo: logoWrap.trailingAnchor),
            logo.topAnchor.constraint(equalTo: logoWrap.topAnchor),
            logo.bottomAnchor.constraint(equalTo: logoWrap.bottomAnchor),
            logo.heightAnchor.constraint(equalToConstant: 72),
        ])

        machineLabel.text = "…"
        machineLabel.textColor = IXColor.text
        machineLabel.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        machineLabel.numberOfLines = 0
        machineLabel.lineBreakMode = .byCharWrapping
        let machineCard = surfaceCard(machineLabel)

        let copyButton = UIButton(type: .system)
        copyButton.setTitle("Copy", for: .normal)
        copyButton.setTitleColor(.white, for: .normal)
        copyButton.backgroundColor = IXColor.accent
        copyButton.layer.cornerRadius = 24
        copyButton.clipsToBounds = true
        copyButton.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
        copyButton.addTarget(self, action: #selector(copyMachine), for: .touchUpInside)

        let siteButton = UIButton(type: .system)
        siteButton.setTitle("identixia.com", for: .normal)
        siteButton.setTitleColor(IXColor.accent, for: .normal)
        siteButton.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
        siteButton.backgroundColor = IXColor.surface
        siteButton.layer.cornerRadius = 26
        siteButton.clipsToBounds = true
        siteButton.layer.borderWidth = 1
        siteButton.layer.borderColor = IXColor.stroke.cgColor
        siteButton.addTarget(self, action: #selector(openSite), for: .touchUpInside)

        let col = UIStackView(arrangedSubviews: [logoWrap, licenseCard, machineCard, copyButton, siteButton])
        col.axis = .vertical
        col.spacing = 16
        col.alignment = .fill
        col.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(col)

        NSLayoutConstraint.activate([
            col.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            col.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            col.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            copyButton.heightAnchor.constraint(equalToConstant: 48),
            siteButton.heightAnchor.constraint(equalToConstant: 52),
        ])

        let appId = Bundle.main.bundleIdentifier ?? "—"
        machineLabel.text = appId

        DispatchQueue.global(qos: .userInitiated).async {
            let status = LicenseStatus.current()
            let text = "License: \(status.label)"
            DispatchQueue.main.async {
                licenseLabel.text = text
            }
        }
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

    private func surfaceCard(_ label: UILabel) -> UIView {
        label.translatesAutoresizingMaskIntoConstraints = false
        let box = UIView()
        box.backgroundColor = IXColor.surface
        box.layer.cornerRadius = 22
        box.layer.borderWidth = 1
        box.layer.borderColor = IXColor.stroke.cgColor
        box.clipsToBounds = true
        box.addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: box.topAnchor, constant: 16),
            label.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: box.trailingAnchor, constant: -16),
            label.bottomAnchor.constraint(equalTo: box.bottomAnchor, constant: -16),
        ])
        return box
    }

    @objc private func copyMachine() {
        let value = machineLabel.text ?? ""
        UIPasteboard.general.string = value
        let alert = UIAlertController(title: nil, message: "Copied", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    @objc private func openSite() {
        if let url = URL(string: "https://identixia.com") {
            UIApplication.shared.open(url)
        }
    }
}
