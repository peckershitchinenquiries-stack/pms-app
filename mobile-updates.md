# pms-mobile — Update Log

Changelog for the **Capacitor Android shell only**.

**Numbering is independent of the web repo.** This file starts at Update 1 and
counts up on its own. `C:\NextJs\peckers-cashflow` has its own shared sequence
across `docs/updates.md` and `docs/updates-operations.md` — never continue that
sequence here, and never continue these numbers there. A change that spans both
repos gets an entry in each, under each repo's own numbering, cross-referenced.

Logging is **mandatory and automatic**. Every code change, config change, file
addition or dependency bump gets an entry, appended immediately after the work.
Newest entries go at the bottom.

---

## Template for Future Updates

```markdown
### Update N: [Short Title]

**Date:** YYYY-MM-DD
**Type:** Feature / Bug Fix / Enhancement / Refactor / Config / Styling / Build / Documentation
**Scope:** Which part of the shell — Capacitor config, Android project, assets, docs, build
**Files Modified:**
- `path/to/file`

**Summary:**
2–3 sentences: what changed and why.

**Changes:**
1. Specific change
2. Specific change

**Rationale:**
Why it matters — device behaviour, staff impact, build safety, technical debt.

**Testing:**
- What was run and the result. Say explicitly if something could NOT be tested.

**Impact:**
- **Users:** effect on staff using the app
- **Web app:** confirm nothing in `peckers-cashflow` was touched, or name what was
- **Build/Release:** effect on building, signing or distributing the APK
```

---

## Updates

### Update 1: Scaffold the Capacitor Android shell in remote mode

**Date:** 2026-10-06
**Type:** Feature
**Scope:** Whole repository — repo creation, Capacitor config, Android project, icons/splash, theming, docs
**Files Modified:**
- `.gitignore` *(new)*
- `CLAUDE.md` *(new)*
- `mobile-updates.md` *(new)*
- `package.json`, `package-lock.json` *(new)*
- `capacitor.config.json` *(new)*
- `www/index.html` *(new)*
- `assets/icon.png`, `assets/icon-foreground.png`, `assets/icon-background.png`, `assets/splash.png`, `assets/splash-dark.png` *(new)*
- `android/**` *(new — generated native project, 136 generated icon/splash resources)*
- `android/app/src/main/AndroidManifest.xml`
- `android/app/src/main/res/values/colors.xml` *(new)*
- `android/app/src/main/res/values/styles.xml`
- `android/app/src/main/res/values/ic_launcher_background.xml`
- `android/app/src/debug/AndroidManifest.xml` *(new)*
- `android/app/src/debug/res/xml/network_security_config.xml` *(new)*

**Summary:**
Created `pms-mobile` as a standalone git repo holding a Capacitor 8 Android
shell that loads the deployed Peckers web app over the network in remote mode.
The shell carries no business logic — only the WebView, the launcher icon,
the splash screen, a portrait lock and the `#0f0f0f` theme. `server.url`
currently points at the LAN dev server so the app can be driven against
`npm run dev` on this machine. Task 2 of 9.

**Changes:**
1. Initialised a git repo at `C:\NextJs\pms-mobile`, branch `main`, entirely
   separate from the web repo.
2. Wrote `.gitignore` **first**, before any install, so `node_modules`,
   `*.keystore`, `*.jks`, `android/local.properties`, `android/.gradle/`,
   `android/app/build/`, `build/` and `google-services.json` were never
   capable of being staged.
3. Wrote `CLAUDE.md`: what the repo is, how remote mode works and why it
   guarantees the web UI cannot diverge, the file-level boundary between the
   two repos, the 9-task plan, the fixed conventions, the three `server.url`
   environments and the shared-Supabase warning, and the hard rules
   (keystore, no `.github/workflows`, mandatory logging).
4. Wrote this log with its own independent numbering and a per-entry template.
5. `npm init` plus `@capacitor/core`, `@capacitor/cli`, `@capacitor/android`
   (all 8.5.2). Added `sync`, `open:android` and `assets` scripts.
6. `npx cap init` with appId `uk.co.peckers.app`, appName `Peckers`,
   webDir `www`.
