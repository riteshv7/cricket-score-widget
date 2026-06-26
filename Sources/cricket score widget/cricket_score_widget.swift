import SwiftUI
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Programmatically hide the Dock icon so the app runs purely in the menu bar.
        NSApp.setActivationPolicy(.accessory)
    }
}

@main
struct CricketMenuBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    // Instantiate the polling service to fetch and manage live match data.
    @State private var matchService = MatchService()
    
    var body: some Scene {
        MenuBarExtra {
            DropdownView(matchService: matchService)
        } label: {
            // The live score label shown directly in the macOS menu bar.
            Text(matchService.menuBarTitle)
        }
        .menuBarExtraStyle(.window)
        
        // Phase 3: The Settings window scene
        Settings {
            SettingsView()
        }
    }
}

// MARK: - Settings View

struct SettingsView: View {
    // Persist API Key in UserDefaults via @AppStorage
    @AppStorage("apiKey") private var apiKey: String = ""
    
    // Persist Poll Interval in UserDefaults via @AppStorage
    @AppStorage("pollInterval") private var pollInterval: Double = 120.0
    
    // Phase 6: Persist Favorite Team in UserDefaults via @AppStorage
    @AppStorage("favoriteTeam") private var favoriteTeam: String = ""
    
    var body: some View {
        Form {
            VStack(alignment: .leading, spacing: 16) {
                // Section 1: API Key
                VStack(alignment: .leading, spacing: 6) {
                    Text("API Configuration")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    TextField("Paste your Highlightly or RapidAPI key here", text: $apiKey)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 340)
                    
                    Text("If empty, the app falls back to the key in Config.swift.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Divider()
                
                // Section 2: Favorite Team Selection (Phase 6)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Favorite Team (Auto-Select)")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    TextField("e.g. India, GT, AUS, ENG", text: $favoriteTeam)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 340)
                    
                    Text("Auto-selects the live match featuring this team if you haven't made a choice.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Divider()
                
                // Section 3: Poll Interval
                VStack(alignment: .leading, spacing: 6) {
                    Text("Refresh Speed")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Picker("Interval", selection: $pollInterval) {
                        Text("Relaxed (free plan) — 120s").tag(120.0)
                        Text("Live (paid plan) — 20s").tag(20.0)
                        Text("Death overs — 10s").tag(10.0)
                    }
                    .pickerStyle(.radioGroup)
                    
                    Text("Note: Faster polling speeds require a paid API subscription.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(20)
        }
        .frame(width: 380, height: 360)
        .navigationTitle("Cricket Widget Settings")
    }
}

// MARK: - Dropdown Window View

struct DropdownView: View {
    @Environment(\.openSettings) private var openSettings
    var matchService: MatchService
    
    // Phase 6: Bind selection to AppStorage so it persists automatically
    @AppStorage("selectedMatchID") private var selectedMatchID: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Phase 6: Multi-Match Switcher (collapses if <= 1 match is live)
            if matchService.liveMatches.count > 1 {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Live Matches")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(matchService.liveMatches) { liveMatch in
                            Button(action: {
                                selectedMatchID = liveMatch.id
                            }) {
                                HStack(spacing: 8) {
                                    // Radio-style selection indicator
                                    Image(systemName: selectedMatchID == liveMatch.id ? "record.circle" : "circle")
                                        .foregroundColor(selectedMatchID == liveMatch.id ? .blue : .secondary)
                                        .font(.subheadline)
                                    
                                    Text(liveMatch.name)
                                        .font(.subheadline)
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                    
                                    Spacer()
                                    
                                    // Format Badge
                                    Text(liveMatch.format)
                                        .font(.system(size: 9, weight: .bold, design: .rounded))
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 2)
                                        .background(Color.blue.opacity(0.15))
                                        .foregroundColor(.blue)
                                        .cornerRadius(4)
                                }
                                .padding(.vertical, 3)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                
                Divider()
            }
            
            // Selected Match Details
            if let match = matchService.currentMatch {
                // Header: Match Name and Live Indicator
                HStack(alignment: .center, spacing: 8) {
                    Text(match.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .lineLimit(2)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    if match.state == .live {
                        LiveIndicatorView()
                    }
                }
                
                Divider()
                
                // Scores for both teams
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
                }
                
                // Hero Number Block (Chase status, CRR, or completed report)
                Text(match.heroNumberString)
                    .font(.system(.body, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(6)
                    .padding(.top, 4)
                
                // Status Line
                Text(match.statusText)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .italic()
                    .padding(.top, 2)
                
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
                .tint(.blue)
                
                // Settings Button (Opens standard macOS Settings scene)
                Button("Settings…") {
                    NSApp.activate(ignoringOtherApps: true)
                    openSettings()
                }
                .buttonStyle(.bordered)
                
                // Quit Button
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(16)
        .frame(width: 345)
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
