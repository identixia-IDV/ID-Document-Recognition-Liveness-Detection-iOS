import UIKit

/// One-scroll result: identity, fields, checks, image strip, Raw JSON drawer.
final class ResultViewController: UIViewController {
    private let json: String
    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private let rawTextView = UITextView()
    private var rawExpanded = false

    init(json: String) {
        self.json = json
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = IXColor.bg
        title = "Result"
        applyNavAppearance()

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        view.addSubview(scrollView)

        contentStack.axis = .vertical
        contentStack.spacing = 20
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 20),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 20),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -20),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -20),
            contentStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -40),
        ])

        buildIdentity()
        buildOverall()
        buildFields()
        buildChecks()
        buildImages()
        buildRawDrawer()
    }

    private func applyNavAppearance() {
        navigationController?.setNavigationBarHidden(false, animated: false)
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = IXColor.bg
        appearance.titleTextAttributes = [.foregroundColor: IXColor.text]
        navigationController?.navigationBar.standardAppearance = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance
        navigationController?.navigationBar.tintColor = IXColor.accent
    }

    private func buildIdentity() {
        let ident = ResultParser.identityLine(json)
        let title = UILabel()
        title.text = ident.title
        title.font = .systemFont(ofSize: 20, weight: .semibold)
        title.textColor = IXColor.text
        title.numberOfLines = 0

        let status = UILabel()
        status.attributedText = Self.boldPrefix(ident.status, size: 13)
        status.numberOfLines = 0

        let counts = UILabel()
        counts.text = ident.counts
        counts.font = .systemFont(ofSize: 13)
        counts.textColor = IXColor.text
        counts.numberOfLines = 0

        let col = UIStackView(arrangedSubviews: [title, status, counts])
        col.axis = .vertical
        col.spacing = 4
        col.translatesAutoresizingMaskIntoConstraints = false

        let card = UIView()
        card.backgroundColor = IXColor.surface
        card.layer.cornerRadius = 8
        card.layer.borderWidth = 1
        card.layer.borderColor = IXColor.stroke.cgColor
        card.clipsToBounds = true
        card.addSubview(col)
        NSLayoutConstraint.activate([
            col.topAnchor.constraint(equalTo: card.topAnchor, constant: 10),
            col.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            col.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
            col.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -10),
        ])
        contentStack.addArrangedSubview(card)
    }

    private func buildOverall() {
        contentStack.addArrangedSubview(sectionTitle("Overall"))
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 0
        for row in ResultParser.overallResults(json) {
            let kind = bodyLabel(
                ResultParser.kindLabel(row.kind),
                muted: false
            )
            let resultChip = resultBadge(row.result)
            let line = UIStackView(arrangedSubviews: [kind, resultChip])
            line.axis = .horizontal
            line.alignment = .center
            line.spacing = 8
            line.isLayoutMarginsRelativeArrangement = true
            line.layoutMargins = UIEdgeInsets(top: 6, left: 0, bottom: 6, right: 0)
            kind.setContentHuggingPriority(.defaultLow, for: .horizontal)
            resultChip.setContentHuggingPriority(.required, for: .horizontal)
            stack.addArrangedSubview(line)
        }
        contentStack.addArrangedSubview(stack)
    }

    private func resultBadge(_ text: String) -> UIView {
        let wrap = UIView()
        wrap.backgroundColor = IXColor.surface
        wrap.layer.cornerRadius = 11
        wrap.layer.borderWidth = 1
        wrap.layer.borderColor = IXColor.stroke.cgColor
        wrap.setContentHuggingPriority(.required, for: .horizontal)

        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = text
        label.font = .systemFont(ofSize: 12, weight: .semibold)
        switch text.lowercased() {
        case "pass", "ok", "true", "success":
            label.textColor = IXColor.accent
        case "fail", "false", "error":
            label.textColor = IXColor.statusError
        default:
            label.textColor = IXColor.muted
        }
        wrap.addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: wrap.topAnchor, constant: 3),
            label.bottomAnchor.constraint(equalTo: wrap.bottomAnchor, constant: -3),
            label.leadingAnchor.constraint(equalTo: wrap.leadingAnchor, constant: 10),
            label.trailingAnchor.constraint(equalTo: wrap.trailingAnchor, constant: -10),
        ])
        return wrap
    }

    private static func boldPrefix(_ text: String, size: CGFloat) -> NSAttributedString {
        let end = text.range(of: " ·")?.lowerBound ?? text.endIndex
        let out = NSMutableAttributedString(
            string: text,
            attributes: [
                .font: UIFont.systemFont(ofSize: size),
                .foregroundColor: IXColor.text,
            ]
        )
        out.addAttribute(
            .font,
            value: UIFont.systemFont(ofSize: size, weight: .bold),
            range: NSRange(text.startIndex..<end, in: text)
        )
        return out
    }

    private func buildFields() {
        contentStack.addArrangedSubview(sectionTitle("Fields"))
        let groups = ResultParser.fieldGroups(json)
        if groups.isEmpty {
            contentStack.addArrangedSubview(emptyLabel("No fields in this response"))
            return
        }
        for group in groups {
            contentStack.addArrangedSubview(groupHeader(ResultParser.sourceLabel(group.source), count: group.items.count))
            for item in group.items {
                contentStack.addArrangedSubview(fieldItem(item))
            }
        }
    }

    private func buildChecks() {
        contentStack.addArrangedSubview(sectionTitle("Checks"))
        let groups = ResultParser.checkGroups(json)
        if groups.isEmpty {
            contentStack.addArrangedSubview(emptyLabel("No checks in this response"))
            return
        }
        for group in groups {
            contentStack.addArrangedSubview(groupHeader(ResultParser.kindLabel(group.kind), count: group.items.count))
            for item in group.items {
                contentStack.addArrangedSubview(checkItem(item))
            }
        }
    }

    private func buildImages() {
        contentStack.addArrangedSubview(sectionTitle("Images"))
        let imgs = ResultParser.images(json)
        if imgs.isEmpty {
            contentStack.addArrangedSubview(emptyLabel("No images in this response"))
            return
        }

        let strip = UIStackView()
        strip.axis = .horizontal
        strip.spacing = 8
        strip.alignment = .top

        for item in imgs {
            strip.addArrangedSubview(imageThumb(item))
        }

        let hScroll = UIScrollView()
        hScroll.showsHorizontalScrollIndicator = true
        hScroll.translatesAutoresizingMaskIntoConstraints = false
        strip.translatesAutoresizingMaskIntoConstraints = false
        hScroll.addSubview(strip)
        NSLayoutConstraint.activate([
            strip.topAnchor.constraint(equalTo: hScroll.contentLayoutGuide.topAnchor),
            strip.leadingAnchor.constraint(equalTo: hScroll.contentLayoutGuide.leadingAnchor),
            strip.trailingAnchor.constraint(equalTo: hScroll.contentLayoutGuide.trailingAnchor),
            strip.bottomAnchor.constraint(equalTo: hScroll.contentLayoutGuide.bottomAnchor),
            strip.heightAnchor.constraint(equalTo: hScroll.frameLayoutGuide.heightAnchor),
            hScroll.heightAnchor.constraint(equalToConstant: 184),
        ])
        contentStack.addArrangedSubview(hScroll)
    }

    private func imageThumb(_ item: ResultImage) -> UIView {
        let col = UIStackView()
        col.axis = .vertical
        col.spacing = 4
        col.alignment = .center

        let iv = UIImageView(image: item.image)
        iv.contentMode = .scaleAspectFit
        iv.clipsToBounds = true
        iv.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            iv.widthAnchor.constraint(equalToConstant: 148),
            iv.heightAnchor.constraint(equalToConstant: 148),
        ])

        let cap = UILabel()
        cap.text = item.category
        cap.textColor = IXColor.muted
        cap.font = .systemFont(ofSize: 12)
        cap.textAlignment = .center
        cap.numberOfLines = 2
        cap.widthAnchor.constraint(equalToConstant: 148).isActive = true

        col.addArrangedSubview(iv)
        col.addArrangedSubview(cap)
        return col
    }

    private func buildRawDrawer() {
        let toggle = UIButton(type: .system)
        toggle.setTitle("Raw JSON", for: .normal)
        toggle.setTitleColor(IXColor.text, for: .normal)
        toggle.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
        toggle.contentHorizontalAlignment = .leading
        toggle.backgroundColor = IXColor.surface
        toggle.layer.cornerRadius = 22
        toggle.layer.borderWidth = 1
        toggle.layer.borderColor = IXColor.stroke.cgColor
        toggle.contentEdgeInsets = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        toggle.addTarget(self, action: #selector(toggleRaw), for: .touchUpInside)
        contentStack.addArrangedSubview(toggle)

        rawTextView.text = ResultParser.pretty(json)
        rawTextView.textColor = IXColor.text
        rawTextView.backgroundColor = IXColor.surface
        rawTextView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        rawTextView.isEditable = false
        rawTextView.isSelectable = true
        rawTextView.isScrollEnabled = false
        rawTextView.layer.cornerRadius = 22
        rawTextView.layer.borderWidth = 1
        rawTextView.layer.borderColor = IXColor.stroke.cgColor
        rawTextView.textContainerInset = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        rawTextView.textContainer.lineFragmentPadding = 0
        rawTextView.isHidden = true
        contentStack.addArrangedSubview(rawTextView)
    }

    @objc private func toggleRaw() {
        rawExpanded.toggle()
        rawTextView.isHidden = !rawExpanded
    }

    private func sectionTitle(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.textColor = IXColor.text
        label.font = .systemFont(ofSize: 15, weight: .semibold)
        return label
    }

    private func emptyLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.textColor = IXColor.muted
        label.font = .systemFont(ofSize: 13)
        label.numberOfLines = 0
        return label
    }

    private func groupHeader(_ text: String, count: Int) -> UIView {
        let row = UIStackView()
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 8
        row.isLayoutMarginsRelativeArrangement = true
        row.layoutMargins = UIEdgeInsets(top: 10, left: 0, bottom: 6, right: 0)

        let wrap = UIView()
        wrap.backgroundColor = IXColor.accent.withAlphaComponent(0.14)
        wrap.layer.cornerRadius = 11
        wrap.layer.masksToBounds = true
        wrap.layer.borderWidth = 1
        wrap.layer.borderColor = IXColor.accent.withAlphaComponent(0.35).cgColor
        wrap.setContentHuggingPriority(.required, for: .horizontal)

        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = text
        label.textColor = IXColor.accent
        label.font = .systemFont(ofSize: 11, weight: .bold)
        wrap.addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: wrap.topAnchor, constant: 3),
            label.bottomAnchor.constraint(equalTo: wrap.bottomAnchor, constant: -3),
            label.leadingAnchor.constraint(equalTo: wrap.leadingAnchor, constant: 10),
            label.trailingAnchor.constraint(equalTo: wrap.trailingAnchor, constant: -10),
        ])

        let countLabel = UILabel()
        countLabel.text = "\(count)"
        countLabel.textColor = IXColor.muted
        countLabel.font = .systemFont(ofSize: 12, weight: .semibold)

        row.addArrangedSubview(wrap)
        row.addArrangedSubview(countLabel)
        row.addArrangedSubview(UIView())
        return row
    }

    private func fieldItem(_ item: FieldItem) -> UIView {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 2
        stack.isLayoutMarginsRelativeArrangement = true
        stack.layoutMargins = UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)
        stack.addArrangedSubview(bodyLabel(item.id, muted: true, small: true))
        let value = bodyLabel(item.value, muted: false)
        value.font = .systemFont(ofSize: 15, weight: .medium)
        stack.addArrangedSubview(value)
        if !item.score.isEmpty {
            stack.addArrangedSubview(bodyLabel(item.score, muted: true, small: true))
        }
        return stack
    }

    private func checkItem(_ item: CheckItem) -> UIView {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 2
        stack.isLayoutMarginsRelativeArrangement = true
        stack.layoutMargins = UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)

        let row = UIStackView()
        row.axis = .horizontal
        row.alignment = .firstBaseline
        row.spacing = 12
        row.addArrangedSubview(bodyLabel(item.id, muted: false))
        let result = UILabel()
        result.text = item.result
        result.font = .systemFont(ofSize: 13)
        switch item.result {
        case "pass": result.textColor = IXColor.accent
        case "fail": result.textColor = IXColor.statusError
        default: result.textColor = IXColor.muted
        }
        result.setContentHuggingPriority(.required, for: .horizontal)
        row.addArrangedSubview(result)
        stack.addArrangedSubview(row)
        if !item.extra.isEmpty {
            stack.addArrangedSubview(bodyLabel(item.extra, muted: true, small: true))
        }
        return stack
    }

    private func bodyLabel(_ text: String, muted: Bool, accent: Bool = false, small: Bool = false) -> UILabel {
        let label = UILabel()
        label.text = text
        if accent {
            label.textColor = IXColor.accent
            label.font = .systemFont(ofSize: small ? 11 : 13)
        } else {
            label.textColor = muted ? IXColor.muted : IXColor.text
            label.font = .systemFont(ofSize: small ? 12 : 13)
        }
        label.numberOfLines = 0
        label.lineBreakMode = .byCharWrapping
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return label
    }
}
