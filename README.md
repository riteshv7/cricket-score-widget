# Maidan

A lightweight, premium macOS menu bar application that displays live cricket scores in real-time. The app runs completely in the background as a menu bar agent (no Dock icon) named **Maidan**, and is powered by the Highlightly Cricket API.

<p align="center">
  <img src="https://img.shields.io/badge/platform-macOS%2014+-blue.svg" alt="Platform: macOS 14+">
  <img src="https://img.shields.io/badge/language-Swift%205.9+-orange.svg" alt="Language: Swift 5.9+">
  <img src="https://img.shields.io/badge/framework-SwiftUI-red.svg" alt="Framework: SwiftUI">
</p>

---

## Features

- **Live Ticker**: Displays a short live score directly in the macOS menu bar (e.g., `IND-A 398/5` or `SL-E · In play` when scoreless).
- **Today's Matches View**: A scrollable list of today's matches grouped into **Live**, **Finished**, and **Upcoming** sections. Select any match from the list to immediately switch the menu bar and details view to that match.
- **Menu Bar Style Customization**: Choose between **Full**, **Compact**, or **Minimal** styles to control the level of detail displayed in your menu bar.
- **Wicket & Match Notifications**: Delivers native macOS system notifications on key events, such as when a wicket falls (showing updated score), when a match ends, or when your favorite team starts playing.
- **Scorecard Click-Through**: Click on the match title inside the dropdown to instantly open a full scorecard search on Cricbuzz/ESPNcricinfo in your default browser.
- **Launch at Login**: Easily toggle launch-at-login from the settings panel so the app starts automatically when your Mac boots.
- **Adaptive & Sleep-Aware Polling**: Intelligently scales polling rates based on match state, backs off when Low Power Mode is active, and pauses completely when your Mac sleeps to conserve API quota and battery.
- **Zero Dock Clutter**: Runs purely in the menu bar as an accessory agent with no Dock presence.

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
   cp "Sources/Maidan/Config.example.swift" "Sources/Maidan/Config.swift"
   ```
3. Open the newly created `Sources/Maidan/Config.swift` file:
   - Paste your API key into `highlightlyAPIKey`.
   - **If using RapidAPI**: Set `useRapidAPI = true` and ensure `apiBaseURL` is set to `"https://cricket-highlights-api.p.rapidapi.com"`.
   - **If using Highlightly Direct**: Leave `useRapidAPI = false` and ensure `apiBaseURL` is set to `"https://cricket.highlightly.net"`.

*Note: `Config.swift` is already added to `.gitignore` to guarantee your private API key is never accidentally committed to GitHub.*

### 3. Build and Package
You can compile and package the widget into a native, standalone macOS `.app` bundle with a custom high-resolution icon:

```bash
./package.sh
```

Upon successful compilation:
- A double-clickable `Maidan.app` bundle will be created in the root folder.
- Simply double-click the app to launch it natively.
- Drag `Maidan.app` to your `/Applications` folder to install it permanently.

*Note: For quick developer testing, you can still run `./run.sh` to compile and run the executable directly in the terminal background.*

### 4. Stopping the App
To close the application, click the menu bar widget, open the **Settings...** panel, and click **Quit**. You can also close it via standard terminal commands if run via `./run.sh`.