7. Created `www/index.html` — a dark offline fallback page with a retry
   button. `webDir` must exist or `cap sync` fails; remote mode ignores its
   contents, so it holds no business UI.
8. Configured `server.url = http://192.168.31.177:3000` with
   `cleartext: true`, `androidScheme: "https"` and
   `android.allowMixedContent: true`.
9. `npx cap add android` to generate the native project.
10. Built 1024×1024 icon sources from
    `peckers-cashflow/public/peckers-logo.png` (read-only) by compositing the
    484×193 wordmark onto a `#0f0f0f` canvas: `icon.png` (logo at 700px wide),
    `icon-foreground.png` (620px, inside the adaptive-icon safe zone),
    `icon-background.png` (solid), and 2732×2732 `splash.png` /
    `splash-dark.png` (logo at 1000px). Generated 136 Android resources with
    `@capacitor/assets`.
11. **Created `android/app/src/main/res/values/colors.xml`, which did not
    exist.** `styles.xml` referenced `@color/colorPrimary`,
    `@color/colorPrimaryDark` and `@color/colorAccent`, none of which were
    defined anywhere in the generated project — the build would have failed on
    unresolved resources. Defined all three plus `splashBackground` as
    `#0f0f0f`.
12. Locked `MainActivity` to `android:screenOrientation="portrait"`.
13. Set `android:allowBackup="false"` — remote mode keeps no local data worth
    restoring to a new device, and the WebView store holds a live session
    cookie.
14. Retargeted `AppTheme` and `AppTheme.NoActionBar` from
    `Theme.AppCompat.Light.*` to the `DayNight` equivalents and set
    `android:windowBackground` to `#0f0f0f`, so the window does not flash
    white before the WebView paints. Gave the launch theme
    `windowSplashScreenBackground` and `postSplashScreenTheme`.
15. Set the unused `ic_launcher_background` colour from `#FFFFFF` to `#0f0f0f`
    for consistency with the adaptive icon's actual background.
16. **Added a debug-only `network_security_config.xml`** permitting cleartext
    for `192.168.31.177`, `localhost` and `10.0.2.2` only, wired in via a
    `src/debug/AndroidManifest.xml` overlay. Android 9+ blocks cleartext at
    the platform level, so `server.cleartext: true` alone would not have
    reached the dev server. Putting it in the debug source set means a release
    build **cannot** ship cleartext — the rule enforces itself rather than
    relying on someone remembering it at Task 4.
17. Created **no** `.github/workflows`, per the hard rule — the web repo's
    cron jobs run against the same production database and must not double-fire.

**Rationale:**
Remote mode is what makes an Android app safe to add to a system already in
production. There is no second copy of the UI to drift, no build step coupling
the two repos, and nothing in this repo that `peckers-cashflow` reads — so the
live web app's behaviour is structurally unable to change because of anything
here. Fixing the missing `colors.xml` and the platform cleartext block now
avoids two build failures that would otherwise have looked like Capacitor
faults. Scoping cleartext to the debug source set turns the "must be off in
release" rule into something the build system enforces.

**Testing:**
- `npx cap init` / `cap add android` / `cap sync android`: ✓ all succeeded
- `@capacitor/assets generate --android`: ✓ 136 resources, 1.82 MB
- Synced `android/app/src/main/assets/capacitor.config.json`: ✓ carries the
  correct `appId`, `server.url` and `cleartext`
- `strings.xml`: ✓ `app_name` = `Peckers`, `package_name` = `uk.co.peckers.app`
- Icon source rendered and visually inspected at 1024×1024: ✓ clean, correct
  colours, logo centred
- **NOT TESTED — could not be:** Gradle build, APK install, loading the web app
  on a device, login, session persistence across app restart. This machine has
  **JDK 8 only** (`C:\Program Files\Java\jdk1.8.0_172`; Capacitor 8 needs
  JDK 21) and **no Android SDK, no `adb`, no Android Studio**. Every
  device-level acceptance criterion for Task 2 is therefore still open.

**Impact:**
- **Users:** none yet. Nothing is installed on any staff device, and nothing
  may be until Tasks 5 and 6 restore shift reminders — Web Push does not work
  in an Android WebView.
