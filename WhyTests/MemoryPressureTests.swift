import Dispatch
import XCTest
@testable import Why

final class MemoryPressureTests: XCTestCase {
    func testObserverStartsUnknown() {
        XCTAssertEqual(MemoryPressureObserver().state, .unknown)
    }

    func testUnknownDoesNotDiagnoseMemory() {
        XCTAssertNil(MemoryPressureRule().evaluate(memory(.unknown)))
    }

    func testNormalDoesNotDiagnoseMemory() {
        XCTAssertNil(MemoryPressureRule().evaluate(memory(.normal)))
    }

    func testWarningProducesSystemPressureDiagnosis() {
        XCTAssertEqual(MemoryPressureRule().evaluate(memory(.warning)), warning)
    }

    func testCriticalProducesStrongerDiagnosis() {
        XCTAssertEqual(MemoryPressureRule().evaluate(memory(.critical)), .issue(
            severity: .critical, title: "Critical memory pressure",
            explanation: "macOS is reporting critical memory pressure, which can make applications less responsive."
        ))
    }

    func testWarningThenNormalClearsMemoryDiagnosis() {
        let observer = MemoryPressureObserver()
        observer.receive(.warning)
        XCTAssertEqual(observer.state, .warning)
        XCTAssertEqual(MemoryPressureRule().evaluate(memory(observer.state)), warning)
        observer.receive(.normal)
        XCTAssertEqual(observer.state, .normal)
        XCTAssertNil(MemoryPressureRule().evaluate(memory(observer.state)))
    }

    func testCriticalThenNormalClearsMemoryDiagnosis() {
        let observer = MemoryPressureObserver()
        observer.receive(.critical)
        XCTAssertEqual(observer.state, .critical)
        observer.receive(.normal)
        XCTAssertEqual(observer.state, .normal)
        XCTAssertNil(MemoryPressureRule().evaluate(memory(observer.state)))
    }

    func testNormalEventResolvesUnknownAndEmptyEventDoesNotInventNormal() {
        let observer = MemoryPressureObserver()
        observer.receive([])
        XCTAssertEqual(observer.state, .unknown)
        observer.receive(.normal)
        XCTAssertEqual(observer.state, .normal)
        observer.receive(.warning)
        observer.receive(.critical)
        XCTAssertEqual(observer.state, .critical)
    }

    func testWarningWithApplicationAddsCautiousAttribution() {
        XCTAssertEqual(explanation(memory(.warning, [process(1, "Helper", 500, app("Google Chrome"))])),
            baseExplanation + " Google Chrome is currently one of the largest observable memory users and may be contributing.")
    }

    func testWarningWithStandaloneProcessFallsBackToProcess() {
        XCTAssertEqual(explanation(memory(.warning, [process(1, "compiler", 500)])),
            baseExplanation + " compiler is currently one of the largest observable memory users and may be contributing.")
    }

    func testUnavailableAttributionUsesSystemOnly() {
        XCTAssertEqual(MemoryPressureRule().evaluate(memory(.warning)), warning)
    }

    func testLargeUtilizationWithNormalPressureDoesNotDiagnose() {
        XCTAssertNil(MemoryPressureRule().evaluate(memory(.normal, [process(1, "large", 15_000)], vm: vm())))
    }

    func testHighCompressionWithNormalPressureDoesNotDiagnose() {
        XCTAssertNil(MemoryPressureRule().evaluate(memory(.normal, vm: vm(compressed: 12_000_000_000))))
    }

    func testExistingSwapWithNormalPressureDoesNotDiagnose() {
        XCTAssertNil(MemoryPressureRule().evaluate(memory(.normal, vm: vm(swap: 8_000_000_000))))
    }

    func testProtectedProcessFailurePreservesAvailableSibling() {
        let rows = MemorySensor.processSnapshots("1 protected\n2 node", footprintLookup: {
            $0 == 1 ? nil : ProcessFootprint(bytes: 50, startTime: 10)
        }, identityLookup: { _ in nil })
        XCTAssertEqual(rows.map(\.pid), [2])
        XCTAssertEqual(explanation(memory(.warning, rows)),
            baseExplanation + " node is currently one of the largest observable memory users and may be contributing.")
    }

