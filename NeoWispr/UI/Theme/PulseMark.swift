import SwiftUI

/// The NeoWispr brand mark — F-deep Night squircle with asymmetric mint pulse,
/// inner-glow halo, ghost-pulse for depth, mint bookend-dots and a mint hairline rim.
///
/// All coordinates mirror `NeoWispr Logo.html` (viewBox 0..512). Squircle uses
/// continuous corners at 22.46% of the side (`115/512`), matching macOS app icons.
struct PulseMark: View {

    var size: CGFloat = 18

    var body: some View {
        Canvas { context, canvasSize in
            let rect = CGRect(origin: .zero, size: canvasSize)
            let scale = canvasSize.width / 512
            let radius = canvasSize.width * (115.0 / 512.0)

            let squircle = Path(roundedRect: rect, cornerSize: CGSize(width: radius, height: radius), style: .continuous)

            // Base — diagonal night gradient
            context.fill(
                squircle,
                with: .linearGradient(
                    Gradient(stops: [
                        .init(color: Neon.logoNight1, location: 0.0),
                        .init(color: Neon.logoNight2, location: 0.55),
                        .init(color: Neon.logoNight3, location: 1.0),
                    ]),
                    startPoint: .zero,
                    endPoint: CGPoint(x: canvasSize.width, y: canvasSize.height)
                )
            )

            // Mint inner glow halo — radial, centered
            context.drawLayer { layer in
                layer.clip(to: squircle)
                layer.fill(
                    Path(rect),
                    with: .radialGradient(
                        Gradient(stops: [
                            .init(color: Neon.brandMint.opacity(0.42), location: 0.0),
                            .init(color: Neon.brandMint.opacity(0.06), location: 0.6),
                            .init(color: Neon.brandMint.opacity(0.0),  location: 1.0),
                        ]),
                        center: CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2),
                        startRadius: 0,
                        endRadius: canvasSize.width * 0.55
                    )
                )
            }

            // Pulse waveform — asymmetric (one big peak + secondaries)
            let svgPulse: [(CGFloat, CGFloat)] = [
                (70, 256), (150, 256), (178, 220), (230, 320), (268, 132),
                (306, 360), (340, 240), (380, 268), (442, 256),
            ]
            let pulsePoints: [CGPoint] = svgPulse.map { CGPoint(x: $0.0 * scale, y: $0.1 * scale) }

            var pulsePath = Path()
            for (i, p) in pulsePoints.enumerated() {
                if i == 0 { pulsePath.move(to: p) } else { pulsePath.addLine(to: p) }
            }

            // Ghost pulse — soft, behind the main one
            context.stroke(
                pulsePath,
                with: .color(Neon.brandMint.opacity(0.18)),
                style: StrokeStyle(lineWidth: 34 * scale, lineCap: .round, lineJoin: .round)
            )

            // Main pulse with outer glow (soft blur layer + crisp stroke on top)
            context.drawLayer { layer in
                layer.addFilter(.blur(radius: 6 * scale))
                layer.stroke(
                    pulsePath,
                    with: .color(Neon.brandMint.opacity(0.85)),
                    style: StrokeStyle(lineWidth: 20 * scale, lineCap: .round, lineJoin: .round)
                )
            }
            context.stroke(
                pulsePath,
                with: .color(Neon.brandMint),
                style: StrokeStyle(lineWidth: 20 * scale, lineCap: .round, lineJoin: .round)
            )

            // Bookend dots — left & right
            for cx in [70.0, 442.0] {
                let dot = Path(ellipseIn: CGRect(
                    x: (cx - 11) * scale,
                    y: (256.0 - 11) * scale,
                    width: 22 * scale,
                    height: 22 * scale
                ))
                context.fill(dot, with: .color(Neon.brandMint))
            }

            // Glass top reflection
            context.drawLayer { layer in
                layer.clip(to: squircle)
                layer.fill(
                    Path(rect),
                    with: .linearGradient(
                        Gradient(stops: [
                            .init(color: Color.white.opacity(0.18), location: 0.0),
                            .init(color: Color.white.opacity(0.0),  location: 0.55),
                        ]),
                        startPoint: CGPoint(x: canvasSize.width / 2, y: 0),
                        endPoint: CGPoint(x: canvasSize.width / 2, y: canvasSize.height)
                    )
                )
            }

            // Edge vignette — radial dark
            context.drawLayer { layer in
                layer.clip(to: squircle)
                layer.fill(
                    Path(rect),
                    with: .radialGradient(
                        Gradient(stops: [
                            .init(color: Color.black.opacity(0.0),  location: 0.55),
                            .init(color: Color.black.opacity(0.45), location: 1.0),
                        ]),
                        center: CGPoint(x: canvasSize.width / 2, y: canvasSize.height * 0.55),
                        startRadius: 0,
                        endRadius: canvasSize.width * 0.7
                    )
                )
            }

            // Mint hairline rim
            let rimInset = max(0.5, scale * 0.5)
            let rimRect = rect.insetBy(dx: rimInset, dy: rimInset)
            let rimRadius = max(0, radius - rimInset)
            let rimPath = Path(roundedRect: rimRect, cornerSize: CGSize(width: rimRadius, height: rimRadius), style: .continuous)
            context.stroke(
                rimPath,
                with: .color(Neon.brandMint.opacity(0.16)),
                lineWidth: 1
            )
        }
        .frame(width: size, height: size)
    }
}

#Preview {
    HStack(spacing: 20) {
        PulseMark(size: 24)
        PulseMark(size: 80)
        PulseMark(size: 200)
    }
    .padding(32)
    .background(Color(hex: 0x141413))
}
