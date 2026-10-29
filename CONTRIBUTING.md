# Contributing to Why?

Start with a focused issue or proposed change. V1 diagnostic behavior is frozen;
new sensors, background monitoring, thresholds, and speculative attribution need
discussion before implementation. Reproducible bugs, documentation fixes,
accessibility improvements, and test coverage are welcome.

## Development

Follow the build and test commands in [README.md](README.md). Keep changes small,
preserve macOS 13 application compatibility and arm64 support, and use public APIs.
Do not add dependencies or permissions without a clear reason and discussion.

Use fabricated immutable snapshots for diagnosis tests. Do not make tests depend
on the host's thermal state, running applications, battery level, or sleep
assertions. Keep experimental libproc CPU code behind `#if DEBUG`.

For a proposed change, explain the problem, user-visible behavior, and checks
actually performed. Include appearance captures for UI changes. Exercise both
light and dark appearance and long application names. Do not terminate real user
workloads as part of automated tests.

Never include credentials, signing identities, personal Xcode settings, build
output, or unredacted system reports. Process names, assertion reasons, paths,
and screenshots can disclose private work; share the minimum needed to reproduce
a problem. If a report contains sensitive security information, do not post it
publicly; use the repository's private vulnerability reporting feature if enabled.

Contributions are submitted under the project's MIT license. Submit only work
you have the right to contribute, and identify any third-party content and its
license. Repeated manual diagnosis QA should check that memory usage stabilizes;
optimize only when evidence shows a leak or practical regression.
