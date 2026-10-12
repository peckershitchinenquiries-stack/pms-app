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
