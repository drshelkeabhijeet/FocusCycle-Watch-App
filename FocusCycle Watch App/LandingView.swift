import SwiftUI

/// Identifies what we want to present as a full-screen sheet from the landing pager.
/// Using `.sheet(item:)` (driven by State) instead of `NavigationLink` is required
/// because `NavigationLink` inside a `TabView(.page)` is dismissed on watchOS as
/// soon as the parent re-renders.
private enum LandingPresentation: Hashable, Identifiable {
    case startYoga
    case startPranayama(PranayamaType)
    case startMeditation(Int) // minutes
    case customizeYoga
    case customizePranayama
    case customizeMeditation

    var id: String {
        switch self {
        case .startYoga: return "startYoga"
        case .startPranayama(let t): return "startPranayama-\(t.rawValue)"
        case .startMeditation(let m): return "startMeditation-\(m)"
        case .customizeYoga: return "customizeYoga"
        case .customizePranayama: return "customizePranayama"
        case .customizeMeditation: return "customizeMeditation"
        }
    }
}

struct LandingView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @StateObject private var streakManager = StreakManager.shared
    @StateObject private var pranayamaSettings = PranayamaSettingsManager.shared
    @StateObject private var quickStart = QuickStartCoordinator.shared
    @State private var selectedPage: LaunchPractice = .yoga
    @State private var presentation: LandingPresentation?

    private var meditationDurationMinutes: Int {
        let stored = UserDefaults.standard.integer(forKey: "meditationCustomDurationMinutes")
        return stored > 0 ? stored : 12
    }

    private var lastPranayamaType: PranayamaType {
        if let raw = LaunchStateStore.lastPranayamaTypeRawValue(),
           let type = PranayamaType(rawValue: raw) {
            return type
        }
        return .anulom
    }

    var body: some View {
        ZStack {
            DesignSystem.Colors.backgroundGradient
                .ignoresSafeArea()

            TabView(selection: $selectedPage) {
                PracticePage(
                    title: "Yoga",
                    icon: "figure.yoga",
                    accentColor: DesignSystem.Colors.focusBlue,
                    streak: streakManager.getCurrentStreak(for: .yoga),
                    onStart: { presentation = .startYoga },
                    onCustomize: { presentation = .customizeYoga }
                )
                .tag(LaunchPractice.yoga)

                PracticePage(
                    title: "Pranayama",
                    icon: "wind",
                    accentColor: DesignSystem.Colors.playGreen,
                    streak: streakManager.getCurrentStreak(for: .pranayama),
                    onStart: { presentation = .startPranayama(lastPranayamaType) },
                    onCustomize: { presentation = .customizePranayama }
                )
                .tag(LaunchPractice.pranayama)

                PracticePage(
                    title: "Meditation",
                    icon: "brain.head.profile",
                    accentColor: DesignSystem.Colors.focusPurple,
                    streak: streakManager.getCurrentStreak(for: .meditation),
                    onStart: { presentation = .startMeditation(meditationDurationMinutes) },
                    onCustomize: { presentation = .customizeMeditation }
                )
                .tag(LaunchPractice.meditation)
            }
            .tabViewStyle(.page)
        }
        .sheet(item: $presentation) { item in
            destinationView(for: item)
        }
        .onAppear {
            if let last = LaunchStateStore.lastPractice() {
                selectedPage = last
            }
            handlePendingQuickStart()
        }
        .onChange(of: quickStart.pendingPractice) { _, _ in
            handlePendingQuickStart()
        }
    }

    private func handlePendingQuickStart() {
        guard let practice = quickStart.pendingPractice else { return }
        quickStart.pendingPractice = nil
        selectedPage = practice
        switch practice {
        case .yoga:
            presentation = .startYoga
        case .pranayama:
            presentation = .startPranayama(lastPranayamaType)
        case .meditation:
            presentation = .startMeditation(meditationDurationMinutes)
        }
    }

    @ViewBuilder
    private func destinationView(for item: LandingPresentation) -> some View {
        switch item {
        case .startYoga:
            YogaTimerView()
        case .startPranayama(let type):
            PranayamaTimerView(pattern: pranayamaSettings.getPattern(for: type))
        case .startMeditation(let minutes):
            MeditationTimerView(duration: minutes)
        case .customizeYoga:
            YogaCustomizeView()
        case .customizePranayama:
            PranayamaView()
        case .customizeMeditation:
            MeditationView()
        }
    }
}

/// One full-screen practice page. Big icon, name, streak, and a single primary Start button.
/// Both Start and Customize use closures (not NavigationLink) because NavigationLink
/// inside a page-style TabView is unstable on watchOS.
struct PracticePage: View {
    let title: String
    let icon: String
    let accentColor: Color
    let streak: Int
    let onStart: () -> Void
    let onCustomize: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Spacer(minLength: 0)

            ZStack {
                Circle()
                    .fill(accentColor.opacity(0.18))
                    .frame(width: 88, height: 88)
                Image(systemName: icon)
                    .font(.system(size: 38, weight: .medium))
                    .foregroundColor(.white)
            }

            VStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)

                if streak > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 11))
                            .foregroundColor(DesignSystem.Colors.pauseOrange)
                        Text("\(streak) day\(streak == 1 ? "" : "s")")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.75))
                    }
                } else {
                    Text("Tap start when ready")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(.white.opacity(0.55))
                }
            }

            Spacer(minLength: 0)

            HStack(spacing: 8) {
                Button(action: onStart) {
                    HStack(spacing: 6) {
                        Image(systemName: "play.fill")
                        Text("Start")
                    }
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(accentColor)
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .accessibilityIdentifier("\(title.lowercased())-quick-start")
                .accessibilityLabel("Start \(title)")

                Button(action: onCustomize) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white.opacity(0.85))
                        .frame(width: 44, height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(DesignSystem.Colors.cardBackgroundHighlight)
                        )
                }
                .buttonStyle(PlainButtonStyle())
                .accessibilityIdentifier("\(title.lowercased())-customize")
                .accessibilityLabel("Customize \(title)")
            }
            .padding(.bottom, 18)
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct LandingView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            LandingView()
                .previewDevice(PreviewDevice(rawValue: "Apple Watch SE (40mm) (2nd generation)"))
            LandingView()
                .previewDevice(PreviewDevice(rawValue: "Apple Watch Series 9 (45mm)"))
            LandingView()
                .previewDevice(PreviewDevice(rawValue: "Apple Watch Ultra 2 (49mm)"))
        }
    }
}