    func testTerminationDuringIdentityLookupFallsBackToSystem() {
        var alive = true
        let rows = MemorySensor.processSnapshots("1 worker", footprintLookup: { _ in
            alive ? ProcessFootprint(bytes: 50, startTime: 10) : nil
        }, identityLookup: { _ in alive = false; return nil })
        XCTAssertTrue(rows.isEmpty)
        XCTAssertEqual(MemoryPressureRule().evaluate(memory(.warning, rows)), warning)
    }

    func testPIDReuseDuringLookupDiscardsUntrustworthyIdentity() {
        var start: UInt64 = 10
        let rows = MemorySensor.processSnapshots("1 worker", footprintLookup: { _ in
            ProcessFootprint(bytes: 50, startTime: start)
        }, identityLookup: { _ in start = 20; return nil })
        XCTAssertTrue(rows.isEmpty)
    }

    func testMultipleApplicationsChooseStrongestDeterministically() {
        let rows = [process(1, "helper", 500, app("Xcode")), process(2, "helper", 800, app("Chrome"))]
        XCTAssertEqual(explanation(memory(.warning, rows)),
            baseExplanation + " Chrome is currently one of the largest observable memory users and may be contributing.")
        XCTAssertEqual(explanation(memory(.warning, rows.reversed())), explanation(memory(.warning, rows)))
        let tied = [process(1, "helper", 500, app("Xcode")), process(2, "helper", 500, app("Chrome"))]
        XCTAssertEqual(explanation(memory(.warning, tied)), explanation(memory(.warning, tied.reversed())))
    }

    func testTrustedApplicationHelpersAggregate() {
        let chrome = app("Chrome")
        let rows = [process(1, "helper-a", 400, chrome), process(2, "helper-b", 400, chrome), process(3, "node", 700)]
        XCTAssertEqual(explanation(memory(.warning, rows)),
            baseExplanation + " Chrome is currently one of the largest observable memory users and may be contributing.")
    }

    func testStandaloneNodeProcessesRemainSeparate() {
        let rows = [process(1, "node", 400), process(2, "node", 400), process(3, "compiler", 700)]
        XCTAssertEqual(explanation(memory(.warning, rows)),
            baseExplanation + " compiler is currently one of the largest observable memory users and may be contributing.")
    }

    func testCPUHeavyWithNormalMemoryKeepsCPUDiagnosis() {
        let first = system(.normal, time: 0, cpu: true)
        let second = system(.normal, time: 5, cpu: true)
        XCTAssertEqual(DiagnosisEngine().evaluate(first, second), HighCPUProcessRule().evaluate(first, second))
    }

    func testMemoryWarningWithoutHighCPUProducesMemoryDiagnosis() {
        XCTAssertEqual(DiagnosisEngine().evaluate(system(.unknown), system(.warning)), warning)
    }

    func testThermalSeriousRetainsPriorityOverMemoryWarning() {
        let snapshot = system(.warning, thermal: .serious)
        XCTAssertEqual(DiagnosisEngine().evaluate(snapshot), .issue(
            severity: .warning, title: "Your Mac is running hot",
            explanation: "macOS reports serious thermal pressure and may temporarily reduce performance."
        ))
    }

    func testSleepRetainsPriorityAndNormalMemoryPreservesBattery() {
        let sleeper = system(.critical, sleep: true)
        XCTAssertEqual(DiagnosisEngine().evaluate(sleeper), SleepPreventedRule().evaluate(sleeper))
        let first = system(.normal, time: 0, cpu: true, battery: true)
        let second = system(.normal, time: 5, cpu: true, battery: true)
        XCTAssertEqual(DiagnosisEngine().evaluate(first, second), BatteryUseContributorRule().evaluate(first, second))
    }

    func testMemoryPressureTakesPriorityOverDuplicateCPUAndBatteryWarnings() {
        XCTAssertEqual(DiagnosisEngine().evaluate(
            system(.warning, time: 0, cpu: true, battery: true),
            system(.warning, time: 5, cpu: true, battery: true)
        ), warning)
    }

    func testNormalAndUnknownSkipExpensiveCollection() {
        for pressure in [MemoryPressureState.unknown, .normal] {
            let result = MemorySensor().read(pressure: { pressure }, vmLookup: {
                XCTFail("VM collection must be gated"); return nil
            }, processLookup: {
                XCTFail("Footprint collection must be gated"); return []
            })
            XCTAssertEqual(result.pressure, pressure)
            XCTAssertNil(result.vm)
            XCTAssertTrue(result.processes.isEmpty)
        }
    }