- **Web app:** `C:\NextJs\peckers-cashflow` was **not modified**. The only
  interaction was reading `public/peckers-logo.png` and `app/layout.tsx` to
  source the icon and confirm the theme colour.
- **Build/Release:** the project is scaffolded but unbuildable on this machine
  until JDK 21 and the Android SDK are installed. No keystore exists yet;
  signing is Task 4.

**Known gaps opened by this update:**
1. **`ACCESS_FINE_LOCATION` is not in the manifest.** The web app's clock-in is
   geofence-gated via `navigator.geolocation`, which an Android WebView will
   refuse without the runtime permission and a `WebChromeClient` geolocation
   prompt handler. Clock-in will fail on device until this is wired. Belongs to
   Task 7, and it is the first thing Task 7 should do.
2. The launcher icon is a **wordmark on a dark square**, because the only
   source art is a 484×193 banner. At 48dp "SERIOUSLY GOOD CHICKEN" will be
   illegible and "PECKERS" very small. A square 1024×1024 mark would be
   materially better and can be dropped into `assets/` and regenerated with
   `npm run assets` at any time.
3. The LAN IP `192.168.31.177` is DHCP-assigned and appears in **two** places —
   `capacitor.config.json` and `network_security_config.xml`. Both must change
   together when it moves.

---

### Update 2: First debug APK built and staged for device install

**Date:** 2026-10-06
**Type:** Build
**Scope:** Local Android toolchain, debug build output
**Files Modified:**
- `android/local.properties` *(new, gitignored — machine-local SDK path)*
- `mobile-updates.md`
- *(no tracked source changed; the APK is build output and stays untracked)*

**Summary:**
Installed the Android SDK command-line tools and JDK 21 on this machine and
produced the first debug APK. Copied it to `C:\NextJs\pms-apk\peckers-debug.apk`
for manual transfer to a phone. This closes the "app builds" criterion of
Task 2; install and on-device verification remain with the user.

**Changes:**
1. Installed Android SDK command-line tools 16111833 to
   `C:\Users\landa\AppData\Local\Android\Sdk`, then `platform-tools`,
   `platforms;android-36` and `build-tools;36.0.0` via the new `android sdk`
   CLI. **Android Studio was not installed** — roughly 700 MB of SDK instead
   of ~8 GB of IDE.
2. **Installed Temurin JDK 21.0.12.1** to
   `AppData\Local\Programs\Eclipse Adoptium\jdk-21.0.12.1+1`. The machine's
   existing JDK 17 was rejected: Capacitor 8's `capacitor-android` module
   compiles with `sourceCompatibility 21`, so the build failed with
   `invalid source release: 21`. JDK 17 is the documented floor for Capacitor
   8 generally, but **not** for this version's bundled Android module — 21 is
   required in practice, not merely recommended.
3. Wrote `android/local.properties` with `sdk.dir` using **forward slashes**.
   The first attempt used single backslashes and the build failed with
   `java.io.IOException: The filename, directory name, or volume label syntax
   is incorrect` — a Java properties file reads `\U`, `\A`, `\L` as invalid
   escapes and silently mangles the path. Forward slashes avoid the escaping
   question entirely.
4. `gradlew assembleDebug` → BUILD SUCCESSFUL, 93 tasks, 1m 32s.
5. Copied the output to `C:\NextJs\pms-apk\peckers-debug.apk` (5.0 MB), a
   folder outside both repos so the APK is never at risk of being committed.

**Rationale:**
Keeping the toolchain to the command-line SDK rather than Android Studio keeps
the machine lean and makes the build reproducible from a script later, which
Task 4's signed release will want. Recording the JDK 21 requirement and the
`local.properties` escaping here means neither failure costs anyone time twice.

