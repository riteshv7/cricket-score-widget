# Cricket Menu Bar Widget

A lightweight, premium macOS menu bar application that displays live cricket scores in real-time. The app runs completely in the background as a menu bar agent (no Dock icon) and is powered by the Highlightly Cricket API.

<p align="center">
  <img src="https://img.shields.io/badge/platform-macOS%2014+-blue.svg" alt="Platform: macOS 14+">
  <img src="https://img.shields.io/badge/language-Swift%205.9+-orange.svg" alt="Language: Swift 5.9+">
  <img src="https://img.shields.io/badge/framework-SwiftUI-red.svg" alt="Framework: SwiftUI">
</p>

---

## Features

- **Live Ticker**: Displays a short live score directly in the macOS menu bar (e.g., `IND-A 398/5` or `SL-E · In play` when scoreless).
- **Intelligent Selection**: Auto-picks the first active live match, prioritizing matches that have live scores over scoreless ones. If no matches are live, it falls back to the most recent completed match.
- **Custom Dropdown Window**: Click the menu bar icon to reveal a custom window card displaying:
  - Both team names and complete innings details (runs, wickets, overs, targets).
  - A pulsing green **LIVE** indicator.
  - Human-readable match status and reports (e.g., "GT need 12 runs in 2 balls").
  - API rate limit status (`x-ratelimit-requests-remaining`).
  - Manual **Refresh now** button with visual progress indicators.
- **Rate-Limit Aware**: Automatically polls the API in the background every 120 seconds, ensuring you stay within the free tier quota.
- **Zero Dock Clutter**: Runs purely in the menu bar as an accessory agent.

---

## Tech Stack

- **Swift & SwiftUI**: Built natively using modern SwiftUI.
- **`MenuBarExtra`**: Integrates into the macOS system menu bar (requires macOS 14 Sonoma or later).
- **`@Observable` Macro**: Leverages modern state observation (macOS 14+).
- **Standalone Compilation**: Configured to compile directly via `swiftc` or through the Swift Package Manager.

---

## Setup & Installation

### 1. Get an API Key
You can obtain a free API key (100 requests/day) from either of these platforms:
- **Highlightly Direct**: Sign up at [highlightly.net](https://highlightly.net).
- **RapidAPI**: Subscribe to the [Cricket Highlights API](https://rapidapi.com) (allows quick login via GitHub/Google).

### 2. Configure the Project
1. Clone this repository to your local machine.
2. Duplicate the configuration template:
   ```bash
   cp "Sources/cricket score widget/Config.example.swift" "Sources/cricket score widget/Config.swift"
   ```
3. Open the newly created `Sources/cricket score widget/Config.swift` file:
   - Paste your API key into `highlightlyAPIKey`.
   - **If using RapidAPI**: Set `useRapidAPI = true` and ensure `apiBaseURL` is set to `"https://cricket-highlights-api.p.rapidapi.com"`.
   - **If using Highlightly Direct**: Leave `useRapidAPI = false` and ensure `apiBaseURL` is set to `"https://cricket.highlightly.net"`.

*Note: `Config.swift` is already added to `.gitignore` to guarantee your private API key is never accidentally committed to GitHub.*

### 3. Build and Run
Execute the included helper script to compile the Swift source files and launch the application:
```bash
./run.sh
```

Upon successful compilation:
- The app will launch in the background.
- The live cricket score will appear in your Mac's top menu bar.
- The console will show details on how to quit or manage the app.

### 4. Stopping the App
To close the application, click the menu bar widget and click the **Quit** button, or focus on the dropdown window and press `Command + Q`.
