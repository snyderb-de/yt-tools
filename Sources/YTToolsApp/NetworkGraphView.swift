import SwiftUI

struct NetworkGraphView: View {
    let samples: [Double]
    let currentMbps: Double
    let peakMbps: Double

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24.0)) { timeline in
            let phase = timeline.date.timeIntervalSinceReferenceDate
            let animatedPalette = palette(for: phase)
            let smoothed = smooth(samples)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(String(format: "Current %.2f Mbps", currentMbps))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(String(format: "Peak %.2f Mbps", peakMbps))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                GeometryReader { geometry in
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        animatedPalette[0].opacity(0.12),
                                        animatedPalette[2].opacity(0.18)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )

                        if smoothed.count > 1 {
                            let normalized = normalizedSamples(smoothed)

                            Path { path in
                                path.move(to: CGPoint(x: 0, y: geometry.size.height))
                                for (index, value) in normalized.enumerated() {
                                    let x = geometry.size.width * CGFloat(index) / CGFloat(max(normalized.count - 1, 1))
                                    let y = geometry.size.height * (1 - CGFloat(value))
                                    path.addLine(to: CGPoint(x: x, y: y))
                                }
                                path.addLine(to: CGPoint(x: geometry.size.width, y: geometry.size.height))
                                path.closeSubpath()
                            }
                            .fill(
                                LinearGradient(
                                    colors: [
                                        animatedPalette[1].opacity(0.28),
                                        animatedPalette[0].opacity(0.06)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )

                            Path { path in
                                for (index, value) in normalized.enumerated() {
                                    let x = geometry.size.width * CGFloat(index) / CGFloat(max(normalized.count - 1, 1))
                                    let y = geometry.size.height * (1 - CGFloat(value))
                                    if index == 0 {
                                        path.move(to: CGPoint(x: x, y: y))
                                    } else {
                                        path.addLine(to: CGPoint(x: x, y: y))
                                    }
                                }
                            }
                            .stroke(
                                LinearGradient(
                                    colors: animatedPalette,
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                style: StrokeStyle(lineWidth: 2.6, lineCap: .round, lineJoin: .round)
                            )
                            .shadow(color: animatedPalette[1].opacity(0.45), radius: 6, x: 0, y: 0)
                            .shadow(color: animatedPalette[0].opacity(0.2), radius: 12, x: 0, y: 0)
                        } else {
                            Text("Waiting for download activity...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .frame(height: 120)
            }
        }
    }

    private func smooth(_ values: [Double]) -> [Double] {
        guard !values.isEmpty else { return [] }
        var output: [Double] = []
        output.reserveCapacity(values.count)

        for value in values {
            if let last = output.last {
                let alpha = 0.22
                output.append((alpha * value) + ((1 - alpha) * last))
            } else {
                output.append(value)
            }
        }

        return output
    }

    private func normalizedSamples(_ values: [Double]) -> [Double] {
        guard let peak = values.max(), peak > 0 else {
            return values.map { _ in 0 }
        }
        return values.map { min(max($0 / peak, 0), 1) }
    }

    private func palette(for phase: TimeInterval) -> [Color] {
        let shift = (sin(phase * 0.9) + 1) / 2
        let hueA = 0.52 + (0.06 * shift)
        let hueB = 0.62 + (0.08 * (1 - shift))
        let hueC = 0.46 + (0.05 * shift)

        return [
            Color(hue: hueA, saturation: 0.9, brightness: 1.0),
            Color(hue: hueB, saturation: 0.8, brightness: 0.95),
            Color(hue: hueC, saturation: 0.9, brightness: 0.98)
        ]
    }
}
