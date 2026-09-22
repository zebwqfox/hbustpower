<div align="center">

# ⚡ 湖科电量 · HBUST Power

**Check your dorm's electricity balance in one glance — no more digging through the campus portal.**

A native iOS client for the Hubei University of Science and Technology dorm electricity service.
Built with UIKit, iOS 26 Liquid Glass, and a fair amount of small delights.

[![Platform](https://img.shields.io/badge/platform-iOS%2026%2B-000000?logo=apple&logoColor=white)](#requirements)
[![Swift](https://img.shields.io/badge/Swift-5.0-F05138?logo=swift&logoColor=white)](#requirements)
[![UI](https://img.shields.io/badge/UI-UIKit%20%2B%20Liquid%20Glass-0A84FF)](#requirements)
[![Widgets](https://img.shields.io/badge/WidgetKit-Home%20%26%20Lock%20Screen-34C759)](#-home-screen--lock-screen-widgets)
[![Foldable](https://img.shields.io/badge/iPhone%20Duo-adapted-8A5CF6)](#-foldable--large-screen)
[![Tests](https://img.shields.io/badge/unit%20tests-26%20passing-2EA043)](#-testing)

<img src="docs/screenshots/home-light.png" width="260" alt="Home screen" />
<img src="docs/screenshots/home-dark.png" width="260" alt="Home screen in dark mode" />
<img src="docs/screenshots/usage-light.png" width="260" alt="Usage chart" />

</div>

---

## Why

The official campus app buries the dorm electricity reading several taps deep. This one answers the two
questions that actually matter — **how much is left** and **how long will it last** — the moment you open it.

Everything is read straight from the school's own web services. No middle server, no account stored anywhere
but your device's Keychain, no password ever saved.

## ✨ Features

### The essentials
| | |
|---|---|
| ⚡ **Balance at a glance** | Remaining kWh, estimated days left, subsidy and unit price |
| 📊 **Usage trends** | Seven-day chart split into lighting and air conditioning; tap or drag to inspect a day |
| 🧾 **Recharge history** | Amounts, kWh and dates, with a summary card and per-record details |
| 💳 **Campus card balance** | Read through the official card portal, multiple cards summed |
| 🔔 **Low-balance reminder** | One local notification when the balance first drops below your threshold |
| 🩺 **Diagnostics page** | Notification state, session state, refresh timings and a redacted report you can copy |

### The delights
- **Liquid balance card** — the card fills like a tank as your balance changes. Tilt the phone and it sloshes;
  flick it sideways and the surface follows your finger.
- **Pull to charge** — pull past the threshold, feel the click, let go and a ring spins while sparks fly. Success
  fills it green with a checkmark; failure shakes it orange.
- **Usage insights** — swipeable cards: *saved 12% this week*, *3 days below average*, *AC used 81% of your power*,
  *your balance is worth ¥57*, *last recharged 12 days ago*.
- **Recharge planner** — pick an amount to see how long it lasts, or pick a date to see what it costs. Split the
  bill between roommates and copy the result into your dorm group chat.
- **Hand-made touches** — doodled underlines, slightly crooked stickers, a taped paper note on the About page,
  and an easter egg hiding in the developer avatar.

### 🎨 Themes
Three palettes, switchable in **Settings → Appearance**. Two of them are modelled on friends' fursuits.

| Theme | Palette | Extra |
|---|---|---|
| **湖科蓝** (HBUST Blue) | Cloud white + clear blue | The original look |
| **紫鸟紫** (Purple Bird) | Night violet + amber | A line from Tagore's *Stray Birds* greets you on every launch |
| **枫烻黄** (Maple Yellow) | Warm amber + collar red | A bell that swings when you tap it |

Switching repaints everything — cards, charts, the liquid, sparks and the widgets.

<div align="center">
<img src="docs/screenshots/theme-picker.png" width="250" alt="Theme picker" />
<img src="docs/screenshots/about.png" width="250" alt="About page" />
<img src="docs/screenshots/changelog.png" width="250" alt="In-app changelog" />
</div>

### 📱 Home screen & lock screen widgets
Small, medium, and all three lock-screen families, following the app's theme and turning amber when the balance
runs low.

<div align="center">
<img src="docs/screenshots/widgets.png" width="300" alt="Widget preview" />
</div>

> **Note** · Widgets read the app's data through an **App Group** (`group.com.local.hbustpower`), which requires a
> paid Apple Developer membership. Sideloading with a free Apple ID installs the extension but leaves it without
> shared storage, so it will keep showing its "open the app once" placeholder. **Settings → Diagnostics → Widgets**
> tells you whether the shared container is really available.

### 📐 Foldable & large screen
Adapted to iPhone Duo following Apple's guidance: layout decisions come from **size classes**, never from screen
dimensions or orientation.

- Two even columns on the unfolded inner display and on iPad; one column on the outer display and on phones.
- When half folded, the gap between the columns is aligned to the **exact hinge position**
  (`reservedRegions(kind: .division)`, iOS 27.1+), so no card or button sits on the crease.
- Content respects asymmetric safe areas, so the vertical bar on the outer display never covers anything.
- Verified on the iPhone Duo simulator in all four poses: outer, inner landscape, inner portrait, half folded.

<div align="center">
<img src="docs/screenshots/duo-inner.png" width="380" alt="Unfolded inner display" />
<img src="docs/screenshots/duo-half-folded.png" width="380" alt="Half folded, columns aligned to the hinge" />
</div>

<details>
<summary><b>More screens</b></summary>

<div align="center">
<img src="docs/screenshots/records-light.png" width="240" alt="Recharge history" />
<img src="docs/screenshots/campus-card-1.6.0.png" width="240" alt="Campus card" />
<img src="docs/screenshots/settings-light.png" width="240" alt="Settings" />
<img src="docs/screenshots/xuexitong-glass-1.4.5.png" width="240" alt="Sign-in" />
</div>

</details>

## 🔐 Privacy & security

- **The password never leaves the official page.** Sign-in happens on the school's own Chaoxing form; the app only
  fills the fields you typed and never stores the password.
- **Only the authorization link is kept**, in the Keychain with `AfterFirstUnlockThisDeviceOnly`.
- **No backend.** All requests go directly to the school; nothing is proxied or collected.
- **Diagnostics are redacted** — no account, dorm number, authorization URL or cookie values.
- Redirect URLs are validated strictly: exact host, exact path, exactly one `appId=180` and one non-empty token.

## 🚀 Getting started

### Requirements
- Xcode 26 or newer (Xcode 27.1+ to run the iPhone Duo simulator)
- iOS 26+ device or simulator
- An Apple Developer account if you want working widgets (App Group capability)

### Build and run
```sh
git clone https://github.com/zebwqfox/hbustpower.git
cd hbustpower/ios
open HBUSTPowerIOS.xcodeproj
```
Select your team under **Signing & Capabilities**, pick a device, and run.

### Configure the school entry point
`ios/HBUSTPowerIOS/Services/ElectricityService.swift` holds the OAuth entry URL for the campus card service. The
`appKey` is redacted in this repository:

```
appKey%3DREPLACE_WITH_YOUR_SCHOOL_APP_KEY
```

Obtain the current value from the official campus portal entry before building. The other parameters (`fidEnc`,
`mappId`, `wfwEnc`) are this school's configuration and are not portable to other universities.

### Unsigned IPA for sideloading
```sh
cd ios
./build_sideloadly_ipa.sh        # writes dist/湖科电量-iOS26-Sideloadly.ipa
```
Drop the IPA into [Sideloadly](https://sideloadly.io) and let it re-sign with your Apple ID.
**Leave "Use automatic bundle ID" unchecked** — it rewrites the app's bundle identifier, and the widget extension
must stay prefixed by it, or iOS silently ignores the extension.

### Debug launch arguments
Debug builds accept flags that make the UI easy to inspect offline:

| Flag | What it does |
|---|---|
| `--ui-preview` | Offline demo data, no network |
| `--preview-tab=1…4` | Open Usage / Recharges / Campus card / Settings |
| `--preview-about`, `--preview-changelog`, `--preview-widgets` | Jump straight to those screens |
| `--slow-refresh-preview` | Delay the demo refresh by 3s to watch the charging animation |
| `--liquid-gravity-x=-0.5` | Fake gravity to check the liquid's tilt direction |
| `--simulate-vertical-bar` | Fake an asymmetric safe area, as on the Duo outer display |

## 🧱 Project layout

```
ios/
├─ HBUSTPowerIOS/
│  ├─ Models/           AppModel, snapshots, insights, recharge planner, changelog
│  ├─ Services/         Networking, HTML parsing, Keychain, notifications, diagnostics
│  ├─ ViewControllers/  Overview, Usage, Records, Campus card, Settings, About, Planner…
│  └─ Views/            Theme, motion, charts, liquid, stickers, pull-to-charge
├─ HBUSTPowerWidgets/   WidgetKit extension
├─ Shared/              Code shared by app and widgets (theme, snapshot, widget views)
├─ HBUSTPowerIOSTests/  Unit tests
└─ WidgetSupport/       Widget Info.plist and entitlements
```

**How the data flows.** The WebView completes the official sign-in, the app captures the electricity redirect,
copies the school cookies into its HTTP session, then fetches three pages and parses them. Parsing lives in
`ElectricityHTMLParser`, kept free of networking so it can be tested against fixtures.

## 🧪 Testing

```sh
cd ios
xcodebuild test -project HBUSTPowerIOS.xcodeproj -scheme '湖科电量' \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

26 unit tests cover the fragile parts: HTML parsing (missing fields must not bleed into the next record, dates are
always Beijing time, a footer mentioning the auth service is not a login page), usage insights, the recharge
planner's arithmetic, theme definitions, widget snapshots, and the changelog staying in sync with the app version.

## 🗺️ Roadmap

- [x] iOS app
- [x] Themes, widgets, recharge planner
- [x] iPhone Duo adaptation
- [ ] Android client (Kotlin + Jetpack Compose) — coming to `android/` in this repository
- [ ] Widgets verified on device with a paid signing team

## 🙏 Credits

- Sign-in runs through the official Chaoxing / HBUST campus services; the Chaoxing logo is used only to label
  that sign-in path.
- The **紫鸟紫** and **枫烻黄** palettes are named after and inspired by two friends.
- *Stray Birds* lines are from Tagore's 1916 collection in Zheng Zhenduo's 1922 translation, both in the public
  domain.

---

<div align="center">
<sub>Made with ⚡ &amp; ☕ · Built for one dorm, shared with whoever needs it.</sub>
</div>