**Testing:**
- `gradlew assembleDebug`: ✓ BUILD SUCCESSFUL in 1m 32s
- `aapt2 dump badging` on the built APK:
  - ✓ `package: name='uk.co.peckers.app'` — the permanent appId
  - ✓ `application-label:'Peckers'`
  - ✓ `minSdkVersion:'24'`, `targetSdkVersion:'36'`
  - ✓ `uses-implied-feature: android.hardware.screen.portrait` — portrait lock
    is live in the built artifact, not just the source manifest
  - ✓ adaptive launcher icon at `res/mipmap-anydpi-v26/ic_launcher.xml`
  - ✓ `launchable-activity: uk.co.peckers.app.MainActivity`
- Unpacked `assets/capacitor.config.json` from inside the APK: ✓ carries
  `server.url = http://192.168.31.177:3000` and `cleartext: true`
- 29 launcher icon entries and 30 splash entries present in the archive
- **NOT TESTED — requires a device:** install, launch, icon and splash as
  rendered, portrait behaviour in the hand, login, session persistence across
  an app restart.

**Impact:**
- **Users:** none. The APK is debug-signed and on this machine only. It must
  not reach staff until Tasks 5 and 6 restore shift reminders.
- **Web app:** `C:\NextJs\peckers-cashflow` not modified; `git status` clean.
- **Build/Release:** the project is now buildable on this machine. `JAVA_HOME`
  must point at the JDK 21 install for every build — it is **not** set
  persistently, so a new shell needs it set or the build fails again with
  `invalid source release: 21`.

**Still open on Task 2:**
1. `ACCESS_FINE_LOCATION` is absent, so clock-in will fail in the app. Task 7,
   but it makes this build look broken to anyone who tries the core feature.
2. The launcher icon is a wordmark on a dark square and will be hard to read at
   48dp. A square 1024×1024 master would fix it; `npm run assets` regenerates.
3. `192.168.31.177` is baked into the APK. A DHCP change means editing
   `capacitor.config.json` **and** `network_security_config.xml`, then
   rebuilding.

---

### Update 3: Location permissions in the manifest, and the LAN origin found to block geolocation outright

**Date:** 2026-10-07
**Type:** Feature
**Scope:** Android manifest, Capacitor config, debug build
**Files Modified:**
- `android/app/src/main/AndroidManifest.xml`
- `capacitor.config.json`
- `android/app/src/main/assets/capacitor.config.json` *(regenerated by `cap sync`)*
- `mobile-updates.md`

**Summary:**
Closed the `ACCESS_FINE_LOCATION` gap carried from Updates 1 and 2 by declaring
both location permissions and marking the GPS hardware features optional. **No
geolocation plugin was installed** — Capacitor's WebView already routes
`navigator.geolocation` to Android's location services and requests the runtime
permission itself, so the web repo needs no plugin code. Also added a
`PeckersApp/1` user-agent marker. The build succeeds and carries both
permissions, but testing uncovered a blocker: the current LAN `server.url` is
plain http, and geolocation is refused on a non-secure origin before any
permission is consulted.

**Changes:**
1. Declared `ACCESS_FINE_LOCATION` **and** `ACCESS_COARSE_LOCATION`. Both are
   required, not one: Capacitor's `BridgeWebChromeClient` launches the runtime
   request for the pair together, and a permission absent from the manifest is
   auto-denied with no prompt. Android 12+ also shows the Precise/Approximate
   toggle only when both are requested.
2. Declared `android.hardware.location` and `android.hardware.location.gps` as
   `required="false"`, so location does not become a Play Store install filter —
   a device without GPS can still use everything but clock-in.
3. Added `android.appendUserAgent: "PeckersApp/1"` to `capacitor.config.json`.
   The web app uses it (web repo Update 249) purely to word location-permission
   advice for an app rather than a browser. Explicit beats sniffing the
   WebView's `; wv` token, which other embedded browsers also carry.
4. `npx cap sync android`, then `gradlew assembleDebug`. Copied the APK to
   `C:\NextJs\pms-apk\peckers-debug.apk`.
5. Installed **no** plugin. `@capacitor/geolocation` is not a dependency and
   `C:\NextJs\peckers-cashflow\lib\geolocation.ts` needed no native branch —
   see Rationale.

**Rationale:**
The free path holds, and it was verified in Capacitor 8's own source rather than
assumed:
- `Bridge.java:591` calls `settings.setGeolocationEnabled(true)`, so the WebView
  serves `navigator.geolocation` from Android's location services.
