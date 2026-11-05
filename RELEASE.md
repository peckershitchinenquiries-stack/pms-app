# Releasing the Peckers Android app

Task 4 of the 9-task plan. Everything here is shell-only — nothing in this file
touches `C:\NextJs\peckers-cashflow`.

---

## 1. The signing key — read this first

| | |
| --- | --- |
| Keystore | `android/peckers-release.jks` (PKCS12, RSA 4096, valid 10 000 days) |
| Credentials | `android/keystore.properties` |
| Alias | `peckers` |
| Certificate SHA-256 | `62f396e5a557adf413dc7ea155052239245ba8955dacdd40db96afc739c8dd54` |
| Certificate SHA-1 | `e90993dba172e70f03716a99fd02abf3b6037934` |

Both files are gitignored (`*.jks`, `android/keystore.properties`) and must
never be committed. The password is **only** in `keystore.properties` — it was
generated straight into that file and exists nowhere else.

> ### ⚠ BACK BOTH FILES UP NOW, OFF THIS MACHINE
> Android will only install an update signed by the **same** key as the
> installed version. If `peckers-release.jks` or its password is lost, every
> staff phone that has the app must **uninstall and reinstall** — losing its
> signed-in session — and the installed app can never be updated again.
>
> Copy `android/peckers-release.jks` **and** `android/keystore.properties`
> together into whatever holds `C:\NextJs\pms-secrets`-grade material, plus one
> location that is not this computer.

The certificate's SHA-1 above is what Google Sign-In or App Links would need if
either is ever added. FCM does not need it.

If the keystore is ever replaced deliberately, v3 signing is enabled, so the
key can be **rotated** rather than forcing a reinstall — but only from a build
that still has the old key.

---

## 2. Which deployment the build points at

`server.url` is baked into the APK at build time. The three environments live
in `config/` and are selected by a script that also runs `cap sync`, because a
forgotten sync ships the previous environment's URL:

```powershell
npm run env:lan       # http://192.168.31.177:3000  (cleartext on, dev only)
npm run env:preview   # the feat/mobile-geolocation Vercel preview
npm run env:prod      # https://peckers-cashflow-peckerschicken.vercel.app
```

Each writes `capacitor.config.json`, prints the URL, `cleartext` and
`allowMixedContent` it just selected, and syncs the native project. `prod` and
`preview` both have `cleartext` absent and `allowMixedContent: false`; only
`lan` turns cleartext on.

### ⚠ `env:prod` is not yet the right choice for staff

The native push code (web Updates 251–253) is on branch
`feat/mobile-geolocation` and has **not** been merged to `main`. Production
therefore has no FCM token registration and no FCM sending, so an APK built
with `env:prod` today would give staff **no shift reminders at all** — the
exact state `CLAUDE.md` forbids rolling out.

Before the first production release: merge that branch, run migration
`067_native_push_tokens.sql`, confirm `FIREBASE_SERVICE_ACCOUNT` is set on the
production Vercel environment, then `npm run env:prod` and rebuild.

---

## 3. Building

Needs JDK 21 — this machine has it at
`C:\Users\landa\AppData\Local\Programs\Eclipse Adoptium\jdk-21.0.12.1+1`
(JDK 8 is also installed and Gradle rejects it):

```powershell
$env:JAVA_HOME = "C:\Users\landa\AppData\Local\Programs\Eclipse Adoptium\jdk-21.0.12.1+1"
npm run env:preview
npm run build:release
```

Output: `android/app/build/outputs/apk/release/app-release.apk` (~4.8 MB).
`npm run bundle:release` produces an `.aab` instead, for Play Store upload only.

A release build with `android/keystore.properties` missing **fails at
configuration time** rather than quietly producing an unsigned APK.

Rename the output by version and environment before distributing, e.g.
`peckers-release-1.0.0-preview.apk`, and stage it in `C:\NextJs\pms-apk`.

### Bump the version on every build that leaves this machine

In `android/app/build.gradle`:

- `versionCode` — an integer that must **increase**. Android refuses to install
  an APK whose `versionCode` is lower than the installed one.
- `versionName` — the human string, e.g. `1.0.1`.

Currently `versionCode 1`, `versionName "1.0.0"`.

---

## 4. Verifying before it goes anywhere

With `build-tools/36.0.0` on hand:

```powershell
$BT = "$env:LOCALAPPDATA\Android\Sdk\build-tools\36.0.0"
$APK = "android\app\build\outputs\apk\release\app-release.apk"
& "$BT\apksigner.bat" verify --verbose --print-certs $APK
& "$BT\aapt2.exe" dump badging $APK
```

What a good release shows:

- `Verifies`, with v2 **and** v3 true, one signer, DN `CN=Peckers, …`, RSA 4096
- the SHA-256 digest matching the table in section 1 — a different digest means
  a different key, and that APK cannot update an installed one
- **no** `application-debuggable` line
- `package: name='uk.co.peckers.app'`, the expected `versionCode`
- permissions: `INTERNET`, `ACCESS_NETWORK_STATE`, `ACCESS_FINE_LOCATION`,
  `ACCESS_COARSE_LOCATION`, `POST_NOTIFICATIONS`, `WAKE_LOCK`,
  `com.google.android.c2dm.permission.RECEIVE`
- no `usesCleartextTraffic` in the manifest

And confirm the two things a release can silently get wrong — the URL and FCM:

```powershell
unzip -p $APK assets/capacitor.config.json          # server.url, cleartext, allowMixedContent
& "$BT\aapt2.exe" dump resources $APK | Select-String google_app_id
```

