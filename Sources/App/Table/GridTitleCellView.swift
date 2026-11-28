import AppKit
import GrabberKit

final class OrbSpinnerView: NSView {
    private let gradientLayer = CAGradientLayer()
    private var rotationAnimation: CABasicAnimation?
    private var isAnimating = false
    private let spinnerSize: CGFloat = 14

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        wantsLayer = true
        layer?.masksToBounds = true

        gradientLayer.type = .conic
        gradientLayer.colors = [
            NSColor(hex: "#5EF2C8").cgColor,
            NSColor(hex: "#8B7BFF").cgColor,
            NSColor(hex: "#FF7A6B").cgColor,
            NSColor(hex: "#5EF2C8").cgColor
        ]
        gradientLayer.startPoint = CGPoint(x: 0.5, y: 0.5)
        gradientLayer.endPoint = CGPoint(x: 0.5, y: 0.5)
        gradientLayer.frame = CGRect(x: 0, y: 0, width: spinnerSize, height: spinnerSize)
        layer?.addSublayer(gradientLayer)

        let maskLayer = CAShapeLayer()
        maskLayer.path = CGPath(ellipseIn: CGRect(x: 0, y: 0, width: spinnerSize, height: spinnerSize), transform: nil)
        gradientLayer.mask = maskLayer

