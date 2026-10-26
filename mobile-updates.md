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

---

### Update 4: `server.url` switched to `localhost` so geolocation has a secure context

**Date:** 2026-10-07
**Type:** Config
**Scope:** Capacitor config, debug network security config, debug build
**Files Modified:**
- `capacitor.config.json`
- `android/app/src/debug/res/xml/network_security_config.xml`
- `android/app/src/main/assets/capacitor.config.json` *(regenerated by `cap sync`)*
- `mobile-updates.md`

**Summary:**
Unblocks the Update 3 finding without a certificate or a deployment. `server.url`
now points at `http://localhost:3000`, reached from the phone over USB with
`adb reverse tcp:3000 tcp:3000`. `localhost` is the one cleartext origin
Chromium treats as a **secure context**, so `navigator.geolocation` is permitted
there — against the local dev server, with hot reload intact.

**Changes:**
1. `server.url`: `http://192.168.31.177:3000` → `http://localhost:3000`.
   `cleartext: true` stays — the origin is still plain http, it is simply a
   trusted one.
2. Added `127.0.0.1` alongside `localhost` in the debug
   `network_security_config.xml`, in case anything resolves to the literal, and
   rewrote the comment to record WHY `localhost` is the entry that matters. The
   `192.168.31.177` entry is kept for any test that does not need location.
3. `npx cap sync android`, `gradlew assembleDebug`, APK re-staged at
   `C:\NextJs\pms-apk\peckers-debug.apk`.

**Rationale:**
Of the two ways to get a secure origin, this is the one that needs nothing
external: no Vercel deployment, no self-signed certificate and no trust anchor,
and the dev server keeps hot reload so a web-side message can be changed and
re-read on the phone in seconds. The trade-off is the USB cable, which bounds
what it can prove — see the open list.

**Testing:**
- `npx cap sync android`: ✓ finished
- `gradlew assembleDebug`: ✓ BUILD SUCCESSFUL, 93 tasks
- Unpacked `assets/capacitor.config.json` from inside the built APK: ✓ carries
  `server.url = http://localhost:3000` and `appendUserAgent = PeckersApp/1`
- **NOT TESTED — needs the phone on USB:** everything on device. `adb reverse`
  has not been run; no device has been attached in this session.

**Impact:**
- **Users:** none. Debug build, our devices only.
- **Web app:** `peckers-cashflow` not modified by this entry.
- **Build/Release:** the LAN address is no longer the active origin, so a DHCP
  change stops mattering while this config is in use. `cleartext: true` and the
  debug network config are still release-blockers for Task 4, unchanged.

**Open — still needed to finish Task 3:**
1. **The on-device run itself.** `adb reverse tcp:3000 tcp:3000`, `npm run dev`,
   then install the APK and open a clock screen. Nothing on device has been
   observed yet, including the accuracy values the task asks for.
2. **A real in-range clock-in cannot be tested this way** — the phone is
   tethered to this machine, and the geofence requires standing at a store. That
   needs the Vercel preview path from Update 3's open list, and it is the one
   acceptance criterion `localhost` cannot reach.
3. Carried from Update 1: the launcher icon is a wordmark on a dark square.

---

### Update 5: `server.url` moved to the Vercel branch preview

**Date:** 2026-10-07
**Type:** Config
**Scope:** Capacitor config, debug build
**Files Modified:**
- `capacitor.config.json`
- `android/app/src/main/assets/capacitor.config.json` *(regenerated by `cap sync`)*
- `mobile-updates.md`

**Summary:**
Replaced the `localhost` origin from Update 4 with the Vercel **branch** preview
for `feat/mobile-geolocation`. This is https, so geolocation has its secure
context, and it needs no cable, no certificate and no dev server — the phone
works on Wi-Fi or mobile data anywhere, which makes it the only configuration
that can test a real in-range clock-in at a store. APK staged as
`C:\NextJs\pms-apk\peckers-preview-debug.apk`.

**Changes:**
1. `server.url` → `https://peckers-cashflow-git-feat-mobile-geolocation-peckerschicken.vercel.app`.
2. Dropped `server.cleartext`. The origin is https, so it had no purpose, and
   removing it now is one less thing to strip at Task 4.
3. Left `android.allowMixedContent` and the debug `network_security_config.xml`
   alone deliberately — a minimal diff, so if the device test fails, neither is
   a candidate cause. Both are Task 4 cleanup.
4. `npx cap sync android`, `gradlew assembleDebug`, APK staged under a new name
   so it cannot be confused with the two earlier builds.

**Rationale:**
The **branch** alias was chosen over the per-deployment URL on purpose. Vercel
gives every deployment its own address containing a random string, which changes
on each push; the branch alias is stable. Pinning the APK to the branch alias
means new web commits reach the phone by themselves on next open, with no
rebuild and no reinstall — which is the behaviour remote mode exists to provide,
and what the two earlier origins both failed to deliver.

**Testing:**
- `npx cap sync android`: ✓ finished
- `gradlew assembleDebug`: ✓ BUILD SUCCESSFUL, 93 tasks
- Unpacked `assets/capacitor.config.json` from inside the built APK: ✓ carries
  the https preview URL, no `cleartext` key, `appendUserAgent` intact
- **❌ BLOCKER — Vercel Deployment Protection is ON for previews.** Loaded the
  preview URL in a browser with no Vercel session: it redirects to
  `https://vercel.com/login?next=/sso-api...`. The owner's own browser opens it
  fine because it holds a Vercel session, so this is invisible until something
  without one tries — which is exactly what the app's WebView is. Until it is
  turned off for Preview, the app will show Vercel's login page instead of the
  Peckers login.
- **NOT TESTED — blocked by the above:** everything on device, including the
  accuracy values Task 3 asks for.

**Impact:**
- **Users:** none. Debug build, our devices only.
- **Web app:** `peckers-cashflow` not modified by this entry. The branch was
  pushed (its own commit, Update 249); `main` is untouched at `acbbac5` and
  production is unaffected.
- **Build/Release:** no cable, no dev server and no LAN IP in the loop any more,
  so DHCP changes stop mattering entirely. `allowMixedContent` and the debug
  network config remain as Task 4 cleanup.

**Open:**
1. **Deployment Protection must be disabled for Preview** before anything can be
   tested. Doing so leaves the preview reachable by anyone holding the URL,
   guarded only by the app's own login — the same posture as production, and the
   repository is already public.
2. The branch is **1 commit behind `main`** (`7daa400`, occupancy cost
   prefill), pushed after this branch was created. Harmless for a geolocation
   test; merge `main` in if the preview should mirror live.
3. Carried from Update 1: the launcher icon is a wordmark on a dark square.

---

### Update 6: Native app behaviour — back button, offline screen, cookie flush, resume version check

**Date:** 2026-10-08
**Type:** Feature
**Scope:** Android project — `MainActivity`, two new shell classes, offline layout/resources, manifest, Capacitor config
**Files Modified:**
- `android/app/src/main/java/uk/co/peckers/app/MainActivity.java`
- `android/app/src/main/java/uk/co/peckers/app/OfflineGate.java` *(new)*
- `android/app/src/main/java/uk/co/peckers/app/BuildFingerprint.java` *(new)*
- `android/app/src/main/res/layout/offline_overlay.xml` *(new)*
- `android/app/src/main/res/drawable/offline_button.xml` *(new)*
- `android/app/src/main/res/values/strings.xml`
- `android/app/src/main/res/values/colors.xml`
- `android/app/src/main/AndroidManifest.xml`
- `capacitor.config.json`
- `android/app/src/main/assets/capacitor.config.json` *(regenerated by `cap sync`)*
- `mobile-updates.md`

**Summary:**
Made the shell behave like an app rather than a page in a frame: hardware back
now navigates instead of closing, a lost network shows a native retry screen
instead of a blank WebView, the session cookie is flushed to disk on pause, and
a resume after a new deployment reloads deterministically. All of it is native
Java in this repo — `peckers-cashflow` was **not** touched, which was the point
of the task.

**Changes:**
1. **Hardware back** — `MainActivity` registers an `OnBackPressedCallback` on
   the `OnBackPressedDispatcher`. It calls `webView.goBack()` while there is
   history, and only when `canGoBack()` is false shows a "Close Peckers?"
   confirm whose positive button `finish()`es. Capacitor 8 ships **no** back
   handling at all (`grep -rn "Back" capacitor/src/main/java` returns only
   `getBackgroundColor` and the Cordova mock), so before this, back closed the
   app from any screen — the task's premise was exactly right.
   **No route names are hardcoded.** "No history left" is the landing screen by
   construction, whichever portal the user is in, so the shell stays free of web
   app knowledge per the boundary rule in `CLAUDE.md`.
2. **Offline screen** — new `OfflineGate` inflates `offline_overlay.xml` into
   `android.R.id.content`, above the Capacitor WebView. It is raised by a
   `BridgeWebViewClient` subclass (`ShellWebViewClient`) on `onReceivedError`
   **for the main frame only**, and lowered on the next `onPageFinished` that
   did not fail. Retry asks `ConnectivityManager` first: with no network it
   swaps the body text to "Still no connection" rather than flashing the
   WebView's own error page; with a network it reloads `server.url`. A
   `registerDefaultNetworkCallback` recovers automatically the moment a network
   returns, with no tap.
   It is **native, not** the existing `www/index.html`: Capacitor's own
   `server.errorPath` would load the bundled page from the local asset host,
   where a retry button's `location.reload()` reloads the offline page instead
   of the site. `www/index.html` is left in place untouched as the `webDir`
   placeholder and last-resort fallback.
   Scoped to **network** errors deliberately. `onReceivedHttpError` is not
   wired: a 4xx/5xx from the app is a real page with real text, and covering it
   with "No connection" would be a lie.
