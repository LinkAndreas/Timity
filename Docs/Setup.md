# Timity 4 — Apple Developer and App Store Connect setup

Timity 4 is a SwiftUI rebuild for iOS 27, iPadOS 27 and watchOS 27. It lives in `Timity.xcodeproj`.

## Project layout

| Folder           | Target(s)                                   | What                                                        |
|------------------|---------------------------------------------|-------------------------------------------------------------|
| `App/`           | Timity                                      | The iOS and iPadOS app                                      |
| `Shared/`        | Timity, TimityWidgets, TimityWatch, TimityWatchWidgets | Date math, sun times, SwiftData model, App Intents, strings |
| `Widgets/`       | TimityWidgets                               | The iOS widget extension's entry point                      |
| `WidgetsShared/` | TimityWidgets, TimityWatchWidgets           | Widgets and complications                                   |
| `Watch/`         | TimityWatch                                 | The watchOS app                                             |
| `WatchWidgets/`  | TimityWatchWidgets                          | The watchOS complications extension's entry point           |
| `Tests/`         | TimityTests                                 | Swift Testing tests for date math, repeats, sun times, milestones and holidays |
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

### Changing the data model

The stored `Event` is versioned (`EventSchemaV1` in `Shared/Persistence/SwiftDataEventStore.swift`), and every store
opens with `EventMigrationPlan`, so a later version can move existing stores to a new shape. iCloud sets the limits:
its Production schema only ever gains fields, and the user's other devices may still run an older Timity.

- **Add, don't change.** New properties need a default value or are optional. Never rename or delete a property or
  change its type; stop using it instead and leave a comment, as `checklistData` shows. Nothing may be unique, and
  relationships must be optional.
- **Make a new version.** Copy the newest `EventSchemaV…` to the next one (`EventSchemaV2`, version 2.0.0), make the
  change there, and leave older versions untouched. Add it to `EventMigrationPlan.schemas`, add
  `.lightweight(fromVersion: EventSchemaV1.self, toVersion: EventSchemaV2.self)` to `stages`, point the `Event`
  typealias at the new class, and map the new property in `snapshot` and `update(from:)`.
- **Keep migrations lightweight.** A custom stage runs on each device separately, while iCloud carries the old values
  between them; transform values when reading them in `snapshot` rather than in a migration.
- **Deploy the CloudKit schema** before releasing: run a debug build, tap Settings › iCloud › Prepare iCloud Schema,
  and deploy to Production in the CloudKit Console. Then add the new field to the `deployedSchema` test.
- The tests check that each version is newer than the last and keeps every field of the one before.

### Crash and hang reports

MetricKit hands Timity iOS's own crash, hang, CPU, disk-write and launch diagnostics (`DiagnosticsCollector`). They
stay in Application Support/Diagnostics (the newest 20) and, only with Settings › Privacy › Share Crash Reports on
(off by default), go to the container's **public** database as `DiagnosticReport` records: `kind`, `appVersion`,
`build`, `osVersion`, `device` and the report as the `payload` asset. Before releasing:

1. Turn the setting on in a development build so the record type is created, then deploy the schema to Production.
2. In the CloudKit Console › Schema › Security Roles, make `DiagnosticReport` private: **World** no access,
   **Authenticated** Create only (no Read), **Creator** as it is. Otherwise any iCloud user could read reports.
3. Add a Queryable index on `recordName` and a Sortable one on `createdTimestamp`, to list reports in the Console
   (Records › Public Database › `DiagnosticReport`).
4. App Store Connect › App Privacy: Diagnostics › Crash Data and Performance Data, not linked to the user, not used
   for tracking, for App Functionality. Mention it in the privacy policy.

The `payload` is MetricKit's JSON; symbolicate its call stacks with the archive's dSYMs.

## Concurrency

Swift 6 with approachable concurrency, and the main actor as the default isolation (`SWIFT_DEFAULT_ACTOR_ISOLATION =
MainActor`, `SWIFT_APPROACHABLE_CONCURRENCY = YES`): new code runs on the main actor unless it says otherwise.
The widget extensions are the exception: they build timelines off the main thread, so their default is `nonisolated`.
Shared code that must run on the main actor says so with `@MainActor`, so it behaves the same in every target. App
Intents, their entity and query, and the widget configuration intent carry no isolation of their own: the App Intents
macros can't expand inside a `nonisolated` type, and the per-target default puts them where each target needs them.

- **`nonisolated`** marks what runs anywhere: the date, astronomy and model types, the store and its reader, widget
  timeline providers and entries, App Intents, system delegates (WatchConnectivity, notifications, MetricKit), file
  transfer and the logger. Types nested in them are marked too.
