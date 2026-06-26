<div align="center">
  <img src="https://img.icons8.com/color/94/cricket.png" alt="Cricket Menu Bar Widget" width="100" height="100" />
  <h1>Cricket Menu Bar Widget</h1>
  <p><b>A lightweight, native macOS menu bar application that displays live cricket scores in real-time, running completely in the background with zero dock clutter.</b></p>

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

- **Live Score Ticker**: Real-time status displayed directly in the macOS menu bar (e.g., `IND-A 398/5` or `SL-E · In play`).
- **Smart Match Prioritization**: Auto-selects the most relevant active live match, prioritizing active scores. If no matches are live, it gracefully falls back to the most recently completed match.
- **Dynamic Dropdown Status Card**: Clicking the widget reveals a detailed window featuring:
  - Complete innings telemetry (runs, wickets, overs, targets).
  - A pulsing green **LIVE** indicator for active matches.
  - Contextual match commentary and status text (e.g., *"GT need 12 runs in 2 balls"*).
  - API Rate-Limit indicator (`x-ratelimit-requests-remaining`) to monitor your quota.
  - Manual **Refresh now** button with visual loading states.
- **Quota Protection**: Intelligent polling interval (defaults to 120 seconds) to ensure you stay safely within the free API tier.
- **Native & Lightweight**: Built using modern Apple frameworks with near-zero CPU and memory footprint.

---

## 📁 Repository Structure

```directory
.
├── Sources/
│   └── cricket score widget/
│       ├── main.swift              # App entry point, lifecycle, and MenuBarExtra setup
│       ├── Model.swift             # Data models mapping Highlightly API responses
│       ├── Network.swift           # Asynchronous API fetcher and rate-limit parser
│       ├── View.swift              # Custom SwiftUI dropdown window card UI
│       ├── Config.example.swift    # API credentials template
│       └── Config.swift            # Private API credentials (Git ignored)
├── Tests/                          # Unit tests
├── Package.swift                   # Swift Package Manager configuration
├── run.sh                          # Compilation helper and runner script
└── README.md                       # Premium documentation
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
Open `Sources/cricket score widget/Config.swift` in your text editor:
- Paste your API key into `highlightlyAPIKey`.
- **If using RapidAPI**: Set `useRapidAPI = true` and ensure `apiBaseURL` is set to `"https://cricket-highlights-api.p.rapidapi.com"`.
- **If using Highlightly Direct**: Leave `useRapidAPI = false` and ensure `apiBaseURL` is set to `"https://cricket.highlightly.net"`.

*(Note: `Config.swift` is Git ignored to ensure your credentials are never pushed to public repositories).*

### 4. Compile and Run
Run the included shell script to compile the Swift package and launch the application:
```bash
chmod +x run.sh
./run.sh
```

---

## ⚙️ How to Manage the App

- **To Refresh**: The widget refreshes automatically every 2 minutes. You can trigger an instant update by opening the dropdown and clicking **Refresh now**.
- **To Quit**: Click the menu bar widget to open the dropdown and click the **Quit** button (or press `Command + Q` while the dropdown window is focused).