3. **Main-frame filtering needed a WebViewClient subclass.** Capacitor's
   `WebViewListener.onReceivedError(WebView)` carries no `WebResourceRequest`,
   so a listener cannot tell a dead main frame from one failed subresource — a
   missing favicon would have raised the offline screen. `bridge.setWebViewClient`
   (Bridge.java:1468) takes a `BridgeWebViewClient`, so the subclass keeps every
   bridge behaviour (`shouldInterceptRequest`, `launchIntent`, the listener
   fan-out) by calling `super` on each override.
4. **Session persistence** — `CookieManager.getInstance().flush()` in
   `onPause`. See Testing for what was verified about the cookie itself; the
   flush is the one durability gap the shell could actually close.
5. **Resume version check** — new `BuildFingerprint`. On resume, if the app was
   away for 60s or more, it fetches `server.url` on a single background thread
   and hashes the sorted set of `/_next/static/...` asset paths in the returned
   HTML. Those paths are content-hashed by the Next.js build, so a new
   deployment always changes the hash and a redeploy of the same commit never
   does. A confirmed change reloads the WebView; an unreachable server, a page
   with no Next.js assets, or a first run with no stored baseline all leave it
   alone. Away for 12h or more reloads unconditionally and clears the baseline.
   The current fingerprint is re-recorded on every `onPageLoaded`.
   **No web-app change was needed** — no version endpoint, no build-ID header.
6. **`server.allowNavigation: []`** added explicitly. The web app contains
   **zero** off-origin links (`grep` for `href="http`, `window.open`,
   `target="_blank"`, `mailto:`, `tel:` across `app/`, `components/`, `lib/`
   finds nothing outside a comment in `lib/push.ts`), and `Bridge.launchIntent`
   (Bridge.java:389) already sends any host that is neither `server.url`'s nor
   in this mask to the system browser via `ACTION_VIEW`. Empty is therefore the
   correct value, not a missing one — it records the decision in the config
   rather than leaving the next reader to infer it from a default.
7. **`android:windowSoftInputMode="adjustResize"`** on `MainActivity`, and
   `ACCESS_NETWORK_STATE` declared (not runtime-granted) for `OfflineGate`.
8. Added `offline*` colours and strings, plus a 10dp rounded button drawable.
   The offline colours are fixed dark rather than DayNight: the window
   background and splash are `#0f0f0f` in both modes, so a light variant would
   flash against them.
9. `MainActivity` null-guards `offline` in `onResume`/`onStop` and in the back
   callback. `BridgeActivity.onCreate` falls back to `R.layout.no_webview` and
   **returns before `load()`** when there is no usable WebView, so the field can
   legitimately be null.

**Rationale:**
Everything here is the difference between a bookmark and an app. Back closing
the app from a half-filled form is the single most jarring thing about a naive
WebView shell; a blank white page on the Tube reads as "the app is broken"; and
an app resumed after a week running last week's JS against a refreshed session
is how silent, unreproducible bugs get reported. Doing it all natively keeps the
promise that remote mode makes — the web app is unchanged and unaware, so none
of this can affect the browser path or the live production site.

**Testing:**
- `npx cap sync android`: ✓ finished
- `gradlew assembleDebug` (JDK 21): ✓ BUILD SUCCESSFUL in 47s, 93 tasks.
  `compileDebugJavaWithJavac` clean — no warnings on the three new/changed
  Java files.
- `aapt2 dump badging` on the built APK: ✓ `ACCESS_NETWORK_STATE` now present
  alongside `INTERNET` and the two location permissions; ✓ `uk.co.peckers.app`,
  `minSdk 24`, `targetSdk 36`, portrait lock and launchable activity unchanged
- Unpacked `assets/capacitor.config.json` from inside the APK: ✓ carries
  `allowNavigation: []`, the preview `server.url` and `appendUserAgent`
- APK staged at `C:\NextJs\pms-apk\peckers-preview-debug.apk` (5.53 MB)
- **Vercel Deployment Protection is now OFF** — the Update 5 blocker is closed.
  `GET` on the branch preview with no Vercel session: ✓ `200`, redirects to
  `/login`, `<title>Admin sign in · Peckers</title>`. The app's WebView will
  now reach the Peckers login, not Vercel's.
- **Version check verified against the real deployment**, not in theory: the
  same `GET` was run through this feature's own regex and it finds **15**
  distinct `/_next/static/chunks/*-<hash>.js` paths on the login page. So the
  fingerprint has real input on the page an unauthenticated probe actually
  lands on, which is the page the probe will always see (it sends no cookies).
- **Session cookie durability, verified by reading the code rather than
  guessing:** `@supabase/ssr` 0.5.2 `DEFAULT_COOKIE_OPTIONS.maxAge` is
  `400 * 24 * 60 * 60` (`node_modules/@supabase/ssr/dist/main/utils/constants.js:10`),
  and `middleware.ts` passes no `cookieOptions` override, so the auth cookie is
  a **persistent** cookie with a 400-day Max-Age — not a session cookie. An
  Android WebView writes persistent cookies to its own app-data store, which
  survives process death and reboot; `android:allowBackup="false"` affects
  cloud backup/restore to a *new* device only, not local persistence. The gap
  was the write timing, which `flush()` now closes. **Conclusion: no change is
  needed in `peckers-cashflow` for session persistence**, which the task asked
  to be reported before touching anything.
- **Screen edges and keyboard, verified by reading Capacitor 8's `SystemBars`:**
  it is auto-registered (`Bridge.registerAllPlugins`, Bridge.java:664) and
  installs an `OnApplyWindowInsetsListener` on the decor view. The web app sets
  `viewportFit: "cover"` (`app/layout.tsx:37`), so on WebView 140+ `SystemBars`
  passes the system-bar and display-cutout insets straight through and the
  page's own `env(safe-area-inset-*)` is populated natively; on older WebViews
  it zeroes them and pads the decor view instead, so content is inset either
  way and nothing is clipped. **The keyboard is handled in both branches** —
  the listener pads the bottom by `imeInsets.bottom` while the IME is visible,
  so the WebView shrinks above the keyboard rather than being covered.
  `@capacitor/keyboard` is therefore **not** needed and was not installed;
  `adjustResize` was set for pre-15 devices where the manifest flag still does
  the work. The web app's seven `env(safe-area-inset-*)` call sites
  (`BottomNav` ×2, `TopBar`, `Modal`, `Toast`, `LiveDashboard`) need **no
  change**.
- **NOT TESTED — requires a device, and every item is on-device by nature:**
  back navigation and the exit confirm in the hand; the offline screen with
  aeroplane mode on; auto-recovery when Wi-Fi returns; the cookie surviving a
  force-stop, a reboot and several days idle; the resume reload firing after a
  real redeploy; and how the `BottomNav` actually sits against gesture nav and
  3-button nav. The APK is staged and ready to install.

**Impact:**
- **Users:** none yet — debug build, our devices only until Tasks 5 and 6
  restore shift reminders. When it does ship, the four behaviours above are the
  ones staff would otherwise have reported as bugs.
- **Web app:** `C:\NextJs\peckers-cashflow` was **NOT modified** — this task was
  scoped to need no change there and it did not. It was read only:
  `app/layout.tsx`, `middleware.ts`, `lib/supabase.ts`, the
  `env(safe-area-inset-*)` call sites and `node_modules/@supabase/ssr`
  constants. Nothing was written, and no entry is owed in
  `docs/updates-operations.md`.
- **Build/Release:** no new dependency — `androidx.activity` and `appcompat`
  were already on the classpath. `JAVA_HOME` must still point at JDK 21 per
  shell. `ACCESS_NETWORK_STATE` is a normal permission, so it adds no runtime
  prompt and no Play Store install filter.

**Open / known gaps:**
1. **`onRenderProcessGone` is not handled — DEFERRED by decision, 2026-10-08.**
   Android runs the page in a separate sandboxed renderer process and kills a
   backgrounded app's renderer first under memory pressure. The WebView then
   calls `onRenderProcessGone`; Capacitor's default returns `false`, which is
   "not handled", and Android's response to that is to kill the app process.
   The symptom is the app being gone when staff come back to it.
   **It does NOT affect anything in this update.** The session is a persistent
   cookie on disk, so a relaunch is still signed in; back-button behaviour and
   the native insets are rebuilt from scratch on every activity start; the
   resume version check is moot because a relaunch loads the current build
   anyway. What is lost is unsubmitted on-screen input — a half-filled manual
   clock entry or weekly-report sheet. Nothing server-side: a clock-in or
   approval that reached the server is already written.
   **Do not "fix" it by returning `true` alone.** The WebView object is
   permanently dead after a renderer kill, so that trades a crash for an app
   that opens to a black rectangle forever and never recovers — strictly harder
   to diagnose than the crash.
   **The intended fix, when it is picked up:** return `true` and restart the
   activity, so `BridgeActivity.onCreate` rebuilds the bridge, the WebView and
   this shell's own `OfflineGate` from scratch and lands on the landing screen.
   Needs a guard against restarting in a loop if the renderer keeps dying. The
   alternative — removing the dead WebView and rebuilding Capacitor's `Bridge`
   in place for a seamless recovery — was rejected: Capacitor exposes no
   supported way to do it.
   **This is one of the few things here that CAN be proven at a desk:** a
   WebView's renderer can be crashed deliberately over USB, so the fix is
   testable without waiting for real memory pressure.
   **Why it was deferred:** nobody is on the APK yet, so there is no staff
   impact either way, and the change belongs with device testing rather than
   bolted onto this one. The reason to do it before Task 8 is our own time — an
   app that silently vanishes with no error looks like a login, geofence or
   shell bug and is reproducible only under memory pressure, so whoever sees it
   during device testing should read this note first.
2. The offline overlay sets `fitsSystemWindows="true"`, which only takes effect
   in the branch where `SystemBars` leaves insets on the decor view. In the
   WebView-140+ passthrough branch the overlay can extend under the status bar.
   Its content is centred with 24dp gutters so nothing is clipped, but it is
   worth a look on a real device.
