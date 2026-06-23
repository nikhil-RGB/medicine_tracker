# Medicine Reminders

A fully offline Flutter app for tracking medications by health condition: pick the conditions you have, add the medicines prescribed for each, set how and when to take them, get reminded when a dose is due, confirm doses in‑app, and review your adherence on a calendar.

---

## ⚗️ About this project — an experiment in autonomous agentic generation

**This entire project was designed and written end‑to‑end by an AI coding agent (Claude) running in self‑supervised agentic loops.** A human supplied only the high‑level idea and answered a handful of product decisions; the agent did everything else — requirements clarification, architecture, all source code, the bundled medical reference dataset, unit tests, the Android build configuration, and iterating through build failures to a working release APK.

The point of the project is **not** the app itself but to **evaluate the code quality, architecture, and structure that a self‑supervised agentic run can produce** with minimal human steering. A few things worth noting about how it was built:

- **Design by multi‑agent deliberation.** The architecture was chosen by a workflow that generated four independent design proposals from different lenses (persistence/domain, navigation, scheduling, pragmatic MVP), scored them with three adversarial judges, and synthesised a single plan. The "compute‑on‑the‑fly" data model below was the consensus winner.
- **Data by research fan‑out.** The reference catalog (251 conditions → 1,112 medicines) was produced by ~15 parallel web‑research agents, one per medical category, then deterministically de‑duplicated and sharded into assets.
- **Self‑verification.** The agent kept the codebase at `flutter analyze` → *no issues* and wrote a unit‑test suite for the correctness‑critical dose engine, all green.

> ⚠️ **Not a medical device.** The condition/medicine lists are reference information (**names only — no dosages or instructions**) and are **not medical advice**. They may be incomplete or contain errors. Always follow your doctor or pharmacist.

---

## Features

### Conditions & medicines
- **Built‑in reference catalog** — 14 categories, **251 health conditions**, **1,112 medicines** (generic names + common brand aliases), bundled and fully offline.
- **Searchable pickers** — fuzzy search conditions and medicines by name/alias.
- **Typical‑for‑condition suggestions** — when you pick a catalog condition, its commonly‑associated medicines surface first.
- **Add anything custom** — every picker offers an inline *"Add '<query>' as custom"* option, so a gap in the catalog never dead‑ends you. Custom entries persist and reappear in future pickers.
- **Grouping by condition** — medicines are organised under the ailment they treat, with a consistent colour chip per condition.

### Scheduling
- **Three course types**
  - **Fixed** — take for *N* days, with a defined end.
  - **Ongoing** — indefinite/chronic, no end date; reminders run until you stop it.
  - **As‑needed (PRN)** — no schedule and no reminders; logged manually when taken.
- **Exact per‑dose times** — set the frequency per day and an exact clock time for each daily dose.
- **Editable** — change times, duration, or course type at any point; past history is preserved.