- **`nonisolated async`** functions run on their caller's actor. Work that takes a while is **`@concurrent`**, so it
  never runs on the main actor: reminder scheduling, Spotlight indexing, calendar import, the event-text parser,
  preparing a picked photo and sending crash reports. Contacts import runs in a detached task.

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
unlocks six **alternative app icons** (Sunrise, Lagoon, Forest, Rose, Midnight, Ember), picked in
Settings › Support the Developer › App Icon. The tint is free for everyone in Settings › Appearance — App Review requires a
subscription to say what it includes (Guideline 3.1.2(c)). When support ends, the chosen icon stays (the app never
changes it unasked, which would show a system alert), but the picker locks again.

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
- Description for both: "Unlocks 6 alternative app icons." / "Schaltet 6 alternative App-Icons frei." /
  "Débloque 6 icônes d’app alternatives." / "Desbloquea 6 iconos alternativos."
- No free trials or introductory offers; Family Sharing off.
- Review notes, e.g.: "Optional developer support; every feature of the app is free. The Monthly and Yearly Support
  subscriptions unlock six alternative app icons, shown locked in Settings › Support the Developer › App Icon, right
  above the subscriptions, and selectable there once subscribed."

The first in-app purchases must be submitted together with an app version.

French and Spanish names and descriptions for every product are in `Config/Timity.storekit`; copy them into App
Store Connect as well.

### Legal pages

