import Darwin

struct HighCPUProcessRule {
    private static let provisionalCPUThreshold = 50.0

    func evaluate(_ first: SystemSnapshot, _ second: SystemSnapshot) -> Diagnosis? {
        guard let strongest = strongestContributor(first, second) else {
            return nil
        }

        return .issue(
            severity: .warning,
            title: "Sustained processor activity",
            explanation: "\(strongest.displayName) is currently the main source of sustained processor activity."
        )
    }

    func strongestContributor(_ first: SystemSnapshot, _ second: SystemSnapshot) -> SustainedCPUContributor? {
        guard let strongest = (Self.matchedCandidates(first, second)
            .filter {
                $0.lowerCPU >= Self.provisionalCPUThreshold
                    && $0.secondCPU >= Self.provisionalCPUThreshold
            }
            .sorted(by: Self.precedes)
            .first) else {
            return nil
        }

        return SustainedCPUContributor(displayName: strongest.displayName)
    }

    func contributors(_ first: SystemSnapshot, _ second: SystemSnapshot) -> [DiagnosisContributor] {
        Self.matchedCandidates(first, second)
            .filter { $0.lowerCPU > 0 }
            .sorted(by: Self.precedes)
            .prefix(5)
            .map { candidate in
                DiagnosisContributor(
                    id: candidate.identity,
                    displayName: candidate.displayName,
                    applicationIdentity: candidate.applicationIdentity,
                    processIdentifier: candidate.processIdentifier,
                    metric: .cpuPercentage(candidate.lowerCPU)
                )
            }
    }

    private static func matchedCandidates(_ first: SystemSnapshot, _ second: SystemSnapshot) -> [Candidate] {
        let firstCandidates = Self.candidates(in: first)
        let secondCandidates = Self.candidates(in: second)
        let firstCPUByIdentity = Dictionary(uniqueKeysWithValues: firstCandidates.map { ($0.identity, $0.cpuUsage) })

        return secondCandidates.compactMap { candidate -> Candidate? in
            guard let firstCPU = firstCPUByIdentity[candidate.identity] else {
                return nil
            }

            return Candidate(
                identity: candidate.identity,
                displayName: candidate.displayName,
                applicationIdentity: candidate.applicationIdentity,
                processIdentifier: candidate.processIdentifier,
                lowerCPU: min(firstCPU, candidate.cpuUsage),
                secondCPU: candidate.cpuUsage,
                averageCPU: (firstCPU + candidate.cpuUsage) / 2
            )
        }
    }

    private static func precedes(_ left: Candidate, _ right: Candidate) -> Bool {
        if left.lowerCPU == right.lowerCPU {
            if left.averageCPU == right.averageCPU {
                return left.identity.sortKey < right.identity.sortKey
            }
            return left.averageCPU > right.averageCPU
        }
        return left.lowerCPU > right.lowerCPU
    }

    private static func candidates(in snapshot: SystemSnapshot) -> [ObservedCandidate] {
        var candidates: [ObservedCandidate] = []
        var indexByIdentity: [DiagnosisContributor.ID: Int] = [:]

        for process in topFive(in: snapshot) {
            let identity: DiagnosisContributor.ID
            let displayName: String
            let applicationIdentity: ApplicationIdentity?
            let processIdentifier: pid_t?
            if let application = process.applicationIdentity {
                identity = .application(application.groupKey)
                displayName = application.displayName
                applicationIdentity = application
                processIdentifier = nil
            } else {
                identity = .process(pid: process.pid, name: process.name)
                displayName = process.name
                applicationIdentity = nil
                processIdentifier = process.pid
            }

            if let index = indexByIdentity[identity] {
                candidates[index].cpuUsage += process.cpuUsage
            } else {
                indexByIdentity[identity] = candidates.count
                candidates.append(
                    ObservedCandidate(identity: identity, displayName: displayName,
                        applicationIdentity: applicationIdentity, processIdentifier: processIdentifier,
                        cpuUsage: process.cpuUsage)
                )
            }
        }

        return candidates
    }

    private static func topFive(in snapshot: SystemSnapshot) -> [ProcessSnapshot] {
        snapshot.processes
            .sorted {
                if $0.cpuUsage == $1.cpuUsage {
                    return ($0.pid, $0.name) < ($1.pid, $1.name)
                }
                return $0.cpuUsage > $1.cpuUsage
            }
            .prefix(5)
            .map { $0 }
    }
}

struct SustainedCPUContributor {
    let displayName: String
}

private struct Candidate {
    let identity: DiagnosisContributor.ID
    let displayName: String
    let applicationIdentity: ApplicationIdentity?
    let processIdentifier: pid_t?
    let lowerCPU: Double
    let secondCPU: Double
    let averageCPU: Double
}

private struct ObservedCandidate {
    let identity: DiagnosisContributor.ID
    let displayName: String
    let applicationIdentity: ApplicationIdentity?
    let processIdentifier: pid_t?
    var cpuUsage: Double
}
