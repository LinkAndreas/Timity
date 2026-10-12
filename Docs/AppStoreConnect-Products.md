# Support the Developer — App Store Connect metadata

Everything App Store Connect asks for on Timity's in-app purchases, ready to copy. Product IDs must match
`App/Support/SupportProductID.swift` exactly. Names and descriptions are within App Store Connect's limits
(display name 30 characters, description 45).

## Before you start

- **Agreements, Tax, and Banking:** the Paid Apps agreement must be active, or the App Store returns no products.
- **App Information › Privacy Policy URL:** `https://www.linkandreas.de/timity/privacy/en/` (German:
  `…/privacy/de/`). The page has to be published first — App Review rejects subscriptions without it.
- **App Information › License Agreement:** keep Apple's Standard License Agreement. The app links to it as Terms of
  Use (`SupportLinks.termsOfUse`), so no terms page of your own is needed.
- **App description (all languages):** end it with
  `Terms of Use: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/` — App Review looks for the
  terms in the description of apps with subscriptions.

## One-time support — Consumable

Monetization › In-App Purchases › +, type **Consumable**, for each:

| Field | Small | Medium | Generous |
|---|---|---|---|
| Reference Name | Small Support | Support | Generous Support |
| Product ID | `de.link.timity.support.small` | `de.link.timity.support.medium` | `de.link.timity.support.generous` |
| Price | €2.99 / $2.99 | €5.99 / $5.99 | €9.99 / $9.99 |
| Availability | All countries or regions | All | All |
| Family Sharing | Off (consumables can't be shared) | | |
| Tax Category | Match to parent app | | |

Localizations (Display Name / Description):

| Language | Small | Medium | Generous |
|---|---|---|---|
| English (U.S.) | Small Support / Buy the developer a coffee. | Support / Help keep Timity growing. | Generous Support / A big thank you. |
| German | Kleine Unterstützung / Spendiere dem Entwickler einen Kaffee. | Unterstützung / Hilf mit, dass Timity weiter wächst. | Großzügige Unterstützung / Ein großes Dankeschön. |
| French | Petit soutien / Offrez un café au développeur. | Soutien / Aidez Timity à grandir. | Soutien généreux / Un grand merci. |
| Spanish (Spain) | Pequeño apoyo / Invita a un café al desarrollador. | Apoyo / Ayuda a que Timity siga creciendo. | Apoyo generoso / Un gran agradecimiento. |

Add English (U.K.), French (Canada) and Spanish (Mexico) with the same texts if you sell there in those languages.

**Review Information** (each consumable):
- Screenshot: Settings › Support the Developer, showing the One-Time Support section (any iPhone screenshot,
  at least 640 × 920 pixels).
- Review notes: "Optional tip to support the developer. It unlocks nothing; every feature of Timity is free. Found in
  Settings › Support the Developer."

## Recurring support — Auto-Renewable Subscriptions

Monetization › Subscriptions › Create a **subscription group**:

| Field | Value |
|---|---|
| Reference Name | Support |
| App Name Display Options | Use App Name |

Group localizations (Subscription Group Display Name / description):

| Language | Display Name | Description |
|---|---|---|
| English (U.S.) | Support Timity | Optional recurring support that unlocks alternative app icons. |
| German | Timity unterstützen | Optionale regelmäßige Unterstützung, die alternative App-Icons freischaltet. |
| French | Soutenir Timity | Soutien régulier facultatif qui débloque des icônes d’app alternatives. |
| Spanish (Spain) | Apoyar Timity | Apoyo periódico opcional que desbloquea iconos alternativos de la app. |

App Store Connect shows the display name on the subscription sheet and in the user's subscriptions in Settings. It
has no description field for groups; the descriptions are used by `Config/Timity.storekit` for testing in Xcode.

Then two subscriptions in that group:

| Field | Yearly | Monthly |
|---|---|---|
| Reference Name | Yearly Support | Monthly Support |
| Product ID | `de.link.timity.support.yearly` | `de.link.timity.support.monthly` |
| Subscription Duration | 1 year | 1 month |
| Group level | 1 (top) | 2 |
| Price | €14.99 / $14.99 | €1.99 / $1.99 |
| Availability | All countries or regions | All |
| Family Sharing | Off | Off |
| Introductory, promotional, win-back offers | None | None |
| Tax Category | Match to parent app | |

Localizations (Display Name / Description):

| Language | Yearly | Monthly |
|---|---|---|
| English (U.S.) | Yearly Support / Unlocks 6 alternative app icons. | Monthly Support / Unlocks 6 alternative app icons. |
| German | Jährliche Unterstützung / Schaltet 6 alternative App-Icons frei. | Monatliche Unterstützung / Schaltet 6 alternative App-Icons frei. |
| French | Soutien annuel / Débloque 6 icônes d’app alternatives. | Soutien mensuel / Débloque 6 icônes d’app alternatives. |
| Spanish (Spain) | Apoyo anual / Desbloquea 6 iconos alternativos. | Apoyo mensual / Desbloquea 6 iconos alternativos. |

**Review Information** (each subscription):
- Screenshot: Settings › Support the Developer, scrolled to the App Icon section (icons locked) and the Recurring
  Support section below it.
- Review notes: "Optional support for the developer; every feature of Timity stays free. The Monthly and Yearly
  Support subscriptions unlock six alternative app icons. They're shown locked in Settings › Support the Developer ›
  App Icon, right above the subscriptions, and can be chosen there once subscribed. Subscribe in the sandbox to see
  them unlock."

The subscriptions also have an optional **App Store Promotion** image (1024 × 1024); leave it empty unless you want
to promote them on the product page.

## Submitting

The first in-app purchases and subscriptions are reviewed with an app version: on the version's page, under
**In-App Purchases and Subscriptions**, add all five before submitting. Their status should read
"Ready to Submit" — if one says "Missing Metadata", it's usually the review screenshot or a localization.

## Testing

`Config/Timity.storekit` has the same products, names and prices, and the shared Timity scheme uses it when running
from Xcode. For TestFlight and the App Store, the products come from App Store Connect.
