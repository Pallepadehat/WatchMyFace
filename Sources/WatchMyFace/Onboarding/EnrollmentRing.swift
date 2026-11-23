import FaceKit
import SwiftUI

/// The camera in a circle, ringed by ticks that turn green as the head points their way, like Face ID setup.
struct EnrollmentRing: View {
    let enrollment: Enrollment
    var diameter: CGFloat = 210

    private var coverage: Set<Int> { enrollment.coverage.covered }
    private var tickCount: Int { enrollment.coverage.tickCount }

    var body: some View {
        ZStack {
            CameraPreview(session: enrollment.session.session)
                .frame(width: diameter, height: diameter)
                .clipShape(.circle)
                .overlay {
                    Circle().fill(.black).opacity(enrollment.showsCheck ? 0.55 : 0)
                }
                .overlay {
                    Image(systemName: "checkmark")
                        .font(.system(size: 64, weight: .semibold))
                        .foregroundStyle(.green)
                        .scaleEffect(enrollment.showsCheck ? 1 : 0.4)
                        .opacity(enrollment.showsCheck ? 1 : 0)
                }
                .scaleEffect(enrollment.showsCheck ? 0.94 : 1)

            ForEach(0..<tickCount, id: \.self) { index in
                let isLit = coverage.contains(index)
                Capsule()
                    .fill(isLit ? Color.green : Color.white.opacity(0.35))
                    .frame(width: 3, height: isLit ? 18 : 12)
                    .offset(y: -(diameter / 2 + 22) - (isLit ? 3 : 0))
                    .rotationEffect(.degrees(Double(index) / Double(tickCount) * 360))
                    .animation(.spring(response: 0.35, dampingFraction: 0.6), value: isLit)
            }
        }
        .frame(width: diameter + 80, height: diameter + 80)
        .animation(.spring(response: 0.5, dampingFraction: 0.75), value: enrollment.showsCheck)
    }
}