        checkReducedMotion()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(checkReducedMotion),
            name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
            object: nil
        )
    }

    @objc fileprivate func checkReducedMotion() {
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        if reduceMotion {
            stopAnimating()
        } else if !isAnimating {
            startAnimating()
        }
    }

    private func startAnimating() {
        guard rotationAnimation == nil else { return }
        let animation = CABasicAnimation(keyPath: "transform.rotation.z")
        animation.fromValue = 0
        animation.toValue = 2 * Double.pi
        animation.duration = 2.0
        animation.repeatCount = .infinity
        animation.isRemovedOnCompletion = false
        gradientLayer.add(animation, forKey: "rotation")
        rotationAnimation = animation
        isAnimating = true
    }

    private func stopAnimating() {
        gradientLayer.removeAnimation(forKey: "rotation")
        rotationAnimation = nil
        isAnimating = false
    }

    override func layout() {
        super.layout()
        gradientLayer.frame = CGRect(x: 0, y: 0, width: spinnerSize, height: spinnerSize)
        if let maskLayer = gradientLayer.mask as? CAShapeLayer {
            maskLayer.path = CGPath(ellipseIn: gradientLayer.frame, transform: nil)
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

extension NSColor {
    convenience init(hex: String) {
        let raw = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        guard let value = UInt64(raw, radix: 16), raw.count == 6 else {
            self.init(white: 0, alpha: 1)
            return
        }
        let red = CGFloat((value >> 16) & 0xFF) / 255
        let green = CGFloat((value >> 8) & 0xFF) / 255
        let blue = CGFloat(value & 0xFF) / 255
        self.init(srgbRed: red, green: green, blue: blue, alpha: 1)
    }
}

final class GridTitleCellView: NSTableCellView {
    private let dot = NSView()
    private let thumbnail = GridThumbnailView()
    private let label = NSTextField(labelWithString: "")
    private let spinner = OrbSpinnerView()
    private var labelLeadingToThumbnail: NSLayoutConstraint!
    private var labelLeadingToDot: NSLayoutConstraint!

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    func apply(
        title: String,
        state: JobState,
        tokens: DownloadsGridTokens,
        thumbnailURL: String? = nil,
        showThumbnail: Bool = false
    ) {
        label.stringValue = title
        label.font = tokens.cell
        label.textColor = tokens.text
        label.toolTip = title
        dot.layer?.backgroundColor = tokens.statusDotColor(for: state).cgColor

        let isRunning = state == .running || state == .probing
        spinner.isHidden = !isRunning
        dot.isHidden = isRunning
        if isRunning {
            spinner.checkReducedMotion()
        }

        thumbnail.isHidden = !showThumbnail
        labelLeadingToThumbnail.isActive = showThumbnail
        labelLeadingToDot.isActive = !showThumbnail
        if showThumbnail {
            thumbnail.apply(url: thumbnailURL, tokens: tokens)
        }
    }

    var cueColor: NSColor? {
        guard let color = dot.layer?.backgroundColor else { return nil }
        return NSColor(cgColor: color)
    }

    private func setup() {
        dot.wantsLayer = true
        dot.layer?.cornerRadius = 3
        label.drawsBackground = false
        label.isBordered = false
        label.lineBreakMode = .byTruncatingTail

        spinner.isHidden = true
        thumbnail.isHidden = true

        addSubview(dot)
        addSubview(thumbnail)
        addSubview(label)
        addSubview(spinner)
        dot.translatesAutoresizingMaskIntoConstraints = false
        thumbnail.translatesAutoresizingMaskIntoConstraints = false
        label.translatesAutoresizingMaskIntoConstraints = false
        spinner.translatesAutoresizingMaskIntoConstraints = false

        labelLeadingToThumbnail = label.leadingAnchor.constraint(
            equalTo: thumbnail.trailingAnchor, constant: 6
        )
        labelLeadingToDot = label.leadingAnchor.constraint(
            equalTo: dot.trailingAnchor, constant: 6
        )
        labelLeadingToDot.isActive = true

        NSLayoutConstraint.activate([
            dot.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            dot.centerYAnchor.constraint(equalTo: centerYAnchor),
            dot.widthAnchor.constraint(equalToConstant: 6),
            dot.heightAnchor.constraint(equalToConstant: 6),

            thumbnail.leadingAnchor.constraint(equalTo: dot.trailingAnchor, constant: 6),
            thumbnail.centerYAnchor.constraint(equalTo: centerYAnchor),
            thumbnail.widthAnchor.constraint(equalToConstant: 52),
            thumbnail.heightAnchor.constraint(equalToConstant: 30),

            spinner.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            spinner.centerYAnchor.constraint(equalTo: centerYAnchor),
            spinner.widthAnchor.constraint(equalToConstant: 14),
            spinner.heightAnchor.constraint(equalToConstant: 14),

            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            label.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }
}

// Loads a page picture off the main thread; a nil or failed load shows a plain placeholder.
final class GridThumbnailView: NSView {
    private static let cache: NSCache<NSString, NSImage> = {
        let cache = NSCache<NSString, NSImage>()
        cache.countLimit = 256
        return cache
    }()

    private let imageView = NSImageView()
    private let placeholder = NSView()
    private var currentURL: String?
    private var loadToken = UUID()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    func apply(url: String?, tokens: DownloadsGridTokens) {
        placeholder.layer?.backgroundColor = tokens.panel.cgColor
        placeholder.layer?.borderColor = tokens.stroke.cgColor
        guard url != currentURL else { return }
        currentURL = url
        loadToken = UUID()
        let token = loadToken
        imageView.image = nil
        placeholder.isHidden = false

        guard let url, let parsed = URL(string: url) else { return }
        if let cached = Self.cache.object(forKey: url as NSString) {
            imageView.image = cached
            placeholder.isHidden = true
            return
        }
        URLSession.shared.dataTask(with: parsed) { data, _, _ in
            guard let data, let image = NSImage(data: data) else { return }
            Self.cache.setObject(image, forKey: url as NSString)
            DispatchQueue.main.async { [weak self] in
                guard let self, loadToken == token else { return }
                imageView.image = image
                placeholder.isHidden = true
            }
        }.resume()
    }

    private func setup() {
        wantsLayer = true
        setAccessibilityHidden(true)
        placeholder.wantsLayer = true
        placeholder.layer?.cornerRadius = 4
        placeholder.layer?.borderWidth = 1
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.wantsLayer = true
        imageView.layer?.cornerRadius = 4
        imageView.layer?.masksToBounds = true

        addSubview(placeholder)
        addSubview(imageView)
        placeholder.translatesAutoresizingMaskIntoConstraints = false
        imageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            placeholder.leadingAnchor.constraint(equalTo: leadingAnchor),
            placeholder.trailingAnchor.constraint(equalTo: trailingAnchor),
            placeholder.topAnchor.constraint(equalTo: topAnchor),
            placeholder.bottomAnchor.constraint(equalTo: bottomAnchor),
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
}