3. The 12h force-reload ceiling and the 60s version-check floor are judgement
   calls, not measurements. If staff report losing a half-filled form on
   resume, the ceiling is the thing to raise.
4. Carried from Update 1: the launcher icon is a wordmark on a dark square and
   will be hard to read at 48dp.

---

### Update 7: Native push plugin in the shell, and POST_NOTIFICATIONS declared

**Date:** 2026-10-08
**Type:** Feature
**Scope:** Capacitor plugins, Android manifest, debug build
**Files Modified:**
- `package.json`, `package-lock.json`
- `android/app/src/main/AndroidManifest.xml`
- `android/app/src/main/assets/capacitor.plugins.json` *(regenerated by `cap sync`)*
- `android/app/src/main/assets/capacitor.config.json` *(regenerated by `cap sync`)*
- `mobile-updates.md`
- *(`android/app/google-services.json` is NOT present and is gitignored — see "Still required")*

**Summary:**
Added `@capacitor/push-notifications` 8.1.3 so the shell can obtain an FCM
registration token, and declared `POST_NOTIFICATIONS` in the manifest. The web
side that actually asks for the token and stores it against the signed-in
employee or manager is in `peckers-cashflow` on branch
`feat/mobile-geolocation` — the same preview branch this APK's `server.url`
already points at, so the web half reaches the phone on next open with no
rebuild — logged there as **Update 251**. Task 5 of 9, cross-repo; this is the shell half.
**No Firebase project exists yet**, so no real token has been issued — that is
the one step that could not be done from here.

**Changes:**
1. `npm install @capacitor/push-notifications` (8.1.3), then
   `npx cap sync android`. The plugin is auto-registered — `cap sync` wrote it
   into `android/app/src/main/assets/capacitor.plugins.json`, and Capacitor's
   `PluginManager` loads it from there, so `MainActivity` needed no change.
2. **Declared `android.permission.POST_NOTIFICATIONS` in the app manifest.**
   The plugin annotates it for Capacitor's runtime request
   (`PushNotificationsPlugin.java:39`) but does **not** declare it in its own
   `AndroidManifest.xml` — that file contains only the `MessagingService`. A
   permission missing from the merged manifest is auto-denied by Android with
   **no prompt shown**, and on API 33+ `requestPermissions()` goes through
   `requestPermissionForAlias` (plugin lines 101–110), so without this line
   every app user would have silently had reminders off. Exactly the trap the
   location permissions hit in Update 3.
3. Installed **no** Firebase SDK by hand and changed **no** Gradle file. The
   Capacitor template's `android/build.gradle` already carries the
   `com.google.gms:google-services:4.4.4` classpath, and `app/build.gradle`
   already applies that plugin **only if `google-services.json` is present** —
   so the project builds either way and the file can be dropped in later with
   no further edit.
4. Wrote **no** business logic here, per the boundary rule. The token request,
   the permission UX and the server write all live in `peckers-cashflow`.

**Rationale:**
The reason the whole APK is blocked from staff: Web Push does not exist in an
Android System WebView, so installing the app is the moment someone stops
getting the shift reminders they were getting in Chrome. FCM is the only route
to a notification inside the app, and a token is the first half of it.
Declaring `POST_NOTIFICATIONS` here rather than discovering it on a device is
worth the note — it is the second time in this project that a permission the
plugin "handles" still had to be declared by hand, and both times the failure
mode was silence rather than an error.

**Testing:**
- `npm install`: ✓ `@capacitor/push-notifications@8.1.3`
- `npx cap sync android`: ✓ "Found 1 Capacitor plugin for android"
- `gradlew assembleDebug` (JDK 21): ✓ BUILD SUCCESSFUL in 52s **with no
  `google-services.json` present** — the conditional in `app/build.gradle`
  holds, so a missing Firebase config does not break the build
- `aapt2 dump badging` on the built APK: ✓ `POST_NOTIFICATIONS` present, and
  the plugin's own merged additions came with it —
  `android.permission.WAKE_LOCK` and
  `com.google.android.c2dm.permission.RECEIVE`, which is FCM wired in. The
  earlier permissions are unchanged: `INTERNET`, `ACCESS_NETWORK_STATE`,
  `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`
- APK size went 5.53 MB → **9.47 MB** (the Firebase Messaging SDK). Worth
  knowing before Task 4 sizes a release build.
- APK staged at `C:\NextJs\pms-apk\peckers-preview-debug.apk`
- Capacitor's bridge injection into a REMOTE origin verified in its own source,
  because the entire design depends on it — a plugin is useless if the Vercel
  page cannot see it. `Bridge.loadWebView` calls
  `WebViewCompat.addDocumentStartJavaScript(webView, injector.getScriptString(),
  Collections.singleton(allowedOrigin))` with `allowedOrigin` taken from
  `appUrl` (Bridge.java:265–272), and the remote host is added to the bridge's
  authorities (Bridge.java:636). So `window.Capacitor.Plugins.PushNotifications`
  **is** reachable from the remote page in remote mode. ✓
- **NOT TESTED — no Firebase project exists.** Without
  `google-services.json`, `FirebaseApp` cannot initialise, so `register()`
  fires neither `registration` nor `registrationError` and the web side's 15s
  timeout surfaces "The device didn't return a notification token." That is the
  expected behaviour today, not a bug.
- **NOT TESTED — everything on device:** the notification permission prompt,
  the token actually arriving, the token reaching the right employee or manager
  row, and a notification being displayed.

**Impact:**
- **Users:** none. Still our devices only — and still blocked from staff, since
  reminders do not arrive until the server can send to these tokens (Task 6).
- **Web app:** `peckers-cashflow` **WAS** modified, deliberately and on the
  existing mobile preview branch `feat/mobile-geolocation` (NOT `main`, which is
  in production and is where bug fixes go), logged there as **Update 251**. Two new
  server actions, a new `lib/native-push.ts`, a native branch in the existing
  reminders card, and migration `067`. The existing Web Push registration path
  was not changed and `lib/push.ts` was not touched.
- **Build/Release:** APK roughly 4 MB larger. `JAVA_HOME` must still point at
  JDK 21 per shell. Once `google-services.json` lands, `app/build.gradle`
  applies the google-services plugin automatically — no Gradle edit, but a
  rebuild is required.

**⚠ STILL REQUIRED — the Firebase project (cannot be done from here):**
This needs a Google account in the Firebase console, so it is a manual step.
Until it is done, the app registers no token.

1. Firebase console → **Add project**. Analytics is not needed.
2. Inside the project → **Add app → Android**.
3. **Android package name must be exactly `uk.co.peckers.app`.** This is the
   permanent `appId` (see "Conventions" in `CLAUDE.md`) and FCM will not deliver
   to a mismatched package. No nickname or signing certificate is needed for
   FCM tokens; a debug SHA-1 is only required for Google Sign-In.
4. Download **`google-services.json`** and put it at
   **`android/app/google-services.json`**. It is already in `.gitignore`
   (line 12) — **do not commit it.**
5. `npx cap sync android`, then rebuild. `app/build.gradle` picks the file up
   on its own.
6. Task 6 will additionally need a **service account key** (Project settings →
   Service accounts → Generate new private key) as a server-side secret in
   `peckers-cashflow`. That is a different credential from this file and must
   never be committed either.

**Open:**
1. The Firebase project above. Everything else in Task 5 is in place.
2. Carried from Update 6: `onRenderProcessGone` is unhandled (deferred).
3. Carried from Update 1: the launcher icon is a wordmark on a dark square.
4. **A cover driver on the app gets no reminders at all**, because
   `cover_driver_push_subscriptions` does not exist in the web repo — its
   `CLAUDE.md` known gap 4. Decided out of scope for this task; recorded here
   so Task 6 does not assume all four roles are covered.

### Update 8: Task 6 — the server can now send to native tokens (web repo only)

**Date:** 2026-10-09
**Type:** Feature
**Scope:** Nothing in this repo. Task 6 is entirely server-side sending, which
by the boundary rule lives in `peckers-cashflow`. Logged here because the task
spans both repos and because it changes what this APK does on a device.
**Files Modified:**
- `mobile-updates.md` (this entry)
- `CLAUDE.md` (the 9-task table: Task 6 state)
- *(no `capacitor.config.json`, no `android/**`, no `www/**`, no `assets/**` —
  and therefore no `cap sync` and no rebuild)*

**Summary:**
Update 7 gave the shell `@capacitor/push-notifications` and
`POST_NOTIFICATIONS`, so a device can obtain an FCM token, and web-repo Update
251 stored those tokens. Nothing sent to them. The web repo's reminder path now
fans out over both transports — browsers keep going through Web Push, app
installs go through FCM — so a shift reminder reaches the app. **Logged in
`peckers-cashflow` as Update 252, on branch `feat/native-push`.**
The shell needed no change at all: the plugin is already registered and the
notification is drawn by Android, not by us.

**Changes:**
1. **No shell change.** Verified rather than assumed: the sending side needs
   only a valid FCM token for the installed package, which the plugin already
   produces, and the tray notification is drawn by Android from the message's
   `notification` block. `capacitor.plugins.json`, the manifest and the Gradle
   files are untouched, so the APK at
   `C:\NextJs\pms-apk\peckers-preview-debug.apk` is still current for this task.
2. **The two Android-specific behaviours were handled in the WEB repo**, where
   the boundary rule puts them:
   - a **tap** on a tray notification reaches the WebView as a plugin event, not
     as a navigation, so the target path is applied by the page
     (`pushNotificationActionPerformed`);
   - a push arriving while the app is **FOREGROUNDED** draws nothing on Android,
     so the page shows an in-app toast instead
     (`pushNotificationReceived`). Without it, a reminder is silently lost for
     exactly the people already looking at the app.
   Both live in a new `components/clock/NativePushHandler.tsx` there. Nothing
   about either was copied into this repo.
3. **The deep link needs no shell handling either.** Both reminder targets
   (`/employee/attendance`, `/manager/live`) are the portal home that
   `middleware.ts` lands on after a login, so an expired session — and a cold
   start, where the WebView loads `/` — resolve to the same screen.
