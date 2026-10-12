# Timity 4 — Apple Developer and App Store Connect setup

Timity 4 is a SwiftUI rebuild for iOS 26, iPadOS 26 and watchOS 26. It lives in `TimitySwiftUI.xcodeproj` next to
the Timity 3 sources (`Timity/`, `TimityTests/`, `TimityUITests/`, `Timity.xcodeproj`), which aren't part of the new
project and can be deleted once Timity 4 has shipped.

## Project layout

| Folder           | Target(s)                                   | What                                                        |
|------------------|---------------------------------------------|-------------------------------------------------------------|
| `App/`           | Timity                                      | The iOS and iPadOS app                                      |
| `Shared/`        | Timity, TimityWidgets, TimityWatch, TimityWatchWidgets | Date math, sun times, SwiftData model, App Intents, strings |
| `Widgets/`       | TimityWidgets                               | The iOS widget extension's entry point                      |
| `WidgetsShared/` | TimityWidgets, TimityWatchWidgets           | Widgets and complications                                   |
| `Watch/`         | TimityWatch                                 | The watchOS app                                             |
| `WatchWidgets/`  | TimityWatchWidgets                          | The watchOS complications extension's entry point           |
| `Tests/`         | TimityTests                                 | Swift Testing tests for date math, repeats and sun times    |
| `Config/`        | —                                           | Entitlements, Info.plist additions, StoreKit configuration  |

The folders are synchronized groups: files added to them are part of their targets without editing the project.

## Identifiers and capabilities

Register these App IDs in Certificates, Identifiers & Profiles (Xcode does it for development when signing
automatically):

| Bundle ID                            | Capabilities                                                       |
|--------------------------------------|--------------------------------------------------------------------|
| `de.link.timity`                     | iCloud (CloudKit, container `iCloud.de.link.timity`), App Groups (`group.de.link.timity`), Push Notifications |
| `de.link.timity.widgets`             | App Groups (`group.de.link.timity`)                                |
| `de.link.timity.watchkitapp`         | iCloud (CloudKit, container `iCloud.de.link.timity`), App Groups (`group.de.link.timity`), Push Notifications |
| `de.link.timity.watchkitapp.widgets` | App Groups (`group.de.link.timity`)                                |

- **iCloud container** `iCloud.de.link.timity` holds the events in each user's private database.
- **App group** `group.de.link.timity` holds the SwiftData store, so the widgets read what the app writes. The
  Watch app and its complications share the same group on the Watch.
- **Push Notifications** let CloudKit tell a device that events changed elsewhere.

### CloudKit schema

SwiftData creates the CloudKit schema in the **Development** environment the first time a development build syncs.
Before releasing, deploy it to **Production** in the CloudKit Console (container `iCloud.de.link.timity` › Schema ›
Deploy Schema Changes). Without that, App Store builds can't sync. Repeat it whenever `Event` gains a property.

`Event` follows CloudKit's rules: every property has a default, nothing is unique, and enumerations are stored as raw
strings so older versions can read newer data.

## Signing in the deploy workflow

`.github/workflows/deploy.yml` signs each bundle with its own App Store provisioning profile. In addition to the
secrets the workflow already uses (API key, signing certificate, keychain password, `PROVISIONING_PROFILE_BASE64` and
`PROVISIONING_PROFILE_NAME` for the app), add:

| Secret                                      | Value                                                    |
|---------------------------------------------|----------------------------------------------------------|
| `WIDGETS_PROVISIONING_PROFILE_BASE64`       | App Store profile for `de.link.timity.widgets`, base64   |
| `WIDGETS_PROVISIONING_PROFILE_NAME`         | Its name                                                 |
| `WATCH_PROVISIONING_PROFILE_BASE64`         | App Store profile for `de.link.timity.watchkitapp`       |
| `WATCH_PROVISIONING_PROFILE_NAME`           | Its name                                                 |
| `WATCH_WIDGETS_PROVISIONING_PROFILE_BASE64` | App Store profile for `de.link.timity.watchkitapp.widgets` |
| `WATCH_WIDGETS_PROVISIONING_PROFILE_NAME`   | Its name                                                 |

