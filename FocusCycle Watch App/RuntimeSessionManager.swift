import Foundation
import WatchKit

extension Notification.Name {
    static let extendedRuntimeSessionDidInvalidateAppNotification = Notification.Name("extendedRuntimeSessionDidInvalidateAppNotification")
    static let extendedRuntimeSessionDidStart = Notification.Name("extendedRuntimeSessionDidStart")
    static let extendedRuntimeSessionWillExpire = Notification.Name("extendedRuntimeSessionWillExpire")
    static let extendedRuntimeSessionWillEnd = Notification.Name("extendedRuntimeSessionWillEnd")
}

final class RuntimeSessionManager: NSObject {
    static let shared = RuntimeSessionManager()

    private var session: WKExtendedRuntimeSession?

    func start() {
        // If we already have a session, start or keep it if active
        if let s = session {
            switch s.state {
            case .running, .scheduled:
                return
            case .notStarted:
                s.start()
                return
            case .invalid:
                break
            @unknown default:
                break
            }
        }
        let s = WKExtendedRuntimeSession()
        s.delegate = self
        s.start()
        session = s
    }

    func stop() {
        guard let s = session else { return }
        switch s.state {
        case .running, .scheduled:
            s.invalidate()
        default:
            break
        }
        session = nil
    }
}

extension RuntimeSessionManager: WKExtendedRuntimeSessionDelegate {
    func extendedRuntimeSessionDidStart(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
        print("Extended runtime session started successfully")
        NotificationCenter.default.post(name: .extendedRuntimeSessionDidStart, object: nil)
    }
    
    func extendedRuntimeSessionWillExpire(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
        print("Extended runtime session will expire soon")
        NotificationCenter.default.post(name: .extendedRuntimeSessionWillExpire, object: nil)
    }
    
    func extendedRuntimeSessionWillEnd(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
        print("Extended runtime session will end")
        NotificationCenter.default.post(name: .extendedRuntimeSessionWillEnd, object: nil)
    }

    func extendedRuntimeSession(_ extendedRuntimeSession: WKExtendedRuntimeSession,
                                didInvalidateWith reason: WKExtendedRuntimeSessionInvalidationReason,
                                error: Error?) {
        print("Extended runtime session invalidated with reason: \(reason.rawValue)")
        if let error = error {
            print("Error: \(error.localizedDescription)")
        }
        
        // Clear reference and notify UI
        session = nil
        NotificationCenter.default.post(name: .extendedRuntimeSessionDidInvalidateAppNotification, object: nil)
    }
}
