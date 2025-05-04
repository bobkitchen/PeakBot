# PeakBot — Strava Integration & Self-Hosted Metrics Engine  
*Version 0.9 · Draft prepared 2025-05-04*

---

## 1  Purpose
Build a **fully self-contained data pipeline** that:

* Pulls raw activity data from **Strava’s public API** (OAuth 2.0).
* Computes **TrainingPeaks-equivalent performance metrics** (NP, IF, TSS, ATL, CTL, TSB, rTSS, etc.).
* Stores results locally (Core Data) and renders them in the existing dashboard UI.
* Operates legally and reliably—no private APIs, no scraping—to replace the brittle TrainingPeaks “tapiriik” workaround.

---

## 2  Scope
| In scope | Out of scope (Phase‑1) |
|----------|-----------------------|
| Cycling, running; HR & power streams | Swimming & multisport TSS variants |
| Strava OAuth, token refresh, manual & webhook sync | Direct TrainingPeaks scraping (keep existing code but mark deprecated) |
| Local analytics (all calculations run on‑device) | Cloud‑hosted analytics cluster |
| Rate‑limit handling (200 req / 15 min, 2 000 req / day) | Advanced “bulk export” helper for >2 yrs history |

---

## 3  Definitions
| Term | Meaning |
|------|---------|
| **NP** | Normalized Power (30 s rolling 4ᵗʰ‑power mean, 4ᵗʰ‑root) |
| **IF** | Intensity Factor = `NP ÷ FTP` |
| **TSS** | Training Stress Score = `[(sec × NP × IF) ÷ (FTP × 3600)] × 100` |
| **ATL** | Acute Training Load = 7‑day EWMA of daily TSS |
| **CTL** | Chronic Training Load = 42‑day EWMA of daily TSS |
| **TSB** | Training Stress Balance = `CTL – ATL` |
| **rTSS** | Run TSS computed from NGP (Normalized Graded Pace) or HR fallback |
| **Webhook** | Strava push notification triggered when an activity is created/updated |

---

## 4  High‑Level Architecture
```mermaid
graph TD
  subgraph macOS App
    A[DashboardViewModel] -->|sync()| B[StravaService]
    B -->|OAuth| C[Strava Auth Page]
    B -->|GET /activities| D[Activity cache (Core Data)]
    D -->|streams| E[MetricsEngine]
    E -->|NP/IF/TSS| D
    D --> F[Swift Charts UI]
  end
  C -->|redirect_uri| G[Local HTTP Callback Server]
  G -->|code| B
  Strava[Strava API + Webhooks] -->|push| H[Webhook Relay*]
```
\* _Webhook Relay_ may be a small HTTPS function if on‑device callbacks are undesirable (see §7.2).

---

## 5  Functional Requirements

### 5.1 StravaService
* **OAuth 2.0 flow** using `SFAuthenticationSession` (macOS) → local callback on `http://localhost:8080/callback`.
* Persist `access_token`, `refresh_token`, `expires_at` in **Keychain**; auto‑refresh when <60 s to expiry.
* **Paginated fetch**  
  * Endpoint `GET /athlete/activities?per_page=50&page=N&after={unix}`  
  * Call `GET /activities/{id}/streams` for keys: `time,watts,heartrate`.
* **Rate‑limit guard**  
  * Ring‑buffer the timestamps of the last 200 calls; if full, sleep until 15‑min window clears.  
  * Surface a user‑visible banner if daily 2 000‑call cap is hit.

### 5.2 Data Model (Core Data)
| Entity | Attributes | Notes |
|--------|------------|-------|
| **Workout** | `id:Int64` (Strava ID) · `name:String` · `sport:String` · `startDate:Date` · `distance:Double` (m) · `movingTime:Int` (s) · `avgPower:Double?` (w) · `avgHR:Double?` (bpm) · `np:Double?` · `if:Double?` · `tss:Double?` | Primary store of raw + derived per‑activity data |
| **Stream** | `workoutID` (rel.) · `type:String` (`watts|heartrate|time`) · `values:[Double]` | Separate table or binary plist blob |
| **DailyLoad** | `date:Date` · `tss:Double` · `atl:Double` · `ctl:Double` · `tsb:Double` | 1 row per calendar day |
| **Settings** | `ftp:Double` · `hrZones:[Int:Int]` · `lastSync:Date` | Single‑row table (singleton) |

