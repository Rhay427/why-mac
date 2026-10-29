import AppKit
import Combine
import Foundation

struct RunningApplicationHandle {
    let processIdentifier: pid_t
    let bundleIdentifier: String?
    let bundleURL: URL?
    let isRegularApplication: Bool
    let terminate: () -> Bool
    let forceTerminate: () -> Bool
}

@MainActor
final class ApplicationActionController: ObservableObject {
    typealias Lookup = (String) -> [RunningApplicationHandle]
    typealias ActivityMonitorOpener = () -> Bool

    @Published private(set) var pendingForceQuit: DiagnosisContributor?
    @Published private(set) var statusMessage: String?

    private let currentBundleIdentifier: String?
    private let lookup: Lookup
    private let activityMonitorOpener: ActivityMonitorOpener

    init(
        currentBundleIdentifier: String? = Bundle.main.bundleIdentifier,
        lookup: Lookup? = nil,
        openActivityMonitor: ActivityMonitorOpener? = nil
    ) {
        self.currentBundleIdentifier = currentBundleIdentifier
        self.lookup = lookup ?? Self.runningApplications
        self.activityMonitorOpener = openActivityMonitor ?? Self.openActivityMonitor
    }

    func actionsAvailable(for contributor: DiagnosisContributor) -> Bool {
        currentApplication(for: contributor) != nil
    }

    private func hasEligibleApplicationIdentity(_ contributor: DiagnosisContributor) -> Bool {
        guard let identity = contributor.applicationIdentity else { return false }
        let key = identity.groupKey
        let path = Self.canonicalURL(key.bundleURL).path
        return !key.bundleIdentifier.isEmpty
            && key.bundleIdentifier != currentBundleIdentifier
            && key.bundleURL.pathExtension.caseInsensitiveCompare("app") == .orderedSame
            && !path.hasPrefix("/System/Library/")
    }

    func quit(_ contributor: DiagnosisContributor) {
        perform(.quit, contributor: contributor)
    }

    func requestForceQuit(_ contributor: DiagnosisContributor) {
        guard actionsAvailable(for: contributor) else { return }
        pendingForceQuit = contributor
    }

    func confirmForceQuit() {
        guard let contributor = pendingForceQuit else { return }
        pendingForceQuit = nil
        perform(.forceQuit, contributor: contributor)
    }

    func cancelForceQuit() {
        pendingForceQuit = nil
    }

    func clearStatus() {
        statusMessage = nil
    }

    func inspectInActivityMonitor(_ contributor: DiagnosisContributor) {
        statusMessage = activityMonitorOpener()
            ? "Activity Monitor opened. Find \(contributor.displayName) to inspect or stop it."
            : "Activity Monitor could not be opened."
    }

    private enum Action {
        case quit, forceQuit
    }

    private func perform(_ action: Action, contributor: DiagnosisContributor) {
        guard let application = currentApplication(for: contributor) else {
            statusMessage = "\(contributor.displayName) is no longer available. Run Check Again for a fresh result."
            return
        }

        let accepted = action == .quit ? application.terminate() : application.forceTerminate()
        statusMessage = accepted
            ? "Request sent to \(contributor.displayName). Run Check Again for a fresh result."
            : "\(contributor.displayName) did not accept the request. Run Check Again for a fresh result."
    }

    private func currentApplication(for contributor: DiagnosisContributor) -> RunningApplicationHandle? {
        guard hasEligibleApplicationIdentity(contributor), let identity = contributor.applicationIdentity else {
            return nil
        }
        let expected = identity.groupKey
        let matches = lookup(expected.bundleIdentifier).filter { application in
            application.isRegularApplication
                && application.bundleIdentifier == expected.bundleIdentifier
                && application.bundleURL.map(Self.canonicalURL) == Self.canonicalURL(expected.bundleURL)
        }
        return matches.count == 1 ? matches[0] : nil
    }

    private static func runningApplications(bundleIdentifier: String) -> [RunningApplicationHandle] {
        NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).map { application in
            RunningApplicationHandle(
                processIdentifier: application.processIdentifier,
                bundleIdentifier: application.bundleIdentifier,
                bundleURL: application.bundleURL,
                isRegularApplication: application.activationPolicy == .regular,
                terminate: { application.terminate() },
                forceTerminate: { application.forceTerminate() }
            )
        }
    }

    private static func openActivityMonitor() -> Bool {
        NSWorkspace.shared.open(
            URL(fileURLWithPath: "/System/Applications/Utilities/Activity Monitor.app")
        )
    }

    private static func canonicalURL(_ url: URL) -> URL {
        url.resolvingSymlinksInPath().standardizedFileURL
    }
}
