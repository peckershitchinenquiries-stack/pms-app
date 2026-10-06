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
