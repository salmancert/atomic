# AtomicBreak

An iOS app for breaking app-addiction habits, built around the four laws of behaviour
change from *Atomic Habits* — inverted. Track the apps that eat your day, learn the cues
that trigger them, and get nudged at the moments that matter.

| | |
|---|---|
| **Dashboard** | Today's minutes against each app's limit, plus points and streaks |
| **Habits** | Implementation intentions and the replacement activities to reach for |
| **Settings** | Limits, and a way to try each of the four interventions |

## Layout

```
Sources/AtomicCore/   The habit engine. Pure Foundation — no UIKit, no CoreLocation.
Sources/AtomicDemo/   A terminal walkthrough of one day in the loop.
App/                  The iOS app: SwiftUI views, app delegate, platform services.
Tests/                Tests for the engine.
Atomic.xcodeproj      The iOS app target.
Package.swift         Builds and tests the engine on any platform.
```

The split is deliberate: everything that decides *what* to do lives in `AtomicCore` and
is testable on any machine, while `App/` only supplies iOS plumbing — notifications,
location, and SwiftUI. Both are compiled into the app target, so there is one source of
truth for the logic.

## Building the engine (any platform)

```bash
swift build
swift test
swift run AtomicDemo
```

## Building the app

An iOS app can only be built on macOS with Xcode.

```bash
open Atomic.xcodeproj          # then pick a simulator or your device and run
```

## Producing an .ipa

```bash
./Scripts/build-ipa.sh           # unsigned  → build/Atomic-unsigned.ipa
./Scripts/build-ipa.sh --signed  # signed    → build/ipa/Atomic.ipa
```

No Mac? Every push runs the `Build` workflow on a macOS runner and attaches the
**AtomicBreak-unsigned-ipa** artifact to the run — download it from the Actions tab.

### Installing it on an iPhone

The CI build is unsigned, because GitHub's runners hold no signing identity. Pick one:

- **AltStore or Sideloadly** — install the `.ipa` with a free Apple ID. The tool signs
  it with your own certificate on the way in. The app then needs re-signing every
  7 days, which is the limit Apple puts on free accounts.
- **Your own signed build** — with a paid Apple Developer account, put your Team ID in
  `ExportOptions.plist` and run `./Scripts/build-ipa.sh --signed`.
- **Xcode directly** — plug the phone in, select it in Xcode and hit Run. Simplest if
  you have a Mac.

Change `PRODUCT_BUNDLE_IDENTIFIER` in `Atomic.xcodeproj` from `com.salmancert.atomicbreak`
to something under your own domain before signing with your account.

## Where the usage numbers come from

Today they come from `SampleUsageDataSource` — fixed sample figures. Real Screen Time
data needs Apple's **Family Controls** entitlement, which has to be requested and
granted for a specific bundle identifier, and which does not work on a sideloaded build.

Everything else is already wired to the `UsageDataSource` protocol, so once that
entitlement exists, swapping in a `DeviceActivity`-backed implementation is a one line
change in `AtomicBreakEngine`. Streaks, points, rewards and interventions need no
changes at all.

## Known gaps

- **No persistence.** Points, streaks and history live in memory and reset on relaunch.
- **No onboarding.** The profile is `UserProfile.sample()`; target apps and limits are
  not yet editable in the UI.
- **Interventions are notifications only.** Actually adding friction in front of another
  app requires the Screen Time shield APIs, and so the same entitlement.