4. **`CLAUDE.md`'s task table:** Task 6 moved to code-complete, blocked on the
   same Firebase project Task 5 is blocked on.

**Rationale:**
This is the second half of the one thing keeping the APK off staff phones. The
warning in `CLAUDE.md` — that installing the app is the moment someone STOPS
getting the reminders they got in Chrome — holds until a server sends to FCM.
With Update 252 the code path is complete end to end; what remains is a
credential, not a change.

Doing it with zero shell edits is the point of remote mode working as intended:
the sending logic, the tap handling and the foreground case are all things the
page does, so they ship to the device on next open with no rebuild and no store
review.

**Testing:**
- **Nothing to build or sync here** — no file this repo owns changed.
- Verified in the web repo instead: typecheck and `next build` pass,
  `firebase-admin` is absent from every client chunk, and dead-token pruning was
  driven for real on both transports (a browser endpoint answering 410 and a
  token FCM reports as unregistered are both pruned; a transient failure is
  not). Full detail in that repo's Update 252.
- **NOT TESTED — a notification arriving on this APK.** Still blocked on the
  Firebase project: no `google-services.json` here, so the shell has never
  issued a real token, and no service account there, so the server cannot
  authenticate to FCM. Nothing in Task 6 could change that from either repo.
- **NOT TESTED on device:** the permission prompt, the tray notification, the
  tap deep-link, and the foreground toast. All four need a real token first.
  They join the Update 6 acceptance list for Task 8.

**Impact:**
- **Users:** none yet. Still our devices only, and still not for staff — but the
  reason has narrowed from "no code" to "no Firebase project".
- **Web app:** `peckers-cashflow` **WAS** modified, deliberately, as Task 6
  requires. Branch `feat/native-push`, cut from `feat/mobile-geolocation` (NOT
  `main`, which is in production). Logged there as **Update 252**. One new
  `lib/fcm.ts`, a platform split inside `lib/push.ts` with both public
  signatures unchanged, a tap/foreground handler mounted in the two portal
  layouts, and two silent-failure fixes in the reminder path. No migration: 067
  from Update 251 already has the columns, and it has **still not been run** —
  the new code tolerates that rather than depending on deploy order.
- **Build/Release:** no effect. No `cap sync`, no rebuild, no size change, no
  new permission. `cleartext: true` is still set for LAN dev and must still come
  off for Task 4's release build.

**⚠ STILL REQUIRED — the Firebase project, now needed in TWO places:**
Unchanged from Update 7's list, plus the server half. Both come from the same
Firebase project and neither is ever committed.

1. `android/app/google-services.json` **here** (package name exactly
   `uk.co.peckers.app`), then `npx cap sync android` and a rebuild.
2. A **service account key** in `peckers-cashflow` as the env var
   `FIREBASE_SERVICE_ACCOUNT` — Firebase console → Project settings → Service
   accounts → Generate new private key. The whole JSON, raw or base64. This is a
   DIFFERENT credential from the file above.
3. Run migration `067_native_push_tokens.sql` in the web repo. Not blocking any
   more (Update 252 falls back to the pre-067 columns), but the `platform`
   column is what routes a device to FCM, so no native reminder is sent until it
   exists.

**Open:**
1. The Firebase project above — now the only thing between this APK and a
   working shift reminder.
2. **A cover driver still gets no reminders at all**, in the app or a browser:
   `cover_driver_push_subscriptions` does not exist in the web repo (its
   CLAUDE.md known gap 4). Carried unchanged from Update 7; Task 6 did not
   assume it was covered.
3. Carried from Update 6: `onRenderProcessGone` is unhandled (deferred).
4. Carried from Update 1: the launcher icon is a wordmark on a dark square.
5. A tap that **cold-starts** the app may fire the plugin event before the page
   has mounted its listener. Harmless today only because `/` resolves to the
   same portal home the reminder points at — worth a device check in Task 8.

### Update 9: Task 4 — release keystore, signed release build, environment switching

**Date:** 2026-10-12
**Type:** Build
**Scope:** Release signing, Gradle build types, `server.url` environment files, release documentation
**Files Modified:**
- `android/app/build.gradle`
- `capacitor.config.json` *(now written BY the env script, not by hand)*
- `config/capacitor.config.lan.json` *(new)*
- `config/capacitor.config.preview.json` *(new)*
- `config/capacitor.config.prod.json` *(new)*
- `scripts/use-env.mjs` *(new)*
- `package.json`
- `RELEASE.md` *(new)*
- `CLAUDE.md` *(task table, environments section, toolchain, hard rule 1)*
- `android/app/src/main/assets/capacitor.config.json` *(regenerated by `cap sync`)*
- `mobile-updates.md`
- *(`android/peckers-release.jks` and `android/keystore.properties` were created
  and are gitignored — never committed)*

**Summary:**
The app can now be built as a signed release. A permanent release keystore was
generated, Gradle signs `assembleRelease` from gitignored credentials, and the
three `server.url` environments moved out of hand-editing into `config/` files
behind `npm run env:lan|preview|prod`. A release APK was built, signature- and
manifest-verified, and staged. Task 4 of 9. Nothing in `peckers-cashflow` was
touched — `main` especially is untouched, and this task needed no web change at
all.

**Changes:**
1. **Release keystore generated** — `android/peckers-release.jks`, PKCS12,
   RSA 4096, SHA384withRSA, 10 000 days, alias `peckers`, DN
   `CN=Peckers, OU=Operations, O=Peckers, L=Stevenage, C=GB`. Certificate
   SHA-256 `62f396e5…c8dd54`, SHA-1 `e90993db…037934` — recorded in
   `RELEASE.md` so a future build can be checked against the installed key.
   The password is a 24-byte random value **generated directly into
   `android/keystore.properties`**: it was passed to `keytool` through
   `-storepass:file` with a temp file deleted afterwards, so it never appeared
   in a command line, console output or transcript. `git check-ignore` confirms
   both files are ignored (`.gitignore` lines 7 and 9).
2. **Gradle signing** in `android/app/build.gradle`: a `signingConfigs.release`
   reading `rootProject.file("keystore.properties")`, applied to
   `buildTypes.release`, with `enableV2Signing` and `enableV3Signing` both on.
   v3 is the one that matters long-term — it is what would let this key be
   **rotated** instead of forcing every phone to reinstall.
3. **A missing `keystore.properties` now FAILS the build** rather than quietly
   producing `app-release-unsigned.apk`: a `gradle.taskGraph.whenReady` guard
   throws when any release task is requested without it. An unsigned APK
   installs nowhere and is indistinguishable from a signed one by filename.
4. **`versionName` 1.0 → 1.0.0**, `versionCode` left at 1, with the bump rule
   written down — Android refuses an install whose `versionCode` is not higher
   than the installed one.
5. **R8 deliberately left off** (`minifyEnabled false`, now commented). Capacitor
   loads plugins reflectively from `capacitor.plugins.json`, so shrinking needs
   keep rules per plugin, and the APK is dominated by the Firebase SDK anyway.
6. **The three environments became files**: `config/capacitor.config.{lan,
   preview,prod}.json`, selected by `scripts/use-env.mjs` which copies one over
   `capacitor.config.json`, prints the URL/`cleartext`/`allowMixedContent` it
   selected, and runs `cap sync android`. Capacitor bakes `server.url` into the
   APK at sync time, so the failure this removes is real: a forgotten sync
   ships the PREVIOUS environment inside a build whose filename says otherwise.
7. **`allowMixedContent` is now `false` in preview and prod**, true only in
   LAN dev, and `cleartext` likewise. The release build was verified to carry
   neither — the Update 1 warning that cleartext "must be off in the release
   build" is now enforced by which file you select, not by remembering.
8. **The production URL is recorded for the first time**:
   `https://peckers-cashflow-peckerschicken.vercel.app`, the stable project
   alias (probed: 307 → `/login`). `APP_URL` in the web repo is empty and no
   custom domain exists, so this is the production host until one does.
9. **`RELEASE.md`** — keystore backup, environment switching, build commands,
   the verification checklist, staff sideload instructions and how an update
   reaches a phone.
10. **`CLAUDE.md`** — Task 4 marked done; Tasks 5 and 6 corrected from
   "blocked on Firebase" to done (the Firebase project, `google-services.json`
   and `FIREBASE_SERVICE_ACCOUNT` all landed after Update 8 was written, and a
   reminder has since reached a device); the environments table rewritten around
   the new commands; the toolchain section rewritten now that JDK 21 and the
   Android SDK are installed; hard rule 1 pointed at the keystore that now
   exists.

**Rationale:**
Everything before this produced debug-signed APKs. A debug key is generated per
machine and shared by every Android developer in the world — it cannot be used
for anything a staff member installs, and the moment one phone has a build,
that build's key is locked in for the life of the install. Doing the keystore
now, with its backup instructions, is the step that cannot be redone later: the
cost of losing it is every staff phone uninstalling and re-logging-in.

Moving the environments into files is the same kind of insurance one level down.
The only thing distinguishing a staff release from a build pointed at a laptop's
LAN IP is one line in a config, and the sync that bakes it in is a separate
command — exactly the shape of mistake that is invisible until a phone shows a
connection error, or worse, quietly works against the wrong deployment.

**The release is pointed at the PREVIEW deployment, not production, on purpose.**
The native push code (web Updates 251–253) is still on
`feat/mobile-geolocation`; `main` has none of it. An APK built against
production today would give staff **no shift reminders at all** — the precise
state `CLAUDE.md` forbids shipping. So this release proves the signing pipeline
against the deployment that actually has push, and `npm run env:prod` is one
command away for when the branch merges.

**Testing:**
- `npm run env:preview`: ✓ wrote the preview config, reported
  `cleartext false` / `allowMixedContent false`, sync found the 1 Capacitor
  plugin (`@capacitor/push-notifications@8.1.3`)
