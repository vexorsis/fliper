import UIKit

protocol FliperImageCellDelegate: AnyObject {
    func cellZoomStateDidChange(_ cell: FliperImageCell, isZoomed: Bool)
}

final class FliperImageCell: UICollectionViewCell {
    weak var cellDelegate: FliperImageCellDelegate?

    let scrollView = UIScrollView()
    let imageView = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.addSubview(scrollView)
        scrollView.addSubview(imageView)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.image = nil
        scrollView.zoomScale = 1.0
        scrollView.contentOffset = .zero
    }
}
