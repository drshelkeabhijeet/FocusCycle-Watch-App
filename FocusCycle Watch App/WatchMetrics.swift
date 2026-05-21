import SwiftUI
import WatchKit

enum WatchBucket { case small, medium, large }

struct WatchMetrics {
    // Bucket + core
    let bucket: WatchBucket
    let ringDiameter: CGFloat
    let innerSingleDiameter: CGFloat
    let multiBaseDiameter: CGFloat
    let multiStep: CGFloat
    // Controls
    let buttonSize: CGFloat
    let buttonSpacing: CGFloat
    // Layout paddings
    let hPad: CGFloat
    let topPad: CGFloat
    let bottomPad: CGFloat
    let controlPad: CGFloat
    // Overlay (settings)
    let gearSize: CGFloat
    let gearOffsetY: CGFloat
    // Line widths
    let outerLineWidth: CGFloat
    let singleLineWidth: CGFloat
    let multiLineWidth: CGFloat
    // Typography
    let timerFontSize: CGFloat

    // Device-aware factory (width + Dynamic Type) similar to Yoga Timer
    static func current(dynamicType: DynamicTypeSize) -> WatchMetrics {
        let width = WKInterfaceDevice.current().screenBounds.width
        let bucket: WatchBucket = (width >= 210) ? .large : (width >= 176 ? .medium : .small)

        func scale(_ s: CGFloat, _ m: CGFloat, _ l: CGFloat) -> CGFloat {
            switch bucket { case .small: return s; case .medium: return m; case .large: return l }
        }

        // Base geometry - more conservative sizing to prevent overflow
        var ring = scale(102, 124, 152)
        var outer = scale(6, 8, 10)
        var single = scale(4, 6, 8)
        var multi = scale(3, 5, 7)
        var btn = scale(40, 50, 58)
        // Moderate button size increase
        btn = max(40, btn * 1.15)

        // Accessibility bumps
        if dynamicType.isAccessibilitySize {
            ring += scale(4, 6, 8)
            outer += 1; single += 1; multi += 1; btn += 3
        }

        let innerSingle = max(70, ring - (outer + single) - 6)
        let multiBase = max(74, ring - (outer + multi) - 6)
        let multiStep = multi + 4
        // Conservative button spacing
        let spacing = scale(14, 22, 30)

        // Paddings and overlay - more conservative
        let hPad = scale(6, 9, 12)
        let topPad = scale(6, 8, 10)
        let bottomPad = scale(8, 12, 16)
        let controlPad = scale(16, 20, 24)
        // Smaller gear to prevent overflow
        let gearSize = scale(40, 50, 60)
        let gearOffsetY: CGFloat = 0

        // Strokes & type
        let outerLine = outer
        let singleLine = single
        let multiLine = multi
        let timerFont = scale(38, 42, 50)

        return WatchMetrics(
            bucket: bucket,
            ringDiameter: ring,
            innerSingleDiameter: innerSingle,
            multiBaseDiameter: multiBase,
            multiStep: multiStep,
            buttonSize: btn,
            buttonSpacing: spacing,
            hPad: hPad, topPad: topPad, bottomPad: bottomPad, controlPad: controlPad,
            gearSize: gearSize, gearOffsetY: gearOffsetY,
            outerLineWidth: outerLine, singleLineWidth: singleLine, multiLineWidth: multiLine,
            timerFontSize: timerFont
        )
    }

    // Designated initializer to support memberwise construction above
    init(bucket: WatchBucket,
         ringDiameter: CGFloat,
         innerSingleDiameter: CGFloat,
         multiBaseDiameter: CGFloat,
         multiStep: CGFloat,
         buttonSize: CGFloat,
         buttonSpacing: CGFloat,
         hPad: CGFloat,
         topPad: CGFloat,
         bottomPad: CGFloat,
         controlPad: CGFloat,
         gearSize: CGFloat,
         gearOffsetY: CGFloat,
         outerLineWidth: CGFloat,
         singleLineWidth: CGFloat,
         multiLineWidth: CGFloat,
         timerFontSize: CGFloat) {
        self.bucket = bucket
        self.ringDiameter = ringDiameter
        self.innerSingleDiameter = innerSingleDiameter
        self.multiBaseDiameter = multiBaseDiameter
        self.multiStep = multiStep
        self.buttonSize = buttonSize
        self.buttonSpacing = buttonSpacing
        self.hPad = hPad
        self.topPad = topPad
        self.bottomPad = bottomPad
        self.controlPad = controlPad
        self.gearSize = gearSize
        self.gearOffsetY = gearOffsetY
        self.outerLineWidth = outerLineWidth
        self.singleLineWidth = singleLineWidth
        self.multiLineWidth = multiLineWidth
        self.timerFontSize = timerFontSize
    }

    // Backward-compatible initializer if size-driven code remains
    init(size: CGSize) {
        // Back-compat shim: build from current metrics
        self = Self.current(dynamicType: .medium)
    }
}
