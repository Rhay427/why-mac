import AppKit
import SwiftUI

struct WhyLogoView: View {
    var body: some View {
        Image("WhyLogo")
            .renderingMode(.template)
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(height: 18) // standard menu bar glyph height (bar is 22pt)
    }
}

struct MenuBarView: View {
    static let preferredWidth: CGFloat = 380

    @ObservedObject var monitor: SystemMonitor
    @StateObject private var applicationActions = ApplicationActionController()
    @State private var contributorsExpanded = false

    private var presentation: DiagnosisPresentation {
        DiagnosisPresentation(
            diagnosis: monitor.diagnosis,
            sleepReminder: monitor.sleepReminder,
            isChecking: monitor.isDiagnosing,
            hasCompletedCheck: monitor.lastCheckedAt != nil
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            Divider()
                .padding(.vertical, 14)

            VStack(alignment: .leading, spacing: 14) {
                conclusion
                if let contributors = monitor.contributors {
                    contributorDisclosure(contributors)
                }
                if let statusMessage = applicationActions.statusMessage {
                    Label(statusMessage, systemImage: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityLabel(statusMessage)
                }
                if let sleepReminder = presentation.sleepReminder {
                    sleepReminderView(sleepReminder)
                }
            }

            Divider()
                .padding(.vertical, 14)

            actions

            #if DEBUG
            Divider()
                .padding(.vertical, 14)
            DiagnosticDetailsView(snapshot: monitor.snapshot)
            #endif
        }
        .padding(20)
        .frame(width: Self.preferredWidth)
        .alert(
            "Force Quit \(applicationActions.pendingForceQuit?.displayName ?? "application")?",
            isPresented: Binding(
                get: { applicationActions.pendingForceQuit != nil },
                set: { if !$0 { applicationActions.cancelForceQuit() } }
            )
        ) {
            Button("Cancel", role: .cancel) {
                applicationActions.cancelForceQuit()
            }
            Button("Force Quit", role: .destructive) {
                applicationActions.confirmForceQuit()
            }
        } message: {
            Text("Unsaved changes may be lost.")
        }
    }

    private func contributorDisclosure(_ contributors: DiagnosisContributors) -> some View {
        DisclosureGroup(isExpanded: $contributorsExpanded) {
            VStack(alignment: .leading, spacing: 9) {
                ForEach(contributors.items) { contributor in
                    contributorRow(contributor)
                }
            }
            .padding(.top, 9)
        } label: {
            HStack {
                Text(contributors.title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(contributors.items.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("\(contributors.items.count) contributors")
            }
        }
    }

    private func contributorRow(_ contributor: DiagnosisContributor) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(contributor.displayName)
                .font(.callout)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 8)

            Text(contributor.metric.displayValue)
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
                .fixedSize()

            Menu {
                if applicationActions.actionsAvailable(for: contributor) {
                    Button("Quit \(contributor.displayName)") {
                        applicationActions.quit(contributor)
                    }
                    Button("Force Quit \(contributor.displayName)…", role: .destructive) {
                        applicationActions.requestForceQuit(contributor)
                    }
                } else {
                    Button("Open Activity Monitor") {
                        applicationActions.inspectInActivityMonitor(contributor)
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 24)
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .accessibilityLabel("Actions for \(contributor.displayName)")
        }
        .accessibilityElement(children: .contain)
    }

    private func sleepReminderView(_ reminder: DiagnosisPresentation.SleepReminder) -> some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: "moon.zzz")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 28)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(reminder.headline)
                    .font(.subheadline.weight(.semibold))
                Text(reminder.detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            WhyLogoView()
                .accessibilityHidden(true)
            Text("Why?")
                .font(.headline)
            Text("Your Mac, explained.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    private var conclusion: some View {
        HStack(alignment: .top, spacing: 11) {
            Group {
                if presentation.kind == .checking {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: presentation.symbolName)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(statusColor)
                }
            }
            .frame(width: 28, height: 28)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                Text(presentation.headline)
                    .font(.title3.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                Text(presentation.detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let lastCheckedAt = monitor.lastCheckedAt, !monitor.isDiagnosing {
                    Text("Last checked \(lastCheckedAt.formatted(date: .omitted, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 2)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var actions: some View {
        HStack {
            Button(monitor.isDiagnosing ? "Checking…" : monitor.lastCheckedAt == nil ? "Check Now" : "Check Again") {
                applicationActions.clearStatus()
                contributorsExpanded = false
                Task { await monitor.refresh() }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
            .disabled(monitor.isDiagnosing)
            .accessibilityHint("Runs a one-time check that takes about five seconds.")

            Spacer()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .keyboardShortcut("q")
            .accessibilityLabel("Quit Why?")
        }
    }

    private var statusColor: Color {
        switch presentation.tone {
        case .neutral: .secondary
        case .positive: .green
        case .warning: .orange
        case .critical: .red
        }
    }
}

#if DEBUG
private struct DiagnosticDetailsView: View {
    let snapshot: SystemSnapshot

    var body: some View {
        DisclosureGroup("Diagnostic Details") {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    metric("Thermal", snapshot.thermalState.label)
                    metric("Memory Pressure", snapshot.memory.pressure.label)
                    metric("Battery", snapshot.power.batteryPercentage.map { "\(Int($0.rounded()))%" } ?? "Unavailable")
                    metric("Power", snapshot.power.source.rawValue)
                    metric("Battery Supplying", booleanLabel(snapshot.power.isBatteryProvidingPower))
                    metric("External Power", booleanLabel(snapshot.power.isExternalPowerAvailable))
                    metric("Charging", snapshot.power.isCharging.map { $0 ? "Yes" : "No" } ?? "Unavailable")
                    metric("Battery Health", snapshot.power.batteryHealth?.rawValue ?? "Unavailable")
                    metric("Low Power Mode", snapshot.power.isLowPowerModeEnabled ? "On" : "Off")
                    metric("Display", snapshot.isDisplayAsleep.map { $0 ? "Asleep" : "Awake" } ?? "Unavailable")

                    if !snapshot.processes.isEmpty {
                        Divider()
                        Text("Top CPU Processes")
                            .font(.subheadline.weight(.semibold))
                        ForEach(snapshot.processes, id: \.pid) { process in
                            metric(process.name, String(format: "%.1f%%", process.cpuUsage))
                        }
                    }
                }
                .padding(.top, 10)
            }
            .frame(maxHeight: 280)
        }
        .font(.caption)
    }

    private func metric(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
            Spacer(minLength: 12)
            Text(value)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
    }

    private func booleanLabel(_ value: Bool?) -> String {
        value.map { $0 ? "Yes" : "No" } ?? "Unavailable"
    }
}

private extension ProcessInfo.ThermalState {
    var label: String {
        switch self {
        case .nominal: "Nominal"
        case .fair: "Fair"
        case .serious: "Serious"
        case .critical: "Critical"
        @unknown default: "Unavailable"
        }
    }
}

private extension MemoryPressureState {
    var label: String {
        switch self {
        case .unknown: "Unknown"
        case .normal: "Normal"
        case .warning: "Warning"
        case .critical: "Critical"
        }
    }
}
#endif
