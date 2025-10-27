import SwiftUI

struct HeartRateGraph: View {
    let samples: [HeartRateManager.Sample]

    private func normalizedPoints(in rect: CGRect) -> [CGPoint] {
        guard samples.count > 1 else { return [] }
        let times = samples.map { $0.date.timeIntervalSince1970 }
        guard let minT = times.min(), let maxT = times.max(), maxT > minT else { return [] }
        let bpms = samples.map { Double($0.bpm) }
        guard let minB = bpms.min(), let maxB = bpms.max(), maxB > 0 else { return [] }
        let minY = max(40.0, minB - 5) // clamp lower HR bound for scale
        let maxY = max(minY + 10, maxB + 5)

        return samples.map { s in
            let x = (s.date.timeIntervalSince1970 - minT) / (maxT - minT)
            let y = (Double(s.bpm) - minY) / (maxY - minY)
            return CGPoint(x: rect.minX + rect.width * CGFloat(x),
                           y: rect.maxY - rect.height * CGFloat(y))
        }
    }

    var body: some View {
        GeometryReader { geo in
            let rect = geo.frame(in: .local)
            let pts = normalizedPoints(in: rect)
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.04))
                if pts.count > 1 {
                    Path { path in
                        path.addLines(pts)
                    }
                    .stroke(LinearGradient(colors: [.red.opacity(0.9), .pink], startPoint: .leading, endPoint: .trailing), style: StrokeStyle(lineWidth: 2, lineJoin: .round))
                } else {
                    Text("No data yet")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

