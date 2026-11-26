# Scrll (Tidyroll)

A free, private iOS app for sorting and cleaning up your camera roll. It has no ads,
no subscriptions, no account and no network access. Everything runs on the device.

> The code name is **Scrll**. On the home screen the app is called **Tidyroll**
> (`CFBundleDisplayName` in `project.yml`). Change it before publishing if you want to.

## Features

| Tab | What it does |
| --- | --- |
| **Library** | Every photo and video, grouped by month. Tap to open a full-screen viewer with swipe paging, video playback, share, favorite, add to album and delete. Use **Select** to act on many items at once, including "Select All" for a whole month. |
| **Review** | Go through a month (or 30 random photos) one card at a time. Swipe **right** to keep, **left** to delete, **up** to favorite, with unlimited undo. Nothing is deleted until you confirm on the summary screen, where you can still keep any photo you marked. Kept photos are remembered, so later passes skip them. |
| **Albums** | Create, rename and delete albums, browse them, and remove photos from them. Deleting an album leaves its photos in the library. |
| **Clean Up** | **Duplicates**: an on-device perceptual-hash scan that suggests the best copy to keep. **Screenshots** and **Long Videos** (over a minute) let you select in bulk and delete. |
| **Settings** | Shows the current photo access level, lets you choose more photos when access is limited, resets review progress, and states the privacy promises. |

Every deletion goes through iOS's own confirmation. Deleted items go to
**Recently Deleted** in the Photos app and can be recovered for 30 days.

## Requirements

- Xcode 16 or later
- iOS 17.0 or later (iPhone)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

## Getting started

```sh
brew install xcodegen
xcodegen generate
open Scrll.xcodeproj
```

In Xcode, pick your team under **Signing & Capabilities** and change the bundle
identifier (`org.scrll.tidyroll`) to one you own. Then run on a device or a simulator.
To get sample photos into the simulator, drag images onto it.

Run the tests with ⌘U, or from the command line:

```sh
xcodebuild test -project Scrll.xcodeproj -scheme Scrll \
  -destination 'platform=iOS Simulator,name=iPhone 16' CODE_SIGNING_ALLOWED=NO
```

CI (`.github/workflows/ios.yml`) generates the project, builds it and runs the unit
tests on every push.

## Project layout

```
Scrll/
  App/          App entry point, permission gate, tab bar
  Core/         Pure logic with unit tests: perceptual hash, duplicate grouping,
                review session (undo), month grouping, review progress store
  Photos/       PhotoKit wrappers: library snapshot and changes, image loading,
                duplicate scanner
  Features/     SwiftUI screens: Library, Viewer, Review, Albums, Cleanup,
                Settings, Onboarding
  Shared/       Reusable views and helpers
  Resources/    Asset catalog (icon, accent colour), privacy manifest
ScrllTests/     XCTest unit tests for Core/
```

## Privacy

- The app makes no network requests and includes no analytics or third-party SDKs.
- Review progress (IDs of kept photos) is stored in Application Support. Duplicate
  hashes are cached in Caches. Neither leaves the device.
- `PrivacyInfo.xcprivacy` declares no tracking and no collected data.
