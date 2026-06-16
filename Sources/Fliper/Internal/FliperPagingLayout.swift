import UIKit

final class FliperPagingLayout: UICollectionViewFlowLayout {
    var interPageSpacing: CGFloat = 20.0

    override func prepare() {
        super.prepare()
        guard let collectionView = collectionView else { return }
        scrollDirection = .horizontal
        itemSize = collectionView.bounds.size
        minimumLineSpacing = 0
        minimumInteritemSpacing = 0
    }

    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        guard let superAttributes = super.layoutAttributesForElements(in: rect)?
            .map({ $0.copy() as! UICollectionViewLayoutAttributes }),
              let collectionView = collectionView else { return nil }

        let halfWidth = collectionView.bounds.width / 2.0
        let centerX = collectionView.contentOffset.x + halfWidth

        for attributes in superAttributes {
            let shift = (attributes.center.x - centerX) / halfWidth * interPageSpacing / 2.0
            attributes.center.x += shift
        }

        return superAttributes
    }

    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        true
    }
}
