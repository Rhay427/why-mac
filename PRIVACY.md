# Privacy

The current Why? app processes diagnostic information on this Mac. Its source
contains no analytics, telemetry upload, account system, network client,
diagnostic persistence, or license activation service.

At launch, Why? collects an initial system snapshot. When you request a check, it
collects two snapshots approximately five seconds apart. It reads thermal and
power-source state, selected process identifiers/names/CPU readings, application
bundle identity, power-management assertions, and display sleep state. If memory
pressure is elevated, it also collects supporting memory statistics and selected
process footprints. A macOS memory-pressure event observer stays registered while
the app is open. Checks do not run on a repeating timer.

The activity-context probe compares aggregate Core Graphics session event
counters. It does not install an event tap or record keystrokes, typed text,
pointer locations, or individual input events. Process collection does not
inspect full command lines or project metadata.

Snapshots are held in memory and replaced by later checks. Debug builds can show
raw details in the interface. If you share screenshots or bug reports yourself,
review them for application names, process names, assertion reasons, and paths.
macOS and development tools may independently produce crash or test reports.

Application quit actions revalidate application identity before sending a request.
Force Quit requires confirmation. The Activity Monitor handoff opens the system
utility; it does not automatically stop a process.

The static website contains no analytics or forms. Its hosting provider may
process normal web requests under that provider's policies. Forks and modified
builds can behave differently; this statement describes this repository's source.
