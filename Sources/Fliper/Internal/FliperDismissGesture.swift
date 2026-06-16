import UIKit

protocol FliperDismissGestureDelegate: AnyObject {
    func dismissGestureDidBegin(_ gesture: FliperDismissGesture)
    func dismissGestureDidChange(_ gesture: FliperDismissGesture, progress: CGFloat)
    func dismissGestureDidEnd(_ gesture: FliperDismissGesture, shouldDismiss: Bool)
}

final class FliperDismissGesture: UIGestureRecognizer {
    weak var dismissDelegate: FliperDismissGestureDelegate?
    var dismissThreshold: CGFloat = 0.25

    private var startPoint = CGPoint.zero
    private var lastPoint = CGPoint.zero
    private var lastTime: TimeInterval = 0
    private var currentVelocity = CGPoint.zero
    private var isInteracting = false
    private var targetScrollView: UIScrollView?

    func setTargetScrollView(_ scrollView: UIScrollView) {
        targetScrollView = scrollView
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        guard let touch = touches.first else { return }
        startPoint = touch.location(in: view)
        lastPoint = startPoint
        lastTime = event.timestamp
        currentVelocity = .zero
        state = .possible
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesMoved(touches, with: event)
        guard let touch = touches.first else { return }
        let point = touch.location(in: view)
        let now = event.timestamp
        let dt = now - lastTime
        if dt > 0 {
            currentVelocity = CGPoint(
                x: (point.x - lastPoint.x) / CGFloat(dt),
                y: (point.y - lastPoint.y) / CGFloat(dt)
            )
        }
        lastPoint = point
        lastTime = now

        if !isInteracting {
            let dx = abs(point.x - startPoint.x)
            let dy = point.y - startPoint.y
            if dy > 3 && dy > dx {
                beginInteraction(at: point)
            }
            return
        }

        let dy = point.y - startPoint.y
        let viewHeight = view?.bounds.height ?? 1
        let progress = min(1.0, max(0.0, abs(dy) / (viewHeight * 1.2)))

        targetScrollView?.center = point

        let scale = max(0.35, 1.0 - progress * 0.65)
        targetScrollView?.transform = CGAffineTransform(scaleX: scale, y: scale)

        dismissDelegate?.dismissGestureDidChange(self, progress: progress)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesEnded(touches, with: event)
        guard isInteracting else { state = .failed; return }

        guard let touch = touches.first else { state = .failed; return }
        let point = touch.location(in: view)
        let dy = point.y - startPoint.y
        let viewHeight = view?.bounds.height ?? 1

        let shouldDismiss = abs(dy) > viewHeight * dismissThreshold || abs(currentVelocity.y) > 800

        dismissDelegate?.dismissGestureDidEnd(self, shouldDismiss: shouldDismiss)
        isInteracting = false
        state = .ended
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesCancelled(touches, with: event)
        if isInteracting {
            dismissDelegate?.dismissGestureDidEnd(self, shouldDismiss: false)
            isInteracting = false
        }
        state = .cancelled
    }

    private func beginInteraction(at point: CGPoint) {
        isInteracting = true
        state = .began

        guard let scrollView = targetScrollView else { return }

        let anchorX = point.x / scrollView.bounds.width
        let anchorY = point.y / scrollView.bounds.height
        scrollView.layer.anchorPoint = CGPoint(x: anchorX, y: anchorY)

        scrollView.isUserInteractionEnabled = false

        dismissDelegate?.dismissGestureDidBegin(self)
    }

    func restoreScrollView(_ scrollView: UIScrollView, to center: CGPoint, duration: TimeInterval = 0.15, completion: (() -> Void)? = nil) {
        UIView.animate(withDuration: duration, delay: 0, options: .curveEaseOut, animations: {
            scrollView.layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            scrollView.center = center
            scrollView.transform = .identity
        }, completion: { _ in
            scrollView.isUserInteractionEnabled = true
            completion?()
        })
    }
}