### Reminders
- **Local notifications** when a dose is due ("Time for your *X* dose"), scheduled on a **rolling 14‑day horizon** capped at 56 pending (safely under iOS's ~64 limit) and refreshed on launch/resume/edit.
- **Exact alarms** on Android 12+, with graceful fallback to inexact if the permission is denied.
- **Confirmation is in‑app** — the notification only alerts; you open the app to confirm, so the dose log can never be corrupted by a background process.

### Tracking & history
- **Per‑dose states**: pending, taken, skipped, and **overdue** — a passed dose stays actionable and shows as overdue until you mark it Taken or Skipped (nothing is auto‑missed or auto‑deleted).
- **Backfill any day** — confirm or skip a past dose from the calendar.
- **PRN logging** — log an as‑needed dose from the Today screen.
- **Undo** — reverse a Taken/Skipped mark.
- **Adherence stats** — taken‑vs‑remaining progress for fixed courses, a rolling **30‑day** rate for ongoing meds, and take counts for PRN.
- **Stop / archive** — stop an ongoing medicine (history kept) or archive a condition.

### Calendar
- **Month view** with per‑day status dots (overdue / upcoming / all‑done).
- **Day detail** — every dose that day, which condition it's for, the time, and its status.

### Safety & onboarding
- **Onboarding** intro and a **mandatory medical disclaimer** that must be scrolled and accepted before use.
- Re‑viewable disclaimer in Settings.

### Privacy
- **100% offline, on‑device.** No accounts, no backend, no network calls. Your data never leaves the phone.

---

## Data persistence

Local storage only, on the phone's **file system as plain JSON** — deliberately **no embedded database** (no SQLite/Hive/Isar). There are two stores:

### 1. Bundled reference catalog (read‑only)
Shipped inside the app under `assets/reference/`, never written to, and loaded lazily to bound memory:

| File | Contents |
| --- | --- |
| `index.json` | Manifest: schema version, disclaimer, category list, and the condition **search index** (name + aliases). Loaded eagerly on first use. |
| `conditions_<category>.json` | Per‑category map of condition → typical drug ids. Loaded lazily. |
| `drugs_<category>.json` | Per‑category drug names + aliases. Loaded lazily, only for opened/matched categories. |

### 2. Your data (mutable, in the app documents directory)
Under `…/medreminders/`, written via `path_provider`:

| File | Role | Written when |
| --- | --- | --- |
| `app_data.json` | **Cold** data: conditions + medicines + their embedded schedule rules. | Only when you add/edit a condition or medicine. |
| `intake_log.json` | **Hot** data: a *sparse* log — one row per dose you actually Took/Skipped/PRN‑logged. | On each dose action. |
| `custom_catalog.json` | Names of custom conditions/medicines you added. | When you add a custom entry. |
| `*.bak` | Last‑good backup of each file, for corrupt‑file recovery. | After each successful load. |
| `.tmp_*` | Transient temp files for atomic writes. | During writes. |
| *(SharedPreferences)* | Tiny flags only: onboarding done, disclaimer version, last‑reconcile time. **Never** domain data. | — |

### The core idea: compute doses, don't store them
The app **never materialises a record per scheduled dose.** It stores only the **schedule rule** per medicine plus the **sparse event log**. Everything you see — Today's list, the calendar, overdue badges, "8 of 14 taken" — is **computed at render time** by expanding each medicine's rule over the visible date window and left‑joining the intake log.

- **Join key**: a deterministic occurrence id `occ|<medicineId>|<yyyy‑MM‑dd>|<slotIndex>` — keyed on **calendar date + which dose‑of‑the‑day**, *not* the clock time, so editing a dose's time never orphans a previously‑logged event. PRN events use a separate `prn|<medicineId>|<uuid>` namespace.
- **Overdue is derived**, never stored: it's simply *a past scheduled time with no matching event*, recomputed against the current clock (which ticks on app resume).
- **Why this matters**: ongoing/indefinite medicines cost *nothing* on disk (a rule is infinite at O(1) storage), missed doses can never be silently dropped, and any past or future day can be enumerated for backfill.

### Crash safety
Every write is **atomic** (write to a temp file, then `rename` over the target), **serialised per file** by an async mutex, and **write‑through** (no debounce) on the dose‑confirmation path, so a kill right after confirming never loses it. A corrupt file is recovered from its `.bak`.

---

## Screens

| Screen | Purpose |
| --- | --- |
| **Boot gate** | Splash that initialises timezone/notifications, loads data, reconciles reminders, then routes to onboarding, the disclaimer, or the app. |
| **Onboarding** | First‑run intro slides. |
| **Disclaimer** | Mandatory, scroll‑to‑accept medical disclaimer. |
| **Tab shell** | Persistent bottom navigation: Today · Calendar · Conditions · Settings. |
| **Today** | Default landing + primary confirm surface: today's doses plus the overdue tail, grouped Overdue / Upcoming / Done; PRN quick‑log. |
| **Dose confirmation sheet** | Modal to mark a dose Taken / Skipped / Undo. |
| **Calendar** | Month grid with per‑day status dots. |
| **Day detail** | Every dose for a tapped day, with condition and status; supports backfill. |
| **Conditions** | The user's conditions with medicine counts; entry to add more. |
| **Condition picker** | Search the catalog or add a custom condition. |
| **Condition detail** | Medicines under a condition (active + stopped), with course‑type badges. |
| **Medicine picker** | Typical‑for‑condition list + full‑catalog search + add custom. |
| **Add / edit medicine** | Course type, start/duration, and an exact time per daily dose. |
| **Medicine detail** | Adherence stats, intake history, and Edit / Stop / Delete. |
| **Settings** | Notification permission, how reminders work, the disclaimer, and about. |

---

## Tech stack

Flutter 3.19.3 / Dart 3.3.1.

| Concern | Choice |
| --- | --- |
| State management | `flutter_riverpod` |
| Navigation | `go_router` (StatefulShellRoute tab shell) |
| Local notifications | `flutter_local_notifications` + `timezone` + `flutter_timezone` |
| Calendar UI | `table_calendar` |
| Storage | `path_provider` (JSON files) + `shared_preferences` (flags) |
| Utilities | `uuid`, `intl`, `collection` |

### Project structure

```
lib/
  main.dart, app.dart, router.dart   # entry, MaterialApp.router, routes
  core/        date + colour + schedule-summary helpers
  models/      UserCondition, PrescribedMedicine, ScheduleRule, IntakeEvent,
               DoseOccurrence (transient), reference models, enums
  data/        JsonStore (atomic IO), repositories, settings, reference catalog,
               AppServices bootstrap
  services/    DoseExpander (rule → occurrences), Adherence,
               NotificationService, NotificationScheduler (rolling horizon)
  state/       Riverpod providers (bootstrap, data notifier, clock, derived views)
  features/    boot · onboarding · shell · today · calendar · conditions ·
               medicines · settings
  widgets/     DoseTile, dose confirmation sheet
assets/reference/   bundled, sharded condition→medicine catalog
test/               dose-engine unit tests
```

---

## Getting started

```bash
flutter pub get
flutter run                 # on a connected device/emulator
# or build a release APK:
flutter build apk --release
```

The APK is written to `build/app/outputs/flutter-apk/app-release.apk`.

**Android build notes** (relevant to this toolchain — AGP 7.3.0):
- `minSdkVersion` is raised to **21** and multidex is enabled (required by core‑library desugaring, which `flutter_local_notifications` needs).
- `desugar_jdk_libs` is pinned to **1.2.2** — the 2.0.x line is incompatible with AGP 7.3.0's R8/D8.
- Release `lintVital` is disabled to avoid a D8 crash on this toolchain.
- The release build is currently **debug‑signed** (fine for testing/sideloading, not for the Play Store).

### Tests

```bash
flutter test
```

Unit tests cover the dose engine: fixed‑course expansion, overdue derivation, taken‑event joining, occurrence‑id stability across time edits, PRN exclusion, and stop‑date cutoff.

---

## Disclaimer

This software is provided for tracking and organisational purposes only. The bundled condition and medicine names are reference information, **not medical advice**, and contain **no dosing guidance**. The data may be incomplete or inaccurate. Do not use this app to make medical decisions; always consult a qualified healthcare professional.
