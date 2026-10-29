import XCTest
@testable import Why

final class BatteryUseContributorRuleTests: XCTestCase {
    func testStableBatteryAndSustainedApplicationProducesContributor() {
        let xcode = application("Xcode", id: "com.apple.dt.Xcode")
        let first = snapshot(processes: [
            ProcessSnapshot(pid: 100, name: "xcodebuild", cpuUsage: 70, applicationIdentity: xcode)
        ])
        let second = snapshot(processes: [
            ProcessSnapshot(pid: 101, name: "swift-frontend", cpuUsage: 65, applicationIdentity: xcode)
        ])

        XCTAssertEqual(
            BatteryUseContributorRule().evaluate(first, second),
            .issue(
                severity: .warning,
                title: "Battery use contributor",
                explanation: "Xcode is using sustained processor resources while your Mac is on battery and is likely contributing to increased battery use."
            )
        )
    }

    func testStableBatteryAndSustainedStandaloneProcessProducesContributor() {
        let processes = [ProcessSnapshot(pid: 100, name: "yes", cpuUsage: 75)]

        XCTAssertEqual(
            explanation(first: snapshot(processes: processes), second: snapshot(processes: processes)),
            "yes is using sustained processor resources while your Mac is on battery and is likely contributing to increased battery use."
        )
    }

    func testBatteryWithoutSustainedCPUProducesNegativeContributorResult() {
        XCTAssertEqual(
            BatteryUseContributorRule().evaluate(snapshot(), snapshot(timestamp: 5)),
            .healthy(
                title: "No processor-related battery contributor found",
                explanation: "No significant sustained processor activity was found. Other hardware and system activity may still be using battery power."
            )
        )
    }

    func testACPowerWithSustainedCPUProducesNoBatteryDiagnosis() {
        let ac = power(source: .ac, batteryProviding: false, externalPower: true)
        let processes = [ProcessSnapshot(pid: 100, name: "yes", cpuUsage: 90)]

        XCTAssertNil(
            BatteryUseContributorRule().evaluate(
                snapshot(power: ac, processes: processes),
                snapshot(timestamp: 5, power: ac, processes: processes)
            )
        )
    }

    func testACToBatteryTransitionInvalidatesObservation() {
        let processes = [ProcessSnapshot(pid: 100, name: "yes", cpuUsage: 90)]

        XCTAssertNil(
            BatteryUseContributorRule().evaluate(
                snapshot(
                    power: power(source: .ac, batteryProviding: false, externalPower: true),
                    processes: processes
                ),
                snapshot(timestamp: 5, processes: processes)
            )
        )
    }

    func testBatteryToACTransitionInvalidatesObservation() {
        let processes = [ProcessSnapshot(pid: 100, name: "yes", cpuUsage: 90)]

        XCTAssertNil(
            BatteryUseContributorRule().evaluate(
                snapshot(processes: processes),
                snapshot(
                    timestamp: 5,
                    power: power(source: .ac, batteryProviding: false, externalPower: true),
                    processes: processes
                )
            )
        )
    }

    func testChargingStateTransitionInvalidatesObservation() {
        let processes = [ProcessSnapshot(pid: 100, name: "yes", cpuUsage: 90)]

        XCTAssertNil(
            BatteryUseContributorRule().evaluate(
                snapshot(processes: processes),
                snapshot(timestamp: 5, power: power(charging: true), processes: processes)
            )
        )
    }

    func testApplicationGroupingSurvivesPIDHandoff() {
        let xcode = application("Xcode", id: "com.apple.dt.Xcode")

        XCTAssertEqual(
            explanation(
                first: snapshot(processes: [
                    ProcessSnapshot(pid: 100, name: "xcodebuild", cpuUsage: 80, applicationIdentity: xcode)
                ]),
                second: snapshot(timestamp: 5, processes: [
                    ProcessSnapshot(pid: 200, name: "swift-frontend", cpuUsage: 75, applicationIdentity: xcode)
                ])
            ),
            "Xcode is using sustained processor resources while your Mac is on battery and is likely contributing to increased battery use."
        )
    }

