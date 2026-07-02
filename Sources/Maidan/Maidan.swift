import SwiftUI
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}

@main
struct MaidanApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @State private var matchService = MatchService()
    
    var body: some Scene {
        MenuBarExtra {
            DropdownView(matchService: matchService)
        } label: {
            HStack(spacing: 4) {
                MenuBarIconView()
                Text(matchService.menuBarTitle)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .lineLimit(1)
            }
        }
        .menuBarExtraStyle(.window)

        // Phase 3: The Settings window scene
        Settings {
            SettingsView()
        }
    }
}

struct MenuBarIconView: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .stroke(.primary, lineWidth: 1.6)
                .frame(width: 18, height: 13)
            
            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                .fill(.primary)
                .frame(width: 3, height: 8)
            
            Circle()
                .fill(.primary)
                .frame(width: 3.2, height: 3.2)
                .offset(x: 6, y: -3.2)
        }
        .frame(width: 22, height: 18)
        .accessibilityLabel("Maidan")
    }
}

// MARK: - Settings View

struct SettingsView: View {
    var isInline: Bool = false
    
    // Persist API Key in UserDefaults via @AppStorage
    @AppStorage("apiKey") private var apiKey: String = ""
    
    // Persist Poll Interval in UserDefaults via @AppStorage
    @AppStorage("pollInterval") private var pollInterval: Double = 120.0
    
    // Phase 6: Persist Favorite Team in UserDefaults via @AppStorage
    @AppStorage("favoriteTeam") private var favoriteTeam: String = ""
    
    // Match Feed Filter Mode (Phase 11)
    @AppStorage("matchFilterMode") private var matchFilterMode: String = "major"
    
    // Menu Bar Customization Style
    @AppStorage("menuBarStyle") private var menuBarStyle: String = "compact"
    
    // Launch at Login Toggle
    @AppStorage("launchAtLogin") private var launchAtLogin: Bool = false
    
    // Predefined popular teams list
    private let popularTeams: [(key: String, value: String)] = [
        ("India", "🇮🇳 India"),
        ("Australia", "🇦🇺 Australia"),
        ("England", "🏴󠁧󠁢󠁥󠁮󠁧󠁿 England"),
        ("South Africa", "🇿🇦 South Africa"),
        ("Pakistan", "🇵🇰 Pakistan"),
        ("New Zealand", "🇳🇿 New Zealand"),
        ("West Indies", "🌴 West Indies"),
        ("Sri Lanka", "🇱🇰 Sri Lanka"),
        ("Bangladesh", "🇧🇩 Bangladesh"),
        ("Afghanistan", "🇦🇫 Afghanistan"),
        ("Super Kings", "💛 CSK"),
        ("Indians", "💙 MI"),
        ("Challengers", "❤️ RCB"),
        ("Knight Riders", "💜 KKR"),
        ("Titans", "🔩 GT"),
        ("Royals", "💗 RR"),
        ("Super Giants", "🤍 LSG"),
        ("Capitals", "❤️‍🔥 DC"),
        ("Sunrisers", "🧡 SRH"),
        ("Punjab", "🔴 PBKS")
    ]
    
    private func isFavoriteTeamSelected(_ teamKey: String) -> Bool {
        let teams = favoriteTeam.components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        return teams.contains(teamKey.lowercased())
    }
    
    private func toggleFavoriteTeam(_ teamKey: String) {
        let teams = favoriteTeam.components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        if teams.contains(where: { $0.lowercased() == teamKey.lowercased() }) {
            // Remove it
            let updated = teams.filter { $0.lowercased() != teamKey.lowercased() }
            favoriteTeam = updated.joined(separator: ", ")
        } else {
            // Add it
            var updated = teams
            updated.append(teamKey)
            favoriteTeam = updated.joined(separator: ", ")
        }
    }
    
