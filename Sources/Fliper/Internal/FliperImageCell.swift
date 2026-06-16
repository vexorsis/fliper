import UIKit

protocol FliperImageCellDelegate: AnyObject {
    func cellZoomStateDidChange(_ cell: FliperImageCell, isZoomed: Bool)
    func cellDidLongPress(_ cell: FliperImageCell, point: CGPoint)
}

final class FliperImageCell: UICollectionViewCell {
    weak var cellDelegate: FliperImageCellDelegate?

    let scrollView = UIScrollView()
    let imageView = UIImageView()

    private var maxZoomScale: CGFloat = 5.0
    private var doubleTapZoomScale: CGFloat = 2.0
    private var isZoomed: Bool = false

    private let doubleTapGesture = UITapGestureRecognizer()
    private let longPressGesture = UILongPressGestureRecognizer()

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
        scrollView.layer.masksToBounds = false
        scrollView.contentInsetAdjustmentBehavior = .never

        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true

        contentView.addSubview(scrollView)
        scrollView.addSubview(imageView)
    }

    private func setupGestures() {
        doubleTapGesture.numberOfTapsRequired = 2
        doubleTapGesture.addTarget(self, action: #selector(handleDoubleTap(_:)))
        scrollView.addGestureRecognizer(doubleTapGesture)

        longPressGesture.minimumPressDuration = 0.5
        longPressGesture.addTarget(self, action: #selector(handleLongPress(_:)))
        scrollView.addGestureRecognizer(longPressGesture)
    }

    func configure(image: UIImage, maxZoomScale: CGFloat, doubleTapZoomScale: CGFloat) {
        self.maxZoomScale = maxZoomScale
        self.doubleTapZoomScale = doubleTapZoomScale
        scrollView.maximumZoomScale = maxZoomScale
        imageView.image = image
        setNeedsLayout()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.image = nil
        resetZoom()
    }

    func resetZoom() {
        scrollView.setZoomScale(1.0, animated: false)
        scrollView.contentOffset = .zero
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
            x: max(0, (screenSize.width - fitWidth) / 2.0),
            y: max(0, (screenSize.height - fitHeight) / 2.0),
            width: fitWidth,
            height: fitHeight
        )

        scrollView.contentSize = CGSize(
            width: max(screenSize.width, fitWidth),
            height: max(screenSize.height, fitHeight)
        )
    }

    @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        let point = gesture.location(in: imageView)
        guard imageView.bounds.contains(point) else { return }

        if scrollView.zoomScale > 1.0 {
            scrollView.setZoomScale(1.0, animated: true)
        } else {
            scrollView.maximumZoomScale = doubleTapZoomScale
            scrollView.zoom(to: CGRect(x: point.x, y: point.y, width: 1, height: 1), animated: true)
        }
    }

    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }
        let point = gesture.location(in: imageView)
        cellDelegate?.cellDidLongPress(self, point: point)
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

        if scrollView.zoomScale <= 1.0 {
            scrollView.maximumZoomScale = maxZoomScale
        }
    }

    private func centerImageViewAfterZoom() {
        let screenSize = scrollView.bounds.size
        let contentSize = imageView.frame.size

        var offsetX: CGFloat = 0
        var offsetY: CGFloat = 0

        if contentSize.width < screenSize.width {
            offsetX = (screenSize.width - contentSize.width) / 2.0
        }
        if contentSize.height < screenSize.height {
            offsetY = (screenSize.height - contentSize.height) / 2.0
        }

        imageView.center = CGPoint(
            x: max(contentSize.width / 2.0, screenSize.width / 2.0) + offsetX,
            y: max(contentSize.height / 2.0, screenSize.height / 2.0) + offsetY
        )
    }
}