    func testThermalPressureStrengthensExistingContributorContext() {
        let processes = [ProcessSnapshot(pid: 100, name: "yes", cpuUsage: 90)]

        XCTAssertEqual(
            explanation(
                first: snapshot(processes: processes),
                second: snapshot(timestamp: 5, thermalState: .serious, processes: processes)
            ),
            "yes is using sustained processor resources while your Mac is on battery and is likely contributing to increased battery use. macOS is also reporting elevated thermal pressure."
        )
    }

    func testDisplayAwakeAloneDoesNotCreateContributor() {
        XCTAssertNoContributor(
            BatteryUseContributorRule().evaluate(
                snapshot(isDisplayAsleep: false),
                snapshot(timestamp: 5, isDisplayAsleep: false)
            )
        )
    }

    func testSleepAssertionAloneDoesNotBecomeCPUEnergyAttribution() {
        let assertion = SleepAssertionSnapshot(
            pid: 100,
            assertionType: "PreventUserIdleSystemSleep",
            name: "Keeping awake",
            humanReadableReason: nil,
            details: nil,
            level: 255,
            applicationIdentity: nil,
            processDisplayName: "caffeinate"
        )

        XCTAssertNoContributor(
            BatteryUseContributorRule().evaluate(
                snapshot(sleepAssertions: [assertion]),
                snapshot(timestamp: 5, sleepAssertions: [assertion])
            )
        )
    }

    func testStrongestOfMultipleSustainedApplicationsWinsDeterministically() {
        let xcode = application("Xcode", id: "com.apple.dt.Xcode")
        let chrome = application("Google Chrome", id: "com.google.Chrome")
        let first = snapshot(processes: [
            ProcessSnapshot(pid: 100, name: "xcodebuild", cpuUsage: 85, applicationIdentity: xcode),
            ProcessSnapshot(pid: 200, name: "Chrome Helper", cpuUsage: 70, applicationIdentity: chrome)
        ])
        let second = snapshot(timestamp: 5, processes: [
            ProcessSnapshot(pid: 101, name: "swift-frontend", cpuUsage: 80, applicationIdentity: xcode),
            ProcessSnapshot(pid: 201, name: "Chrome Helper", cpuUsage: 75, applicationIdentity: chrome)
        ])

        XCTAssertEqual(
            explanation(first: first, second: second),
            "Xcode is using sustained processor resources while your Mac is on battery and is likely contributing to increased battery use."
        )
    }

    func testLowPowerModeDoesNotChangeAttributionSemantics() {
        let processes = [ProcessSnapshot(pid: 100, name: "yes", cpuUsage: 90)]
        let lowPower = power(lowPowerMode: true)

        XCTAssertEqual(
            explanation(
                first: snapshot(power: lowPower, processes: processes),
                second: snapshot(timestamp: 5, power: lowPower, processes: processes)
            ),
            "yes is using sustained processor resources while your Mac is on battery and is likely contributing to increased battery use."
        )
    }

    func testMissingOptionalBatteryFieldsDoNotBreakAttribution() {
        let incompletePower = power(
            externalPower: nil,
            percentage: nil,
            health: nil
        )
        let processes = [ProcessSnapshot(pid: 100, name: "yes", cpuUsage: 90)]

        XCTAssertEqual(
            explanation(
                first: snapshot(power: incompletePower, processes: processes),
                second: snapshot(timestamp: 5, power: incompletePower, processes: processes)
            ),
            "yes is using sustained processor resources while your Mac is on battery and is likely contributing to increased battery use."
        )
    }

    func testLongObservationGapConservativelyInvalidatesObservation() {
        let processes = [ProcessSnapshot(pid: 100, name: "yes", cpuUsage: 90)]

        XCTAssertNil(
            BatteryUseContributorRule().evaluate(
                snapshot(processes: processes),
                snapshot(timestamp: 60, processes: processes)
            )
        )
    }

