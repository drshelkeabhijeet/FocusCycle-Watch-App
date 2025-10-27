import SwiftUI
import Foundation

// MARK: - Session Log Models
struct HRSession: Identifiable, Codable {
    struct SampleCodable: Codable { let t: Double; let bpm: Int }
    let id: UUID
    let startDate: Date
    let durationSec: Int
    let samples: [SampleCodable]

    func toGraphSamples() -> [HeartRateManager.Sample] {
        let base = startDate
        return samples.map { sc in
            HeartRateManager.Sample(date: base.addingTimeInterval(sc.t), bpm: sc.bpm)
        }
    }
}

// MARK: - Session Log Manager
final class SessionLogManager: ObservableObject {
    static let shared = SessionLogManager()

    @AppStorage("hrSessionLogJSON") private var store: String = ""
    @Published private(set) var sessions: [HRSession] = []

    private init() { load() }

    private func load() {
        guard !store.isEmpty, let data = store.data(using: .utf8) else { sessions = []; return }
        if let decoded = try? JSONDecoder().decode([HRSession].self, from: data) {
            sessions = decoded
        } else {
            sessions = []
        }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(sessions), let s = String(data: data, encoding: .utf8) {
            store = s
        }
    }

    func appendSession(from liveSamples: [HeartRateManager.Sample]) {
        guard liveSamples.count > 1 else { return }
        let start = liveSamples.first!.date
        let last = liveSamples.last!.date
        let duration = max(1, Int(last.timeIntervalSince(start)))
        let encoded = liveSamples.map { s in
            HRSession.SampleCodable(t: s.date.timeIntervalSince(start), bpm: s.bpm)
        }
        let session = HRSession(id: UUID(), startDate: start, durationSec: duration, samples: encoded)
        sessions.insert(session, at: 0)
        if sessions.count > 5 { sessions = Array(sessions.prefix(5)) }
        persist()
    }
}

// MARK: - Views
struct HeartRateHistoryView: View {
    @ObservedObject var log = SessionLogManager.shared

    var body: some View {
        ScrollView {
            VStack(spacing: DesignSystem.Spacing.md) {
                if log.sessions.isEmpty {
                    Text("No heart rate sessions yet")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .padding()
                        .cardStyle()
                }
                ForEach(log.sessions) { session in
                    NavigationLink(destination: HeartRateSessionDetailView(session: session)) {
                        HStack(spacing: DesignSystem.Spacing.md) {
                            Image(systemName: "heart.fill").foregroundColor(.red)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(session.startDate, style: .date)
                                    .font(DesignSystem.Typography.body)
                                    .foregroundColor(DesignSystem.Colors.textPrimary)
                                HStack(spacing: 8) {
                                    Text(session.startDate, style: .time)
                                    Text("•")
                                    Text("\(session.durationSec)s")
                                }
                                .font(DesignSystem.Typography.micro)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12))
                                .foregroundColor(DesignSystem.Colors.textTertiary)
                        }
                        .padding(DesignSystem.Spacing.md)
                        .cardStyle()
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.md)
        }
        .background(DesignSystem.Colors.backgroundGradient.ignoresSafeArea())
        .navigationTitle("Heart Rate")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct HeartRateSessionDetailView: View {
    let session: HRSession
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            HeartRateGraph(samples: session.toGraphSamples())
                .frame(height: 120)
                .cardStyle()

            HStack {
                Text(session.startDate, style: .date)
                Text(session.startDate, style: .time)
                Text("• \(session.durationSec)s")
            }
            .font(DesignSystem.Typography.micro)
            .foregroundColor(DesignSystem.Colors.textSecondary)
        }
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.backgroundGradient.ignoresSafeArea())
        .navigationTitle("Session")
        .navigationBarTitleDisplayMode(.inline)
    }
}

