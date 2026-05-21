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
            return "Next"
        }
        return "Focus"
    }

    private func currentDetailLabel() -> String {
        let defaults = UserDefaults.standard
        let hold = defaults.integer(forKey: "userHoldSeconds")
        let rest = defaults.integer(forKey: "userRestSeconds")
        if hold > 0 {
            return "H:\(hold)s R:\(max(0, rest))s"
        }
        return "Start Session"
    }

    private func template(for family: CLKComplicationFamily) -> CLKComplicationTemplate? {
        let logo = UIImage(named: "ComplicationLogo") ?? UIImage(systemName: "figure.yoga")
        guard let logo else { return nil }

        let title = CLKSimpleTextProvider(text: currentPhaseLabel())
        let detail = CLKSimpleTextProvider(text: currentDetailLabel())

        switch family {
        case .modularSmall:
            return CLKComplicationTemplateModularSmallSimpleImage(
                imageProvider: CLKImageProvider(onePieceImage: logo)
            )
        case .utilitarianSmall:
            return CLKComplicationTemplateUtilitarianSmallSquare(
                imageProvider: CLKImageProvider(onePieceImage: logo)
            )
        case .circularSmall:
            return CLKComplicationTemplateCircularSmallSimpleImage(
                imageProvider: CLKImageProvider(onePieceImage: logo)
            )
        case .graphicCircular:
            return CLKComplicationTemplateGraphicCircularImage(
                imageProvider: CLKFullColorImageProvider(fullColorImage: logo)
            )
        case .graphicCorner:
            return CLKComplicationTemplateGraphicCornerTextImage(
                textProvider: detail,
                imageProvider: CLKFullColorImageProvider(fullColorImage: logo)
            )
        case .graphicRectangular:
            return CLKComplicationTemplateGraphicRectangularStandardBody(
                headerImageProvider: CLKFullColorImageProvider(fullColorImage: logo),
                headerTextProvider: CLKSimpleTextProvider(text: "Yoga Asana Timer"),
                body1TextProvider: title,
                body2TextProvider: detail
            )
        default:
            return nil
        }
    }
}