    func testDiagnosisEngineUsesBatteryContextInsteadOfDuplicateGenericCPUWarning() {
        let processes = [ProcessSnapshot(pid: 100, name: "yes", cpuUsage: 90)]

        XCTAssertEqual(
            explanation(
                for: DiagnosisEngine().evaluate(
                    snapshot(processes: processes),
                    snapshot(timestamp: 5, processes: processes)
                )
            ),
            "yes is using sustained processor resources while your Mac is on battery and is likely contributing to increased battery use."
        )
    }

    func testDiagnosisEnginePresentsBatteryWithoutContributorAsHealthy() {
        let first = snapshot()
        let second = snapshot(timestamp: 5)
        let selection = DiagnosisRelevance().select(
            DiagnosisEngine().validDiagnoses(first, second),
            context: .unknown
        )
        let presentation = DiagnosisPresentation(
            diagnosis: selection.primary,
            isChecking: false,
            hasCompletedCheck: true
        )

        XCTAssertEqual(selection.source, .fallback)
        XCTAssertEqual(presentation.kind, .healthy)
        XCTAssertEqual(presentation.headline, "Nothing noteworthy found")
    }

    func testThermalDiagnosisWinsWhenBatteryHasNoContributor() {
        let first = snapshot()
        let second = snapshot(timestamp: 5, thermalState: .serious)

        XCTAssertEqual(
            DiagnosisRelevance().select(
                DiagnosisEngine().validDiagnoses(first, second),
                context: .unknown
            ).source,
            .thermal
        )
    }

    private func snapshot(
        timestamp: TimeInterval = 0,
        thermalState: ProcessInfo.ThermalState = .nominal,
        power: PowerSnapshot? = nil,
        processes: [ProcessSnapshot] = [],
        sleepAssertions: [SleepAssertionSnapshot] = [],
        isDisplayAsleep: Bool? = false
    ) -> SystemSnapshot {
        SystemSnapshot(
            timestamp: Date(timeIntervalSince1970: timestamp),
            thermalState: thermalState,
            power: power ?? self.power(),
            processes: processes,
            sleepAssertions: sleepAssertions,
            isDisplayAsleep: isDisplayAsleep
        )
    }

    private func power(
        source: PowerSource = .battery,
        batteryProviding: Bool? = true,
        externalPower: Bool? = false,
        charging: Bool? = false,
        percentage: Double? = 60,
        health: BatteryHealth? = .good,
        lowPowerMode: Bool = false
    ) -> PowerSnapshot {
        PowerSnapshot(
            batteryPercentage: percentage,
            isCharging: charging,
            source: source,
            isBatteryProvidingPower: batteryProviding,
            isExternalPowerAvailable: externalPower,
            batteryHealth: health,
            isLowPowerModeEnabled: lowPowerMode
        )
    }

    private func application(_ name: String, id: String) -> ApplicationIdentity {
        ApplicationIdentity(
            groupKey: ApplicationIdentity.GroupKey(
                bundleURL: URL(fileURLWithPath: "/Applications/\(name).app"),
                bundleIdentifier: id
            ),
            displayName: name
        )
    }

    private func explanation(first: SystemSnapshot, second: SystemSnapshot) -> String? {
        explanation(for: BatteryUseContributorRule().evaluate(first, second))
    }

    private func explanation(for diagnosis: Diagnosis?) -> String? {
        guard case let .issue(_, _, explanation) = diagnosis else {
            return nil
        }
        return explanation
    }

    private func XCTAssertNoContributor(
        _ diagnosis: Diagnosis?,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(
            diagnosis,
            .healthy(
                title: "No processor-related battery contributor found",
                explanation: "No significant sustained processor activity was found. Other hardware and system activity may still be using battery power."
            ),
            file: file,
            line: line
        )
    }
}