- `BridgeWebChromeClient.onGeolocationPermissionsShowPrompt` (line 246) launches
  the runtime request for `{COARSE, FINE}` the first time the page asks, and
  grants the WebView callback when it is allowed.

So the only thing missing was the manifest declaration. That keeps
`lib/geolocation.ts` — which sits on the clock-in spine and is shared with
`lib/use-geo-fix.ts` and the store-capture screen — free of any plugin branch,
and keeps the plugin out of the web bundle entirely.

One thing the same source makes clear is worth carrying forward: when FINE is
refused but COARSE is held on Android 12+, the handler still grants the WebView
(`callback.invoke(origin, true, false)`). An app user who taps **Approximate**
therefore gets a working position at 1–3km — which can never satisfy a 250m
geofence. That is handled on the web side in Update 249, not here.

**Testing:**
- Capacitor 8 source read for both claims above: ✓ confirmed, file and line
- `npx cap sync android`: ✓ finished; synced
  `android/app/src/main/assets/capacitor.config.json` carries `appendUserAgent`
- `gradlew assembleDebug` (JDK 21, `JAVA_HOME` set for the shell): ✓ BUILD
  SUCCESSFUL, 93 tasks
- `aapt2 dump badging` on the built APK: ✓ `ACCESS_FINE_LOCATION` and
  `ACCESS_COARSE_LOCATION` both present; ✓ both location features listed as
  `uses-feature-not-required`; ✓ `uk.co.peckers.app`, `targetSdkVersion 36` and
  the portrait lock unchanged
- APK staged at `C:\NextJs\pms-apk\peckers-debug.apk` (5.2 MB)
- **❌ BLOCKER FOUND — geolocation cannot work from the current `server.url`.**
  Loaded the dev server over its LAN address in a desktop Chromium and called
  `getCurrentPosition`: it returned `{ code: 1, message: "Only secure origins
  are allowed" }` with `window.isSecureContext === false`. Android's own WebView
  documentation states that for apps targeting API 23+ the Geolocation API is
  supported on secure origins only, and a request from a non-secure origin is
  **denied without `onGeolocationPermissionsShowPrompt()` ever being called**.
  This app targets 36 and `server.url` is `http://192.168.31.177:3000`, so the
  permissions added here are necessary but not yet sufficient. `androidScheme:
  "https"` does not help — it governs bundled assets, which remote mode ignores.
- **NOT TESTED — blocked by the above:** the accuracy values actually observed
  in the app, in-range and out-of-range behaviour, the permission prompt, denial
  and the Approximate-location case. No clock record was written; no row needs
  cleaning up.

**Impact:**
- **Users:** none yet. Still our devices only until Tasks 5 and 6 restore shift
  reminders.
- **Web app:** `peckers-cashflow` WAS modified, deliberately and on a branch —
  `feat/mobile-geolocation`, logged as Update 249 there. The changes are
  additive message handling on the clock screens; no geofence rule, server
  action or migration was touched, and `lib/geofence-verify.ts` was not opened.
- **Build/Release:** unchanged. `JAVA_HOME` must still point at JDK 21 per
  shell. Adding a geolocation plugin later would need `cap sync` again; none is
  present.

**Open — Task 3 is not done:**
1. **`server.url` must be https before geolocation can be tested at all.** Two
   ways, and they answer different questions:
   - **A Vercel preview URL for the `feat/mobile-geolocation` branch** — the
     only option that allows an untethered phone at a store, so the only one
     that can test in-range. Needs no certificate.
   - **`adb reverse tcp:3000 tcp:3000` with `server.url` set to
     `http://localhost:3000`** — `localhost` IS a secure context, so this
     unblocks geolocation against the local dev server with hot reload and no
     certificate. The phone stays on USB, so it tests permissions, denial,
     the Approximate case and out-of-range, but not a real in-range clock-in.
2. `cleartext: true` and `network_security_config.xml` become dead weight on an
   https `server.url`. Leave them until Task 4 strips cleartext for release.
3. The launcher icon is still a wordmark on a dark square (carried from
   Update 1).
