# Technical Brief
**Project:** Integrate *TrainingPeaks bulk‑export* + *near‑real‑time sync* into the **Peakbot** macOS app  
**Audience:** Windsurf developers (using GPT‑4.1 code‑generation)  
**Author:** Bob Kitchen  
**Date:** 27 Apr 2025  

---

## 1  Objectives & Scope

| # | Objective | Success metric |
|---|-----------|----------------|
| **O‑1** | Pull *official* TrainingPeaks (TP) workout files **and** TP‑computed metrics (TSS, IF, CTL, etc.) directly into Peakbot without manual download. | New workouts appear in the local database ≤ 5 min after TP has processed them. |
| **O‑2** | Provide both **nightly full‑sync** (02:00) and **morning near‑real‑time sync** (user‑selectable trigger). | <1 % duplicate rows; no missed workouts. |
| **O‑3** | Keep the entire solution *inside* the Swift app—no Python helpers, no Selenium binaries—so it ships through the Mac App Store if desired. | App passes App Review (hardened runtime, no private entitlements). |

*Out of scope:* computing metrics ourselves, building Garmin connectors, or de‑duping multi‑source feeds (handled separately).

---

## 2  Functional Requirements

1. **Initial login UI** – off‑screen WebKit view where the user enters TP credentials (supports MFA).  
2. **Cookie storage** – store TP session cookies securely in Keychain; refresh automatically.  
3. **Export request** – `POST https://app.trainingpeaks.com/ExportData/ExportUserData`.  
4. **ZIP download** – follow 302 redirect to CloudFront URL; stream to disk.  
5. **Unzip & ingest**  
   * Extract `StructuredWorkoutExport.csv`, `WorkoutSummaryExport.csv`, body‑metrics CSVs, and `/FitFiles/<date>/…/*.fit`.  
   * Parse summary CSV and insert/update Core Data entities (`Workout`, `DailyMetrics`).  
   * Move *.fit* files to an app‑private cache folder and store path refs.  
6. **Nightly BG sync** – `BGProcessingTask` scheduled at 02:00 local.  
7. **Morning triggers**  
   * **Toolbar “Sync Now”** button.  
   * **Auto‑poller** (05:00–12:00, default 5‑min interval). Poll stops once no new rows for two consecutive cycles.  
   * **File‑watcher** observing HealthFit/Garmin export folder; on change, run “Sync Today”.  
8. **Status UX** – small sync indicator (idle / syncing / error) + timestamp of last successful import.  
9. **Settings pane** – toggle triggers, set poll interval, re‑authenticate, manual “Backfill last N years”.  
10. **Logging & telemetry** – unified log subsystem; user‑opt‑in error telemetry.

---

## 3  Non‑Functional Requirements

| Category | Requirement |
|----------|-------------|
| **Security** | Keychain for cookies; HTTPS only; no credential plaintext. |
| **Performance** | Nightly sync < 3 min for 365‑day export; incremental sync < 10 s. |
| **Offline/Metered** | Detect via `NWPathMonitor`; skip auto‑poll on cellular. |
| **Resilience** | If TP changes parameters or adds CSRF tokens, log 4xx/5xx and surface “Re‑login required”. |
| **Entitlements** | `com.apple.developer.networking.background` (BG tasks); no private APIs. |

---

## 4  External Interface Specification

### 4.1  Authentication Flow

```
POST /Session       → 302 → /Dashboard
Cookie: ASP.NET_SessionId=…
```

*Use `WKWebView` once, then extract cookies from `HTTPCookieStorage.shared`.*

### 4.2  Export Endpoint

```
POST /ExportData/ExportUserData
Content-Type: application/x-www-form-urlencoded

startDate=YYYY-MM-DD&endDate=YYYY-MM-DD&exportOptions=7
```

`exportOptions` bitmask  
* 1 – Workout summary CSV  
* 2 – Body‑metrics CSV  
* 4 – Original FIT files  

Response → **302 Location:**  
`https://tp-cloudfront-exports.s3.amazonaws.com/{GUID}.zip`  
Download is unauthenticated (pre‑signed).

---

## 5  Architecture Overview

```
                     +----------- BGProcessingTask (02:00) -----------+
                     |                                               |
+––––––––––––––––––– v ––––––––––––––––+       +––––––––––––––––––+   |
|  TrainingPeaksExportService          |       | CookieVault      |   |
|  - build POST request                |       | (Keychain)       |   |
|  - follow 302 → download ZIP         |<––+   +––––––––––––––––––+   |
+––––––––––––––+–––––––––––––––––––––––+   |                         |
           | unzip & parse                | load/save cookies       |
+–––––––––– v ––––––––––+            +––– v –––––––+                |
| ZipIngestor           |            | AuthWebView |<–– re‑login –––+
|  - Extract CSV & FIT  |            +–––––––––––––+    on 401/err
|  - Core Data writes   |
+–––––––––––––––––––––––+
           |
    Core Data stack
           |
+–––––––––– v –––––––––+          +–––––––––––––––––+
| WorkoutListVM        |<––bind––| SyncIndicator    |
+––––––––––––––––––––––+          +–––––––––––––––––+

Triggers  
* Toolbar button  
* Combine timer (morning poller)  
* File‑system watcher  
```

