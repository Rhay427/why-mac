import XCTest
@testable import Why

final class DiagnosisContributorsTests: XCTestCase {
    func testCPUContributorsUseSustainedOrderingAndKeepValuesAboveOneHundred() {
        let first = snapshot(processes: [
            process(1, "Xcode", 160),
            process(2, "Simulator", 80),
            process(3, "node", 45)
        ])
        let second = snapshot(processes: [
            process(1, "Xcode", 148),
            process(2, "Simulator", 76),
            process(3, "node", 41)
        ])

        let result = DiagnosisContributors.make(source: .processor, first: first, second: second)

        XCTAssertEqual(result?.title, "Top contributors")
        XCTAssertEqual(result?.items.map(\.displayName), ["Xcode", "Simulator", "node"])
        XCTAssertEqual(result?.items.map(\.metric), [
            .cpuPercentage(148), .cpuPercentage(76), .cpuPercentage(41)
        ])
        XCTAssertEqual(result?.items.first?.metric.displayValue, "148% CPU")
    }

    func testCPUContributorsAreCappedAtFiveAndDoNotInventMissingRows() {
        let six = (1...6).map { process(pid_t($0), "p\($0)", Double(70 - $0)) }
        XCTAssertEqual(contributors(.processor, six, six).items.count, 5)

        let two = Array(six.prefix(2))
        XCTAssertEqual(contributors(.processor, two, two).items.count, 2)
    }

    func testTrustedApplicationProcessesGroupWhileUnresolvedProcessesRemainSeparate() {
        let chrome = app("Google Chrome", "com.google.Chrome")
        let first = [
            process(1, "Chrome Helper", 70, chrome),
            process(2, "Chrome Helper", 60, chrome),
            process(3, "renderer", 40)
        ]
        let second = [
            process(4, "Chrome Helper", 65, chrome),
            process(5, "Chrome Helper", 55, chrome),
            process(3, "renderer", 35)
        ]

        let result = contributors(.processor, first, second)

        XCTAssertEqual(result.items.map(\.displayName), ["Google Chrome", "renderer"])
        XCTAssertEqual(result.items.map(\.metric), [.cpuPercentage(120), .cpuPercentage(35)])
        XCTAssertEqual(result.items.first?.applicationIdentity, chrome)
        XCTAssertNil(result.items.last?.applicationIdentity)
    }

    func testBatteryUsesProcessorMetricsWithoutInventingBatteryDrainPercentage() {
        let rows = [process(1, "Xcode", 126)]

        let result = contributors(.battery, rows, rows)

        XCTAssertEqual(result.title, "Top processor contributors")
        XCTAssertEqual(result.items.first?.metric, .cpuPercentage(126))
        XCTAssertFalse(result.items.first?.metric.displayValue.lowercased().contains("battery") == true)
        XCTAssertFalse(result.items.first?.metric.displayValue.lowercased().contains("drain") == true)
    }

    func testMemoryUsesGroupedAbsoluteFootprintWithoutInventingPercentage() {
        let chrome = app("Google Chrome", "com.google.Chrome")
        let memory = MemorySnapshot(pressure: .warning, processes: [
            ProcessMemorySnapshot(pid: 1, name: "Chrome Helper", physicalFootprint: 700_000_000,
                                  applicationIdentity: chrome),
            ProcessMemorySnapshot(pid: 2, name: "Chrome Helper", physicalFootprint: 500_000_000,
                                  applicationIdentity: chrome),
            ProcessMemorySnapshot(pid: 3, name: "node", physicalFootprint: 400_000_000)
        ])
        let second = snapshot(processes: [], memory: memory)

        let result = DiagnosisContributors.make(source: .memory, first: second, second: second)

        XCTAssertEqual(result?.items.map(\.displayName), ["Google Chrome", "node"])
        XCTAssertEqual(result?.items.map(\.metric), [
            .memoryFootprint(1_200_000_000), .memoryFootprint(400_000_000)
        ])
        XCTAssertTrue(result?.items.first?.metric.displayValue.contains("GB") == true)
        XCTAssertTrue(result?.items.first?.metric.displayValue.contains("memory") == true)
        XCTAssertFalse(result?.items.first?.metric.displayValue.contains("%") == true)
    }

