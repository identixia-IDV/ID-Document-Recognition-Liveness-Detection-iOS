import UIKit


/// Passport-ratio guide (125:88) plus optional locate corners overlay.
final class DocumentGuideView: UIView {
    private var detected: [CGPoint]?
    var locked: Bool = false {
        didSet { setNeedsDisplay() }
    }


    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        backgroundColor = .clear
    }


    required init?(coder: NSCoder) {
        super.init(coder: coder)
        isOpaque = false
        backgroundColor = .clear
    }


    func clearDetection() {
        detected = nil
        setNeedsDisplay()
    }


    func setDetectedCorners(_ corners: [CGPoint]?) {
        if let corners, corners.count >= 4, isUsable(corners) {
            detected = Array(corners.prefix(4))
        } else {
            detected = nil
        }
        setNeedsDisplay()
    }


    private func isUsable(_ corners: [CGPoint]) -> Bool {
        ResultParser.isPlausibleCardQuad(corners)
    }


    static func passportGuideRect(in bounds: CGRect) -> CGRect {
        let w = bounds.width
        let h = bounds.height
        guard w > 0, h > 0 else { return .zero }
        let ratio: CGFloat = 125.0 / 88.0
        var fw = w * 0.86
        var fh = fw / ratio
        if fh > h * 0.72 {
            fh = h * 0.72
            fw = fh * ratio
        }
        return CGRect(x: (w - fw) / 2, y: (h - fh) / 2, width: fw, height: fh)
    }


    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        let guide = DocumentGuideView.passportGuideRect(in: bounds)
        guard guide.width > 0, guide.height > 0 else { return }

        let path = UIBezierPath()
        if let corners = detected, corners.count >= 4 {
            path.move(to: corners[0])
            for p in corners.dropFirst() { path.addLine(to: p) }
            path.close()
        } else {
            path.append(UIBezierPath(roundedRect: guide, cornerRadius: 16))
        }

        IXColor.overlay.setFill()
        ctx.fill(bounds)
        ctx.setBlendMode(.clear)
        path.fill()
        ctx.setBlendMode(.normal)

        (locked ? IXColor.accent : IXColor.muted).setStroke()
        path.lineWidth = locked ? 10 : 6
        path.lineJoinStyle = .round
        path.stroke()
    }
}
