import UIKit

public protocol FliperImageLoader {
    func loadImage(from url: URL) async throws -> UIImage
}
