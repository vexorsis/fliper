import UIKit

protocol FliperImageCellDelegate: AnyObject {
    func cellZoomStateDidChange(_ cell: FliperImageCell, isZoomed: Bool)
    func cellDidLongPress(_ cell: FliperImageCell, point: CGPoint)
    func cellDidTapRetry(_ cell: FliperImageCell)
}

final class FliperImageCell: UICollectionViewCell {
    weak var cellDelegate: FliperImageCellDelegate?

    let scrollView = UIScrollView()
    let imageView = UIImageView()

    private var maxZoomScale: CGFloat = 5.0
    private var doubleTapZoomScale: CGFloat = 2.0
    private var isZoomed: Bool = false
    private var hasThumbnail: Bool = false

    private let doubleTapGesture = UITapGestureRecognizer()
    private let longPressGesture = UILongPressGestureRecognizer()

    private let spinner = UIActivityIndicatorView(style: .whiteLarge)
    private let errorLabel = UILabel()
    private let retryButton = UIButton(type: .system)
    private let errorContainer = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        setupGestures()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupViews() {
        scrollView.delegate = self
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = maxZoomScale
        scrollView.decelerationRate = .fast
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .never

        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true

        contentView.addSubview(scrollView)
        scrollView.addSubview(imageView)

        spinner.hidesWhenStopped = true
        spinner.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(spinner)
        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])

        errorLabel.text = "Failed to load image"
        errorLabel.textColor = .white
        errorLabel.font = .preferredFont(forTextStyle: .subheadline)
        errorLabel.textAlignment = .center

        retryButton.setTitle("Retry", for: .normal)
        retryButton.setTitleColor(.white, for: .normal)
        retryButton.titleLabel?.font = .preferredFont(forTextStyle: .subheadline)
        retryButton.layer.borderColor = UIColor.white.cgColor
        retryButton.layer.borderWidth = 1.0
        retryButton.layer.cornerRadius = 6.0
        retryButton.contentEdgeInsets = UIEdgeInsets(top: 6, left: 16, bottom: 6, right: 16)
        retryButton.addTarget(self, action: #selector(handleRetry), for: .touchUpInside)

        let errorStack = UIStackView(arrangedSubviews: [errorLabel, retryButton])
        errorStack.axis = .vertical
        errorStack.spacing = 12
        errorStack.alignment = .center

        errorContainer.addSubview(errorStack)
        errorStack.translatesAutoresizingMaskIntoConstraints = false
        errorContainer.translatesAutoresizingMaskIntoConstraints = false
        errorContainer.isHidden = true
        contentView.addSubview(errorContainer)
        NSLayoutConstraint.activate([
            errorContainer.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            errorContainer.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            errorStack.topAnchor.constraint(equalTo: errorContainer.topAnchor),
            errorStack.bottomAnchor.constraint(equalTo: errorContainer.bottomAnchor),
            errorStack.leadingAnchor.constraint(equalTo: errorContainer.leadingAnchor),
            errorStack.trailingAnchor.constraint(equalTo: errorContainer.trailingAnchor)
        ])
    }

    private func setupGestures() {
        doubleTapGesture.numberOfTapsRequired = 2
        doubleTapGesture.addTarget(self, action: #selector(handleDoubleTap(_:)))
        scrollView.addGestureRecognizer(doubleTapGesture)

        longPressGesture.minimumPressDuration = 0.5
        longPressGesture.addTarget(self, action: #selector(handleLongPress(_:)))
        scrollView.addGestureRecognizer(longPressGesture)
    }

    func configure(item: FliperViewerItem, maxZoomScale: CGFloat, doubleTapZoomScale: CGFloat) {
        self.maxZoomScale = maxZoomScale
        self.doubleTapZoomScale = doubleTapZoomScale
        scrollView.maximumZoomScale = maxZoomScale

        switch item {
        case .image(let image):
            hasThumbnail = false
            imageView.image = image
            hideSpinnerAndError()
        case .url:
            hasThumbnail = false
            imageView.image = nil
            showLoading()
        case .imageAndURL(let thumbnail, _):
            hasThumbnail = true
            imageView.image = thumbnail
            showLoading()
        }

        setNeedsLayout()
    }

    func showLoading() {
        spinner.startAnimating()
        errorContainer.isHidden = true
    }

    func showError() {
        spinner.stopAnimating()
        errorContainer.isHidden = false
    }

    func setImage(_ image: UIImage) {
        spinner.stopAnimating()
        errorContainer.isHidden = true

        if hasThumbnail {
            let transition = CATransition()
            transition.duration = 0.25
            transition.type = .fade
            imageView.layer.add(transition, forKey: "crossfade")
        }
        imageView.image = image
        setNeedsLayout()
    }

    private func hideSpinnerAndError() {
        spinner.stopAnimating()
        errorContainer.isHidden = true
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.image = nil
        hasThumbnail = false
        hideSpinnerAndError()
        resetZoom()
    }

    func resetZoom() {
        scrollView.setZoomScale(1.0, animated: false)
        scrollView.contentOffset = .zero
        scrollView.contentInset = .zero
        updateZoomState()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        scrollView.frame = contentView.bounds
        layoutImageView()
    }

    private func layoutImageView() {
        guard let image = imageView.image else { return }
        let screenSize = scrollView.bounds.size
        let imageSize = image.size

        let widthRatio = screenSize.width / imageSize.width
        let heightRatio = screenSize.height / imageSize.height
        let scale = min(widthRatio, heightRatio)

        let fitWidth = imageSize.width * scale
        let fitHeight = imageSize.height * scale

        imageView.frame = CGRect(
            x: 0,
            y: 0,
            width: fitWidth,
            height: fitHeight
        )

        scrollView.contentSize = imageView.frame.size
        centerImageViewAfterZoom()
    }

    @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        let point = gesture.location(in: imageView)
        guard imageView.bounds.contains(point) else { return }

        if scrollView.zoomScale > 1.0 {
            scrollView.setZoomScale(1.0, animated: true)
        } else {
            let zoomRect = CGRect(x: point.x, y: point.y, width: 1, height: 1)
            let savedMaxZoom = scrollView.maximumZoomScale
            scrollView.maximumZoomScale = doubleTapZoomScale
            scrollView.zoom(to: zoomRect, animated: true)
            scrollView.maximumZoomScale = savedMaxZoom
        }
    }

    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }
        let point = gesture.location(in: imageView)
        cellDelegate?.cellDidLongPress(self, point: point)
    }

    @objc private func handleRetry() {
        cellDelegate?.cellDidTapRetry(self)
    }

    private func updateZoomState() {
        let zoomed = scrollView.zoomScale > 1.0
        if zoomed != isZoomed {
            isZoomed = zoomed
            cellDelegate?.cellZoomStateDidChange(self, isZoomed: zoomed)
        }
    }
}

extension FliperImageCell: UIScrollViewDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        imageView
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        centerImageViewAfterZoom()
        updateZoomState()
    }

    private func centerImageViewAfterZoom() {
        let boundsSize = scrollView.bounds.size
        let contentSize = imageView.frame.size
        var inset = UIEdgeInsets.zero
        if contentSize.width < boundsSize.width {
            inset.left = (boundsSize.width - contentSize.width) / 2.0
            inset.right = inset.left
        }
        if contentSize.height < boundsSize.height {
            inset.top = (boundsSize.height - contentSize.height) / 2.0
            inset.bottom = inset.top
        }
        scrollView.contentInset = inset
    }
}
