import CoreGraphics

enum UserActivityContext: Equatable {
    case active
    case unknown
}

struct UserActivityContextProbe {
    func capture() -> UInt32? {
        guard let anyInputEvent = CGEventType(rawValue: UInt32.max) else {
            return nil
        }
        return CGEventSource.counterForEventType(.combinedSessionState, eventType: anyInputEvent)
    }

    func context(between first: UInt32?, and second: UInt32?) -> UserActivityContext {
        guard let first, let second, first != second else {
            return .unknown
        }
        return .active
    }
}
