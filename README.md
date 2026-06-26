<div align="center">
  <img src="https://img.icons8.com/color/94/cricket.png" alt="Cricket Menu Bar Widget" width="100" height="100" />
  <h1>Cricket Menu Bar Widget</h1>
  <p><b>A native, premium macOS menu bar application that displays live cricket scores in real-time. Power-efficient, rate-limit aware, and featuring custom chase math and an interactive settings panel.</b></p>

  <p>
    <img src="https://img.shields.io/badge/macOS-14.0+-000000?style=for-the-badge&logo=apple&logoColor=white" alt="macOS Sonoma+" />
    <img src="https://img.shields.io/badge/Swift-FA7343?style=for-the-badge&logo=swift&logoColor=white" alt="Swift 5.9+" />
    <img src="https://img.shields.io/badge/SwiftUI-0A84FF?style=for-the-badge&logo=swift&logoColor=white" alt="SwiftUI" />
    <img src="https://img.shields.io/badge/Highlightly_API-2E9EF7?style=for-the-badge" alt="Highlightly API" />
  </p>
</div>

---

## 📌 Project Overview

**Cricket Menu Bar Widget** is a native, premium macOS application designed for cricket enthusiasts. Running completely in the background as a menu bar agent (LSUIElement), it eliminates dock clutter while keeping you updated with live match scores, innings details, and run-rate requirements.

Powered by the **Highlightly Cricket API** (supporting both direct endpoints and RapidAPI), the app intelligently displays a live ticker directly in your system menu bar and expands into a beautifully structured status card when clicked.

---

## ⚡ Key Features

### 1. Interactive macOS Settings Panel
Access a native preference panel (macOS `Settings` scene) to configure the widget on-the-fly:
- **API Configuration**: Easily paste your Highlightly or RapidAPI key (stored securely in `UserDefaults` via `@AppStorage`, falling back to `Config.swift` if empty).
- **Favorite Team Selection**: Input your favorite team (e.g. `India`, `GT`, `AUS`, `ENG`). The widget will automatically prioritize and auto-select live matches featuring this team.
- **Refresh Speed**: Choose between **Relaxed (120s)** for free tiers, **Live (20s)** for paid plans, or **Death Overs (10s)** for ball-by-ball updates.

### 2. Multi-Match Switcher
When multiple matches are live simultaneously, a dedicated **Live Matches** section appears in the dropdown. You can view all active games and click on any match to manually override and pin that specific score to your system menu bar. Your selection persists automatically across app launches.

### 3. Phase 4 Chase Math & Hero Number
Displays a prominent, computed state card for live matches:
- **Chasing Context**: Computes and displays: *"Need X runs (Y balls) · Required Run Rate: Z"*.
- **First Innings Context**: Automatically calculates and displays the **Current Run Rate (CRR)**.
- **Format Aware**: Gracefully bypasses run-rate calculations for Test matches and finished games.

### 4. Smart Resource Management & Observers
- **Sleep/Wake Watcher**: Automatically pauses API polling when your Mac goes to sleep and resumes upon waking, conserving network quota and battery life.
- **Battery Saver**: Automatically detects when **Low Power Mode** is active, doubling the polling interval (minimum 120s) to conserve power.
- **Adaptive Quota Guard**: Dynamically tightens polling (down to 10s on paid tier) during tight match finishes (e.g., <= 18 balls remaining or <= 24 runs needed) to catch every ball, returning to normal once the game concludes.

---

## 📁 Repository Structure

```directory
.
├── Sources/
│   └── cricket score widget/
│       ├── cricket_score_widget.swift  # App entry point, Settings view, and Dropdown card UI
│       ├── Models.swift                # Innings/Match models, parsing helpers, and Chase/Hero math
│       ├── MatchService.swift          # Polling coordinator, settings observer, and sleep/battery watchers
│       ├── MatchSelector.swift         # Priority selector (manually selected vs. favorite team vs. live first)
│       ├── APIClient.swift             # Asynchronous API fetcher and rate-limit parser
│       ├── Config.example.swift        # API credentials template
│       └── Config.swift                # Private API credentials (Git ignored)
├── Tests/                              # Unit tests
├── Package.swift                       # Swift Package Manager configuration
├── run.sh                              # Compilation helper and runner script
└── README.md                           # Premium documentation
```

---

## 🛠️ Setup & Installation

### Prerequisites
- A Mac running **macOS 14 Sonoma** or later.
- **Xcode Command Line Tools** or Xcode installed (for the Swift compiler `swiftc`).

### 1. Clone the Repository
```bash
git clone https://github.com/riteshv7/cricket-score-widget.git
cd cricket-score-widget
```

### 2. Obtain a Free API Key
Get an API key (100 free requests/day) from either of these sources:
- **Highlightly Direct**: Sign up at [highlightly.net](https://highlightly.net).
- **RapidAPI**: Subscribe to the [Cricket Highlights API](https://rapidapi.com).

### 3. Configure Your Key
Duplicate the configuration template:
```bash
cp "Sources/cricket score widget/Config.example.swift" "Sources/cricket score widget/Config.swift"
```
*(Note: `Config.swift` is Git ignored to ensure your credentials are never pushed to public repositories).*

### 4. Compile and Run
Run the included shell script to compile the Swift package and launch the application:
```bash
chmod +x run.sh
./run.sh
```

---

## ⚙️ How to Manage the App

- **To Open Settings**: Click the menu bar widget to expand the dropdown and click **Settings...** (or focus on the app and press `Command + ,`).
- **To Refresh**: The widget refreshes automatically based on your configured poll interval. You can trigger an instant update by opening the dropdown and clicking **Refresh**.
- **To Quit**: Click the menu bar widget to open the dropdown and click the **Quit** button (or press `Command + Q` while the dropdown window is focused).
