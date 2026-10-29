import AppKit
import XCTest
@testable import Why

@MainActor
final class ApplicationActionControllerTests: XCTestCase {
    func testOnlyTrustedNormalApplicationContributorsOfferActions() {
        let trusted = app("Xcode", "com.apple.dt.Xcode")
        let controller = controller(identity: trusted)

        XCTAssertTrue(controller.actionsAvailable(for: contributor(trusted)))
        XCTAssertFalse(controller.actionsAvailable(for: contributor(nil)))
        XCTAssertFalse(controller.actionsAvailable(for: contributor(
            app("System Helper", "com.apple.helper", path: "/System/Library/CoreServices/System Helper.app")
        )))
        XCTAssertFalse(controller.actionsAvailable(for: contributor(app("Why", "com.example.Why"))))
    }

    func testMissingOrNonRegularApplicationUsesSafeHandoffInsteadOfTerminationActions() {
        let identity = app("Helper", "com.example.Helper")
        let missing = ApplicationActionController(currentBundleIdentifier: "com.example.Why", lookup: { _ in [] })
        let nonRegular = ApplicationActionController(currentBundleIdentifier: "com.example.Why", lookup: { _ in [
            self.handle(identity: identity, pid: 123, isRegular: false)
        ] })

        XCTAssertFalse(missing.actionsAvailable(for: contributor(identity)))
        XCTAssertFalse(nonRegular.actionsAvailable(for: contributor(identity)))
    }

    func testQuitRevalidatesIdentityAndUsesNormalTermination() {
        var quitCount = 0
        var forceCount = 0
        let identity = app("Xcode", "com.apple.dt.Xcode")
        let controller = controller(identity: identity, quit: { quitCount += 1; return true },
                                    force: { forceCount += 1; return true })

        controller.quit(contributor(identity))

        XCTAssertEqual(quitCount, 1)
        XCTAssertEqual(forceCount, 0)
        XCTAssertTrue(controller.statusMessage?.contains("Check Again") == true)
    }

    func testForceQuitRequiresConfirmationAndCancelDoesNothing() {
        var forceCount = 0
        let identity = app("Xcode", "com.apple.dt.Xcode")
        let controller = controller(identity: identity, force: { forceCount += 1; return true })
        let row = contributor(identity)

        controller.requestForceQuit(row)
        XCTAssertEqual(controller.pendingForceQuit, row)
        XCTAssertEqual(forceCount, 0)

        controller.cancelForceQuit()
        XCTAssertNil(controller.pendingForceQuit)
        XCTAssertEqual(forceCount, 0)
    }

    func testConfirmedForceQuitUsesForcedTermination() {
        var quitCount = 0
        var forceCount = 0
        let identity = app("Xcode", "com.apple.dt.Xcode")
        let controller = controller(identity: identity, quit: { quitCount += 1; return true },
                                    force: { forceCount += 1; return true })

        controller.requestForceQuit(contributor(identity))
        controller.confirmForceQuit()

        XCTAssertEqual(quitCount, 0)
        XCTAssertEqual(forceCount, 1)
        XCTAssertNil(controller.pendingForceQuit)
        XCTAssertTrue(controller.statusMessage?.contains("Check Again") == true)
    }

    func testMissingMismatchedOrAmbiguousApplicationNeverReceivesAction() {
        var quitCount = 0
        let identity = app("Xcode", "com.apple.dt.Xcode")
        let row = contributor(identity, pid: 42)
        let missing = ApplicationActionController(currentBundleIdentifier: "com.example.Why", lookup: { _ in [] })
        let mismatched = ApplicationActionController(currentBundleIdentifier: "com.example.Why", lookup: { _ in [
            self.handle(identity: self.app("Other", "com.example.Other"), pid: 42,
                        quit: { quitCount += 1; return true })
        ] })
        let match = handle(identity: identity, pid: 99, quit: { quitCount += 1; return true })
        let ambiguous = ApplicationActionController(currentBundleIdentifier: "com.example.Why", lookup: { _ in [match, match] })

        missing.quit(row)
        mismatched.quit(row)
        ambiguous.quit(row)

        XCTAssertEqual(quitCount, 0)
        XCTAssertTrue(missing.statusMessage?.contains("Check Again") == true)
        XCTAssertTrue(mismatched.statusMessage?.contains("Check Again") == true)
        XCTAssertTrue(ambiguous.statusMessage?.contains("Check Again") == true)
    }

    func testUnresolvedContributorHandsOffToActivityMonitorWithoutSendingTermination() {
        var openCount = 0
        let controller = ApplicationActionController(
            currentBundleIdentifier: "com.example.Why",
            lookup: { _ in [] },
            openActivityMonitor: { openCount += 1; return true }
        )

        controller.inspectInActivityMonitor(contributor(nil))

        XCTAssertEqual(openCount, 1)
        XCTAssertTrue(controller.statusMessage?.contains("worker") == true)
    }

    func testFailedActivityMonitorHandoffDoesNotClaimItOpened() {
        let controller = ApplicationActionController(
            currentBundleIdentifier: "com.example.Why",
            lookup: { _ in [] },
            openActivityMonitor: { false }
        )

        controller.inspectInActivityMonitor(contributor(nil))

        XCTAssertEqual(controller.statusMessage, "Activity Monitor could not be opened.")
    }

    private func controller(
        identity: ApplicationIdentity,
        quit: @escaping () -> Bool = { true },
        force: @escaping () -> Bool = { true }
    ) -> ApplicationActionController {
        ApplicationActionController(currentBundleIdentifier: "com.example.Why", lookup: { _ in [
            self.handle(identity: identity, pid: 123, quit: quit, force: force)
        ] })
    }

    private func handle(
        identity: ApplicationIdentity,
        pid: pid_t,
        isRegular: Bool = true,
        quit: @escaping () -> Bool = { true },
        force: @escaping () -> Bool = { true }
    ) -> RunningApplicationHandle {
        RunningApplicationHandle(
            processIdentifier: pid,
            bundleIdentifier: identity.groupKey.bundleIdentifier,
            bundleURL: identity.groupKey.bundleURL,
            isRegularApplication: isRegular,
            terminate: quit,
            forceTerminate: force
        )
    }

    private func contributor(_ identity: ApplicationIdentity?, pid: pid_t? = nil) -> DiagnosisContributor {
        DiagnosisContributor(
            id: identity.map { .application($0.groupKey) } ?? .process(pid: pid ?? 1, name: "worker"),
            displayName: identity?.displayName ?? "worker",
            applicationIdentity: identity,
            processIdentifier: pid,
            metric: .cpuPercentage(75)
        )
    }

    private func app(_ name: String, _ identifier: String,
                     path: String? = nil) -> ApplicationIdentity {
        ApplicationIdentity(
            groupKey: .init(bundleURL: URL(fileURLWithPath: path ?? "/Applications/\(name).app"),
                            bundleIdentifier: identifier),
            displayName: name
        )
    }
}