    func testNormalEventDuringCollectionDropsStaleWarningAndFootprints() {
        var state = MemoryPressureState.warning
        let result = MemorySensor().read(pressure: { state }, vmLookup: { nil }, processLookup: {
            state = .normal
            return [self.process(1, "node", 500)]
        })
        XCTAssertEqual(result.pressure, .normal)
        XCTAssertTrue(result.processes.isEmpty)
        XCTAssertNil(MemoryPressureRule().evaluate(result))
    }

    func testVMFailureStillProducesAuthoritativeSystemWarning() {
        let result = MemorySensor().read(pressure: { .warning }, vmLookup: { nil }, processLookup: { [] })
        XCTAssertNil(result.vm)
        XCTAssertEqual(MemoryPressureRule().evaluate(result), warning)
    }

    func testEnumerationRejectsMalformedRowsAndEnrichesOnlyTopFiveFootprints() {
        var enriched: [pid_t] = []
        let rows = MemorySensor.processSnapshots(
            "0 kernel\n-1 bad\nnot-pid name\n9\n1 one\n2 two\n3 three\n4 four\n5 five\n6 six\n6 duplicate",
            footprintLookup: { ProcessFootprint(bytes: UInt64($0) * 100, startTime: 10) },
            identityLookup: { enriched.append($0); return nil }
        )
        XCTAssertEqual(rows.map(\.pid), [6, 5, 4, 3, 2])
        XCTAssertEqual(enriched, [6, 5, 4, 3, 2])
    }

    private var baseExplanation: String {
        "macOS is reporting elevated memory pressure, which can make applications less responsive."
    }
    private var warning: Diagnosis {
        .issue(severity: .warning, title: "Memory pressure", explanation: baseExplanation)
    }
    private func memory(_ pressure: MemoryPressureState, _ rows: [ProcessMemorySnapshot] = [], vm: MemoryVMStatistics? = nil) -> MemorySnapshot {
        MemorySnapshot(pressure: pressure, physicalMemory: 16_000_000_000, vm: vm, processes: rows)
    }
    private func process(_ pid: pid_t, _ name: String, _ bytes: UInt64, _ app: ApplicationIdentity? = nil) -> ProcessMemorySnapshot {
        ProcessMemorySnapshot(pid: pid, name: name, physicalFootprint: bytes, applicationIdentity: app)
    }
    private func app(_ name: String) -> ApplicationIdentity {
        ApplicationIdentity(groupKey: .init(bundleURL: URL(fileURLWithPath: "/Applications/\(name).app"), bundleIdentifier: "test.\(name)"), displayName: name)
    }
    private func vm(compressed: UInt64 = 0, swap: UInt64 = 0) -> MemoryVMStatistics {
        MemoryVMStatistics(pageSize: 16_384, freePages: 1, activePages: 900_000, inactivePages: 0, wiredPages: 0,
            compressorPages: compressed / 16_384, pageIns: 0, pageOuts: 0, compressions: 1_000_000,
            decompressions: 0, swapIns: 0, swapOuts: 0, swapUsedBytes: swap)
    }
    private func explanation(_ memory: MemorySnapshot) -> String? {
        guard case let .issue(_, _, text) = MemoryPressureRule().evaluate(memory) else { return nil }
        return text
    }
    private func system(_ pressure: MemoryPressureState, time: TimeInterval = 5,
                        cpu: Bool = false, battery: Bool = false, thermal: ProcessInfo.ThermalState = .nominal,
                        sleep: Bool = false) -> SystemSnapshot {
        SystemSnapshot(timestamp: Date(timeIntervalSince1970: time), thermalState: thermal,
            power: PowerSnapshot(batteryPercentage: 80, isCharging: false, source: battery ? .battery : .ac,
                isBatteryProvidingPower: battery, isExternalPowerAvailable: !battery),
            processes: cpu ? [ProcessSnapshot(pid: 10, name: "node", cpuUsage: 90)] : [],
            sleepAssertions: sleep ? [SleepAssertionSnapshot(pid: 20, assertionType: "PreventUserIdleSystemSleep",
                name: nil, humanReadableReason: nil, details: nil, level: 255,
                applicationIdentity: nil, processDisplayName: "caffeinate")] : [],
            memory: memory(pressure))
    }
}
