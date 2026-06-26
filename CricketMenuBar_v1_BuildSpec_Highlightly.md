# Cricket Menu Bar — v1 Build Spec · Highlightly edition (for Antigravity)

> This replaces the earlier CricketData version. It uses the **Highlightly Cricket API** as the data source. Hand Antigravity **this single file** — everything it needs is here.

## What you are building
A macOS **menu bar app** that shows the **live cricket score** in the Mac's top menu bar, pulled from the **Highlightly Cricket API**. That is the entire scope of v1.

- Menu bar title example: `IND 287/5 (48.2)`
- Click the title → a small dropdown showing both teams, both scores, overs, and match status.

---

## How to use this spec (READ FIRST)
- Build in the numbered **Phases** below, **in order**.
- **Stop at the end of each phase and report what works before starting the next one.** Do not chain ahead.
- Build **only** what each phase lists. Do not add features, screens, settings, or data fields that aren't explicitly requested.
- If something feels "obviously useful to add," check the **DO NOT BUILD** list first.

---

## 🚫 DO NOT BUILD (hard boundaries for v1)
- ❌ **No WidgetKit** / desktop widget / Notification Center widget. Menu bar only.
- ❌ **No App Groups, no widget extension, no second target.** One single app target.
- ❌ **No settings / preferences window, no onboarding, no API-key entry screen.** (Key is a constant for now — see *Config*.)
- ❌ **No at-the-crease detail:** no batters, no bowler figures, no last-6-balls, no manhattan, no full scorecard. (Do **not** call `GET /matches/{id}` in v1 — it's a separate request per match and burns quota.)
- ❌ **No Test-match-specific logic** (no days/sessions/lead-deficit branching). Just display whatever score string the API returns; that already covers Test as plain text.
- ❌ **No multi-match switcher UI.** Auto-pick one live match (see logic below).
- ❌ **No notifications / alerts** of any kind.
- ❌ **No charts**, no animations beyond a simple "live" dot, no theming/customization.
- ❌ **No login, no accounts, no analytics, no third-party packages/SDKs.** Pure Swift + SwiftUI.
- ❌ **No backend, no server code, no payments/subscriptions.**

> If a feature is not described in the **Phases** section, it is out of scope for v1.

---

## Tech stack
- **Swift + SwiftUI**
- **`MenuBarExtra`** scene (requires macOS 13+; target **macOS 14 Sonoma or later**)
- **Menu-bar-only:** set `LSUIElement` ("Application is agent (UIElement)") = `YES` in Info.plist so there is **no Dock icon**
- **No external dependencies / Swift packages**
- Networking via built-in **`URLSession` + `Codable`**
- State via the **`@Observable`** macro (macOS 14+); `ObservableObject` is also fine

---

## Architecture (single target, single process)
Four small layers, all inside the one app:
1. **Model** — Swift structs + enum representing a match (see *Data Model*).
2. **API client** — fetches and decodes Highlightly JSON into the model.
3. **Match service** — owns a repeating timer, polls the API client on an interval, picks the live match, and publishes the current state to the UI.
4. **UI** — the `MenuBarExtra`: a text label (the title) plus a small dropdown view.

No cross-process data sharing, no shared files, no sandboxed extension.

---

## Data source — Highlightly Cricket API

### Sign up (two options — use whichever works)
- **Highlightly directly:** create an account at `https://highlightly.net/login`.
- **Via RapidAPI** (Google/GitHub sign-in, no web form): subscribe to the "Cricket Highlights API" on RapidAPI.
- Both give the **same data** and a **free Basic plan = 100 requests/day**. Accounts are **not** synced across the two — pick one.

### Connection details
- **Auth header (both platforms):** `x-rapidapi-key: YOUR_API_KEY`
- **Base URL (Highlightly direct):** `https://cricket.highlightly.net`
- **Base URL (RapidAPI):** `https://cricket-highlights-api.p.rapidapi.com`
  - If using RapidAPI, **also** send: `x-rapidapi-host: cricket-highlights-api.p.rapidapi.com`
- **Rate-limit tracking:** every response carries the header `x-ratelimit-requests-remaining` — read it and surface it (see Phase 2). Log it during development so testing doesn't silently burn the 100/day.

### Endpoint for v1
`GET {baseURL}/matches?date=YYYY-MM-DD&limit=50`
- Use **today's date in the user's local timezone** (do not use a naive UTC `toISOString` slice — it breaks near midnight for users ahead of UTC).
- Returns `{ "data": [ ...match objects... ] }`.

### Response shape (verify against a real call in Phase 0)
```json
{
  "data": [
    {
      "format": "T20",
      "startTime": "2026-04-17T14:00:00.000Z",
      "homeTeam": { "name": "Gujarat Titans", "abbreviation": "GT", "logo": "..." },
      "awayTeam": { "name": "Kolkata Knight Riders", "abbreviation": "KKR", "logo": "..." },
      "league": { "name": "IPL", "season": 2026 },
      "state": {
        "description": "In play",
        "report": "GT need 12 runs",
        "teams": {
          "home": { "score": "181/5", "info": "19.4/20 ov, T:181" },
          "away": { "score": "180",   "info": null }
        }
      }
    }
  ]
}
```
- `state.teams.home.score` / `.away.score` — a **string** like `"181/5"` (runs/wickets). Test innings may look like `"261 & 8/1"`. `null` if the team hasn't batted.
- `state.teams.*.info` — a **string** like `"19.4/20 ov, T:181"` (overs, and target when relevant). May be `null`.
- `state.description` — the status (`"In play"`, `"Innings break"`, `"Stumps"`, `"Tea"`, `"Finished"`, `"Not started"`, `"Abandoned"`, `"No result"`, …).
- `state.report` — a human-readable line ("GT need 12 runs" / result / day summary).

### Which match to show (auto-pick, no UI)
Classify `state.description` (lowercased):
- **live** = `in play`, `live`, `innings break`
- **break** = `stumps`, `tea`, `lunch`, `dinner`, `drinks`
- **finished** = `finished`, `abandoned`, `no result`
- **upcoming** = `not started`, `scheduled`

Pick the **first match classified `live`**. If none, fall back to the most recent `finished` one, or show `No live match`. v1 picks automatically — no switcher.

### Rate-limit awareness (important)
Free tier = **100 requests/day**. Default polling interval = **120 seconds** (constant `pollInterval`). **Do not poll faster than 120s in v1.** When no match is live, you may slow down. The `/matches` call is one request; **do not** add per-match `/matches/{id}` calls in v1.

---

## Data model (keep minimal; design to extend later)
```swift
enum MatchState {
    case scheduled
    case live
    case onBreak       // stumps / tea / innings break, etc.
    case finished
    case noData
}

struct Innings {
    let teamShortName: String   // from homeTeam/awayTeam.abbreviation, e.g. "IND"
    let scoreText: String       // raw "181/5" (or "261 & 8/1" for Tests) — display as-is in v1
    let infoText: String?       // raw "19.4/20 ov, T:181" — display as-is in v1
}

struct Match {
    let name: String            // build from homeTeam.name + " vs " + awayTeam.name
    let format: String          // "T20", "ODI", "TEST"
    let statusText: String      // state.report (fallback to state.description)
    let innings: [Innings]      // home + away
    let state: MatchState
}
```
**v1 parsing rule:** keep `score` and `info` as the **raw strings** the API gives you and display them directly. Do **not** split them into integer runs/wickets/overs or compute run rates in v1 — that's a v2 job. (When you do parse later: overs are base-6, e.g. `19.4` = 19 overs + 4 balls = 118 balls, never decimal math.)

---

## Phases

### Phase 0 — Data layer only (NO UI yet)  ·  *[Swift, console]*
**Goal:** prove data flows from Highlightly → typed model → a printed score string.
- Add `Config.swift` with the API key + base URL (see *Config*).
- Build the API client: `GET /matches?date=<today-local>`, decode `{ data: [...] }` into the model. Send the `x-rapidapi-key` header.
- Pick the live match using the classifier above.
- Print a title string (e.g. `GT 181/5 (19.4/20 ov, T:181)`) **and** `state.report` to the console.
- Log `x-ratelimit-requests-remaining` so you can see quota use.

✅ **Done when:** running it prints a correct, current score string for a real match, and the real JSON field names are confirmed. **Stop and report before Phase 1.**

### Phase 1 — Menu bar shell + live title  ·  *[Swift, SwiftUI]*
**Goal:** the live score appears in the menu bar and refreshes itself.
- Create the `MenuBarExtra` app; set `LSUIElement` so there's no Dock icon.
- Show the title string as the menu bar label. For the title, use the **batting / live team's** `abbreviation + score` (e.g. `IND 287/5`); keep it short.
- Add the Match service: a timer firing every `pollInterval` (120s) that re-fetches and updates the title.
- Handle gracefully: a loading state, no-live-match (`No live match`), and fetch/timeout errors (keep the last value or show `—`; **never crash**). Use a request timeout (e.g. 10s).

✅ **Done when:** the menu bar shows a live score that updates on its own during a match. **Stop and report before Phase 2.**

### Phase 2 — Dropdown detail + basic actions  ·  *[Swift, SwiftUI]*
**Goal:** clicking the menu bar item shows a bit more, plus manual refresh and quit.
- Use `.menuBarExtraStyle(.window)` so the dropdown can hold a small custom SwiftUI view.
- Dropdown contents (and **nothing more**):
  - Match name ("Gujarat Titans vs Kolkata Knight Riders")
  - Both innings as text: `GT 181/5 (19.4/20 ov, T:181)` and `KKR 180`
  - The status line: `state.report` (fallback `state.description`)
  - A small **live indicator** (dot/color) shown only when `state == .live`
  - An **"API: 87 left today"** line from the `x-ratelimit-requests-remaining` header
  - A **"Refresh now"** button (manual fetch — counts against the limit; that's fine)
  - A **"Quit"** button

✅ **Done when:** the dropdown shows current match detail and Refresh / Quit both work.

---

## Config & secrets (this matters — the repo goes on GitHub later)
- Put the key + base URL in `Config.swift`:
  ```swift
  enum Config {
      static let highlightlyAPIKey = "PASTE_YOUR_KEY_HERE"
      static let apiBaseURL = "https://cricket.highlightly.net"   // or the RapidAPI base
      static let pollInterval: TimeInterval = 120
  }
  ```
- **Add `Config.swift` to `.gitignore`.** Commit a `Config.example.swift` template (empty key) in its place.
- The real API key must **never** be committed to GitHub.
- Do **not** build a settings UI to enter the key in v1. (That's the later BYOK screen.)

---

## v1 definition of done
- [ ] App lives **only** in the menu bar (no Dock icon).
- [ ] Menu bar shows a **live score**, auto-updating ~every 2 minutes.
- [ ] Clicking shows **both scores + status + requests-remaining + Refresh + Quit**.
- [ ] **No crashes** when offline or when no match is live.
- [ ] Real API key is **gitignored**; `Config.example.swift` is committed.
- [ ] Only the `/matches` endpoint is called (no `/matches/{id}` in v1).
- [ ] **None** of the *DO NOT BUILD* items are present.
