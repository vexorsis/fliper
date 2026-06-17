import UIKit

protocol FliperImageLoadingCoordinatorDelegate: AnyObject {
    func coordinator(_ coordinator: FliperImageLoadingCoordinator,
                     didLoadImage image: UIImage, forItemAt index: Int)
    func coordinator(_ coordinator: FliperImageLoadingCoordinator,
                     didFailWithError error: Error, forItemAt index: Int)
}

final class FliperImageLoadingCoordinator {
    weak var delegate: FliperImageLoadingCoordinatorDelegate?
    private let imageLoader: FliperImageLoader
    private var tasks: [Int: Task<Void, Never>] = [:]
    private var failedURLs: [Int: URL] = [:]

    init(imageLoader: FliperImageLoader) {
        self.imageLoader = imageLoader
    }

    func startLoading(url: URL, forItemAt index: Int) {
        cancelLoading(forItemAt: index)
        failedURLs.removeValue(forKey: index)

        let task = Task<Void, Never> { [weak self] in
            do {
                let image = try await imageLoader.loadImage(from: url)
                guard !Task.isCancelled, let self else { return }
                DispatchQueue.main.async {
                    self.delegate?.coordinator(self, didLoadImage: image, forItemAt: index)
                }
            } catch {
                guard !Task.isCancelled, let self else { return }
                self.failedURLs[index] = url
                DispatchQueue.main.async {
                    self.delegate?.coordinator(self, didFailWithError: error, forItemAt: index)
                }
            }
        }
        tasks[index] = task
    }

    func cancelLoading(forItemAt index: Int) {
        tasks[index]?.cancel()
        tasks.removeValue(forKey: index)
        failedURLs.removeValue(forKey: index)
    }

    func retry(forItemAt index: Int) {
        guard let url = failedURLs[index] else { return }
        startLoading(url: url, forItemAt: index)
    }

    func cancelAll() {
        for (_, task) in tasks {
            task.cancel()
        }
        tasks.removeAll()
        failedURLs.removeAll()
    }
}