    var body: some View {
        Form {
            VStack(alignment: .leading, spacing: 14) {
                // Section 1: API Key
                VStack(alignment: .leading, spacing: 4) {
                    Text("API Configuration")
                        .font(.subheadline)
                        .fontWeight(.bold)
                    
                    TextField("Paste your Highlightly or RapidAPI key here", text: $apiKey)
                        .textFieldStyle(.roundedBorder)
                        .labelsHidden()
                        .frame(width: isInline ? 280 : 340)
                    
                    Text("If empty, falls back to key in Config.swift.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Divider()
                
                // Section 2: Match Feed Filter & Startup
                VStack(alignment: .leading, spacing: 6) {
                    Text("Match Feed & Startup")
                        .font(.subheadline)
                        .fontWeight(.bold)
                    
                    Picker("Feed Filter", selection: $matchFilterMode) {
                        Text("All Matches").tag("all")
                        Text("Major Matches").tag("major")
                        Text("IPL Only").tag("ipl")
                        Text("International Only").tag("intl")
                    }
                    .pickerStyle(.menu)
                    .frame(width: isInline ? 280 : 340)
                    
                    Text("Filter matches by league/level to keep your feed clean.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Toggle("Launch at Login", isOn: $launchAtLogin)
                        .toggleStyle(.checkbox)
                        .font(.subheadline)
                        .padding(.top, 4)
                }
                
                Divider()
                
                // Section 3: Favorite Team Selection (Phase 6 / Multi-Select Redesign)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Favorite Teams (Auto-Select & Alerts)")
                        .font(.subheadline)
                        .fontWeight(.bold)
                    
                    Text("Tap teams to toggle. Selected teams are prioritized for auto-selection and notification alerts.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.bottom, 2)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("International")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                        
                        let columns = [GridItem(.adaptive(minimum: 100, maximum: 140), spacing: 6)]
                        
                        LazyVGrid(columns: columns, alignment: .leading, spacing: 6) {
                            ForEach(popularTeams.prefix(10), id: \.key) { team in
                                let isSelected = isFavoriteTeamSelected(team.key)
                                Button(action: {
                                    toggleFavoriteTeam(team.key)
                                }) {
                                    Text(team.value)
                                        .font(.system(size: 10, weight: isSelected ? .bold : .regular))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(isSelected ? Color.blue.opacity(0.15) : Color.primary.opacity(0.04))
                                        .foregroundColor(isSelected ? .blue : .primary)
                                        .cornerRadius(8)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        
                        Text("IPL Franchises")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                        
                        LazyVGrid(columns: columns, alignment: .leading, spacing: 6) {
                            ForEach(popularTeams.suffix(10), id: \.key) { team in
                                let isSelected = isFavoriteTeamSelected(team.key)
                                Button(action: {
                                    toggleFavoriteTeam(team.key)
                                }) {
                                    Text(team.value)
                                        .font(.system(size: 10, weight: isSelected ? .bold : .regular))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(isSelected ? Color.blue.opacity(0.15) : Color.primary.opacity(0.04))
                                        .foregroundColor(isSelected ? .blue : .primary)
                                        .cornerRadius(8)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(6)
                    .background(Color.primary.opacity(0.02))
                    .cornerRadius(8)
                    
                    TextField("Selected Teams (comma-separated)", text: $favoriteTeam)
                        .textFieldStyle(.roundedBorder)
                        .labelsHidden()
                        .frame(width: isInline ? 280 : 340)
                        .padding(.top, 2)
                }
                
                Divider()
                
                // Section 4: Menu Bar Customization
                VStack(alignment: .leading, spacing: 4) {
                    Text("Menu Bar Customization")
                        .font(.subheadline)
                        .fontWeight(.bold)
                    
                    Picker("Style", selection: $menuBarStyle) {
                        Text("Full — IND 142/3 (16.2)").tag("full")
                        Text("Compact — IND 142/3").tag("compact")
                        Text("Minimal — 🏏 🟢").tag("minimal")
                    }
                    .pickerStyle(.radioGroup)
                    .font(.subheadline)
                }
                
                Divider()
                
                // Section 5: Poll Interval
                VStack(alignment: .leading, spacing: 4) {
                    Text("Refresh Speed")
                        .font(.subheadline)
                        .fontWeight(.bold)
                    
                    Picker("Interval", selection: $pollInterval) {
                        Text("Relaxed (free plan) — 120s").tag(120.0)
                        Text("Live (paid plan) — 20s").tag(20.0)
                        Text("Death overs — 10s").tag(10.0)
                    }
                    .pickerStyle(.radioGroup)
                    .font(.subheadline)
                    
                    if !isInline {
                        Text("Note: Faster polling speeds require a paid API subscription.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(isInline ? 8 : 20)
        }
        .frame(width: isInline ? nil : 380, height: isInline ? nil : 480)
        .navigationTitle("Maidan Settings")
        .onAppear {
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}

// MARK: - Dropdown Window View

struct DropdownView: View {
    @Environment(\.openSettings) private var openSettings
    var matchService: MatchService
    
    // Phase 6: Bind selection to AppStorage so it persists automatically
    @AppStorage("selectedMatchID") private var selectedMatchID: String = ""
    
    // Additive: Expand/collapse state for Today's Matches
    @State private var isTodayMatchesExpanded: Bool = true
    
    // New state to toggle inline Settings panel
    @State private var showSettings: Bool = false
    
    // Keyboard focus state (Phase 11)
    @FocusState private var isFocused: Bool
    
    // Hover state for matches list
    @State private var hoveredMatchID: String? = nil
    
    var body: some View {
        let todaysMatchesList = matchService.todaysMatches
        let liveMatchesList = todaysMatchesList.filter { $0.state == .live || $0.state == .onBreak }
        let finishedMatchesList = todaysMatchesList.filter { $0.state == .finished }
        let upcomingMatchesList = todaysMatchesList.filter { $0.state == .scheduled }
        
        return VStack(alignment: .leading, spacing: 12) {
            if showSettings {
                // Inline Settings Panel
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Maidan Settings")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        Spacer()
                        Button(action: {
                            withAnimation {
                                showSettings = false
                            }
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                                .font(.title3)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.bottom, 2)
                    
                    ScrollView {
                        SettingsView(isInline: true)
                    }
                    .frame(height: 300)
                }
                
                Divider()
                
                // Footer for Settings Panel
                HStack {
                    Spacer()
                    Button("Back") {
                        withAnimation {
                            showSettings = false
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    
                    Button("Quit") {
                        NSApplication.shared.terminate(nil)
                    }
                    .buttonStyle(.bordered)
                }
            } else {
                // Selected Match Details
                if let match = matchService.currentMatch {
                    // Header: Match Name and Live Indicator (Click to open scorecard in browser)
                    Button(action: {
                        let query = "cricket score \(match.name)"
                        if let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                           let url = URL(string: "https://www.google.com/search?q=\(encoded)") {
                            NSWorkspace.shared.open(url)
                        }
                    }) {
                        HStack(alignment: .center, spacing: 6) {
                            Text(match.name)
                                .font(.headline)
                                .fontWeight(.semibold)
                                .lineLimit(2)
                                .foregroundColor(matchAccent)
                            
                            Image(systemName: "arrow.up.forward.app")
                                .font(.caption)
                                .foregroundColor(matchAccent)
                            
                            Spacer()
                            
                            if match.state == .live {
                                LiveIndicatorView()
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    
                    Divider()
                    
                    selectedMatchScorePanel(for: match)
                    
                    // Phase 9: Live crease / final top performers section
                    if let details = match.detailedInfo {
                        let batsmen = battersForPlayerCard(match: match, details: details)
                        let bowlers = bowlersForPlayerCard(match: match, details: details)
                        if !batsmen.isEmpty || !bowlers.isEmpty {
                        VStack(alignment: .leading, spacing: 5) {
                            if match.state == .finished {
                                Text("Top performers")
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .foregroundColor(.secondary)
                                    .textCase(.uppercase)
                            }

                            ForEach(batsmen) { batsman in
                                HStack(spacing: 6) {
                                    Image(systemName: "cricket.ball")
                                        .foregroundColor(.secondary)
                                        .font(.system(size: 10))

                                    teamBadge(batsman.teamAbbreviation)
                                    
                                    Text(batsman.name)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .lineLimit(1)
                                    
                                    Spacer()
                                    
                                    Text(batsman.balls > 0 ? "\(batsman.runs) (\(batsman.balls))" : "\(batsman.runs)")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    
                                    Text(batsman.strikeRate > 0 ? "SR: \(Int(batsman.strikeRate))" : "SR: --")
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                        .frame(width: 45, alignment: .trailing)
                                }
                            }
                            
                            if !batsmen.isEmpty && !bowlers.isEmpty {
                                Divider()
                                    .opacity(0.4)
                            }
                            
                            ForEach(bowlers) { bowler in
                                HStack(spacing: 6) {
                                    Image(systemName: "figure.cricket")
                                        .foregroundColor(.secondary)
                                        .font(.system(size: 10))

                                    teamBadge(bowler.teamAbbreviation)
                                    
                                    Text(bowler.name)
                                        .font(.subheadline)
                                        .lineLimit(1)
                                    
                                    Spacer()
                                    
                                    Text("\(bowler.wickets)/\(bowler.runsConceded)")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    
                                    Text(bowler.overs > 0 ? "\(String(format: "%.1f", bowler.overs)) ov" : "-- ov")
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                        .frame(width: 45, alignment: .trailing)
                                }
                            }
                        }
                        .padding(8)
                        .background(Color.primary.opacity(0.04))
                        .cornerRadius(6)
                        .padding(.top, 4)
                        }
                    }
                    
                    // Phase 9: Live Win Probability Bar
                    if match.state != .finished,
                       let details = match.detailedInfo,
                       let homeProbStr = details.homeWinProb,
                       let awayProbStr = details.awayWinProb,
                       let homeProb = parsePercent(homeProbStr),
                       let awayProb = parsePercent(awayProbStr) {
                        
                        let drawProb = parsePercent(details.drawWinProb) ?? 0.0
                        let total = homeProb + awayProb + drawProb
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Win Probability")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.secondary)
                                Spacer()
                                
                                let homeAbbr = match.innings.first?.teamShortName ?? "HOME"
                                let awayAbbr = match.innings.last?.teamShortName ?? "AWAY"
                                
                                if drawProb > 0 {
                                    Text("\(homeAbbr) \(Int(homeProb))% · Draw \(Int(drawProb))% · \(awayAbbr) \(Int(awayProb))%")
                                        .font(.system(size: 9, weight: .bold, design: .rounded))
                                        .foregroundColor(.secondary)
                                } else {
                                    Text("\(homeAbbr) \(Int(homeProb))% · \(awayAbbr) \(Int(awayProb))%")
                                        .font(.system(size: 9, weight: .bold, design: .rounded))
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            // Stacked Progress Bar representing percentages
                            GeometryReader { geo in
                                HStack(spacing: 0) {
                                    Color.green
                                        .frame(width: total > 0 ? geo.size.width * CGFloat(homeProb / total) : 0)
                                    if drawProb > 0 {
                                        Color.gray.opacity(0.7)
                                            .frame(width: total > 0 ? geo.size.width * CGFloat(drawProb / total) : 0)
                                    }
                                    Color.blue
                                        .frame(width: total > 0 ? geo.size.width * CGFloat(awayProb / total) : 0)
                                }
                                .cornerRadius(2.5)
                            }
                            .frame(height: 5)
                        }
                        .padding(.top, 4)
                    }
                    
                    // Phase 9: Venue & Weather Footer
                    if let details = match.detailedInfo, let venueName = details.venueName {
                        let city = details.venueCity ?? ""
                        let weatherStatus = details.weatherStatus ?? ""
                        let weatherTemp = details.weatherTemp ?? ""
                        
                        let weatherIcon: String = {
                            let desc = weatherStatus.lowercased()
                            if desc.contains("rain") || desc.contains("drizzle") || desc.contains("shower") {
                                return "🌧️"
                            } else if desc.contains("cloud") || desc.contains("overcast") {
                                return "☁️"
                            } else if desc.contains("sun") || desc.contains("clear") || desc.contains("sunny") {
                                return "☀️"
                            } else {
                                return "⛅"
                            }
                        }()
                        
                        HStack(spacing: 4) {
                            Image(systemName: "mappin.and.ellipse")
                                .foregroundColor(.secondary)
                                .font(.system(size: 9))
                            
                            Text("\(venueName)\(!city.isEmpty ? ", \(city)" : "")")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                            
                            Spacer()
                            
                            if !weatherStatus.isEmpty || !weatherTemp.isEmpty {
                                Text("\(weatherIcon) \(weatherTemp)")
                                    .font(.system(size: 9))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.top, 6)
                    }
                    
                } else {
                    // Loading / Empty State / No Key State
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(matchService.menuBarTitle)
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Spacer()
                            if matchService.isFetching {
                                ProgressView()
                                    .controlSize(.small)
                            }
                        }
                        
                        if !matchService.hasAPIKey {
                            Text("To view live scores, click 'Settings…' below and enter a valid Highlightly or RapidAPI key.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .lineLimit(3)
                        }
                    }
                }
                
                // Additive: Today's Matches Expandable Section
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    Button(action: {
                        withAnimation {
                            isTodayMatchesExpanded.toggle()
                        }
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text("Today")
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.primary)
                                    
                                    Text("\(todaysMatchesList.count)")
                                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                                        .foregroundColor(matchAccent)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(matchAccent.opacity(0.12))
                                        .cornerRadius(5)
                                }
                                
                                if matchService.hasActiveMatchFilter {
                                    Text("Auto-pick: \(matchService.activeFilterLabel) · \(matchService.allMatches.count) prioritized")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            Image(systemName: isTodayMatchesExpanded ? "chevron.up" : "chevron.down")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    
                    if isTodayMatchesExpanded {
                        if todaysMatchesList.isEmpty {
                            todayEmptyState
                        } else {
                            // Fixed height ScrollView to prevent layout collapsing in accessory Extra window
                            ScrollView {
                                VStack(alignment: .leading, spacing: 12) {
                                    // 1. Live/Break Matches Section (treats stumps/tea sensibly)
                                    if !liveMatchesList.isEmpty {
                                        matchSection(title: "Live", matches: liveMatchesList)
                                    }
                                    
                                    // 2. Finished Matches Section
                                    if !finishedMatchesList.isEmpty {
                                        matchSection(title: "Finished", matches: finishedMatchesList)
                                    }
                                    
                                    // 3. Upcoming Matches Section
                                    if !upcomingMatchesList.isEmpty {
                                        matchSection(title: "Upcoming", matches: upcomingMatchesList)
                                    }
                                }
                                .padding(.trailing, 8)
                            }
                            .frame(height: max(110, min(CGFloat(todaysMatchesList.count * 54), 220)))
                        }
                    }
                }
                
                Divider()
                
                // Footer: Quota & Actions
                HStack(alignment: .center) {
                    // Quota Remaining & Active Poll Interval (Phase 5)
                    VStack(alignment: .leading, spacing: 2) {
                        if let quota = matchService.rateLimitRemaining {
                            Text("API: \(quota) left today")
                                .font(.footnote)
                                .foregroundColor(quota < 20 ? .red : .secondary)
                        } else {
                            Text("API: Unknown quota")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                        
                        Text("Poll Speed: \(Int(matchService.activePollInterval))s")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Refresh Button
                    Button(action: {
                        Task {
                            await matchService.fetchUpdates()
                        }
                    }) {
                        HStack(spacing: 4) {
                            if matchService.isFetching {
                                ProgressView()
                                    .controlSize(.small)
                                    .scaleEffect(0.7)
                            } else {
                                Image(systemName: "arrow.clockwise")
                                    .font(.caption)
                            }
                            Text("Refresh")
                        }
                    }
                    .disabled(matchService.isFetching || !matchService.hasAPIKey)
                    .buttonStyle(.borderedProminent)
                    .tint(matchAccent)
                    
                    // Settings Button (Toggles inline Settings panel)
                    Button("Settings…") {
                        NSApp.activate(ignoringOtherApps: true)
                        withAnimation {
                            showSettings = true
                        }
                    }
                    .buttonStyle(.bordered)
                    
                    // Quit Button
                    Button("Quit") {
                        NSApplication.shared.terminate(nil)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding(16)
        .frame(width: 365)
        .focusable()
        .focused($isFocused)
        .focusEffectDisabled()
        .onKeyPress { keyPress in
            if keyPress.key == .leftArrow || keyPress.key == .upArrow {
                cycleSelectedMatch(forward: false)
                return .handled
            } else if keyPress.key == .rightArrow || keyPress.key == .downArrow {
                cycleSelectedMatch(forward: true)
                return .handled
            }
            return .ignored
        }
        .onAppear {
            isFocused = true
            NSApp.activate(ignoringOtherApps: true)
        }
    }
    
    // MARK: - Match Section Helper
    
    private var matchAccent: Color {
        Color(red: 0.16, green: 0.43, blue: 0.28)
    }
    
    @ViewBuilder
    private var todayEmptyState: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                if matchService.isFetching {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: matchService.hasAPIKey ? "calendar.badge.clock" : "key.horizontal")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(matchAccent)
                }
                
                Text(matchService.isFetching ? "Checking today’s fixtures" : emptyTodayMessage)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
            
            if !matchService.hasAPIKey {
                Text("Add an API key in Settings.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else if !matchService.isFetching, let lastUpdatedAt = matchService.lastUpdatedAt {
                Text("Last checked: \(lastUpdatedAt.formatted(date: .omitted, time: .shortened))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.035))
        .cornerRadius(8)
    }
    
    private var emptyTodayMessage: String {
        matchService.hasAPIKey ? "No fixtures found for today" : "API key required"
    }

    private func teamBadge(_ abbreviation: String) -> some View {
        Text(abbreviation.isEmpty ? "TEAM" : abbreviation)
            .font(.system(size: 9, weight: .bold, design: .rounded))
            .foregroundColor(matchAccent)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(width: 42, alignment: .center)
            .padding(.vertical, 2)
            .background(matchAccent.opacity(0.12))
            .cornerRadius(4)
    }

    private func battersForPlayerCard(match: Match, details: DetailedInfo) -> [ActiveBatsman] {
        guard match.state == .finished else {
            return details.activeBatsmen
        }

        let candidates = details.topBatsmen
        let sorted = candidates.sorted {
            if $0.runs != $1.runs { return $0.runs > $1.runs }
            if $0.strikeRate != $1.strikeRate { return $0.strikeRate > $1.strikeRate }
            return $0.balls < $1.balls
        }

        return bestOnePerTeam(
            teamOrder: match.innings.map(\.teamShortName),
            candidates: sorted,
            team: { $0.teamAbbreviation },
            id: { $0.name },
            limit: 2
        )
    }

    private func bowlersForPlayerCard(match: Match, details: DetailedInfo) -> [ActiveBowler] {
        guard match.state == .finished else {
            return details.activeBowlers
        }

        let candidates = details.topBowlers
        let sorted = candidates.sorted {
            if $0.wickets != $1.wickets { return $0.wickets > $1.wickets }
            if $0.runsConceded != $1.runsConceded { return $0.runsConceded < $1.runsConceded }
            return $0.economy < $1.economy
        }

        return bestOnePerTeam(
            teamOrder: match.innings.map(\.teamShortName),
            candidates: sorted,
            team: { $0.teamAbbreviation },
            id: { $0.name },
            limit: 2
        )
    }

    private func bestOnePerTeam<T>(
        teamOrder: [String],
        candidates: [T],
        team: (T) -> String,
        id: (T) -> String,
        limit: Int
    ) -> [T] {
        var selected: [T] = []
        var selectedIDs = Set<String>()

        for teamAbbreviation in teamOrder {
            if let candidate = candidates.first(where: {
                team($0).caseInsensitiveCompare(teamAbbreviation) == .orderedSame &&
                !selectedIDs.contains(id($0))
            }) {
                selected.append(candidate)
                selectedIDs.insert(id(candidate))
            }
        }

        for candidate in candidates where selected.count < limit {
            guard !selectedIDs.contains(id(candidate)) else { continue }
            selected.append(candidate)
            selectedIDs.insert(id(candidate))
        }

        return Array(selected.prefix(limit))
    }

    @ViewBuilder
    private func selectedMatchScorePanel(for match: Match) -> some View {
        if match.state == .finished {
            finalScorecard(for: match)
        } else {
            liveScorePanel(for: match)
        }
    }

    private func liveScorePanel(for match: Match) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(match.innings, id: \.teamShortName) { innings in
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(innings.teamShortName)
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.bold)
                        .frame(width: 55, alignment: .leading)

                    Text(innings.scoreText)
                        .font(.body)

                    if let info = innings.infoText, !info.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("(\(info))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }

            if let projected = match.projectedScoreString {
                Text(projected)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                    .padding(.top, 2)
            }

            if let crr = match.currentRunRate, let rrr = match.requiredRunRate {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        runRateBar(title: "Current RR", value: crr, tint: .green)
                        runRateBar(title: "Required RR", value: rrr, tint: crr >= rrr ? .green : .orange)
                    }
                }
                .padding(.top, 4)
            }

            Text(match.heroNumberString)
                .font(.system(.body, design: .rounded))
                .fontWeight(.bold)
                .foregroundColor(matchAccent)
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .background(matchAccent.opacity(0.11))
                .cornerRadius(6)
                .padding(.top, 4)

            Text(match.statusText)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .italic()
                .padding(.top, 2)
        }
    }

    private func finalScorecard(for match: Match) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Final scorecard")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(.secondary)
                .textCase(.uppercase)

            ForEach(match.innings, id: \.teamShortName) { innings in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(innings.teamShortName)
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.bold)
                        .frame(width: 58, alignment: .leading)

                    Text(innings.scoreText)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    if let info = innings.infoText, !info.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("(\(info))")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            Text(match.statusText)
                .font(.system(.body, design: .rounded))
                .fontWeight(.bold)
                .foregroundColor(matchAccent)
                .lineLimit(2)
                .padding(.vertical, 7)
                .padding(.horizontal, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(matchAccent.opacity(0.11))
                .cornerRadius(6)
                .padding(.top, 4)
        }
    }

    private func runRateBar(title: String, value: Double, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer()
                Text(String(format: "%.2f", value))
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(tint)
            }
            ProgressView(value: min(max(value, 0), 15.0), total: 15.0)
                .progressViewStyle(.linear)
                .tint(tint)
                .scaleEffect(x: 1, y: 0.5, anchor: .center)
        }
    }
    
    @ViewBuilder
    private func matchSection(title: String, matches: [Match]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.secondary)
                .padding(.bottom, 2)
            
            ForEach(matches) { match in
                Button(action: {
                    selectedMatchID = match.id
                }) {
                    HStack(spacing: 9) {
                        // Radio dot indicating selection
                        Image(systemName: selectedMatchID == match.id ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(selectedMatchID == match.id ? matchAccent : .secondary)
                            .font(.caption)
                        
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                let homeAbbr = match.innings.first?.teamShortName ?? "T1"
                                let awayAbbr = match.innings.last?.teamShortName ?? "T2"
                                
                                Text("\(homeAbbr) vs \(awayAbbr)")
                                    .fontWeight(.semibold)
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                                
                                Text(match.format)
                                    .font(.system(size: 8, weight: .bold, design: .rounded))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(matchAccent.opacity(0.12))
                                    .foregroundColor(matchAccent)
                                    .cornerRadius(4)
                            }
                            
                            // Context-based subtitle
                            Group {
                                if match.state == .live || match.state == .onBreak {
                                    HStack(spacing: 5) {
                                        Text(scoresString(for: match))
                                        Circle()
                                            .fill(Color.green)
                                            .frame(width: 6, height: 6)
                                    }
                                } else if match.state == .finished {
                                    Text("\(scoresString(for: match)) · \(match.statusText)")
                                } else {
                                    Text("Starts \(formatStartTime(match.startTime))")
                                }
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                        }
                        
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
                .padding(.vertical, 7)
                .padding(.horizontal, 8)
                .background(
                    selectedMatchID == match.id ? matchAccent.opacity(0.09) :
                    (hoveredMatchID == match.id ? Color.primary.opacity(0.04) : Color.clear)
                )
                .cornerRadius(6)
                .contentShape(Rectangle())
                .onHover { isHovering in
                    if isHovering {
                        hoveredMatchID = match.id
                    } else if hoveredMatchID == match.id {
                        hoveredMatchID = nil
                    }
                }
            }
        }
    }
    
    private func cycleSelectedMatch(forward: Bool) {
        let list = matchService.todaysMatches.filter { $0.state == .live || $0.state == .onBreak } +
                   matchService.todaysMatches.filter { $0.state == .finished } +
                   matchService.todaysMatches.filter { $0.state == .scheduled }
        guard !list.isEmpty else { return }
        
        let currentIndex = list.firstIndex(where: { $0.id == selectedMatchID })
        let nextIndex: Int
        if let idx = currentIndex {
            if forward {
                nextIndex = (idx + 1) % list.count
            } else {
                nextIndex = (idx - 1 + list.count) % list.count
            }
        } else {
            nextIndex = 0
        }
        selectedMatchID = list[nextIndex].id
    }
    
    private func scoresString(for match: Match) -> String {
        let home = match.innings.first
        let away = match.innings.last
        let homeScore = home?.scoreText ?? "-"
        let awayScore = away?.scoreText ?? "-"
        let homeAbbr = home?.teamShortName ?? "T1"
        let awayAbbr = away?.teamShortName ?? "T2"
        return "\(homeAbbr) \(homeScore) / \(awayAbbr) \(awayScore)"
    }
    
    private func formatStartTime(_ isoString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        var date = formatter.date(from: isoString)
        if date == nil {
            let fallbackFormatter = ISO8601DateFormatter()
            fallbackFormatter.formatOptions = [.withInternetDateTime]
            date = fallbackFormatter.date(from: isoString)
        }
        
        guard let validDate = date else {
            if isoString.count >= 16 {
                return String(isoString.prefix(16).suffix(5)) // e.g. "14:30"
            }
            return isoString
        }
        
        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .none
        displayFormatter.timeStyle = .short
        displayFormatter.timeZone = TimeZone.current
        return displayFormatter.string(from: validDate)
    }
    
    private func parsePercent(_ percentStr: String?) -> Double? {
        guard let s = percentStr else { return nil }
        let clean = s.replacingOccurrences(of: "%", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        return Double(clean)
    }
}

// MARK: - Pulsing Live Indicator

struct LiveIndicatorView: View {
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(Color.green)
                .frame(width: 8, height: 8)
                .scaleEffect(isAnimating ? 1.3 : 1.0)
                .opacity(isAnimating ? 0.5 : 1.0)
                .animation(
                    Animation.easeInOut(duration: 0.8)
                        .repeatForever(autoreverses: true),
                    value: isAnimating
                )
            
            Text("LIVE")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(.green)
        }
        .onAppear {
            isAnimating = true
        }
    }
}
