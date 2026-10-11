# App Store submission

Legend: **CLI** = Claude runs it · **Browser** = Claude drives dev-browser, you only sign in / approve 2FA · **You** = only you can.

URLs: marketing https://yesterdo.netlify.app · privacy https://yesterdo.netlify.app/privacy · support https://yesterdo.netlify.app/support · email alkait+yesterdo@gmail.com. Site deploys with `tool/site.sh`.

## 1. One-time access (≈5 min of you)
- [x] **You** — Sign into appstoreconnect.apple.com and developer.apple.com in the dev-browser profile (`dev-browser https://appstoreconnect.apple.com`), so Claude can drive it.
- [x] **Browser** — Accept any pending agreements (Business → Free Apps is enough for a free app).
- [x] **Browser** — Create an App Store Connect API key (Users and Access → Integrations → Team Keys, role App Manager). Reused the existing `fastlane` key 5KU77ARTX7. Save the `.p8` to `~/.appstoreconnect/private_keys/`, put `ASC_KEY_ID` and `ASC_ISSUER_ID` in `.env`. From here on, fastlane and `altool` need no login.

## 2. Make the build App Store–safe (CLI, code)
- [x] Hide the hoster update row and its network call in App Store builds (`--dart-define=APP_STORE=true`). Guideline 2.5.2/3.2.2: no links to install builds outside the store.
- [x] Add `ios/ExportOptions-AppStore.plist`: `method` `app-store-connect`, `iCloudContainerEnvironment` `Production`.
- [x] `ITSAppUsesNonExemptEncryption = NO` in `Info.plist` (skips the export-compliance question every build).
- [x] Add `ios/Runner/PrivacyInfo.xcprivacy`: no tracking, no data collected, required-reason APIs (UserDefaults `CA92.1`, file timestamps `C617.1`).
- [x] Check every `NS…UsageDescription` string in `Info.plist` is present and readable.
- [x] `tool/appstore.sh` (bump `pubspec.yaml` first): `fvm flutter build ipa --dart-define=APP_STORE=true --export-options-plist=ios/ExportOptions-AppStore.plist`, upload with `xcrun altool --upload-app --apiKey … --apiIssuer …`.

## 3. CloudKit production (Browser)
- [x] CloudKit console → `iCloud.com.alkait.yesterdo` → Deploy Schema Changes to Production. Without it, sync fails silently for every store user.
- [x] Indexes: none needed; the pull reads zone changes, never a query. `rule` was missing `imageNames`/`images` (added in Development first).

## 4. App record (Browser, or `fastlane produce` with Apple ID + 2FA)
- [x] New app: name Yesterdo, bundle `com.alkait.yesterdo`, SKU `yesterdo`, primary language English. App ID 6821577473. (Apple's API can't create apps; this is the one form.)
- [x] Mac: leave "Make available on Mac (Designed for iPad)" on.

## 5. Metadata (CLI — `fastlane deliver`, from `fastlane/metadata/`)
- [x] Claude writes: name, subtitle, description, keywords, promo text, release notes, support/privacy/marketing URLs, copyright, category (Productivity / Lists), age rating config (all "None" → 4+), review contact (name, email, phone — phone given), review notes (no login needed; iCloud sync optional).
- [x] `cd ios && fastlane metadata` pushes it all, age rating included (`ios/fastlane/`). Re-run after any text change.

## 6. Screenshots (You capture, CLI does the rest)
- [x] Required: iPhone 6.9" (1320×2868) and iPad 13" (2064×2752). 3–5 each.
- [x] `tool/screenshots.sh` seeds a day and takes shots 1–4 per device with no tapping (iPad at Largest text); 5–6 (attention sheet, task view) taken by hand. Uploaded by `cd ios && fastlane metadata`.

## 7. Forms the API can't fill (Browser)
- [x] App Privacy → "Data Not Collected" → Publish.
- [x] Pricing and Availability → Free, all territories.
- [x] Content rights → uses third-party content with the rights (the licensed sounds).
- [x] DSA trader status (EU): already non-trader at account level. Accessibility labels are optional, skipped.

## 8. Ship (CLI)
- [x] `tool/appstore.sh` → wait for processing (`fastlane pilot builds` to poll).
- [x] TestFlight: internal group "Me" (automatic distribution). Build 15 installed over the ad hoc app on the phone and on the Mac (TestFlight for Mac); local data kept, first sync reset into Production and uploaded everything.
- [x] `cd ios && fastlane submit` — 2.4.3 (15) submitted 11 Oct 2026, withdrawn once for the new description (`fastlane withdraw`), resubmitted the same day. Waiting for Review.
- [x] Header and search results images (`design/store/`, 5244×2950), checked uncropped in the Device Preview on iPhone, iPad and iPhone Duo.
- [x] Release: automatic after approval (the version was already set so; nothing to press).

## After
- [ ] Swap the landing page's "Coming soon" button for the App Store link, then `tool/site.sh`.
- [ ] Once released, retire the ad hoc path: `tool/deploy.sh` and `tool/mac.sh` still build for Development CloudKit, which no longer shares data with the phone and Mac. Until then, deploy as is.
