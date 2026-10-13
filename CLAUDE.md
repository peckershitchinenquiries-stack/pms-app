# Claude Code Instructions for pms-mobile

Mandatory rules for ALL work in this repository. They apply automatically and
do not need to be restated.

---

## What this folder is

`pms-mobile` is a **Capacitor native shell for Android and iOS, and nothing else.**

It contains **zero business logic**: no React components, no server actions, no
Supabase client, no SQL, no migrations, no pay or clock calculations. It is a
thin native wrapper whose only job is to open a WebView and point it at the
deployed Peckers web app.

If you ever find yourself about to write a clock-in rule, a pay calculation, a
query or a UI screen in this repo, **stop — it belongs in
`C:\NextJs\peckers-cashflow`.**

---

## How remote mode works

`capacitor.config.json` sets `server.url`. When that key is present, Capacitor
**ignores the bundled web assets entirely** and the WebView loads that URL over
the network at runtime, exactly as a browser would.

```
┌──────────────────────┐        HTTPS         ┌────────────────────────┐
│  APK (this repo)     │  ─────────────────►  │  Vercel: peckers web   │
│  • WebView           │                      │  Next.js 14, RSC,      │
│  • icon + splash     │  ◄─────────────────  │  server actions        │
│  • portrait lock     │      HTML/JS/RSC     └───────────┬────────────┘
│  • www/index.html    │                                  │
│    (offline page     │                                  ▼
│     only)            │                      ┌────────────────────────┐
└──────────────────────┘                      │  Supabase (ONE DB)     │
                                              └────────────────────────┘
```

**Why this guarantees the web UI cannot diverge:** there is no copy of the web
code to drift out of sync. The app renders whatever the server sends. Shipping a
fix to Vercel fixes it in the app the next time the WebView loads, with no APK
rebuild and no store review. Equally, this repo **cannot** break the web UI —
it has no files the web app reads.

The trade-off, which is deliberate: **no offline capability.** Without a
network the app shows `www/index.html` or a WebView error. Clocking in is a
geofenced, server-verified write, so it was never going to work offline anyway.

---

## The two repos and the exact boundary

| Repo | Role | Status |
| --- | --- | --- |
| `C:\NextJs\peckers-cashflow` | The whole product: Next.js 14 app, Supabase, server actions, migrations, cron jobs | **IN PRODUCTION, real users, live data** |
| `C:\NextJs\pms-mobile` | This repo. Android shell only | Pre-release, not yet on any staff device |

They are **separate git repos** with separate histories and separate changelogs.

### Which file goes where

Lives **here**, in `pms-mobile`:

- `capacitor.config.json` — `server.url`, `appId`, scheme settings
- `android/**` — the generated native project, `AndroidManifest.xml`,
  `colors.xml`, `styles.xml`, Gradle files
- `android/app/src/main/res/**` — launcher icons, splash drawables
- `www/index.html` — the offline fallback page (never business UI)
- `assets/` — the 1024×1024 icon/splash source images
- `ios/**` — the generated Xcode project, `Info.plist`, the SPM package
- `codemagic.yaml` — the cloud macOS build definition (we own no Mac)
- `mobile-updates.md` — this repo's changelog

Must go in **`peckers-cashflow`**, never here:

- Anything a user sees after login. Every screen, every button, every number.
- Push notification **sending** — the API route, the subscription table and its
  migration, the cron that fires shift reminders (Task 6)
