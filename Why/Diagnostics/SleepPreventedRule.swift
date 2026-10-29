import Darwin
import Foundation

/// Power assertions do not prevent forced sleep such as closing the lid or explicitly choosing Sleep.
struct SleepPreventedRule {
    func evaluate(_ snapshot: SystemSnapshot) -> Diagnosis {
        guard let candidate = Self.candidates(in: snapshot).min(by: Self.precedes) else {
            return .healthy(
                title: "No supported sleep blocker detected",
                explanation: "No supported application sleep blocker is currently active."
            )
        }

        return .issue(
            severity: .warning,
            title: "Sleep blocker detected",
            explanation: candidate.explanation
        )
    }

    private static func candidates(in snapshot: SystemSnapshot) -> [Candidate] {
        var candidatesByOwner: [Owner: Candidate] = [:]

        for assertion in snapshot.sleepAssertions where assertion.isActive {
            guard
                let kind = AssertionKind(rawValue: assertion.assertionType),
                !isNormalInfrastructure(assertion)
            else {
                continue
            }

            let owner: Owner
            let displayName: String
            let isApplication: Bool
            if let application = assertion.applicationIdentity {
                owner = .application(application.groupKey)
                displayName = application.displayName
                isApplication = true
            } else {
                owner = .process(pid: assertion.pid, name: assertion.processDisplayName)
                displayName = assertion.processDisplayName
                isApplication = false
            }

            let candidate = Candidate(
                owner: owner,
                displayName: displayName,
                kind: kind,
                isApplication: isApplication
            )

            if let current = candidatesByOwner[owner] {
                if precedes(candidate, current) {
                    candidatesByOwner[owner] = candidate
                }
            } else {
                candidatesByOwner[owner] = candidate
            }
        }

        return Array(candidatesByOwner.values)
    }

    private static func isNormalInfrastructure(_ assertion: SleepAssertionSnapshot) -> Bool {
        if let application = assertion.applicationIdentity {
            // Bundles nested in System Library are OS components, not trustworthy user-facing culprits.
            return application.groupKey.bundleURL.path.hasPrefix("/System/Library/")
        }
        return ["coreaudiod", "powerd", "runningboardd", "windowserver"]
            .contains(assertion.processDisplayName.lowercased())
    }

    private static func precedes(_ left: Candidate, _ right: Candidate) -> Bool {
        if left.priority == right.priority {
            return left.owner.sortKey < right.owner.sortKey
        }
        return left.priority < right.priority
    }
}

private enum AssertionKind {
    case idleSystem, display, system, network

    init?(rawValue: String) {
        switch rawValue {
        case "PreventUserIdleSystemSleep", "NoIdleSleepAssertion": self = .idleSystem
        case "PreventUserIdleDisplaySleep", "NoDisplaySleepAssertion": self = .display
        case "PreventSystemSleep": self = .system
        case "NetworkClientActive": self = .network
        default: return nil
        }
    }
}

private enum Owner: Hashable {
    case application(ApplicationIdentity.GroupKey)
    case process(pid: pid_t, name: String)

    var sortKey: String {
        switch self {
        case let .application(groupKey):
            "0|\(groupKey.bundleIdentifier)|\(groupKey.bundleURL.path)"
        case let .process(pid, name):
            "1|\(String(format: "%010d", pid))|\(name)"
        }
    }
}

private struct Candidate {
    let owner: Owner
    let displayName: String
    let kind: AssertionKind
    let isApplication: Bool

    var priority: Int {
        if kind == .network {
            return 6
        }
        return switch (isApplication, kind) {
        case (true, .idleSystem): 0
        case (true, .display): 1
        case (true, .system): 2
        case (false, .idleSystem): 3
        case (false, .display): 4
        case (false, .system): 5
        case (_, .network): 6
        }
    }

    var explanation: String {
        switch kind {
        case .idleSystem:
            isApplication
                ? "\(displayName) is currently preventing your Mac from automatically going to sleep while idle."
                : "\(displayName) is currently preventing automatic idle sleep."
        case .display:
            "\(displayName) is currently keeping your display awake."
        case .system:
            "\(displayName) is currently requesting that your Mac remain awake."
        case .network:
            "\(displayName) is reporting network activity that may delay automatic sleep."
        }
    }
}