### 5.3 MetricsEngine
* **Input**: `Stream` data (power preferred, HR fallback) + `Settings.ftp`.
* **Output**: Fill `np`, `if`, `tss` in each `Workout`; recompute `DailyLoad` forward from earliest changed day.
* **Algorithmic specs**  
  * **NP**: 30‑second rolling mean → each value ⁴ → mean → 4ᵗʰ root.  
  * **IF**: NP ÷ current FTP (editable in Settings).  
  * **TSS**: as per Coggan formula (see §3).  
  * **ATL / CTL**: EWMA using `exp(-1/τ)` where `τ = 7 days` for ATL, `42 days` for CTL.  
  * **TSB**: `CTL – ATL`, computed daily.  
  * **rTSS** fallback: use Daniels VDOT method or default TRIMP scaling if no power and pace.

### 5.4 Sync Workflow
| Stage | Trigger | Action |
|-------|---------|--------|
| **Manual** | User clicks **“Sync Now”** | Pull last 30 days, update DB, recalc metrics |
| **Webhook** | Strava push (activity create/update) | Fetch specific activity only |
| **Back‑fill** | First‑run or “Sync history” | Year‑by‑year batch download until Strava joins date of first TP record or 1 Jan 2020 |

### 5.5 UI/UX
* **Dashboard**: already displays CTL/ATL/TSB; adjust labels “TrainingPeaks Data” → “Fitness (Strava)”.
* **SettingsView** (new, modal or sidebar): FTP field, “Connect Strava” button, “Sync Now”, “Sync history”, token expiry countdown.
* **Error banners**: OAuth failure, rate-limit exceeded, token expired & refresh failed.

---

## 6 Non‑Functional Requirements
| Aspect | Requirement |
|--------|-------------|
| **Privacy** | All analytics on‑device; no 3rd‑party servers except Strava. |
| **Security** | Store tokens in Keychain; **never** commit client secret to repo (use `.xcconfig`). |
| **Performance** | Initial daily metrics calc <3 s for 1 year (~365 × 1 activity/day). |
| **Accessibility** | UI compatible with macOS VoiceOver; CTL/ATL chart annotated. |
| **Offline mode** | App must open and display last‑synced data when offline. |
| **Error logging** | `os_log` subsystem `com.bobkitchen.peakbot.strava`; rotate at 7 MB. |

---

## 7 Implementation Plan

| Phase | Deliverables | Owner | Status |
|-------|--------------|-------|--------|
| **P0** – restore code (✅) | Re‑add `StravaService.swift`, calculators, models from commit `d1c7688`. | done | ✅ |
| **P1** – OAuth & manual sync | Token flow, fetch last 30 days, NP/IF/TSS calc, chart renders. | Windsurf | ☐ |
| **P2** – Settings UI | FTP field, Connect button, error banners. | Windsurf | ☐ |
| **P3** – Rate‑limit guard & back‑fill | Timestamp ring buffer, year‑by‑year history importer. | Windsurf | ☐ |
| **P4** – Webhook endpoint (optional)\* | Tiny HTTPS relay function + local listener toggle. | Windsurf | ☐ |

\* _If webhook hosting is deferred, polling every 4 h is acceptable interim workaround._

---

## 8 Open Decisions (for Bob)

1. **Metric fidelity** — *OK if PeakBot values differ ±5 % from TrainingPeaks?*  
2. **FTP source of truth** — *Single global FTP (manual), or per‑sport / time‑stamped FTP history?*  
3. **Run TSS method** — *Use Daniels VDOT (pace‑based) or TRIMP (HR‑based) fallback?*  
4. **Webhook hosting** — *Local mac‑only callback (app must be open) or serverless relay (e.g., Fly.io + Vapor)?*  
5. **Dual‑source future** — *Retain TP scraping for power users or plan full sunset once Strava path is stable?*

Please answer these to promote the spec to **v1.0**.

---

## 9 Change Log Template
| Date | Version | Author | Summary |
|------|---------|--------|---------|
| 2025‑05‑04 | 0.9 draft | ChatGPT | Initial detailed spec |

---

_© 2025 Bob Kitchen. All rights reserved._