- `gradlew assembleRelease` (JDK 21): ✓ BUILD SUCCESSFUL, 168 tasks, including
  `lintVitalRelease` — which only runs on release builds and passed
- `apksigner verify --print-certs`: ✓ **Verifies**, v2 **true**, v3 **true**,
  1 signer, DN `CN=Peckers, OU=Operations, O=Peckers, L=Stevenage, C=GB`,
  RSA 4096, SHA-256 digest matching the keystore
- `aapt2 dump badging`: ✓ `uk.co.peckers.app`, `versionCode 1`,
  `versionName 1.0.0`, `minSdkVersion 24`, `targetSdkVersion 36`, portrait,
  label `Peckers`, launchable `MainActivity`, and **no `application-debuggable`
  line** — the one-line difference between this and every earlier APK
- Permissions unchanged from Update 7: ✓ `INTERNET`, `ACCESS_NETWORK_STATE`,
  `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`, `POST_NOTIFICATIONS`,
  `WAKE_LOCK`, `com.google.android.c2dm.permission.RECEIVE`
- `aapt2 dump xmltree AndroidManifest.xml`: ✓ no `usesCleartextTraffic`,
  `allowBackup=false`
- Unpacked `assets/capacitor.config.json` from inside the APK: ✓ preview URL,
  `allowMixedContent: false`, no `cleartext`, `allowNavigation: []`
- **FCM confirmed present in the release build, not assumed**: `aapt2 dump
  resources` shows `google_app_id`, `gcm_defaultSenderId` and `project_id`, and
  the merged manifest carries `MessagingService`,
  `FirebaseMessagingService`, `FirebaseInstanceIdReceiver` and
  `ComponentDiscoveryService`. Worth checking explicitly: `app/build.gradle`
  applies the google-services plugin **only if `google-services.json` exists**,
  so a release that silently lost push would look completely normal otherwise.
- APK size **4.8 MB**, against 9.47 MB for the Update 7 debug build — release
  strips debug symbols and optimises resources
- Staged at `C:\NextJs\pms-apk\peckers-release-1.0.0-preview.apk`
- **NOT TESTED — installing or running this APK on a device.** A release build
  differs from the debug one in signature, debuggability and resource
  optimisation, so it is its own install: it must be sideloaded onto a phone
  (uninstalling the debug build first, since the signatures differ) and taken
  through login, clock-in and a reminder. That is Task 8, and this APK is now
  the build it should be run against.
- **NOT TESTED — `npm run env:prod`.** The config is written and the script is
  the same code path as `env:preview`, but no build has been made from it.

**Impact:**
- **Users:** none yet. Still our devices only. The blocker is no longer signing;
  it is the web branch reaching production and Task 8 device testing.
- **Web app:** `peckers-cashflow` **NOT touched** — not `main`, not any branch.
  Task 4 is entirely shell-side, which is why it needed no cross-repo step.
- **Build/Release:** release builds are now signed, reproducible and
  environment-switchable. `JAVA_HOME` must point at JDK 21. The keystore and
  its properties file must be backed up off this machine **before** any phone
  installs the app, and `versionCode` must be bumped for every build that
  leaves here.

**Open:**
1. **Back up `android/peckers-release.jks` + `android/keystore.properties`
   off this machine.** Nothing else in the project has this failure mode.
2. A production release needs `feat/mobile-geolocation` merged, migration
   `067_native_push_tokens.sql` run, and `FIREBASE_SERVICE_ACCOUNT` set on the
   production Vercel environment — then `npm run env:prod` and rebuild.
3. Updates 6, 7 and 8's code is **still uncommitted** in this repo (last commit
   is `94975c2`, Update 5). This release was built from that working tree, so
   nothing in git reproduces the staged APK yet.
4. Carried from Update 8: cover drivers get no reminders on any platform
   (`cover_driver_push_subscriptions` does not exist in the web repo).
5. Carried from Update 6: `onRenderProcessGone` is unhandled.
6. Carried from Update 1: the launcher icon is a wordmark on a dark square.
7. New, found while documenting: FCM messages specify no `channel_id` and the
   app declares no small notification icon, so Android draws them on an
   auto-created "Miscellaneous" channel and may show a white square. Task 7
   polish, not a blocker.

### Update 10: `versionCode` bumped to 2

**Date:** 2026-10-13
**Type:** Config
**Scope:** Android version metadata
**Files Modified:**
- `android/app/build.gradle`
- `mobile-updates.md`

**Summary:**
`versionCode` 1 → 2 so the next release APK can install as an update over the
one now on test devices. `versionName` stays `1.0.0`: no app behaviour changed,
only the install-ordering integer. **No rebuild was done** — the number takes
effect on the next build, and the APK already on phones is unaffected.

**Changes:**
1. `versionCode 1` → `versionCode 2` in `android/app/build.gradle`.