- Any Supabase migration, including the FCM token table
- Any `navigator.userAgent` / Capacitor detection used to branch behaviour in
  the web UI (Task 5's native-push path)
- Environment variables and secrets

> A change needed in `peckers-cashflow` is a change to a **production app with
> live users.** Treat it as such: smallest possible diff, additive, gated so the
> browser path is untouched, and logged in `docs/updates-operations.md` under
> that repo's own numbering.

---

## The 9-task plan

| # | Task | State |
| --- | --- | --- |
| 1 | Decide the approach: Capacitor remote mode vs rewrite | ✅ done — remote mode chosen |
| 2 | **Scaffold this repo: Capacitor + Android, icons, splash, portrait, LAN dev server** | ✅ **done (Update 1)** |
| 3 | Vercel preview + production `server.url` environments, build variants | ✅ **done (Updates 3–5, 9)** — all three environments now live in `config/` behind `npm run env:lan|preview|prod`; Deployment Protection off |
| 4 | Release keystore, signed release build, APK distribution to staff | ✅ **done (Update 9)** — keystore generated and gitignored, Gradle signing wired, v2+v3 signed release verified. See `RELEASE.md`. A production release still waits on the web branch merging. |
| 5 | Native push: FCM in the shell + token registration from the web app | ✅ **done (Update 7 here, Update 251 in the web repo)** — Firebase project created, `google-services.json` in place, real token issued on a device |
| 6 | Server-side native push sending — shift reminders reach app users | ✅ **done (Update 8 here, Updates 252–253 in the web repo)** — `FIREBASE_SERVICE_ACCOUNT` set on the preview environment and a reminder confirmed on a device |
| 7 | Native polish: back button, offline screen, session durability, screen edges, reload-on-resume, status bar, splash timing, geolocation permission prompts | ✅ **mostly done (Updates 3 and 6)** — geolocation permissions, back button, offline retry screen, cookie flush, inset/keyboard verification and the resume version check are all in. Status bar styling and splash timing are untouched, and every Update 6 behaviour is still unverified on a device. |
| 8 | Device testing across the real staff phone estate | ⬜ — now carries the whole Update 6 acceptance list |
| 9 | Staff rollout | ⬜ |

**Open: Task 7 leftovers (status bar styling, splash timing,
`onRenderProcessGone`, the FCM notification channel and small icon), Task 8
device testing, and Task 9 rollout.** Task 9 additionally waits on
`feat/mobile-geolocation` reaching production — until it does, an APK built
with `npm run env:prod` gives staff no reminders at all. Update this table
whenever a task completes.

### The iOS track

Opened at Update 11, and numbered **separately again** — by the plan used in
conversation, where **step 7 is "cloud build setup for iPhone without a Mac"**,
step 8 is registering staff iPhones and making the install link, and step 9 is
iPhone testing and rollout. Steps 1–6 of that plan are the Android work above.

Step 7 is **done** (Update 14): `codemagic.yaml` builds the project unsigned for
the simulator on a cloud Mac mini M2, and the artifact was verified to carry the
right bundle id, portrait lock, location usage string and push plugin.
Everything past that — a real `.ipa`, TestFlight, push on iOS — needs the $99/yr
Apple Developer account, which is now justified by a project proven to compile.

`xcodebuild archive` requires `-scheme`, so a shared `App.xcscheme` must be
committed before an `.ipa` can be produced. The simulator build sidesteps it with
`-target`; the signing work cannot.

> **Two numberings are in play.** This table is the one every
> `mobile-updates.md` entry refers to — "Task 4" in the log always means
> keystore and signing. The working plan used in conversation numbers the
> native-behaviour work (Update 6) as its own "Task 4"; in this table that work
> is Task 7. When a log entry cites a task number, it is this table's.

---

## Conventions — do not change these

| Setting | Value | Why it is fixed |
| --- | --- | --- |
| `appId` | `uk.co.peckers.app` | **PERMANENT.** Android identifies an installed app by its package name. Change it and every staff phone must uninstall and reinstall — losing the signed-in session — and the old app can never be updated again. Not negotiable once one device has it. The same string is also the **iOS bundle identifier** and must be registered verbatim in App Store Connect. |
| `appName` | `Peckers` | Shown under the launcher icon |
| Theme colour | `#0f0f0f` | Matches `viewport.themeColor` in the web app's `app/layout.tsx` and `theme_color` in `public/manifest.webmanifest`. Any other value shows as a visible seam between the native chrome and the page. |
| Orientation | **Portrait only** | Locked in `AndroidManifest.xml` and in `UISupportedInterfaceOrientations` in `ios/App/App/Info.plist`. The web app's mobile layouts are built for portrait; the manifest already declares `"orientation": "portrait"`. |
| `webDir` | `www` | Must exist or `cap sync` fails, even though remote mode ignores its contents |

---

## The three `server.url` environments

Each one is a file in `config/`, selected by a script that copies it over
`capacitor.config.json` and runs `cap sync` — never hand-edit the root config,
because a forgotten sync ships the PREVIOUS environment inside the APK:

| Environment | Command | `server.url` | Extra config |
| --- | --- | --- | --- |
| **LAN dev** | `npm run env:lan` | `http://192.168.31.177:3000` | `cleartext: true`, `allowMixedContent: true` |
| **Branch preview** | `npm run env:preview` | the `feat/mobile-geolocation` preview. Current setting. | none |
| **Production** | `npm run env:prod` | `https://peckers-cashflow-peckerschicken.vercel.app` | none |

A rebuild is still required after switching.

`cleartext: true` exists **only** for LAN dev, because a dev server is plain
HTTP and Android blocks cleartext by default. **It must be off in the release
build** (Task 4).

The LAN IP is DHCP-assigned and **will change**. If the app shows a connection
error, re-check the machine's IP before debugging anything else:

```powershell
Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.PrefixOrigin -eq 'Dhcp' }
```

Next.js must also be listening on all interfaces, not just localhost:

```powershell
npm run dev -- -H 0.0.0.0
```

### ⚠ All three environments hit the SAME Supabase

There is no staging database. A clock-in from a dev build on the LAN writes a
**real `clock_events` row**, auto-creates a **real `rota_shifts` cell**, and is
picked up by the **real alert scan** — against live production data that feeds
the Tuesday payout.

So when testing on a device:

- Use a **test employee** and clean up afterwards, or accept that a manager will
  see it on the Live board and on Daily Approval.
- A test clock-in you leave open gets closed by the **nightly auto clock-out
  sweep** and becomes an approvable day.
- Never approve a test day. An approved day reaches the payout sheet.
- Geofence checks are real: the device must actually be at a store, and the
  position must be fresh (`MAX_FIX_AGE_MS`).
- The **early clock-in gate is strict** — before a booked start, clock-in is
  refused outright with no override. A test refusal is correct behaviour, not a
  shell bug.

---

## Hard rules

1. **The release keystore is NEVER committed and NEVER lost.**
   `*.keystore`, `*.jks` and `keystore.properties` are in `.gitignore` from the
   first commit. Android requires every update to be signed by the **same** key
   as the installed version. Lose the keystore and **no phone that has the app
   can ever receive an update** — every staff device needs a manual uninstall
   and reinstall. **It exists as of Update 9** —
   `android/peckers-release.jks` with `android/keystore.properties` beside it,
   both gitignored, and the password written nowhere else. Back BOTH up outside
   this repo and outside this machine; `RELEASE.md` section 1 has the detail
   and the certificate fingerprints to check a build against.

2. **NO `.github/workflows` in this repo. Ever.**
   The web repo runs cron jobs against the production database — the nightly
   auto clock-out sweep (`app/api/cron/auto-clock-out`) and shift reminders
   (`app/api/cron/shift-reminders`). A workflow here pointed at the same
   endpoints would **double-fire against the same data**: duplicate reminders to
   staff, and a sweep racing itself over open clock rows. CI for this repo is a build-only job that touches no endpoint.

   `codemagic.yaml` (Update 11) is exactly that, and it is **not** a GitHub
   workflow — it runs on Codemagic, compiles the iOS project and calls nothing.

3. **Every change is logged in `mobile-updates.md`**, immediately, using the
   template in that file. This repo has its **own numbering starting at
   Update 1**, completely independent of the web repo's shared 1→N sequence
   across `docs/updates.md` and `docs/updates-operations.md`. Never continue the
   web repo's numbers here, and never continue these numbers there.

4. **Do not modify `C:\NextJs\peckers-cashflow` from a task scoped to this
   repo.** When a task genuinely spans both (Tasks 5 and 6 do), make the two
   changes as two deliberate steps and log each in its own repo's changelog.

5. **Never copy a component, lib file, server action or migration into this
   repo.** A copy is a divergence waiting to happen, and it defeats the single
   reason remote mode was chosen.

---

## ⚠ Web Push does NOT work in an Android WebView

The web app's shift reminders use the **Web Push API** with a service worker
(`public/sw.js`, `push_subscriptions`). An Android System WebView does not
implement Web Push — there is no `PushManager` to subscribe with. The code does
not crash; subscription simply fails, silently.

**Consequence: a user on the APK gets NO shift reminders at all** — not even the
ones they were getting in Chrome, because installing the app is exactly the
moment they stop opening the site in a browser.

That is strictly worse than the PWA they have today, and reminders are the
feature staff rely on to show up for a shift.

> **DO NOT roll this APK out to staff until Tasks 5 and 6 are complete.**
> Task 5 adds FCM to the shell and registers the device token from the web app;
> Task 6 makes the server send to native tokens alongside Web Push. Until both
> ship, this build is for **our own devices only.**

---

## Before starting any task here

1. Read `mobile-updates.md` — most recently first.
2. Confirm which of the 9 tasks you are on, and which repo the change belongs
   in. If it is user-visible, it is not this repo.
3. Check which `server.url` is active; a device symptom is very often just the
   wrong environment or a stale LAN IP.
4. Switch environments with `npm run env:lan|preview|prod`, which syncs for
   you. After editing a `config/*.json` or anything under `android/`, run
   `npx cap sync android`.
5. Log the change in `mobile-updates.md`. **Do not wait to be reminded** — it is
   automatic and mandatory.

---

## Toolchain

Both prerequisites are installed as of Update 2:

- **JDK 21** at
  `C:\Users\landa\AppData\Local\Programs\Eclipse Adoptium\jdk-21.0.12.1+1`.
  Set `JAVA_HOME` to it per shell — JDK 8 is also on this machine
  (`C:\Program Files\Java\jdk1.8.0_172`) and Capacitor's Gradle plugin rejects it.
- **Android SDK** at `C:\Users\landa\AppData\Local\Android\Sdk`, with
  `build-tools/36.0.0` (`apksigner`, `aapt2`) and `platform-tools` (`adb`).

Building and distributing a signed release is documented in `RELEASE.md`.