The app's profile has to be regenerated after adding the iCloud, App Groups and Push capabilities to
`de.link.timity`. The variables `TEAM_ID` (`59983C7393`) and `BUNDLE_ID` (`de.link.timity`) stay as they are; the
other bundle IDs are derived from `BUNDLE_ID`.

The build number is the workflow's run number plus 9, set for all four targets on the command line; the marketing
version (`4.0.0`) is `MARKETING_VERSION` in the project.

## Support the Developer

Support works like ImgZen's: optional one-time tips and two subscriptions; no feature is locked. Recurring support
unlocks six **supporter colours** (Sunrise, Aurora, Lagoon, Blossom, Ember, Nightfall) for events, widgets and the
app's tint — App Review requires a subscription to say what it includes (Guideline 3.1.2(c)). When support ends,
events keep the colour they have, but the pickers lock again.

Create the products in App Store Connect › Timity › Monetization. Product identifiers live only in
`App/Support/SupportProductID.swift`; names and prices come from the App Store at runtime.

### One-time support — Consumable

| Product ID                         | Reference name   | Proposed price | Display name (en / de)                      |
|------------------------------------|------------------|----------------|---------------------------------------------|
| `de.link.timity.support.small`     | Small Support    | €2.99          | Small Support / Kleine Unterstützung        |
| `de.link.timity.support.medium`    | Support          | €5.99          | Support / Unterstützung                     |
| `de.link.timity.support.generous`  | Generous Support | €9.99          | Generous Support / Großzügige Unterstützung |

Descriptions: "Buy the developer a coffee." / "Spendiere dem Entwickler einen Kaffee.", "Help keep Timity growing." /
"Hilf mit, dass Timity weiter wächst.", "A big thank you." / "Ein großes Dankeschön."

### Recurring support — Auto-Renewable Subscription

One subscription group, **Support** ("Support Timity" / "Timity unterstützen"), containing:

| Product ID                       | Reference name  | Duration | Proposed price | Group level |
|----------------------------------|-----------------|----------|----------------|-------------|
| `de.link.timity.support.yearly`  | Yearly Support  | 1 year   | €14.99         | 1           |
| `de.link.timity.support.monthly` | Monthly Support | 1 month  | €1.99          | 2           |

- Display names: Yearly Support / Jährliche Unterstützung, Monthly Support / Monatliche Unterstützung.
- Description for both: "Unlocks 6 supporter colours." / "Schaltet 6 Supporter-Farben frei."
- No free trials or introductory offers; Family Sharing off.
- Review notes, e.g.: "Optional developer support; every feature of the app is free. The Monthly and Yearly Support
  subscriptions unlock six gradient colours, shown locked in Settings › Support the Developer › Supporter Colours and
  in the event editor's colour picker, and selectable once subscribed."

The first in-app purchases must be submitted together with an app version.

### Legal pages

The Support screen links to the Terms of Use and the Privacy Policy at
`https://www.linkandreas.de/timity/termsofuse/<language>/` and `https://www.linkandreas.de/timity/privacy/<language>/`
(`App/Support/SupportLinks.swift`). These pages don't exist yet on the website and need to be published in English
and German before the subscriptions go to review; set the privacy URL in App Information as well.

### Testing purchases

`Config/Timity.storekit` defines all five products, and the shared `Timity` scheme uses it when running from Xcode.
Use Debug › StoreKit › Manage Transactions to approve Ask to Buy, refund, or expire subscriptions.

## Moving from Timity 3

On first launch Timity 4 reads Timity 3's Core Data store (`Documents/Timity.sqlite`) and copies its events —
names, dates, photos — into the new store, which then syncs to iCloud. The old file is left untouched. The theme and
highlight colour chosen in Timity 3 carry over as the appearance and accent colour, and the last location the solar
calculator used is kept for the Sun tab.
