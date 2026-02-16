# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run

```bash
# Build for simulator (iOS 18.1+)
xcodebuild build -scheme BioPulse -destination 'platform=iOS Simulator,name=iPhone 16 Pro'

# Archive for distribution
xcodebuild archive -scheme BioPulse -archivePath /tmp/BioPulse.xcarchive -destination 'generic/platform=iOS' -allowProvisioningUpdates

# Export & upload to TestFlight (IMPORTANT: exclude Homebrew rsync from PATH)
PATH="/usr/bin:$(echo $PATH | tr ':' '\n' | grep -v homebrew | tr '\n' ':')" \
  xcodebuild -exportArchive -archivePath /tmp/BioPulse.xcarchive \
  -exportOptionsPlist ExportOptions.plist -exportPath /tmp/export -allowProvisioningUpdates
```

**Known issue:** Homebrew's rsync 3.4.x breaks Xcode's export pipeline. Always prefix export commands with the PATH override above to use macOS's built-in openrsync.

## Architecture

SwiftUI app with no external dependencies. All data comes from HealthKit (read-only). No backend.

**Data flow:** HealthKit → `HealthDataManager` (callback-based queries) → `@State` in views → UI

- **HealthDataManager.swift** — Single centralized ObservableObject handling all HealthKit queries. Each view creates its own `@StateObject` instance. Queries use completion handlers (not async/await); bridge to `.refreshable` with `withCheckedContinuation`.
- **ContentView.swift** — Root TabView with 5 tabs: Data, Trends, Energy, Recovery, Insights.
- **NightData** struct — Core data model: `date`, `sleepScore`, `hrv`, `restingHeartRate`, `sleepDuration`, `sleepStartTime`, `sleepEndTime`, `totalAwakeTime`. No sleep stage breakdowns (deep/REM/core) are exposed to views.

**User settings** stored in `UserDefaults`: `sleepGoal` (minutes, default 480), `goalWakeTime` (epoch timestamp).

## Key Conventions

- Sleep day boundaries: 6 PM to 6 PM (not midnight). The `minuteOfDay()` helper adds 24×60 for hours before noon to handle this.
- Sleep goal fallback: always use `let val = UserDefaults.standard.integer(forKey: "sleepGoal"); return val > 0 ? val : 480`
- Each view has its own toolbar with info.circle (leading) and gearshape (trailing) presenting InfoView/SettingsView as sheets.
- Pull-to-refresh requires `withCheckedContinuation` to bridge HealthKit's callback API to async/await.
- Card UI: RoundedRectangle cornerRadius 16, `colorScheme == .dark ? Color(.systemGray6) : Color(.systemBackground)`, shadow radius 5.
- Portrait orientation enforced via AppDelegate.

## Project Config

- **Deployment target:** iOS 18.1
- **Signing:** Automatic (cloud-managed distribution certificates)
- **Frameworks:** SwiftUI, HealthKit, Charts (Apple native only)
