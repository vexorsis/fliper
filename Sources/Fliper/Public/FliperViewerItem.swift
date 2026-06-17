import UIKit

public enum FliperViewerItem {
    /// A locally available image (e.g. thumbnail already in memory)
    case image(UIImage)
    /// A remote image to be loaded via FliperImageLoader
    case url(URL)
    /// A thumbnail shown immediately, with a remote original loaded in the background
    case imageAndURL(thumbnail: UIImage, original: URL)

    /// The URL to load, if this item requires remote loading
    var remoteURL: URL? {
        switch self {
        case .image:
            return nil
        case .url(let url):
            return url
        case .imageAndURL(_, let original):
            return original
        }
    }

    /// The thumbnail image, if available immediately
    var thumbnail: UIImage? {
        switch self {
        case .image(let image):
            return image
        case .url:
            return nil
        case .imageAndURL(let thumbnail, _):
            return thumbnail
        }
    }
}
