import XCTest
@testable import Why

final class SleepAssertionSensorTests: XCTestCase {
    func testParsePreservesDocumentedFieldsAndResolvedOwner() {
        let app = ApplicationIdentity(
            groupKey: ApplicationIdentity.GroupKey(
                bundleURL: URL(fileURLWithPath: "/Applications/Example.app"),
                bundleIdentifier: "com.example.app"
            ),
            displayName: "Example"
        )
        let raw: NSDictionary = [
            NSNumber(value: 42): [[
                "AssertType": "PreventUserIdleSystemSleep",
                "AssertName": "Exporting",
                "HumanReadableReason": "Exporting a movie",
                "Details": "Preparing frames",
                "AssertLevel": 255
            ]]
        ]

        let snapshots = SleepAssertionSensor.parse(raw) { _ in
            ProcessIdentityResolution(applicationIdentity: app, processDisplayName: "ExampleHelper")
        }

        XCTAssertEqual(snapshots.count, 1)
        XCTAssertEqual(snapshots[0].pid, 42)
        XCTAssertEqual(snapshots[0].assertionType, "PreventUserIdleSystemSleep")
        XCTAssertEqual(snapshots[0].name, "Exporting")
        XCTAssertEqual(snapshots[0].humanReadableReason, "Exporting a movie")
        XCTAssertEqual(snapshots[0].details, "Preparing frames")
        XCTAssertEqual(snapshots[0].level, 255)
        XCTAssertEqual(snapshots[0].applicationIdentity?.groupKey, app.groupKey)
        XCTAssertEqual(snapshots[0].processDisplayName, "ExampleHelper")
    }

    func testParseSkipsMalformedAssertionWithoutDroppingValidSibling() {
        let raw: NSDictionary = [
            NSNumber(value: 42): [
                ["AssertType": "PreventUserIdleSystemSleep", "AssertLevel": 255],
                ["AssertType": 123, "AssertLevel": "on"],
                ["AssertLevel": 255]
            ]
        ]

        let snapshots = SleepAssertionSensor.parse(raw) { _ in nil }

        XCTAssertEqual(snapshots.count, 1)
        XCTAssertEqual(snapshots[0].assertionType, "PreventUserIdleSystemSleep")
        XCTAssertEqual(snapshots[0].processDisplayName, "Process 42")
    }

    func testParseExcludesInactiveAssertionsAndInvalidOwners() {
        let raw: NSDictionary = [
            NSNumber(value: 42): [["AssertType": "PreventSystemSleep", "AssertLevel": 0]],
            NSNumber(value: -1): [["AssertType": "PreventSystemSleep", "AssertLevel": 255]],
            "not-a-pid": [["AssertType": "PreventSystemSleep", "AssertLevel": 255]]
        ]

        XCTAssertTrue(SleepAssertionSensor.parse(raw) { _ in nil }.isEmpty)
    }
}
