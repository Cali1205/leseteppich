import SwiftUI

struct ShakeEffect: GeometryEffect {
    var amount: CGFloat = 6
    var shakesPerUnit: CGFloat = 4
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(
            CGAffineTransform(
                translationX: amount * sin(animatableData * .pi * shakesPerUnit),
                y: 0
            )
        )
    }
}
