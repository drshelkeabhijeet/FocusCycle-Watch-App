import SwiftUI
import WatchKit

struct HapticSelectionView: View {
    @Binding var selectedHaptic: AppHaptic
    @Environment(\.dismiss) var dismiss
    @State private var playingHaptic: AppHaptic? = nil
    
    let allHaptics = AppHaptic.all
    
    var body: some View {
        ScrollView {
            VStack(spacing: DesignSystem.Spacing.sm) {
                // Header with description
                VStack(spacing: DesignSystem.Spacing.xs) {
                    Text("Choose Alert")
                        .font(DesignSystem.Typography.subheading)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    
                    Text("Tap to preview each haptic")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                .padding(.vertical, DesignSystem.Spacing.md)
                
                // Haptic Options Grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: DesignSystem.Spacing.md) {
                    ForEach(allHaptics) { haptic in
                        HapticOptionCard(
                            haptic: haptic,
                            isSelected: selectedHaptic == haptic,
                            isPlaying: playingHaptic == haptic,
                            onSelect: {
                                selectHaptic(haptic)
                            }
                        )
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.sm)
                
                // Priority Info
                VStack(spacing: DesignSystem.Spacing.sm) {
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 12))
                        Text("Priority System")
                            .font(DesignSystem.Typography.caption)
                    }
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    
                    Text("Higher priority haptics play when intervals overlap")
                        .font(DesignSystem.Typography.micro)
                        .foregroundColor(DesignSystem.Colors.textTertiary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, DesignSystem.Spacing.lg)
                .padding(.horizontal, DesignSystem.Spacing.md)
            }
            .padding(.bottom, DesignSystem.Spacing.xl)
        }
        .background(DesignSystem.Colors.backgroundGradient.ignoresSafeArea())
        .navigationTitle("Haptic Alerts")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
                    .font(DesignSystem.Typography.body)
                    .foregroundColor(DesignSystem.Colors.focusBlue)
            }
        }
    }
    
    private func selectHaptic(_ haptic: AppHaptic) {
        // Visual feedback
        withAnimation(DesignSystem.Animation.bounce) {
            playingHaptic = haptic
        }
        
        // Play haptic
        WKInterfaceDevice.current().play(haptic.type)
        
        // Update selection after a brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(DesignSystem.Animation.standard) {
                selectedHaptic = haptic
                playingHaptic = nil
            }
            
            // Dismiss after selection
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                dismiss()
            }
        }
    }
}

// MARK: - Haptic Option Card
struct HapticOptionCard: View {
    let haptic: AppHaptic
    let isSelected: Bool
    let isPlaying: Bool
    let onSelect: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: DesignSystem.Spacing.sm) {
                // Icon with priority badge
                ZStack(alignment: .topTrailing) {
                    HapticIconView(hapticType: haptic.name, size: 28)
                        .scaleEffect(isPlaying ? 1.2 : 1.0)
                        .animation(DesignSystem.Animation.bounce, value: isPlaying)
                    
                    // Priority badge
                    Text("P\(haptic.priority)")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(priorityColor(for: haptic.priority))
                        )
                        .offset(x: 8, y: -8)
                }
                .frame(height: 40)
                
                // Haptic name
                Text(haptic.name)
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(isSelected ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.textSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(height: 30)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignSystem.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large)
                    .fill(cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large)
                            .strokeBorder(
                                isSelected ? DesignSystem.Colors.focusBlue : Color.clear,
                                lineWidth: 2
                            )
                    )
                    .shadow(
                        color: isPlaying ? hapticIconColor : Color.clear,
                        radius: 10,
                        x: 0,
                        y: 0
                    )
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(DesignSystem.Animation.quick) {
                isPressed = pressing
            }
        }, perform: {})
    }
    
    private var cardBackground: Color {
        if isPlaying {
            return DesignSystem.Colors.cardBackgroundHighlight
        } else if isSelected {
            return DesignSystem.Colors.focusBlue.opacity(0.15)
        } else {
            return DesignSystem.Colors.cardBackground
        }
    }
    
    private var hapticIconColor: Color {
        switch haptic.name.lowercased() {
        case "success", "start": return DesignSystem.Colors.playGreen
        case "failure", "stop": return DesignSystem.Colors.stopRed
        case "notification": return DesignSystem.Colors.focusBlue
        default: return DesignSystem.Colors.focusIndigo
        }
    }
    
    private func priorityColor(for priority: Int) -> Color {
        switch priority {
        case 5: return DesignSystem.Colors.stopRed
        case 4: return DesignSystem.Colors.pauseOrange
        case 3: return DesignSystem.Colors.focusBlue
        case 2: return DesignSystem.Colors.focusIndigo
        default: return DesignSystem.Colors.textTertiary
        }
    }
}

#Preview {
    NavigationView {
        HapticSelectionView(selectedHaptic: .constant(AppHaptic.notification))
    }
}