    func testSleepAndThermalDoNotInventContributorMetrics() {
        let rows = [process(1, "Xcode", 90)]
        let first = snapshot(processes: rows)
        let second = snapshot(processes: rows)

        XCTAssertNil(DiagnosisContributors.make(source: .sleep, first: first, second: second))
        XCTAssertNil(DiagnosisContributors.make(source: .thermal, first: first, second: second))
        XCTAssertNil(DiagnosisContributors.make(source: .fallback, first: first, second: second))
    }

    func testMixedFindingsUseOnlyTheSelectedPrimaryMeasurement() {
        let cpuRows = [process(1, "Xcode", 90)]
        let memory = MemorySnapshot(pressure: .warning, processes: [
            ProcessMemorySnapshot(pid: 2, name: "Chrome", physicalFootprint: 900_000_000)
        ])
        let first = snapshot(processes: cpuRows, memory: memory)
        let second = snapshot(processes: cpuRows, memory: memory)

        let result = DiagnosisContributors.make(source: .memory, first: first, second: second)

        XCTAssertEqual(result?.items.map(\.displayName), ["Chrome"])
        XCTAssertEqual(result?.items.first?.metric, .memoryFootprint(900_000_000))
    }

    func testContributorProjectionUsesRelevanceSelectionInsteadOfCompetingFindings() {
        let cpuRows = [process(1, "Xcode", 90)]
        let memory = MemorySnapshot(pressure: .warning, processes: [
            ProcessMemorySnapshot(pid: 2, name: "Chrome", physicalFootprint: 900_000_000)
        ])
        let first = snapshot(processes: cpuRows, memory: memory)
        let second = snapshot(processes: cpuRows, memory: memory)
        let memoryDiagnosis = MemoryPressureRule().evaluate(memory)
        let selection = DiagnosisRelevance().select(
            ValidDiagnoses(
                memory: memoryDiagnosis,
                processor: HighCPUProcessRule().evaluate(first, second),
                sleep: .issue(severity: .warning, title: "Sleep blocker detected", explanation: "Brave is active."),
                fallback: .healthy(title: "Healthy", explanation: "Healthy")
            ),
            context: .unknown
        )

        let result = DiagnosisContributors.make(selection: selection, first: first, second: second)

        XCTAssertEqual(result?.items.map(\.displayName), ["Chrome"])
        XCTAssertEqual(selection.sleepReminder, .issue(
            severity: .warning, title: "Sleep blocker detected", explanation: "Brave is active."
        ))
    }

    private func contributors(
        _ source: DiagnosisSelection.Source,
        _ first: [ProcessSnapshot],
        _ second: [ProcessSnapshot]
    ) -> DiagnosisContributors {
        DiagnosisContributors.make(
            source: source,
            first: snapshot(processes: first),
            second: snapshot(processes: second)
        )!
    }

    private func process(_ pid: pid_t, _ name: String, _ cpu: Double,
                         _ application: ApplicationIdentity? = nil) -> ProcessSnapshot {
        ProcessSnapshot(pid: pid, name: name, cpuUsage: cpu, applicationIdentity: application)
    }

    private func app(_ name: String, _ identifier: String) -> ApplicationIdentity {
        ApplicationIdentity(
            groupKey: .init(bundleURL: URL(fileURLWithPath: "/Applications/\(name).app"),
                            bundleIdentifier: identifier),
            displayName: name
        )
    }

    private func snapshot(
        processes: [ProcessSnapshot],
        memory: MemorySnapshot = MemorySnapshot()
    ) -> SystemSnapshot {
        SystemSnapshot(
            timestamp: Date(timeIntervalSince1970: 0),
            thermalState: .nominal,
            power: PowerSnapshot(batteryPercentage: nil, isCharging: nil, source: .unknown),
            processes: processes,
            memory: memory
        )
    }
}