**Rationale:**
Android refuses to install an APK whose `versionCode` is lower than the
installed one, and treats an EQUAL `versionCode` inconsistently across
installers — some reinstall, some do nothing at all, which on a phone looks
exactly like "tapped update, nothing happened". A second build still numbered 1
would therefore have been indistinguishable from the debug-to-release signature
failure a teammate hit on 2026-10-12 (see Update 9's signing notes): same
symptom, different cause, and no way to tell them apart from the phone.

Bumping now rather than at build time is the point — the number has to be right
BEFORE an APK is produced, because it is compiled in and cannot be corrected
afterwards without rebuilding.

**Testing:**
- Not built. `versionCode` is read at build time, so this change is inert until
  `npm run build:release` runs; the staged
  `C:\NextJs\pms-apk\peckers-release-1.0.0-preview.apk` still reports
  `versionCode 1` and is still the build under test.
- To confirm after the next build:
  `aapt2 dump badging <apk> | findstr versionCode` should read 2.

**Impact:**
- **Users:** none now. The installed app keeps working; nothing re-installs.
- **Web app:** `peckers-cashflow` not touched.
- **Build/Release:** the next release APK will update cleanly over the current
  one, **provided it is signed with the same `peckers-release.jks`**. Bump this
  integer again for every build that leaves this machine.

**Open:**
1. The staged APK's filename (`1.0.0`) no longer implies its `versionCode`.
   Name the next one for the build, e.g. `peckers-release-1.0.0-vc2-preview.apk`.
2. Carried from Update 9: Updates 6–10 are all still uncommitted, this repo has
   no remote, and the keystore + `keystore.properties` still need backing up
   off this machine.

---

### Update 11: iOS track opened — Xcode project scaffolded and a cloud macOS build defined

**Date:** 2026-10-13
**Type:** Build
**Scope:** iOS native project, CI definition, docs. No Android file changed.
**Files Modified:**
- `package.json`, `package-lock.json` — added `@capacitor/ios@^8.5.2`
- `ios/**` *(new — generated Xcode project)*
- `ios/App/App/Info.plist`
- `codemagic.yaml` *(new)*
- `ios/App/App/Assets.xcassets/**` — Peckers icon and splash generated for iOS
- `.gitignore`
- `CLAUDE.md`
- `mobile-updates.md`

**Summary:**
Step 7 of the iOS plan: get an iPhone build running on a Mac we do not own.
`npx cap add ios` scaffolds the Xcode project on Windows — Capacitor only gates
the Xcode and CocoaPods checks behind macOS, not the scaffold itself — and
`codemagic.yaml` compiles it on a cloud Mac mini M2. The build is **unsigned and
simulator-only**, which is what lets the whole pipeline be proven before the
$99/yr Apple Developer account is bought.

**Changes:**
1. Installed `@capacitor/ios@^8.5.2` and ran `npx cap add ios`. Capacitor 8 uses
   **Swift Package Manager, not CocoaPods** — there is no `Podfile` and no
   `.xcworkspace`, only `App.xcodeproj` plus `ios/App/CapApp-SPM`. The
   `@capacitor/push-notifications` plugin was picked up into `Package.swift`
   automatically.
2. Added `NSLocationWhenInUseUsageDescription` to `Info.plist`.
3. Locked iOS to portrait by removing the landscape entries from
   `UISupportedInterfaceOrientations` (and the landscape pair from the `~ipad`
   array), matching the orientation convention already fixed for Android.
4. Added `codemagic.yaml` with one workflow, `ios-simulator`: `npm ci` →
   `npx cap sync ios` → `xcodebuild … -sdk iphonesimulator -configuration Debug
   CODE_SIGNING_ALLOWED=NO` → zip the `.app` as an artifact.
5. Built with `-target App`, **not** `-scheme App`: the Capacitor 8 template
   ships no shared `.xcscheme`, so a scheme-based invocation would fail on a CI
   machine that has never opened the project in Xcode.
6. Left out any `triggering:` block, so builds are manual only.
7. Extended `.gitignore` for iOS signing material (`*.p12`, `*.cer`,
   `*.mobileprovision`, `GoogleService-Info.plist`) and build output.
8. Ran `capacitor-assets generate --ios` so the app carries the Peckers icon
   and splash rather than Capacitor's default, and deleted the three unused
   `splash-2732x2732*.png` template files the generator left unreferenced.
9. Added `npm run sync:ios` and `npm run assets:ios` beside their Android twins,
   and widened the package description to "Android + iOS".
10. Updated `CLAUDE.md`: the repo is no longer Android-only, `ios/**` and
   `codemagic.yaml` are declared as living here, the portrait and `appId`
   conventions now name their iOS equivalents, hard rule 2 states that
   `codemagic.yaml` is not a GitHub workflow, and an "iOS track" section records
   that this plan numbers its steps separately from the table above.

**Rationale:**
An iOS build is the one piece of this project that cannot be done on the
development machine at all. Proving the project compiles on a cloud Mac **before**
spending $99 separates "does it build" from "can we distribute it", so the Apple
subscription is bought against a known-good project rather than on faith. The
portrait lock and the location string are not cosmetic: the iOS layouts are the
same portrait-only mobile layouts, and a WKWebView that asks for a position with
no usage description in `Info.plist` **crashes the app outright** — which would
take out the geofenced clock-in, the single thing staff use the app for.

**Testing:**
- `npx cap add ios`: ✓ project generated, 1 plugin resolved into `Package.swift`
- `Info.plist`: ✓ re-read after editing; location key present, orientation arrays
  portrait-only
- `codemagic.yaml`: ✓ parses as valid YAML (one workflow, five scripts)
- **NOT tested: the build itself.** It has never been compiled — there is no Mac
  here and the Codemagic build has not been run yet. `xcodebuild` arguments,
  SPM resolution on CI and the artifact path are all unverified until the first
  cloud build goes green.

**Impact:**
- **Users:** none. No staff device runs iOS yet and no Android behaviour changed.
- **Web app:** nothing in `C:\NextJs\peckers-cashflow` was touched.
- **Build/Release:** Android builds are unaffected — `npm run build:release` and
  the keystore path are untouched. Note that `scripts/use-env.mjs` still runs
  `cap sync android` only, so switching environments does not sync the iOS
  project; CI does its own `cap sync ios`, so this bites only a future local Mac
  build. The LAN environment would additionally need an ATS exception on iOS,
  since `http://` is blocked by default — not needed for preview or production,
  which are both HTTPS.

---

### Update 12: Codemagic pinned to Node 22.19.0 — the Capacitor CLI refuses Node 20

**Date:** 2026-10-13
**Type:** Bug Fix
**Scope:** CI definition only
**Files Modified:**
- `codemagic.yaml`

**Summary:**
The first cloud build (`6acdc266546ce6236cee0826`) failed at the `cap sync ios`
step with `[fatal] The Capacitor CLI requires NodeJS >=22.0.0`. Update 11 pinned
`node: 20`. Pinned to `22.19.0`, the exact version the development machine runs.

**Changes:**
1. `environment.node`: `20` → `22.19.0`.

**Rationale:**
`@capacitor/cli@8` declares `engines.node: ">=22.0.0"` and enforces it at
runtime rather than warning. An exact pin instead of `22` keeps CI on the same
version as local, so a Capacitor behaviour difference can never be a silent
Node version difference.

**Testing:**
- YAML re-parsed: ✓ valid
- The build itself is still unverified past this step. Steps 1–3 of the workflow
  (`npm ci`, machine prep, source fetch) did pass on the failed run, so only the
  Capacitor and `xcodebuild` steps remain unproven.

**Impact:**
- **Users:** none.
- **Web app:** untouched.
- **Build/Release:** Android is unaffected; this file governs iOS CI only.

---

### Update 13: iOS build output moved from `-derivedDataPath` to `SYMROOT`

**Date:** 2026-10-13
**Type:** Bug Fix
**Scope:** CI definition only
**Files Modified:**
- `codemagic.yaml`
- `.gitignore`

**Summary:**
Build 2 (`6acddec2546ce6236cee0e46`) got past Node and Capacitor and failed in
`xcodebuild` with `The flag -scheme, -testProductsPath, or -xctestrun is
required when specifying -derivedDataPath`. The two flags Update 11 combined are
mutually exclusive: `-derivedDataPath` is only accepted alongside `-scheme`, and
this build uses `-target` because the Capacitor 8 template ships no shared
scheme. Output location now set with `SYMROOT`, which `-target` does accept.

**Changes:**
1. Dropped `-derivedDataPath ios/App/build`; added `SYMROOT="$PWD/build-ios"`.
2. Product path therefore moved from
   `ios/App/build/Build/Products/Debug-iphonesimulator/` to
   `build-ios/Debug-iphonesimulator/` — `SYMROOT` has no `Build/Products/`
   nesting, unlike a derived data directory. Zip step and `artifacts` updated.
3. Added `ls -la` before the zip so a wrong product path names itself in the log
   instead of failing as a bare "no such file".
4. `build-ios/` added to `.gitignore`.

**Rationale:**
Keeping `-target` is the deliberate choice — a scheme-based build would depend
on Xcode having autocreated a scheme on a machine that has never opened the
project. `SYMROOT` is the scheme-free way to pin the output directory, so the
artifact path stays predictable.

**Testing:**
- YAML re-parsed: ✓ valid
- Build 2 confirmed that `npm ci`, `npx cap sync ios` and `xcodebuild -list` all
  pass on CI — so the project resolves and SPM is not an obstacle.
- **Still unverified: the compile itself.** Build 2 failed on argument parsing,
  before xcodebuild compiled a single file.

**Impact:**
- **Users:** none.
- **Web app:** untouched.
- **Build/Release:** iOS CI only; Android unaffected.

**Follow-up for the signing work:** `xcodebuild archive` *does* require
`-scheme`, so a shared `App.xcscheme` will have to be committed before a real
`.ipa` can be produced. Deferred until the Apple Developer account exists.

---

### Update 14: iOS step 7 complete — the cloud build is green and the artifact verified

**Date:** 2026-10-13
**Type:** Documentation
**Scope:** Docs only — records the first successful iOS build. No build file changed.
**Files Modified:**
- `CLAUDE.md`
- `mobile-updates.md`

**Summary:**
The fourth cloud build, on commit `7541948`, compiled the iOS project and
published `Peckers-simulator.zip`. Step 7 of the iOS plan — a cloud build for
iPhone on a machine we do not own — is done, with no Apple Developer account
spent on proving it.

**Changes:**
1. `CLAUDE.md` iOS track updated from "half done" to done, with the follow-up
   that `xcodebuild archive` requires a shared scheme the template lacks.

**Rationale:**
The whole point of ordering it this way was to reach a known-good project before
spending $99/yr. That is now the case, so the account is bought against evidence
rather than hope.

**Testing — the downloaded artifact was unpacked and inspected:**
- `CFBundleIdentifier`: ✓ `uk.co.peckers.app`, identical to the Android package
- `CFBundleDisplayName`: ✓ `Peckers`
- `NSLocationWhenInUseUsageDescription`: ✓ present — the string whose absence
  crashes a WKWebView geolocation request, and with it the clock-in
- `UISupportedInterfaceOrientations`: ✓ `[Portrait]` only
- `capacitor.config.json` inside the bundle: ✓ `server.url` is the production
  Vercel deployment, `PushNotificationsPlugin` in `packageClassList`
- `MinimumOSVersion` 15.0; `DTSDKName` `iphonesimulator26.5`
- **Not tested, and not testable yet:** the app has never been RUN. A simulator
  build executes only on an iOS Simulator under macOS — not on Windows and not
  on an iPhone. Nothing about the WebView loading, the session, the geofence or
  push on iOS is verified by this; only that the project compiles and is
  configured as intended.

**Build history for the record:**
| Build | Commit | Outcome |
| --- | --- | --- |
| 1 | `12f5a60` | failed — Capacitor CLI requires Node >= 22 (Update 12) |
| 2 | `a222ba8` | failed — `-derivedDataPath` needs `-scheme` (Update 13) |
| 3 | `7541948` | ✅ green, `Peckers-simulator.zip` published |

**Impact:**
- **Users:** none. No iOS device runs this yet.
- **Web app:** untouched throughout the iOS track so far.
- **Build/Release:** iOS builds are now reproducible from a push plus one click.
  Android is unaffected.

---

### Update 15: Production release 1.0.1 (versionCode 3), replacing the mobile-ui preview APK

**Date:** 2026-10-19
**Type:** Release
**Scope:** Android release build. No shell behaviour changed.
**Files Modified:**
- `android/app/build.gradle`
- `mobile-updates.md`

**Summary:**
The APK on the owner's phone was `peckers-release-1.0.0-mobile-ui-preview.apk`
(16 Oct), whose baked-in `server.url` was the `feat/mobile-native-ui` Vercel
preview. That branch is now merged into the web repo's `main`, so a production
build was cut to point the installed app at the live site, where the new
Loyalty Customers dashboard is.

**Changes:**
1. `versionCode` 2 → 3 and `versionName` "1.0.0" → "1.0.1", so it installs as
   an update over the versionCode 2 preview build.
2. `npm run env:prod` → `server.url` `https://peckers-cashflow-pearl.vercel.app`
   synced into `android/app/src/main/assets`.
3. `gradlew assembleRelease`, staged as
   `C:\NextJs\pms-apk\peckers-release-1.0.1-production.apk`.

**Rationale:**
`server.url` is fixed at build time, so merging the web branch could never move
an APK built against its preview. Once on production, web changes reach the app
on every push to `main` with no rebuild.

**Testing:**
- `gradlew assembleRelease`: ✓ BUILD SUCCESSFUL in 52s
- `assets/capacitor.config.json` in the APK: ✓ `server.url` is the production URL
- `aapt2 dump badging`: ✓ `uk.co.peckers.app`, versionCode 3, versionName 1.0.1
- `apksigner verify`: ✓ same signing certificate (SHA-256 `62f396e5…dd54`) as the
  installed 1.0.0 mobile-ui-preview build, so it updates in place
- **Not tested here:** installing on the phone and loading the dashboard.

**Impact:**
- **Users:** the app loads production; the Vercel toolbar disappears.
- **Web app:** untouched.
- **Build/Release:** the next build that leaves this machine needs versionCode 4.

---

### Update 16: iOS push wired to FCM, aps entitlement, and the PeckersApp marker on iOS

**Date:** 2026-10-20
**Type:** Feature
**Scope:** iOS shell (push registration, entitlements, user agent) and the Codemagic build.
Companion to the web repo's Update 266 (`apns` block in `lib/fcm.ts`, iOS-aware copy).
**Files Modified:**
- `ios/App/App/AppDelegate.swift`
- `ios/App/App/App.entitlements` (new)
- `ios/App/App/Info.plist`
- `ios/App/App.xcodeproj/project.pbxproj`
- `capacitor.config.json`, `config/capacitor.config.{lan,preview,prod}.json`
- `codemagic.yaml`
- `mobile-updates.md`

**Summary:**
Before this, push on iPhone could not work at all: the AppDelegate never forwarded the APNs
token to Capacitor, so `register()` timed out after 15s, and even if it had, the token would
have been a raw APNs token that the server's FCM sender rejects as invalid (and then prunes
as dead). The shell now hands the APNs token to Firebase Messaging and gives the page an FCM
token, the same kind Android produces, so the existing server path needs only an `apns` block.

