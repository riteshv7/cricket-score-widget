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
    }
}

// MARK: - Dropdown Window View

struct DropdownView: View {
    var matchService: MatchService
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
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
                                .frame(width: 50, alignment: .leading)
                            
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
                
                // Status Line
                Text(match.statusText)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .italic()
                    .padding(.top, 2)
                
            } else {
                // Loading / Empty State
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
            }
            
            Divider()
            
            // Footer: Quota & Actions
            HStack(alignment: .center) {
                // Quota Remaining
                if let quota = matchService.rateLimitRemaining {
                    Text("API: \(quota) left today")
                        .font(.footnote)
                        .foregroundColor(quota < 20 ? .red : .secondary)
                } else {
                    Text("API: Unknown quota")
                        .font(.footnote)
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
                        Text("Refresh now")
                    }
                }
                .disabled(matchService.isFetching)
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                
                // Quit Button
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(16)
        .frame(width: 320)
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