The Support screen links to Apple's Standard License Agreement as Terms of Use, and to the Privacy Policy at
`https://timity.linkandreas.de/privacy/<language>/` (`App/Support/SupportLinks.swift`), published by the
[Timity website](https://github.com/LinkAndreas/Timity-Website) in English, German, Spanish and French; any other
language gets English. Set the same URL, per localization, in App Information. Every field for the products
themselves is in
[`AppStoreConnect-Products.md`](AppStoreConnect-Products.md).

## App icon

The icon is an Icon Composer file, `Shared/AppIcon.icon` (iPhone, iPad and Watch), with vector layers for the
background, the countdown ring and the clock hands, in light, dark and tinted variants; the system renders the
Liquid Glass look, the clear style and every size from it. The six supporter icons are `App/AppIcons/AppIcon-<Name>.icon`
(iPhone and iPad only — watchOS doesn't support alternate icons), listed in the app target's *Alternate App Icon Sets*.
`IconPreview-<Name>` images in the asset catalog show them in the picker; regenerate them when an icon changes.
[`Docs/AppIconPreview.png`](AppIconPreview.png) shows the whole set.

## Languages

English, German, French and Spanish: `Shared/Resources/Localizable.xcstrings` for the app, widgets and Watch, and
`App/Resources/InfoPlist.xcstrings` for permission prompts. Add App Store metadata (description, keywords,
screenshots) for French and Spanish in App Store Connect.

Strings are looked up by **semantic keys** — `Text("settings.rateTimity")`, `String(localized: "import.added \(count)")` —
named `<screen>.<what>`, or `common.<what>` when several screens share them. The English text is the key's `en` value
in the catalog, so changing copy never changes a key and never loses a translation. Add a new string by writing its key
in code, building once so Xcode adds it to the catalog, then filling in English, German, French and Spanish.
Interpolations follow the key in order (`"import.added \(count)"` is `import.added %lld`). Strings made only of
placeholders (`"%@ %@"`) and App Intents summaries (`"Add ${name} on ${date}"`) keep their text as the key.

### Testing purchases

`Config/Timity.storekit` defines all five products, and the shared `Timity` scheme uses it when running from Xcode.
Use Debug › StoreKit › Manage Transactions to approve Ask to Buy, refund, or expire subscriptions.

## Features that need no extra setup

- **Import from Contacts and Calendar** asks for access the first time (`NSContactsUsageDescription`,
  `NSCalendarsFullAccessUsageDescription`). Birthdays without a year are stored with a placeholder year and
  `isYearUnknown`, so no age is shown.
- **Live Activities** (`NSSupportsLiveActivities`): an event's detail screen offers *Show on Lock Screen* in the last
  eight hours before it — the longest a Live Activity runs. They're started from the app only; there's no push server.
- **New Event control** in Control Center and on the Lock Screen (iOS 18 and later).
- **Typing an event** ("Mum's birthday on 3 March") uses Apple Intelligence's on-device model where it's available,
  and the system's date detection otherwise.
- **Milestones** (10,000 days, a billion seconds) are shown on each event; *Milestone Alerts* in Settings sends a
  notification on the day.
- **Public holidays** for working days are calculated in code for Germany, Austria, Switzerland, France, Italy,
  Spain, the Netherlands, the UK (England and Wales) and the US — nationwide holidays only.
- **The Watch syncs exactly when the iPhone does.** The iPhone sends through WatchConnectivity whether it really
  syncs — off until its welcome has asked — and whether the welcome is done (`WatchConnectivitySyncSettingSharer`,
  `PhoneSyncSetting`). Until it has heard, the Watch keeps events to itself and asks the iPhone directly, which
  wakes Timity there; its status then reads "Waiting for Timity on iPhone". Events added on the Watch meanwhile
  sync once it does. Each launch opens the Watch's store without iCloud and turns iCloud on only once the
  iPhone's latest word is in (or after five seconds without WatchConnectivity), so a switch-off made while the
  Watch app was closed never lets it sync; when watchOS wakes the app in the background to deliver a change, it
  stays awake until the change is applied (`.backgroundTask(.watchConnectivity)`). On a new iPhone or iPad, the welcome's iCloud page says when the account already has
  Timity's events from another device (`CloudKitEventsChecker`).
- **Life in Weeks** keeps the birthday in the app group's user defaults for its widget. It isn't synced, so the Watch
  doesn't show it.
- **Send a Copy** shares an event as a `.timity` file (`de.link.timity.event`, declared in `Config/Timity-Info.plist`);
  opening it in Timity opens the editor with the event filled in. It's a copy — changes don't sync between people,
  as SwiftData doesn't support shared iCloud records.
- **Mac and Apple Vision Pro** run the iPad app (*Designed for iPad*); choose their availability in App Store Connect
  under Pricing and Availability.

- **Repeats** can be every N days, weeks, months or years, on the nth or last weekday, on the last working day, or
  yearly by the Chinese, Hebrew, Islamic, Persian or Indian calendar (`RecurrenceRule`).
- **Progress** shows how much of the wait has passed; **Start Over** turns a past event into a counter with streaks.
- **Calculators:** working days in Add & Subtract, Hours, Time Zones and Exact Age.
- **Sun tab:** moon phase, moonrise and moonset, the next phases, equinoxes and solstices, and the next clock change.
- **Import:** public holidays for the next twelve months, named in the country's language.
- **Widgets:** Time Left (day, week, month and year) and Sun (the next sunrise, golden hour or sunset). The Sun widget
  uses the last location the Sun tab found; on the Watch, the Watch app's Sun screen finds it
  (`NSLocationWhenInUseUsageDescription` on the Watch target).
- **Add to Calendar** opens Calendar's own new-event sheet, which needs no calendar access.

- **Onboarding** greets new users (welcome, import, own birthday, suggested events); people with events skip it.
  **Templates** (New Year's Eve, Christmas, payday, next public holiday, weekend, summer, vacation) start new events.
- **Year in Review** counts the year's moments per month, the busiest month and the longest streak, as a share card.
- **Interactive widgets:** the medium countdown widget pins and unpins, and starts counters over. Widgets write to the
  shared store; the app sends those changes to iCloud the next time it runs.
- **Rating prompt:** Apple's own (`requestReview`), only after a week of use, four active days and three good
  moments (a new event saved, an event opened on its day), never during the welcome, and at most once per version
  (`ReviewPrompter`). Apple decides whether it appears. Feedback has its own way in: Settings › About › Send Feedback
  and the iCloud help's sync report.
- **Spotlight** finds events; **Shortcuts and Siri** gain Add Countdown, Days Between Dates and Add to Date.
- **Search** on iPhone sits in the Events list: pulling it down reveals the field, as does the magnifying glass in its
  toolbar, which reads Search, Sort and Filter, More; it finds events in every list, archived or past. The tab bar ends
  in a + (`TabRole.prominent`) that adds an event. On iPad, search is the sidebar's Search page and the Events toolbar
  keeps its +.
- **Apple Watch:** add events by dictation, Double Tap opens the next event, and countdown complications rise in the
  Smart Stack on the event's day.
- **Menu bar and keyboard shortcuts** on iPad and Mac: ⌘N new event, ⇧⌘N from a template, ⇧⌘I import, ⌘1–3 tabs,
  ⌘F search, ⇧⌘Y Year in Review.
- **Accessibility:** the countdown number scales with text size, chips use two columns at accessibility sizes, the sun
  chart is described to VoiceOver, and the moving photo stops with Reduce Motion.

`Event` gained `checklistData`; deploy the CloudKit schema again.

`Event` gained `timeZoneIdentifier`, `listName`, `isArchived` and `isYearUnknown`, and later `recurrenceInterval`,
`recurrencePatternRawValue`, `calendarRawValue`, `showsProgress`, `progressStart` and `resetHistoryData`; deploy the CloudKit schema to
Production again after a development build has synced them.

## Moving from Timity 3

On first launch Timity 4 reads Timity 3's Core Data store (`Documents/Timity.sqlite`) and copies its events —
names, dates, photos — into the new store, which then syncs to iCloud. The old file is left untouched. The theme chosen
in Timity 3 carries over as the appearance, and the last location the solar
calculator used is kept for the Sun tab.