**Changes:**
1. `AppDelegate.swift`: `FirebaseApp.configure()` at launch **only if**
   `GoogleService-Info.plist` is in the bundle (configuring without it crashes).
   `didRegisterForRemoteNotificationsWithDeviceToken` sets `Messaging.apnsToken`, fetches the
   FCM token and posts it as `.capacitorDidRegisterForRemoteNotifications` (the plugin accepts
   a String token). Failures — including "Firebase not configured in this build" — post
   `.capacitorDidFailToRegisterForRemoteNotifications`, so the page gets a clear
   `registrationError` instead of a 15s timeout. The empty template lifecycle stubs were removed.
2. `Info.plist`: `FirebaseAppDelegateProxyEnabled = false`. The token is forwarded explicitly,
   and swizzling would otherwise compete with Capacitor's notification delegate.
3. Xcode project: Swift package `firebase-ios-sdk` (up to next major from 12.0.0), product
   `FirebaseMessaging` linked into the App target. Added to the `.xcodeproj` directly, NOT to
   `CapApp-SPM/Package.swift`, which `cap sync` regenerates.
4. `App.entitlements` with `aps-environment = development`, set as `CODE_SIGN_ENTITLEMENTS` for
   Debug and Release. Ad hoc / TestFlight export re-signs it as `production`.
5. New run-script build phase "Copy GoogleService-Info.plist": copies the gitignored plist into
   the bundle when present and prints a warning otherwise, so a build without it still compiles.
6. `ios.appendUserAgent: "PeckersApp/1"` added to the root config and all three `config/` files
   (it was under `android` only, so the web app could not tell it was in the iOS app — the
   `in-app` class, export-button hiding and app-specific messages were all browser-mode).
7. `codemagic.yaml`: imports the env group `firebase` and writes
   `GOOGLE_SERVICE_INFO_PLIST` (base64) to `ios/App/App/GoogleService-Info.plist`, validated
   with `plutil -lint`. Unset → the build continues without push.

**Rationale:**
Shift reminders are the one feature that must survive the move from browser to app (see
"Web Push does NOT work in an Android WebView"; the same holds for WKWebView). Using FCM on
iOS keeps one server sender, one token table and one prune rule for both platforms.

**Testing:**
- `project.pbxproj`: balanced braces/parens; each new object id defined once and referenced
  where expected. `Info.plist` / `App.entitlements` well-formed.
- All four config files parse as JSON and carry `ios.appendUserAgent`.
- **NOT tested:** the Swift compiles or the package resolves — there is no Mac here. The next
  Codemagic run is the check. No device test is possible before the Apple Developer account.

