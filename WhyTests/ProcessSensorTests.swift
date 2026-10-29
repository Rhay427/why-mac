import XCTest
@testable import Why

final class ProcessSensorTests: XCTestCase {
    func testParsePreservesProcessIdentityAndReturnsTopFiveByCPU() {
        let output = """
          10   4.5 /Applications/Low.app/Contents/MacOS/Low
          20  99.8 /Applications/Xcode.app/Contents/MacOS/Xcode
          30  12.0 /Applications/Name With Spaces.app/Contents/MacOS/Name With Spaces
          40   8.0 fourth
          50   7.0 fifth
          60   6.0 sixth
        """

        let snapshots = ProcessSensor.parse(output)

        XCTAssertEqual(snapshots.map(\.pid), [20, 30, 40, 50, 60])
        XCTAssertEqual(snapshots[1].name, "/Applications/Name With Spaces.app/Contents/MacOS/Name With Spaces")
        XCTAssertEqual(snapshots.map(\.cpuUsage), [99.8, 12, 8, 7, 6])
    }

    func testParseSkipsMalformedAndPartialRows() {
        let output = """
        PID %CPU COMMAND
        nonsense
        100
        101 nope /Applications/Broken.app/Contents/MacOS/Broken
        -1 50.0 invalid-pid
        102 -4.0 invalid-cpu
        103 nan invalid-cpu
        104 14.2
        105 3,5 /Applications/Valid.app/Contents/MacOS/Valid
        """

        let snapshots = ProcessSensor.parse(output)

        XCTAssertEqual(snapshots.map(\.pid), [105])
        XCTAssertEqual(snapshots.map(\.cpuUsage), [3.5])
        XCTAssertEqual(snapshots.map(\.name), ["/Applications/Valid.app/Contents/MacOS/Valid"])
    }

    func testMachTimeConversionUsesTheSystemTimebase() {
        XCTAssertEqual(
            ExperimentalLibprocProcessSensor.nanoseconds(fromMachTime: 24, numerator: 125, denominator: 3),
            1_000
        )
    }

    func testSnapshotsCalculatePerCoreUsageAndSortDescending() {
        let previous = [
            ExperimentalProcessCPUTimeSample(pid: 1, name: "First", cpuTimeNanoseconds: 1_000_000_000),
            ExperimentalProcessCPUTimeSample(pid: 2, name: "Second", cpuTimeNanoseconds: 2_000_000_000)
        ]
        let current = [
            ExperimentalProcessCPUTimeSample(pid: 1, name: "First", cpuTimeNanoseconds: 2_000_000_000),
            ExperimentalProcessCPUTimeSample(pid: 2, name: "Second", cpuTimeNanoseconds: 4_000_000_000),
            ExperimentalProcessCPUTimeSample(pid: 3, name: "New", cpuTimeNanoseconds: 500_000_000)
        ]

        let snapshots = ExperimentalLibprocProcessSensor.snapshots(
            previous: previous,
            current: current,
            elapsedSeconds: 2
        )

        XCTAssertEqual(snapshots.map(\.pid), [2, 1])
        XCTAssertEqual(snapshots.map(\.cpuUsage), [100, 50])
    }
}
