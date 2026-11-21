import UIKit

@MainActor
enum ThemeTransition {
    static func roll(reduceMotion: Bool, change: () -> Void) {
        guard let window = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .flatMap(\.windows)
                .first(where: \.isKeyWindow),
              let snapshot = window.snapshotView(afterScreenUpdates: false)
        else {
            change()
            return
        }
        snapshot.frame = window.bounds
        snapshot.isUserInteractionEnabled = false
        window.addSubview(snapshot)
        change()

        if reduceMotion {
            UIView.animate(withDuration: 0.25, animations: { snapshot.alpha = 0 }, completion: { _ in snapshot.removeFromSuperview() })
            return
        }

        let bounds = window.bounds
        let depth = bounds.height * 0.1
        func remaining(edge: CGFloat) -> CGPath {
            let p = UIBezierPath()
            p.move(to: CGPoint(x: 0, y: edge))
            p.addCurve(to: CGPoint(x: bounds.width, y: edge - depth * 0.6),
                       controlPoint1: CGPoint(x: bounds.width * 0.38, y: edge + depth * 0.5),
                       controlPoint2: CGPoint(x: bounds.width * 0.66, y: edge + depth * 0.35))
            p.addLine(to: CGPoint(x: bounds.width, y: bounds.height + depth * 3))
            p.addLine(to: CGPoint(x: 0, y: bounds.height + depth * 3))
            p.close()
            return p.cgPath
        }
        let start = remaining(edge: -depth * 0.5)
        let end = remaining(edge: bounds.height + depth)

        let mask = CAShapeLayer()
        mask.path = end
        snapshot.layer.mask = mask

        let roll = CABasicAnimation(keyPath: "path")
        roll.fromValue = start
        roll.toValue = end
        roll.duration = 0.95
        roll.timingFunction = CAMediaTimingFunction(controlPoints: 0.65, 0, 0.35, 1)
        CATransaction.begin()
        CATransaction.setCompletionBlock { snapshot.removeFromSuperview() }
        mask.add(roll, forKey: "roll")
        CATransaction.commit()
    }
}