**Impact:**
- **Users:** none yet — no iPhone has the app.
- **Build/Release:** **Before the next Codemagic build**, create the env group `firebase` in
  Codemagic (an imported group that doesn't exist can stop the build). To make push work:
  (a) add an iOS app `uk.co.peckers.app` to the existing Firebase project and download
  `GoogleService-Info.plist`; (b) store it base64-encoded as `GOOGLE_SERVICE_INFO_PLIST`
  (secure) in that group; (c) after the Apple account is active, create an APNs Auth Key
  (.p8) and upload it under Firebase › Project settings › Cloud Messaging › Apple app
  configuration; (d) enable Push Notifications on the App ID. SPM resolution of Firebase
  adds a few minutes to each cloud build.
- **Android:** unaffected — no Android file changed, and the `android` config block is identical.

---

### Update 17: iOS ready for a signed build — iPhone-only, upload flags, shared scheme, signed workflows, status bar

**Date:** 2026-10-20
**Type:** Feature
**Scope:** iOS project settings, Codemagic, status bar. Companion to the web repo's Update 267.
Branch `feat/ios-app` — not on `main`.
**Files Modified:**
- `ios/App/App/Info.plist`
- `ios/App/App/PrivacyInfo.xcprivacy` (new)
- `ios/App/App/PeckersBridgeViewController.swift` (new)
- `ios/App/App/SceneDelegate.swift`
- `ios/App/App.xcodeproj/project.pbxproj`
- `ios/App/App.xcodeproj/xcshareddata/xcschemes/App.xcscheme` (new)
- `codemagic.yaml`
- `mobile-updates.md`

**Summary:**
Clears the things that would have stopped the first signed build or App Store Connect upload,
and adds the two signed Codemagic workflows. Also makes the status bar text follow the
page's light/dark theme, so the clock and battery are never invisible.

**Changes:**
1. `TARGETED_DEVICE_FAMILY` `"1,2"` → `1` (iPhone only), and the `~ipad` orientation list
   removed. A portrait-only iPad app is refused at upload unless it supports every orientation.
2. `UIRequiredDeviceCapabilities` `armv7` → `arm64`.
3. `ITSAppUsesNonExemptEncryption = false` — the app only uses HTTPS, which is exempt, so
   TestFlight builds no longer stop on the export-compliance question.
4. `PrivacyInfo.xcprivacy` added to Resources: no tracking; collects precise location and a
   device ID (the push token), both linked to the user, for app functionality only. No
   required-reason APIs in our own code (Capacitor and Firebase ship their own manifests).
5. Shared scheme `App.xcscheme` committed — `xcodebuild archive` and `xcode-project build-ipa`
   need `-scheme`, which the Capacitor template did not ship.
6. `codemagic.yaml` restructured with YAML anchors (the simulator workflow behaves exactly as
   before) and two new manually-started workflows: `ios-testflight` (App Store signing,
   uploads to TestFlight) and `ios-adhoc` (ad hoc signing, `.ipa` artifact for registered
   UDIDs). Both set `CFBundleVersion` to Codemagic's `BUILD_NUMBER` so every upload is newer.
7. `PeckersBridgeViewController` (subclass of `CAPBridgeViewController`, now the scene's root)
   registers a `peckersTheme` script message handler; `"dark"` → light status bar text,
   `"light"` → dark text. Held through a weak proxy so the web view does not retain its
   controller. Until the page reports, Capacitor's default (follow the phone) applies.

**Rationale:**
Steps 8 and 9 of the iOS plan start the moment the Apple account is approved; everything
that can be prepared without it is now prepared, so the first signed build is a configuration
exercise rather than a debugging one.

**Testing:**
- `project.pbxproj`: balanced; every new object id defined once and referenced where
  expected; `TARGETED_DEVICE_FAMILY = 1` in both configurations.
- `Info.plist`, `PrivacyInfo.xcprivacy`: balanced and well-formed.
- `codemagic.yaml` parsed with js-yaml: three workflows, anchors resolve to the expected steps.
- Web side: the theme messages fire on toggle (web Update 267).
- **NOT tested:** Swift compile, package resolution and signing — needs the next Codemagic
  run (simulator) and the Apple account (signed workflows).

**Impact:**
- **Users:** none yet.
- **Build/Release:** one-time Codemagic setup before a signed run: env group `firebase`
  (Update 16), an App Store Connect API key integration named exactly **`Peckers ASC`**, the
  distribution certificate and the App Store / ad hoc profile under Code signing identities,
  and the app record for `uk.co.peckers.app` in App Store Connect (TestFlight route).
- **Android:** unaffected — no Android file changed.

---

### Update 18: Firebase moved to the Peckers account; release 1.0.2 (versionCode 4)

**Date:** 2026-10-21
**Type:** Release
**Scope:** Android release build. Firebase project replaced. No shell code changed.
Branch `feat/ios-app`.
**Files Modified:**
- `android/app/build.gradle`
- `android/app/google-services.json` (gitignored — replaced by the owner, not committed)
- `mobile-updates.md`

**Summary:**
The Firebase project behind push (`pms-pp`) had been created under a personal Google
account. Since no staff had the app yet, it was replaced with a new project owned by the
Peckers account, **`pms-app-8e58b`** (sender ID `1017846986384`), with the Android app and the
iOS app `uk.co.peckers.app` both registered in it. This build is the first to carry it.

**Changes:**
1. Owner replaced `android/app/google-services.json` with the new project's file.
2. Owner replaced `FIREBASE_SERVICE_ACCOUNT` in Vercel (Production and Preview) with the
   new project's service-account key, base64-encoded, and redeployed production.
3. `versionCode` 3 → 4, `versionName` "1.0.1" → "1.0.2".
4. `npm run env:prod` → `server.url` `https://peckers-cashflow-pearl.vercel.app`, synced.
5. `gradlew assembleRelease`, staged as `C:\NextJs\pms-apk\pms-android-v1.0.2.apk`
   (SHA-256 `8d4d94de…8b70`).

**Rationale:**
The business, not one person's mailbox, has to own the credential that every shift
reminder depends on. Replacing it before any staff install meant no device token had to be
migrated.

**Testing:**
- Pre-build health check of the deployment this APK loads: `next build` ✓ (58 pages);
  `https://peckers-cashflow-pearl.vercel.app` and `…-peckerschicken.vercel.app` serve the same
  build; `/`, all four portal logins, `/manifest.webmanifest` and `/sw.js` ✓ 200.
- `gradlew assembleRelease`: ✓ BUILD SUCCESSFUL, `processReleaseGoogleServices` ran.
- `aapt2 dump badging`: ✓ `uk.co.peckers.app`, versionCode 4, versionName 1.0.2.
- `aapt2 dump resources`: ✓ `project_id` `pms-app-8e58b`, `gcm_defaultSenderId` `1017846986384`.
- `apksigner verify`: ✓ certificate SHA-256 `62f396e5…dd54`, same as every earlier release.
- APK `assets/capacitor.config.json`: ✓ production `server.url`.
- **NOT tested here:** install, sign-in, clock-in or a delivered reminder on a phone.

**Impact:**
- **Users:** none yet — the owner reinstalls on the test phone.
- **Build/Release:** any phone token registered under `pms-pp` is now useless. FCM answers
  it with `messaging/mismatched-credential`, which `lib/fcm.ts` does not treat as dead, so such
  a row would never be pruned — clear old app rows from `push_subscriptions` /
  `manager_push_subscriptions` if any remain. The next build that leaves this machine needs
  versionCode 5. The old `pms-pp` project can be deleted once a reminder arrives through the
  new one.

---

### Update 19: iOS native behaviour: swipe-back, offline screen, resume version check

**Date:** 2026-10-22
**Type:** Feature
**Scope:** iOS shell only. Ports Update 6's Android behaviour to the iPhone app.
Branch `feat/ios-app`.
**Files Modified:**
- `ios/App/App/PeckersBridgeViewController.swift`
- `ios/App/App/OfflineGate.swift` (new)
- `ios/App/App/BuildFingerprint.swift` (new)
- `ios/App/App.xcodeproj/project.pbxproj`
- `mobile-updates.md`

**Summary:**
The iPhone app had none of the native behaviour Android got in Update 6. A screen with no
in-page back link was a dead end, a lost network showed a blank page, and a phone left
in the background kept running an old deployment. All three now match Android. They are
native Swift in the shell, and the web app is unchanged.

**Changes:**
1. **Swipe-back.** `allowsBackForwardNavigationGestures = true` on the web view. iPhones have
   no back button. WKWebView walks pushState history, so Next.js client-side navigation is
   covered. As on Android, no route names are hardcoded. The gesture is switched off while the
   offline screen is up, as Android blocks back there.
2. **Offline screen.** New `OfflineGate` lays a native view over the web view. It uses the same
   copy and fixed dark colours as Android's `offline_overlay.xml` and has a "Try again" button
   that reloads `server.url`. It is not Capacitor's `server.errorPath`, because a local error
   page would reload only itself. An `NWPathMonitor` retries automatically when the network
   comes back. "Still no connection" shows if Try again is pressed while still offline. The
   status bar turns light while the screen is up and goes back to the page's theme when it
   hides.
3. **Detecting a failed load.** `CAPBridgeViewController.loadView` is `final`, so Capacitor's
   `WebViewDelegationHandler` cannot be replaced by a subclass. A small `NavigationObserver`
   becomes the web view's navigation delegate. It forwards every call to Capacitor's handler
   (`responds(to:)` + `forwardingTarget(for:)`). Its three own methods (`didFinish`,
   `didFail`, `didFailProvisionalNavigation`) call through to Capacitor first. Only
   `NSURLErrorDomain` failures other than `NSURLErrorCancelled` show the screen. A tap that
   interrupts a load, and a link Capacitor sends to Safari (`WebKitErrorDomain`), are not
   network failures.
4. **Resume version check.** New `BuildFingerprint`, the same rule as `BuildFingerprint.java`.
   It hashes (SHA-256) every `/_next/static/...` path in the HTML served at `server.url`,
   records the hash after each page load (UserDefaults), and compares it on resume. Same
   thresholds as Android: under 60s away does nothing, 60s to 12h reloads only on a confirmed
   difference, and over 12h always reloads. Driven by `UIScene` background/foreground
   notifications. An unreachable server, or a page with no Next.js assets, leaves the web
   view alone.
5. Both new files are registered in the App target's Sources phase (`F1EB000A`–`F1EB000D`).

**Not ported, on purpose:**
- **Exit confirmation.** iOS apps do not quit themselves, and there is no back button to
  trigger it.
- **Cookie flush on pause.** WKWebView has no flush API. It writes persistent cookies from
  its own process, which an app kill does not take down. To check on a device: sign in, kill
  the app at once, and reopen it.

**Rationale:**
The same staff use both platforms. On iOS, a dead-end screen or a blank page during a signal
drop at the store would make the app look broken. That would hurt most at clock-in, the one
thing staff open it for.

**Testing:**
- `project.pbxproj`: braces and parentheses balanced, and each new id appears exactly twice
  (definition and reference). Capacitor 8.5's iOS source was read to confirm the APIs used
  are public: `capacitorDidLoad`, `webView`, `bridge.config.appStartServerURL`,
  `setStatusBarStyle`, and the delegate being assigned only in `prepareWebView`.
- **NOT tested: the Swift has not been compiled.** This machine has no Swift toolchain. The
  next `ios-simulator` Codemagic run is the compile check. It also checks Updates 16 and 17,
  which have not been compiled either.
- **NOT tested on a device or simulator:** the swipe gesture, the offline screen
  (aeroplane mode, then turn it off), and a reload after a deployment.

**Impact:**
- **Users:** none yet. No iPhone has the app.
- **Web app:** nothing in `C:\NextJs\peckers-cashflow` was touched.
- **Build/Release:** two more Swift files in the App target. No new package; `Network` and
  `CryptoKit` are system frameworks on iOS 15. Android is unaffected; no Android file changed.

---

### Update 20: iOS simulator build green with Updates 16, 17 and 19 compiled, Firebase config bundled

**Date:** 2026-10-22
**Type:** Documentation
**Scope:** Docs only. Records the first cloud build that compiles the push, status-bar
and native-behaviour Swift. No build file changed.
**Files Modified:**
- `mobile-updates.md`

**Summary:**
The owner added `GOOGLE_SERVICE_INFO_PLIST` to the Codemagic `firebase` group and ran
`ios-simulator` on the code merged in Update 19. It went green, and the downloaded
`Peckers-simulator.zip` was unpacked and inspected. The Swift from Updates 16, 17 and 19,
which had never been compiled, now compiles and links. Firebase is resolved through SPM and
its iOS config is in the bundle.

**Changes:**
1. None to the project. This entry records verification only.

**Rationale:**
Updates 16, 17 and 19 were all logged as "NOT tested: the Swift compiles". This closes that
gap before the Apple Developer account arrives, so the first signed build only has to deal
with signing.

**Testing (downloaded artifact, unpacked and inspected):**
- `Info.plist`: ✓ `uk.co.peckers.app`, display name `Peckers`, `UIDeviceFamily [1]`
  (iPhone only), portrait only, `arm64`, `ITSAppUsesNonExemptEncryption false`,
  `FirebaseAppDelegateProxyEnabled false`, location usage string present. MinimumOSVersion
  15.0, SDK `iphonesimulator26.5`, Xcode 26.6.
- `GoogleService-Info.plist` in the bundle: ✓ `BUNDLE_ID uk.co.peckers.app`,
  `PROJECT_ID pms-app-8e58b`, sender `1017846986384`, GCM enabled. The CI step and the
  "Copy GoogleService-Info.plist" build phase both work.
- Firebase SPM bundles present (Core, CoreInternal, Installations, Messaging); binary
  references `FIRMessaging`.
- `capacitor.config.json`: ✓ production `server.url`, `ios.appendUserAgent PeckersApp/1`,
  `PushNotificationsPlugin`.
- Binary (universal x86_64 + arm64 simulator) contains `PeckersBridgeViewController`,
  `OfflineGate`, `BuildFingerprint`, `NavigationObserver`, `peckersTheme`, the offline copy,
  the `/_next/static/` pattern, `setAllowsBackForwardNavigationGestures:`, `NWPathMonitor`,
  `UISceneDidEnterBackgroundNotification` and `appStartServerURL`.
- **NOT tested:** running the app. A simulator build runs only in the iOS Simulator on macOS.
  Swipe-back, the offline screen, the resume reload, the theme-matched status bar, the
  WKWebView location prompt and push delivery all wait for a signed build on an iPhone.

**Impact:**
- **Users:** none yet.
- **Web app:** nothing in `C:\NextJs\peckers-cashflow` was touched.
- **Build/Release:** what remains before an iPhone install is Apple-account setup only:
  App Store Connect app record, the `Peckers ASC` API key integration, Push Notifications on
  the App ID, and an APNs key uploaded to Firebase. Then `ios-testflight` or `ios-adhoc`.

---

### Update 21: iPhone camera and photo-library permission text for profile photos

**Date:** 2026-10-26
**Type:** Config
**Scope:** iOS project (`Info.plist`). Android needs no change.
**Files Modified:**
- `ios/App/App/Info.plist`

**Summary:**
The web app now lets staff add an optional profile photo inside the app (peckers-cashflow
Update 268), through an ordinary `<input type="file" accept="image/*">`. On iOS, WKWebView
offers "Take Photo" for that input, and iOS terminates an app that opens the camera without
an `NSCameraUsageDescription`. The two usage strings are added so the picker works.

**Changes:**
1. Added `NSCameraUsageDescription`: "Peckers uses the camera only when you choose to take a
   profile photo."
2. Added `NSPhotoLibraryUsageDescription`: "Peckers opens your photos only when you choose one
   for your profile photo."

**Rationale:**
A missing camera usage string is a crash on first tap, not a soft failure. Android needs
nothing: Capacitor's `BridgeWebChromeClient` serves the file chooser, and because the manifest
does not declare `CAMERA`, the camera opens through `ACTION_IMAGE_CAPTURE` with no runtime
permission, using the existing `${applicationId}.fileprovider` (`file_paths.xml` already
covers `external-path` and `cache-path`).

**Testing:**
- Plist edited by hand; keys sit in alphabetical order beside the location string.
- **NOT tested:** an iOS build or a device. Needs the next `ios-simulator` / signed build.
- **NOT tested on Android hardware yet:** the camera and gallery pickers inside the APK.

**Impact:**
- **Users:** iPhone staff can take or choose a profile photo without the app closing.
- **Web app:** the feature itself lives in `peckers-cashflow` (Update 268); nothing else there
  depends on this.
- **Build/Release:** iOS needs a rebuild for the strings to ship. The Android APK is unchanged
  and needs no rebuild — it loads the web app remotely.