---

## 6  Component Breakdown & File Plan

| File | Responsibility | Key APIs |
|------|----------------|----------|
| **CookieVault.swift** | Persist/refresh cookies; encrypt via Keychain. | Keychain, `HTTPCookie` |
| **TrainingPeaksExportService.swift** | High‑level `sync(from:to:)`; POST, redirect, download. | `URLSession` (background) |
| **ZipIngestor.swift** | Unzip via `ZIPFoundation`; parse CSV via `SwiftCSV`; Core Data writes. | `FileManager`, Core Data |
| **TPSyncBackgroundTask.swift** | Register/schedule BGProcessingTask; call ExportService nightly. | `BGTaskScheduler` |
| **TPToolbarSyncButton.swift** | Manual Sync UI. | SwiftUI / AppKit |
| **MorningPoller.swift** | Auto‑poll logic. | Combine `Timer` |
| **DropFolderWatcher.swift** | Watcher for FIT exports; debounce 60 s. | GCD |
| **SyncIndicatorView.swift** | UX state indicator. | SwiftUI/AppKit |
| **CoreDataModel.xcdatamodeld** | Entities `Workout`, `DailyMetrics`. | Core Data |

---

## 7  Data Model

### 7.1  Entities

| Entity | Attributes | Relationships |
|--------|------------|---------------|
| **Workout** | `id` (UUID), `tpId` (Int64), `sport` (String), `startTime` (Date), `duration` (Double sec), `tss` (Double), `intensityFactor` (Double), `normalizedPower` (Double), `fitPath` (String) | many‑to‑one `DailyMetrics` |
| **DailyMetrics** | `date` (Date, primary), `ctl` (Double), `atl` (Double), `tsb` (Double), `hrv` (Double?) | one‑to‑many `Workout` |

Unique constraint on `tpId`; `NSMergePolicy.overwrite` on conflict.

---

## 8  Workflow Algorithms

### 8.1  `sync(from:to:)`

1. Build form‑encoded POST body.  
2. Attach cookies from CookieVault to URLSession.  
3. `dataTask` → expect HTTP 302.  
4. Grab `Location` header → `zipURL`.  
5. `downloadTask(zipURL)` → `temp.zip`.  
6. `ZipIngestor.ingest(temp.zip, dateRange)`.  
7. If `rowsImported > 0` → `Notification(.TPDidSync)`.  
8. Else if HTTP 401 → `CookieVault.clear()`; launch AuthWebView.

### 8.2  Morning Poller Logic

```
poll() {
    let imported = await sync(today)
    if imported == 0 && lastImported == 0 { stop() }
    else lastImported = imported
}
```

### 8.3  File‑Watcher Debouncer

```
Debouncer.run(after: 60) { sync(today) }
```

---

## 9  Security & Privacy

* Store only TP cookies (no passwords).  
* Encrypt at rest (Keychain).  
* Respect TP ToS: ≤1 POST/min; user triggers exempt.  
* Provide “Disconnect TP” that deletes cookies & local files.

---

## 10  Testing Plan

| Layer | Tool | Tests |
|-------|------|-------|
| Unit | XCTest | CookieVault; CSV parser; duplicate merge. |
| Integration | Xcode UI Tests | Simulated login with HTML fixture. |
| End‑to‑end | TestFlight + TP sandbox | Overnight sync; morning trigger; error inject. |

Mock `/ExportUserData` with WireMock.

---

## 11  Milestones

| Week | Deliverable |
|------|-------------|
| 1 | CookieVault.swift, AuthWebView.swift. |
| 2 | TrainingPeaksExportService.swift (happy path). |
| 3 | ZipIngestor.swift + Core Data; nightly BG task. |
| 4 | Toolbar Sync button + MorningPoller; UX polish. |
| 5 | File‑Watcher; Settings; logging; error banners. |
| 6 | QA, docs, hand‑off.

---

## 12  GPT‑4.1 Coding Guidelines

1. Output **full Swift files** – imports, comments, unit tests.  
2. Use **Swift Concurrency** (`async/await`).  
3. Only external deps: `ZIPFoundation`, `SwiftCSV` via SwiftPM.  
4. CamelCase types; camelCase funcs; prefix TP‑classes `TP`.  
5. Document public APIs with `///`.  
6. Provide sample XCTest files.

*End of brief*
