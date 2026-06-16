import UIKit

final class FliperPagingLayout: UICollectionViewFlowLayout {
    var interPageSpacing: CGFloat = 20.0

    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        guard let superAttributes = super.layoutAttributesForElements(in: rect)?
            .map({ $0.copy() as! UICollectionViewLayoutAttributes }) else { return nil }
        return superAttributes
    }

    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        true
    }
}
