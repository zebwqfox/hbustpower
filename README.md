<div align="center">

# 湖科电量 · HBUST Power

Native iOS and Android apps for checking your dorm's electricity balance at Hubei University of Science and Technology.

[简体中文](README.zh-CN.md) · English

[![Platforms](https://img.shields.io/badge/platforms-iOS%2026%2B%20%7C%20Android%206%2B-2563EB)](#getting-started)
[![Languages](https://img.shields.io/badge/Swift%20%7C%20Kotlin-native-F05138)](#getting-started)
[![Tests](https://img.shields.io/badge/tests-149-2EA043)](#testing)

<img src="docs/screenshots/home-light.png" width="250" alt="Home screen" />
<img src="docs/screenshots/home-dark.png" width="250" alt="Dark mode" />
<img src="docs/screenshots/usage-light.png" width="250" alt="Usage chart" />

</div>

## Why

On the campus portal, the dorm electricity reading is several taps deep. This app puts the two numbers people check
most on the first screen: how much is left, and roughly how many days that lasts.

Balance, usage and recharge data are read straight from the school's own web pages. Your password is never stored.

## Features

| | |
|---|---|
| Balance | Remaining kWh, estimated days left, subsidy and unit price |
| Usage | Seven-day chart of lighting and air conditioning; tap or drag to read a single day |
| Recharges | History with a summary card, plus every field of a single record |
| Campus card | Balance read through the official card portal; several cards are added up |
| Reminder | One local notification when the balance first drops below your threshold |
| Updates | A prompt when a new version is out, and short notices such as planned school maintenance |
| Diagnostics | Notification and session state, refresh timings, and a redacted report you can copy |

Some smaller touches:

- The balance card fills like a tank. Tilt the phone and the surface tilts with it; push the card sideways and the
  liquid follows your finger. A new reading counts up from the old one.
- Refreshing takes a full pull and a release. A ring spins while the app fetches, then turns into a green check, or
  shakes orange if the school didn't answer.
- Usage insights are small cards you swipe through: 12% less than last week, 3 days below average, air conditioning
  used 81% of the power, the balance is worth about ¥57, last recharge 12 days ago.
- The recharge planner works both ways. Pick an amount to see how long it lasts, or a date to see the least you need
  to top up. It splits the bill between roommates and copies a line for the group chat.
- Doodled underlines, slightly crooked stickers, a taped note on the About page, and one easter egg.

### Themes

**Settings → Appearance** has three palettes. Two are named after friends.

| Theme | Palette | Extra |
|---|---|---|
| 湖科蓝 | Cloud white and blue | The original look |
| 紫鸟紫 | Night violet and amber | A line from Tagore's *Stray Birds* on every launch |
| 枫烻黄 | Warm amber and collar red | A bell that swings when tapped |

A theme changes the cards, charts, liquid, sparks and widgets together.

<div align="center">
<img src="docs/screenshots/theme-picker.png" width="240" alt="Theme picker" />
<img src="docs/screenshots/about.png" width="240" alt="About page" />
<img src="docs/screenshots/changelog.png" width="240" alt="Changelog" />
</div>

### Widgets

Small and medium home screen widgets, plus all three lock screen families. They use the app's theme and switch to the
warning colour when the balance runs low.

<div align="center">
<img src="docs/screenshots/widgets.png" width="300" alt="Widget preview" />
</div>

> Widgets read the app's data through an App Group (`group.com.local.hbustpower`), and App Groups need a paid Apple
> Developer membership. Sideloaded with a free Apple ID, the extension installs but gets no shared storage, so it keeps
> showing the "open the app once" placeholder. **Settings → Diagnostics → Widgets** shows whether the shared container
> exists.

### Foldables and large screens

The layout is picked by size class. Screen dimensions and orientation don't enter into it.

- An unfolded inner display and the iPad get two even columns; the outer display and phones get one.
- Half folded, the gap between the columns sits on the hinge reported by `reservedRegions(kind: .division)`
  (iOS 27.1+), so no control lands on the crease. Builds from Xcode 27.0 skip this and keep the even split.
- Content stays inside asymmetric safe areas, so the vertical bar on the outer display doesn't cover anything.
- Tried on the iPhone Duo simulator in four poses: outer, inner landscape, inner portrait, half folded.

<div align="center">
<img src="docs/screenshots/duo-inner.png" width="370" alt="Unfolded inner display" />
<img src="docs/screenshots/duo-half-folded.png" width="370" alt="Half folded" />
</div>

<details>
<summary>More screens</summary>

<div align="center">
<img src="docs/screenshots/records-light.png" width="230" alt="Recharge history" />
<img src="docs/screenshots/campus-card-1.6.0.png" width="230" alt="Campus card" />
<img src="docs/screenshots/settings-light.png" width="230" alt="Settings" />
<img src="docs/screenshots/xuexitong-glass-1.4.5.png" width="230" alt="Sign-in" />
</div>

</details>

## Privacy

- You sign in on Chaoxing's own page. The app fills in what you typed and never saves the password.
- The only thing kept is the authorization link: in the Keychain on iOS, encrypted with Android Keystore on Android.
- Balance, usage, recharge and campus card data travel between your phone and the school only. None of it reaches
  the developer.
- Separately, the app checks the developer's site for new versions and notices, and sends anonymous usage
  statistics at most once a day. The statistics are on by default; you can switch them off on the first-run screen
  or under **Settings → Help improve**. The privacy policy lists exactly what is sent.
- Diagnostics contain no account, dorm number, authorization URL or cookie values.
- Redirect URLs are checked strictly: exact host and path, exactly one `appId=180`, one non-empty token.

The full privacy policy (in Chinese) is [filing/03-隐私政策.md](filing/03-隐私政策.md).

## Getting started

### iOS requirements

- Xcode 26 or newer (27.1+ for the iPhone Duo simulator and hinge alignment)
- iOS 26 or newer
- A paid Apple Developer team if the widgets should show real data

### Build iOS

```sh
git clone https://github.com/zebwqfox/hbustpower.git
cd hbustpower/ios
open HBUSTPowerIOS.xcodeproj
```

Pick your team under Signing & Capabilities, choose a device, and run.

### Build Android

You need SDK Platform 37, Build Tools 36+ and JDK 17–26. The app runs on Android 6 and later.

```powershell
cd android
.\gradlew.bat testDebugUnitTest assembleDebug lintDebug
```

The debug APK ends up at `android/app/build/outputs/apk/debug/app-debug.apk`. The
[Android development guide](android/README.md) has the rest.

### Secrets on two machines

The school app key isn't in the repository. It lives in `secrets/secrets.env`, which git ignores. The encrypted copy,
`secrets/secrets.env.enc`, is committed, so a `git pull` brings it to both the Mac and the Windows machine. Only the
passphrase stays out of git; keep it in a password manager.

```sh
./scripts/secrets.sh unlock   # secrets.env.enc -> secrets.env (asks for the passphrase)
./scripts/secrets.sh apply    # writes ios/Config/Secrets.xcconfig and android/secrets.properties
./scripts/secrets.sh lock     # secrets.env -> secrets.env.enc, commit the result
```

On Windows, `scripts\secrets.ps1` takes the same commands. Both scripts need only `openssl`, which comes with macOS
and with Git for Windows.

Both projects build without the secrets file. iOS falls back to the placeholder in `ios/Config/Base.xcconfig`,
Android to an empty `BuildConfig.SCHOOL_APP_KEY`, and the app says it isn't configured.

### Configure the school entry point

Copy `secrets/secrets.env.example` to `secrets/secrets.env`, fill in the school's current `appKey`, and run
`./scripts/secrets.sh apply`. The value comes from the official campus portal entry. The other parameters (`fidEnc`,
`mappId`, `wfwEnc`) are in the source; they belong to this school and won't work for another one.

### Unsigned IPA for sideloading

```sh
cd ios
./build_sideloadly_ipa.sh        # writes dist/湖科电量-iOS26-Sideloadly.ipa
```

Drop the IPA into [Sideloadly](https://sideloadly.io) and let it re-sign with your Apple ID. Leave
**Use automatic bundle ID** unchecked. It rewrites the app's bundle identifier, and iOS ignores the widget extension
unless its identifier starts with the app's.

### Debug launch arguments

Debug builds of the iOS app take these flags, which help when looking at the UI offline.

| Flag | Effect |
|---|---|
| `--ui-preview` | Offline demo data, no network |
| `--preview-tab=1…4` | Open Usage / Recharges / Campus card / Settings |
| `--preview-about`, `--preview-changelog`, `--preview-widgets` | Jump to those screens |
| `--slow-refresh-preview` | Delay the demo refresh by 3s to watch the charging animation |
| `--liquid-gravity-x=-0.5` | Fake gravity to check the liquid's tilt direction |
| `--simulate-vertical-bar` | Fake an asymmetric safe area, like the Duo outer display |

## Project layout

```
ios/
├─ HBUSTPowerIOS/
│  ├─ Models/           App state, snapshots, insights, recharge planner, changelog
│  ├─ Services/         Networking, HTML parsing, Keychain, notifications, diagnostics
│  ├─ ViewControllers/  Overview, Usage, Records, Campus card, Settings, About, Planner
│  └─ Views/            Theme, motion, charts, liquid, stickers, pull-to-charge
├─ HBUSTPowerWidgets/   WidgetKit extension
├─ Shared/              Code shared by app and widgets
├─ HBUSTPowerIOSTests/  Unit tests
└─ WidgetSupport/       Widget Info.plist and entitlements
android/                 Kotlin + Jetpack Compose Android client
fixtures/                Redacted HTML fixtures shared by both clients
filing/                  Privacy policy, user agreement and filing materials
```

How the data gets in: a WebView completes the official sign-in, the app catches the electricity redirect, copies the
school's cookies into its HTTP session, then fetches three pages and parses them. Parsing sits in
`ElectricityHTMLParser` with no networking in it, so the fixtures can test it directly.

## Testing

```sh
cd ios
xcodebuild test -project HBUSTPowerIOS.xcodeproj -scheme '湖科电量' \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

iOS has 64 XCTest methods. Android has 85 JVM unit tests and passes Android Lint. The tests go after what breaks most
easily: HTML parsing, redirect validation, usage estimates, recharge planning, remote config and changelog consistency.

## Roadmap

- [x] iOS app
- [x] Themes, widgets, recharge planner
- [x] iPhone Duo adaptation
- [x] Android client (Kotlin + Jetpack Compose), in `android/`
- [ ] Widgets verified on a device with a paid signing team

## Credits

- Written and maintained by [@zebwqfox](https://github.com/zebwqfox).
- Sign-in runs through the official Chaoxing and HBUST services. The Chaoxing logo only marks that sign-in path.
- The 紫鸟紫 and 枫烻黄 palettes are named after two friends.
- The *Stray Birds* lines come from Tagore's 1916 collection, in Zheng Zhenduo's 1922 translation. Both are in the
  public domain.
