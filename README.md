# AtomicBreak

An iOS app for breaking app-addiction habits, built around the four laws of behaviour
change from *Atomic Habits* — inverted. Track the apps that eat your day, learn the cues
that trigger them, and get nudged at the moments that matter.

| | |
|---|---|
| **Today** | Minutes against each limit, the chain, and the votes today cast for your identity |
| **Scorecard** | What you already do each day, marked +, = or − |
| **Plan** | All 21 tools, filed under the law each one serves |
| **Review** | The reflection log and an integrity report of what the record actually says |
| **Settings** | Limits, the habit contract, and the replacement activities |

## The toolkit

Every tool from the book is implemented, filed under the stage of the habit loop it
acts on. The laws are stated here inverted, because this app breaks a habit rather
than builds one — `HabitStage.buildingLaw` gives the other direction.

| Law | Tools |
|---|---|
| **1. Make it invisible** *(cue)* | Habits Scorecard · Implementation Intentions · Habit Stacking · Environment Design · Pointing and Calling |
| **2. Make it unattractive** *(craving)* | Temptation Bundling · Motivation Ritual · Reframing · Social Circle — the close, the many, the powerful |
| **3. Make it difficult** *(response)* | Two-Minute Rule · Law of Least Effort · Commitment Devices · One-Time Actions |
| **4. Make it unsatisfying** *(reward)* | Habit Tracker · Never Miss Twice · Reinforcement · Habit Contract · Accountability Partner |
| **Beyond the four laws** | Identity Votes · Goldilocks Rule · Reflection and Review |

Sixteen of them are things you write down, and live in `Playbook`. The other five run
off live data in the engine:

- **Habit Tracker** and **Never Miss Twice** read the day-by-day chain. One miss is an
  accident; a second in a row raises an alert and offers the two-minute version.
- **Identity Votes** counts each app that stayed under its limit as a vote for the
  person you said you wanted to be, and names the habit voting against you most.
- **Goldilocks Rule** watches the last seven days and offers a new limit when one
  stops being just manageable — tighter when it is never missed, looser when it is
  missed every day. Limits only move when you accept the suggestion.
- **Reflection and Review** keeps the log and produces the integrity report.

The nudges are the same four laws, in order, and each one is written from your own
plan rather than generic advice: the first names the app and the minutes out loud, the
second prices the scroll against something you wanted, the third stalls the opening and
offers your two-minute alternative, and the fourth shows the chain it is about to break
and the vote it is about to cast.

## Layout

```
Sources/AtomicCore/   The habit engine and the toolkit. Pure Foundation.
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
- **No onboarding.** The profile is `UserProfile.sample()` and the plan is
  `Playbook.sample()` — a worked example aimed at phone use. The Plan tab shows the
  toolkit but does not yet let you edit it; the scorecard, intentions, stacks and
  contract are all writable from code today.
- **Interventions are notifications only.** Actually adding friction in front of another
  app requires the Screen Time shield APIs, and so the same entitlement.
