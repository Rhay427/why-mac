import Foundation

struct ProcessSensor {
    func read() -> (processes: [ProcessSnapshot], succeeded: Bool) {
        let task = Process()
        let output = Pipe()
        var environment = ProcessInfo.processInfo.environment
        environment["LC_ALL"] = "C"

        task.executableURL = URL(fileURLWithPath: "/bin/ps")
        task.arguments = ["-A", "-c", "-r", "-o", "pid=,pcpu=,comm="]
        task.environment = environment
        task.standardOutput = output
        task.standardError = FileHandle.nullDevice

        do {
            try task.run()
            let data = output.fileHandleForReading.readDataToEndOfFile()
            task.waitUntilExit()
            guard task.terminationStatus == 0 else {
                return ([], false)
            }
            return (Self.parse(String(decoding: data, as: UTF8.self)).map { process in
                ProcessSnapshot(
                    pid: process.pid,
                    name: process.name,
                    cpuUsage: process.cpuUsage,
                    applicationIdentity: ProcessIdentityResolver.resolve(pid: process.pid)?.applicationIdentity
                )
            }, true)
        } catch {
            return ([], false)
        }
    }

    static func parse(_ output: String) -> [ProcessSnapshot] {
        output.split(whereSeparator: \.isNewline).compactMap { line in
            let fields = line.split(maxSplits: 2, whereSeparator: \.isWhitespace)
            guard
                fields.count == 3,
                let pid = pid_t(fields[0]),
                pid > 0,
                let cpuUsage = Double(fields[1].replacingOccurrences(of: ",", with: ".")),
                cpuUsage.isFinite,
                cpuUsage >= 0,
                !fields[2].isEmpty
            else {
                return nil
            }

            return ProcessSnapshot(pid: pid, name: String(fields[2]), cpuUsage: cpuUsage)
        }
        .sorted { $0.cpuUsage > $1.cpuUsage }
        .prefix(5)
        .map { $0 }
    }
}
