# Claude Code Instructions for pms-mobile

Mandatory rules for ALL work in this repository. They apply automatically and
do not need to be restated.

---

## What this folder is

`pms-mobile` is a **Capacitor native shell for Android and nothing else.**

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
| 3 | Vercel preview + production `server.url` environments, build variants | ⬜ |
| 4 | Release keystore, signed release build, APK distribution to staff | ⬜ |
| 5 | Native push: FCM in the shell + token registration from the web app | ⬜ |
| 6 | Server-side native push sending — shift reminders reach app users | ⬜ |
| 7 | Native polish: status bar, splash timing, back button, geolocation permission prompts | ⬜ |
| 8 | Device testing across the real staff phone estate | ⬜ |
| 9 | Staff rollout | ⬜ |

**We are on Task 2.** Update this table whenever a task completes.

---

## Conventions — do not change these

| Setting | Value | Why it is fixed |
| --- | --- | --- |
| `appId` | `uk.co.peckers.app` | **PERMANENT.** Android identifies an installed app by its package name. Change it and every staff phone must uninstall and reinstall — losing the signed-in session — and the old app can never be updated again. Not negotiable once one device has it. |
| `appName` | `Peckers` | Shown under the launcher icon |
| Theme colour | `#0f0f0f` | Matches `viewport.themeColor` in the web app's `app/layout.tsx` and `theme_color` in `public/manifest.webmanifest`. Any other value shows as a visible seam between the native chrome and the page. |
| Orientation | **Portrait only** | Locked in `AndroidManifest.xml`. The web app's mobile layouts are built for portrait; the manifest already declares `"orientation": "portrait"`. |
| `webDir` | `www` | Must exist or `cap sync` fails, even though remote mode ignores its contents |

---

## The three `server.url` environments

Only one is active at a time, in `capacitor.config.json`. Changing it requires
`npx cap sync android` and a rebuild.

| Environment | `server.url` | Extra config | Use |
| --- | --- | --- | --- |
| **LAN dev** | `http://192.168.31.177:3000` | `cleartext: true` | `npm run dev` on this machine, phone on the same Wi-Fi. Current setting. |
| **Branch preview** | `https://<branch>-<project>.vercel.app` | none | Testing a web branch on a real device off the LAN |
| **Production** | the production Vercel domain | none | What staff install |

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
   and reinstall. Back it up, with its passwords, somewhere outside this repo
   and outside this machine, before Task 4 generates it.

2. **NO `.github/workflows` in this repo. Ever.**
   The web repo runs cron jobs against the production database — the nightly
   auto clock-out sweep (`app/api/cron/auto-clock-out`) and shift reminders
   (`app/api/cron/shift-reminders`). A workflow here pointed at the same
   endpoints would **double-fire against the same data**: duplicate reminders to
   staff, and a sweep racing itself over open clock rows. CI for this repo, if
   it is ever wanted, is a build-only job that touches no endpoint — and it is
   not wanted yet.

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
4. After editing `capacitor.config.json` or anything under `android/`, run
   `npx cap sync android`.
5. Log the change in `mobile-updates.md`. **Do not wait to be reminded** — it is
   automatic and mandatory.

---

## Toolchain prerequisites (not yet installed as of Update 1)

Scaffolding this repo needs only Node. **Building an APK additionally needs:**

- **JDK 21** — this machine has only JDK 8 (`C:\Program Files\Java\jdk1.8.0_172`),
  which Capacitor's Gradle plugin rejects.
- **Android SDK** + platform tools (`adb`), normally via Android Studio.

Install both before attempting `gradlew assembleDebug` or `npx cap run android`.
