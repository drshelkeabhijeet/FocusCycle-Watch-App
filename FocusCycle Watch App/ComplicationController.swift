import ClockKit
import SwiftUI

// Minimal ClockKit data source to show a simple complication
class ComplicationController: NSObject, CLKComplicationDataSource {

    // MARK: - Descriptors (watchOS 7+)
    func getComplicationDescriptors(handler: @escaping ([CLKComplicationDescriptor]) -> Void) {
        let families: [CLKComplicationFamily] = [
            .modularSmall, .utilitarianSmall, .circularSmall,
            .graphicCircular, .graphicCorner, .graphicRectangular
        ]
        let descriptor = CLKComplicationDescriptor(
            identifier: "main",
            displayName: "Yoga Timer",
            supportedFamilies: families
        )
        handler([descriptor])
    }

    func handleSharedComplicationDescriptors(_ complicationDescriptors: [CLKComplicationDescriptor]) { }

    // MARK: - Timeline Configuration
    func getTimelineEndDate(for complication: CLKComplication, withHandler handler: @escaping (Date?) -> Void) {
        handler(nil) // No future timeline
    }

    func getPrivacyBehavior(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationPrivacyBehavior) -> Void) {
        handler(.showOnLockScreen)
    }

    // MARK: - Timeline Population
    func getCurrentTimelineEntry(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationTimelineEntry?) -> Void) {
        let tmpl = template(for: complication.family)
        if let tmpl = tmpl {
            handler(CLKComplicationTimelineEntry(date: Date(), complicationTemplate: tmpl))
        } else {
            handler(nil)
        }
    }

    func getTimelineEntries(for complication: CLKComplication, after date: Date, limit: Int, withHandler handler: @escaping ([CLKComplicationTimelineEntry]?) -> Void) {
        handler(nil) // No future entries
    }

    // MARK: - Placeholder Templates
    func getLocalizableSampleTemplate(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationTemplate?) -> Void) {
        let tmpl = template(for: complication.family)
        handler(tmpl)
    }

    // MARK: - Helpers
    private func currentPhaseLabel() -> String {
        // Read persisted settings if available to show a hint.
        let defaults = UserDefaults.standard
        let hold = defaults.integer(forKey: "userHoldSeconds")
        let rest = defaults.integer(forKey: "userRestSeconds")
        if hold > 0 && rest >= 0 {
            return "Yoga"
        }
        return "Yoga"
    }

    private func currentDetailLabel() -> String {
        let defaults = UserDefaults.standard
        let hold = defaults.integer(forKey: "userHoldSeconds")
        let rest = defaults.integer(forKey: "userRestSeconds")
        if hold > 0 {
            return "H:\(hold)s R:\(max(0, rest))s"
        }
        return "Hold/Rest"
    }

    private func template(for family: CLKComplicationFamily) -> CLKComplicationTemplate? {
        // Use a single imageset named "ComplicationLogo" (backed by AppIcon-200.png)
        let img = UIImage(named: "ComplicationLogo") ?? UIImage(systemName: "figure.yoga")
        guard let ui = img else { return nil }
        switch family {
        case .modularSmall:
            return CLKComplicationTemplateModularSmallSimpleImage(
                imageProvider: CLKImageProvider(onePieceImage: ui)
            )
        case .utilitarianSmall:
            return CLKComplicationTemplateUtilitarianSmallSquare(
                imageProvider: CLKImageProvider(onePieceImage: ui)
            )
        case .circularSmall:
            return CLKComplicationTemplateCircularSmallSimpleImage(
                imageProvider: CLKImageProvider(onePieceImage: ui)
            )
        case .graphicCircular:
            return CLKComplicationTemplateGraphicCircularImage(
                imageProvider: CLKFullColorImageProvider(fullColorImage: ui)
            )
        case .graphicCorner:
            return CLKComplicationTemplateGraphicCornerTextImage(
                textProvider: CLKSimpleTextProvider(text: ""),
                imageProvider: CLKFullColorImageProvider(fullColorImage: ui)
            )
        case .graphicRectangular:
            return CLKComplicationTemplateGraphicRectangularFullImage(
                imageProvider: CLKFullColorImageProvider(fullColorImage: ui)
            )
        default:
            return nil
        }
    }
}
