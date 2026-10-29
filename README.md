# Why? — Your Mac, explained.

An open-source native macOS menu-bar utility that turns system signals into a
plain-English explanation. Open Why?, choose **Check Now**, and receive the
strongest supported explanation after an observation of about five seconds.

Why? can explain thermal pressure, memory pressure, sustained processor
activity, a likely processor-related contributor to battery use, and supported
sleep-prevention assertions. Related processes are grouped only when their
application identity can be resolved conservatively.

## Status

V1 diagnostic scope is frozen. The source is available on
[GitHub](https://github.com/Rhay427/why-mac). An official signed and notarized download is not available yet.
No purchase, account, or license key is required to build or use the source.

## Requirements

- Apple Silicon Mac; the checked-in project builds for arm64.
- macOS 13 Ventura or later to run the app.
- Xcode 26 or later, with Swift 6 support, to build this project.
- The XCTest target requires macOS 14 or later; the application target remains macOS 13.

## Build and run

Open `Why.xcodeproj`, select the shared **Why** scheme and **My Mac**, then Run.
The app appears in the menu bar and has no Dock window. Local builds use ad-hoc
signing; no paid developer membership or configured development team is needed
for the commands below.

```sh
xcodebuild -project Why.xcodeproj -scheme Why -configuration Debug \
  -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/local build
open .build/local/Build/Products/Debug/Why.app
```

Run the fabricated-snapshot regression suite:

```sh
xcodebuild -project Why.xcodeproj -scheme Why -configuration Debug \
  -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/tests test
```

Build Release:

```sh
xcodebuild -project Why.xcodeproj -scheme Why -configuration Release \
  -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/release clean build
```

A local build is not a notarized public release. Official direct downloads still
need Developer ID signing and notarization. This project currently targets direct
distribution; its process collection and app actions are not designed for the Mac
App Store sandbox.

## How it works

Sensors → immutable `SystemSnapshot` values → diagnosis rules → presentation →
native `MenuBarExtra`.

- CPU: `/bin/ps` is invoked directly, with no shell or command-line inspection.
  Two observations match standalone processes by PID and name, or applications
  by canonical bundle location and bundle identifier. The provisional sustained
  activity threshold is 50% in both observations.
- Identity: supported Security framework APIs resolve executable locations;
  application bundles establish grouping, with optional AppKit display metadata.
- Sleep: public IOKit power-management assertion interfaces.
- Battery: supported power-source information correlated with the existing CPU
  candidate. It does not measure abnormal drain, watts, or battery life.
- Memory: macOS memory-pressure events, with supporting memory data collected
  when pressure is elevated. Low free memory alone is not a diagnosis.
- Thermal: Foundation's reported thermal state.

An initial snapshot is collected at launch. Subsequent diagnosis checks are
manual; there is no periodic sampling timer. A memory-pressure event observer
remains registered while the app is open. See [Privacy](PRIVACY.md).

## Boundaries

Results describe the evidence in a check, not a continuous view of the system.
Short activity can be missed, permissions or process termination can limit
attribution, and top-five process observations do not represent every process
belonging to an application. CPU percentages are sampled evidence, not an energy
measurement. A healthy result is bounded to supported checks, not a guarantee
that every part of the Mac is healthy.

Sleep explanations follow the assertion type. Ordinary idle-sleep assertions do
not establish that manual sleep or closing the lid is blocked. Quiet sleep
reminders remain secondary when a stronger primary explanation exists.

Trusted normal applications offer Quit and a confirmed Force Quit action.
Unresolved or protected contributors offer an Activity Monitor handoff instead.
The experimental libproc CPU sensor is DEBUG-only and is not the Release CPU path.

## Repository

- `Why/`: native app, models, sensors, rules, and presentation.
- `WhyTests/`: fabricated-data tests and presentation/action regression tests.
- `Website/`: static HTML/CSS for Cloudflare Pages; no build step.
- `Marketing/`: product artwork and illustrative catalog screenshots. These are
  examples, not live measurements of the user's Mac.

## Contributing and licensing

Read [CONTRIBUTING.md](CONTRIBUTING.md) before proposing changes. Code and
project-authored documentation are available under the [MIT license](LICENSE).
See [BRANDING.md](BRANDING.md) for the name, logo, artwork, and third-party marks.