`google_app_id` present means `google-services.json` was picked up and FCM will
initialise. Absent means push is dead in that build, with no error at runtime —
`app/build.gradle` applies the google-services plugin only if the file exists.

---

## 5. Distribution to staff

Sideloaded APK, not the Play Store. Play would need an AAB, a privacy policy, a
Data Safety declaration, and would risk rejection under the "minimum
functionality" policy for a WebView-only app.

1. Host the renamed APK somewhere each phone can reach, or transfer it directly.
2. On the phone, opening it prompts **"install unknown apps"** for whichever app
   is doing the opening (Chrome, Files, WhatsApp) — that permission is per-app
   and has to be granted once.
3. First launch asks for **notifications** (Android 13+) and, at the first
   clock-in attempt, **location**. Location must be granted as **Precise** —
   Approximate returns a 1–3 km fix, which reads as out of range against the
   250 m geofence and makes clocking in impossible.
4. Sign in once. The session is a persistent cookie, flushed to disk on pause.

### How an update reaches a phone

- **Web changes need nothing.** Remote mode means the WebView loads the
  deployed site, so a Vercel deploy reaches every phone on next open. The shell
  also version-checks on resume and reloads when the deployment moved.
- **Shell changes (`android/**`, `capacitor.config.json`) need a new APK**,
  installed by hand on every device. There is no in-app updater. Budget for
  that before changing anything native.

---

## 6. Known state at Update 9

- Signed release builds work and are verified; `versionCode 1`, pointed at the
  **preview** deployment.
- Not yet done, and not part of Task 4: Task 7's leftovers (status bar styling,
  splash timing, `onRenderProcessGone`, FCM notification channel and small
  icon), Task 8 device testing, Task 9 rollout.
- Still true of every build: CSV/XLSX export and `window.print()` do nothing in
  an Android WebView, and cover drivers get no reminders on any platform.

---

## 7. iPhone (iOS) release

Built in the cloud on Codemagic (`codemagic.yaml`) — there is no Mac. Everything
below except the first block is already done in the project; it is listed so the
first signed build is a checklist, not a debugging session.

### 7.1 One-time setup once the Apple Developer account is approved

1. **App ID** `uk.co.peckers.app` in the Apple Developer portal, with the
   **Push Notifications** capability ticked.
2. **APNs Auth Key** (`.p8`): Certificates, Identifiers & Profiles › Keys › new
   key with APNs. Upload it to Firebase project `pms-app-8e58b` › Project
   settings › Cloud Messaging › Apple app configuration, with its Key ID and the
   Team ID. One key covers development and production. Without it Firebase
   issues tokens but no reminder is ever delivered to an iPhone.
3. **App Store Connect app record** for bundle id `uk.co.peckers.app`
   (needed for TestFlight and for an unlisted App Store app).
4. **Codemagic:**
   - App Store Connect API key integration named exactly **`Peckers ASC`**
   - env group **`firebase`** holding `GOOGLE_SERVICE_INFO_PLIST` (base64) —
     already set, used by the green simulator builds
   - distribution certificate + profile (App Store, or Ad hoc) under Code
     signing identities
5. **Privacy answers** in App Store Connect must match `PrivacyInfo.xcprivacy`:
   precise location, device ID, user ID, name, email address, photos — all
   linked to the user, none used for tracking, all for app functionality.

### 7.2 What the signed workflows enforce

`ios-testflight` and `ios-adhoc` switch `App.entitlements` to
`aps-environment = production` before signing (every distribution profile is
production; the committed `development` value is for simulator/dev builds), then
**fail the run** unless the finished `.ipa` is signed for production push and
carries `GoogleService-Info.plist`. A signed build that cannot receive shift
reminders never leaves Codemagic.

### 7.3 Choosing how staff install it — decide before the first build

| Route | Good | Limits |
| --- | --- | --- |
| **TestFlight** (`ios-testflight`) | Easiest to start. Staff install the TestFlight app and accept an invite; updates arrive automatically. | **Every build expires after 90 days** — a new build must be uploaded at least every ~80 days or the app stops opening. Staff outside your App Store Connect team need the build to pass Beta App Review. |
| **Ad hoc** (`ios-adhoc`) | No Apple review. A link installs the `.ipa`. | Every iPhone's **UDID** registered first, max **100 iPhones per year**, and the profile rebuilt after each new phone. Expires with the profile (1 year). |
| **Unlisted App Store app** | Permanent, normal App Store updates, only people with the link can find it. | Full App Review, and Apple may refuse a web-wrapper app (guideline 4.2) — the native offline screen, push and location help the case. Apply via Apple's unlisted-app request form after the record exists. |

**Recommendation:** start on TestFlight for the pilot (owner + a few managers),
and request **unlisted distribution** before the whole staff estate installs —
it is the only route without a 90-day or 100-device ceiling.

### 7.4 How an update reaches an iPhone

- **Web changes need nothing**, exactly as on Android.
- **Shell changes (`ios/**`, `capacitor.config.json`)** need a new Codemagic
  build. Bump `PeckersApp/N` in all four configs when native code changes, so
  the web app can tell an old install to update (see `CLAUDE.md`).

### 7.5 First run on an iPhone — check these

1. The app opens on the crew login, and the offline screen, swipe-back and
   status bar all work (one window, built by `SceneDelegate`).
2. Clock in: **one** location prompt, worded "Peckers uses your location to
   confirm you are at the store…". A second prompt naming the website means the
   location bridge is not active.
3. Turn on reminders → a test reminder arrives with sound.
4. Profile photo: camera and photo library both open without the app closing.
5. Kill the app straight after signing in, reopen: still signed in.
