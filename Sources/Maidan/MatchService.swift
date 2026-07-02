import Foundation
import Observation
import Combine
import AppKit
import UserNotifications
import ServiceManagement

@Observable
class MatchService {
    var menuBarTitle: String = "Loading..."
    var currentMatch: Match? = nil
    var liveMatches: [Match] = []
    var allMatches: [Match] = []
    var todaysMatches: [Match] = []
    var rateLimitRemaining: Int? = nil
    var isFetching: Bool = false
    var lastUpdatedAt: Date? = nil
    
    // Track the active poll interval so we can print and adapt in the UI
    var activePollInterval: TimeInterval = 120.0
    
    private let client = APIClient()
    private var timer: Timer? = nil
    private var cancellables = Set<AnyCancellable>()
    
    private var lastPollInterval: TimeInterval = 120.0
    private var lastApiKey: String = ""
    private var lastSelectedMatchID: String = ""
    private var lastFavoriteTeam: String = ""
    private var lastActiveInterval: TimeInterval = 120.0
    private var lastFilterMode: String = "major"
    private var lastMenuBarStyle: String = "compact"
    private var lastLaunchAtLogin: Bool = false
    private var lastFetchedRawMatches: [APIMatch] = []
    
    init() {
        // Cache initial values
        self.lastPollInterval = currentPollInterval()
        self.lastApiKey = currentApiKey()
        self.lastSelectedMatchID = currentSelectedMatchID()
        self.lastFavoriteTeam = currentFavoriteTeam()
        self.lastFilterMode = UserDefaults.standard.string(forKey: "matchFilterMode") ?? "major"
        self.lastMenuBarStyle = UserDefaults.standard.string(forKey: "menuBarStyle") ?? "compact"
        self.lastLaunchAtLogin = UserDefaults.standard.bool(forKey: "launchAtLogin")
        self.lastActiveInterval = calculateActiveInterval()
        self.activePollInterval = self.lastActiveInterval
        
        requestNotificationAuthorization()
        startPolling()
        setupSettingsObserver()
        setupWorkspaceNotifications()
        setupBatteryObserver()
    }
    
    /// Helper to read the active API key
    func currentApiKey() -> String {
        let stored = UserDefaults.standard.string(forKey: "apiKey") ?? ""
        if stored.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return Config.highlightlyAPIKey
        }
        return stored
    }
    
    /// Helper to check if a valid API key is present
    var hasAPIKey: Bool {
        let key = currentApiKey()
        return !key.isEmpty && key != "PASTE_YOUR_KEY_HERE"
    }
    
    var activeFilterLabel: String {
        switch UserDefaults.standard.string(forKey: "matchFilterMode") ?? "major" {
        case "all":
            return "All"
        case "ipl":
            return "IPL"
        case "intl":
            return "International"
        case "major":
            fallthrough
        default:
            return "Major"
        }
    }
    
    var hasActiveMatchFilter: Bool {
        (UserDefaults.standard.string(forKey: "matchFilterMode") ?? "major") != "all"
    }
    
    /// Helper to read the active poll interval
    func currentPollInterval() -> TimeInterval {
        let stored = UserDefaults.standard.double(forKey: "pollInterval")
        return stored > 0 ? stored : Config.pollInterval
    }
    
    /// Helper to read the user-selected match ID
    func currentSelectedMatchID() -> String {
        return UserDefaults.standard.string(forKey: "selectedMatchID") ?? ""
    }
    
    /// Helper to read the favorite team
    func currentFavoriteTeam() -> String {
        return UserDefaults.standard.string(forKey: "favoriteTeam") ?? ""
    }
    
    /// Calculates the active poll interval based on settings, match state, and battery status
    func calculateActiveInterval() -> TimeInterval {
        let base = currentPollInterval()
        
        // 1. If no live match is selected or found, slow down to 5 minutes (300s)
        guard let match = currentMatch else {
            return max(base, 300.0)
        }
        
        // 2. If the match is finished, scheduled, or on break, slow down to 5 minutes (300s)
        if match.state == .finished || match.state == .scheduled || match.state == .onBreak {
            return max(base, 300.0)
        }
        
        // 3. Innings break check (state is live but second innings yet to start)
        let desc = match.statusText.lowercased()
        if desc.contains("innings break") || desc.contains("break") {
            return max(base, 300.0)
        }
        
        var interval = base
        
        // 4. Tight finish check (chase and ballsRemaining <= 18 or runsNeeded <= 24)
        if match.isChase, let targetVal = match.target, let active = match.activeInnings {
            let runs = Match.parseRuns(from: active.scoreText) ?? 0
            let runsNeeded = targetVal - runs
            
            if let info = active.infoText,
               let oversVal = Match.parseOvers(from: info),
               let limit = Match.parseOversLimit(from: info) {
                let totalBalls = limit * 6
                let bowled = Match.ballsBowled(from: oversVal)
                let ballsRemaining = max(0, totalBalls - bowled)
                
                let isTightFinish = ballsRemaining <= 18 || runsNeeded <= 24
                
                if isTightFinish {
                    // Quota Guard: only poll faster if they are NOT on the free tier (base >= 120s)
                    if base < 120.0 {
                        interval = 10.0 // Tighten to 10s for paid tier
                    }
                }
            }
        }
        
        // 5. Battery / Low Power Mode backoff
        if ProcessInfo.processInfo.isLowPowerModeEnabled {
            interval = max(interval * 2.0, 120.0) // Double interval, min 120s
        }
        
        return interval
    }
    
    /// Starts the background polling timer
    func startPolling() {
        stopPolling()
        
        // If no API key is configured, show setup message and skip timer
        guard hasAPIKey else {
            self.currentMatch = nil
            self.liveMatches = []
            self.todaysMatches = []
            self.menuBarTitle = "Set API key in Settings"
            return
        }
        
        // Fetch immediately
        Task {
            await fetchUpdates()
        }
        
        let interval = calculateActiveInterval()
        self.lastActiveInterval = interval
        self.activePollInterval = interval
        
        // Setup repeating timer (runs on main thread)
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { [weak self] in
                await self?.fetchUpdates()
            }
        }
    }
    
    /// Stops the polling timer
    func stopPolling() {
        timer?.invalidate()
        timer = nil
    }
    
    /// Listens to UserDefaults changes in real-time
    private func setupSettingsObserver() {
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.handleSettingsChange()
            }
            .store(in: &cancellables)
    }
    
    /// Reacts to changes in settings or user selections
    private func handleSettingsChange() {
        let newInterval = currentPollInterval()
        let newKey = currentApiKey()
        let newSelectedID = currentSelectedMatchID()
        let newFavTeam = currentFavoriteTeam()
        let newFilterMode = UserDefaults.standard.string(forKey: "matchFilterMode") ?? "major"
        let newStyle = UserDefaults.standard.string(forKey: "menuBarStyle") ?? "compact"
        let newLaunchAtLogin = UserDefaults.standard.bool(forKey: "launchAtLogin")
        
        var needsRestart = false
        var needsImmediateFetch = false
        var needsProcess = false
        
        if newInterval != lastPollInterval {
            lastPollInterval = newInterval
            needsRestart = true
        }
        
        if newKey != lastApiKey {
            lastApiKey = newKey
            needsImmediateFetch = true
            needsRestart = true
        }
        
        if newSelectedID != lastSelectedMatchID {
            lastSelectedMatchID = newSelectedID
            needsProcess = true
        }
        
        if newFavTeam != lastFavoriteTeam {
            lastFavoriteTeam = newFavTeam
            needsProcess = true
        }
        
        if newFilterMode != lastFilterMode {
            lastFilterMode = newFilterMode
            needsProcess = true
        }
        
        if newStyle != lastMenuBarStyle {
            lastMenuBarStyle = newStyle
            needsProcess = true
        }
        
        if newLaunchAtLogin != lastLaunchAtLogin {
            lastLaunchAtLogin = newLaunchAtLogin
            updateLaunchAtLogin(enabled: newLaunchAtLogin)
        }
        
        if needsRestart {
            startPolling()
        } else if needsImmediateFetch && hasAPIKey {
            Task {
                await self.fetchUpdates()
            }
        } else if needsProcess {
            processMatches(self.lastFetchedRawMatches, rateLimitRemaining: nil)
        }
    }
    
    /// Listen to Mac Sleep and Wake notifications
    private func setupWorkspaceNotifications() {
        let nc = NSWorkspace.shared.notificationCenter
        
        nc.publisher(for: NSWorkspace.willSleepNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                print("MatchService: Mac is going to sleep. Pausing polling to conserve resources.")
                self?.stopPolling()
                self?.menuBarTitle = "Sleeping..."
            }
            .store(in: &cancellables)
        
        nc.publisher(for: NSWorkspace.didWakeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                print("MatchService: Mac woke up. Resuming polling.")
                self?.startPolling()
            }
            .store(in: &cancellables)
    }
    
    /// Listen to Low Power Mode state changes
    private func setupBatteryObserver() {
        NotificationCenter.default.publisher(for: Notification.Name.NSProcessInfoPowerStateDidChange)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                print("MatchService: Power state changed. Re-evaluating polling speed.")
                self?.startPolling()
            }
            .store(in: &cancellables)
    }
    
    /// Performs the fetch and updates the state
    func fetchUpdates() async {
        guard hasAPIKey else {
            await MainActor.run {
                self.currentMatch = nil
                self.liveMatches = []
                self.allMatches = []
                self.todaysMatches = []
                self.menuBarTitle = "Set API key in Settings"
            }
            return
        }
        
        guard !isFetching else { return }
        
        await MainActor.run {
            isFetching = true
        }
        
        do {
            let result = try await client.fetchMatchesForToday()
            
            // Lazy detailed fetch for the selected match to conserve quota.
            // Live matches use it for active players; finished matches use it for top performers.
            let selectedId = currentSelectedMatchID()
            let favTeam = currentFavoriteTeam()
            
            let apiMatchesToUse = filterMatches(result.rawMatches)
            let selectionMatches = result.rawMatches.contains(where: { $0.id == selectedId }) ? result.rawMatches : apiMatchesToUse
            let selectionResult = MatchSelector.selectMatch(
                from: selectionMatches,
                selectedMatchID: selectedId,
                favoriteTeam: favTeam
            )
            
            var detailedInfo: DetailedInfo? = nil
            if let selectedMatch = selectionResult.selectedMatch {
                let shouldFetchDetail = selectedMatch.state == .live ||
                    selectedMatch.state == .onBreak ||
                    selectedMatch.state == .finished
                
                if shouldFetchDetail {
                    do {
                        detailedInfo = try await client.fetchMatchDetail(id: selectedMatch.id)
                    } catch {
                        print("MatchService: Detailed fetch failed for match \(selectedMatch.id): \(error)")
                    }
                }
            }
            
            processMatches(result.rawMatches, rateLimitRemaining: result.rateLimitRemaining, activeMatchDetail: detailedInfo)
        } catch {
            print("MatchService: Fetch failed with error: \(error)")
            
            await MainActor.run {
                self.isFetching = false
                self.lastUpdatedAt = Date()
                if self.currentMatch == nil {
                    self.menuBarTitle = "—"
                }
            }
        }
    }
    
    /// Processes and filters the raw matches, then updates the observable state on the MainActor
    func processMatches(_ rawMatches: [APIMatch], rateLimitRemaining: Int?, activeMatchDetail: DetailedInfo? = nil) {
        self.lastFetchedRawMatches = rawMatches
        
        let apiMatchesToUse = filterMatches(rawMatches)
        
        let liveAPIMatches = apiMatchesToUse.filter {
            let state = MatchSelector.classify($0.state.description)
            return state == .live || state == .onBreak
        }
        var domainLiveMatches = liveAPIMatches.map { $0.toDomain() }
        var domainAllMatches = apiMatchesToUse.map { $0.toDomain() } // respect the active filter in dropdown list
        let domainTodaysMatches = rawMatches
            .sorted { $0.startTime < $1.startTime }
            .map { $0.toDomain() }
        
        let selectedId = currentSelectedMatchID()
        let favTeam = currentFavoriteTeam()
        let selectionMatches = rawMatches.contains(where: { $0.id == selectedId }) ? rawMatches : apiMatchesToUse
        
        let selectionResult = MatchSelector.selectMatch(
            from: selectionMatches,
            selectedMatchID: selectedId,
            favoriteTeam: favTeam
        )
        
        // Compare with previous state to trigger notifications before updating currentMatch
        var newMatch = selectionResult.selectedMatch
        
        if let detail = activeMatchDetail, let activeMatchVal = newMatch {
            let enrichedMatch = activeMatchVal.withDetailedInfo(detail)
            newMatch = enrichedMatch
            
            if let index = domainLiveMatches.firstIndex(where: { $0.id == enrichedMatch.id }) {
                domainLiveMatches[index] = enrichedMatch
            }
            if let index = domainAllMatches.firstIndex(where: { $0.id == enrichedMatch.id }) {
                domainAllMatches[index] = enrichedMatch
            }
        }
        if let newMatch = newMatch {
            if let oldMatch = self.currentMatch, oldMatch.id == newMatch.id {
                // 1. Wicket Check
                for newInnings in newMatch.innings {
                    if let oldInnings = oldMatch.innings.first(where: { $0.teamShortName == newInnings.teamShortName }) {
                        if let newW = Match.parseWickets(from: newInnings.scoreText),
                           let oldW = Match.parseWickets(from: oldInnings.scoreText) {
                            if newW > oldW {
                                sendNotification(
                                    title: "WICKET! 🏏",
                                    body: "\(newInnings.teamShortName) is now \(newInnings.scoreText) (\(newMatch.name))"
                                )
                            }
                        }
                    }
                }
                
                // 2. Boundary Alerts (4/6) (Phase 10)
                for newInnings in newMatch.innings {
                    if let oldInnings = oldMatch.innings.first(where: { $0.teamShortName == newInnings.teamShortName }) {
                        if let newRuns = Match.parseRuns(from: newInnings.scoreText),
                           let oldRuns = Match.parseRuns(from: oldInnings.scoreText) {
                            let diff = newRuns - oldRuns
                            if diff == 4 {
                                sendNotification(
                                    title: "FOUR! 🏏🔥",
                                    body: "Boundary! \(newInnings.teamShortName) hits a 4. Now \(newInnings.scoreText) (\(newMatch.name))"
                                )
                            } else if diff == 6 {
                                sendNotification(
                                    title: "SIX! 🏏🚀",
                                    body: "Maximum! \(newInnings.teamShortName) hits a 6. Now \(newInnings.scoreText) (\(newMatch.name))"
                                )
                            }
                        }
                    }
                }
                
                // 3. Innings Break Check (Phase 10)
                let oldStatus = oldMatch.statusText.lowercased()
                let newStatus = newMatch.statusText.lowercased()
                let isOldBreak = oldStatus.contains("innings break") || oldStatus.contains("break")
                let isNewBreak = newStatus.contains("innings break") || newStatus.contains("break")
                if !isOldBreak && isNewBreak {
                    sendNotification(
                        title: "Innings Break 🏏",
                        body: "\(newMatch.name): \(newMatch.statusText)"
                    )
                }
                
                // 4. Close Finish Check (Phase 10)
                if newMatch.isChase {
                    if let active = newMatch.activeInnings,
                       let runs = Match.parseRuns(from: active.scoreText),
                       let targetVal = newMatch.target,
                       let info = active.infoText,
                       let oversVal = Match.parseOvers(from: info),
                       let limit = Match.parseOversLimit(from: info) {
                        
                        let totalBalls = limit * 6
                        let bowled = Match.ballsBowled(from: oversVal)
                        let ballsRemaining = max(0, totalBalls - bowled)
                        let runsNeeded = targetVal - runs
                        
                        let isCloseFinish = ballsRemaining > 0 && ballsRemaining <= 18 && runsNeeded > 0 && runsNeeded <= 24
                        
                        var wasCloseFinishBefore = false
                        if let oldActive = oldMatch.activeInnings,
                           let oldRuns = Match.parseRuns(from: oldActive.scoreText),
                           let oldInfo = oldActive.infoText,
                           let oldOvers = Match.parseOvers(from: oldInfo) {
                            
                            let oldBowled = Match.ballsBowled(from: oldOvers)
                            let oldBallsRemaining = max(0, totalBalls - oldBowled)
                            let oldRunsNeeded = targetVal - oldRuns
                            wasCloseFinishBefore = oldBallsRemaining > 0 && oldBallsRemaining <= 18 && oldRunsNeeded > 0 && oldRunsNeeded <= 24
                        }
                        
                        if isCloseFinish && !wasCloseFinishBefore {
                            sendNotification(
                                title: "TENSE FINISH! 🚨🏏",
                                body: "\(newMatch.name): Need \(runsNeeded) runs off \(ballsRemaining) balls!"
                            )
                        }
                    }
                }
                
                // 5. Match Completed Check
                if oldMatch.state != .finished && newMatch.state == .finished {
                    sendNotification(
                        title: "Match Finished 🏆",
                        body: "\(newMatch.name): \(newMatch.statusText)"
                    )
                }
            } else if self.currentMatch == nil || self.currentMatch?.id != newMatch.id {
                // 3. Favorite Team Match Starts Check
                let favLower = currentFavoriteTeam().lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                if !favLower.isEmpty {
                    let favTeams = favLower.components(separatedBy: ",")
                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                        .filter { !$0.isEmpty }
                    
                    let featuresFav = favTeams.contains { fav in
                        newMatch.name.lowercased().contains(fav) ||
                        newMatch.innings.contains { $0.teamShortName.lowercased().contains(fav) }
                    }
                    if featuresFav && newMatch.state == .live {
                        sendNotification(
                            title: "Match Live! 🏏",
                            body: "\(newMatch.name) is now live!"
                        )
                    }
                }
            }
        }
        
        DispatchQueue.main.async {
            if let rateLimitRemaining = rateLimitRemaining {
                self.rateLimitRemaining = rateLimitRemaining
            }
            self.liveMatches = domainLiveMatches
            self.allMatches = domainAllMatches
            self.todaysMatches = domainTodaysMatches
            self.currentMatch = newMatch
            self.lastUpdatedAt = Date()
            
            if selectionResult.clearedStaleSelection {
                UserDefaults.standard.set("", forKey: "selectedMatchID")
                self.lastSelectedMatchID = ""
            }
            
            // Format Menu Bar Title dynamically based on Style setting
            let style = UserDefaults.standard.string(forKey: "menuBarStyle") ?? "compact"
            self.menuBarTitle = self.formatMenuBarTitle(for: newMatch, style: style)
            
            self.isFetching = false
            
            // Adaptive Polling Check
            let newAdaptiveInterval = self.calculateActiveInterval()
            self.activePollInterval = newAdaptiveInterval
            if newAdaptiveInterval != self.lastActiveInterval {
                print("MatchService: Adaptive interval adapted to \(newAdaptiveInterval)s based on game state. Rescheduling timer.")
                self.lastActiveInterval = newAdaptiveInterval
                self.startPolling()
            }
        }
    }
    
    /// Helper to format the menu bar title based on selected style
    private func formatMenuBarTitle(for match: Match?, style: String) -> String {
        guard let match = match else {
            return style == "minimal" ? "🏏" : "No live match"
        }
        
        if match.state == .finished, style != "minimal" {
            return finishedMenuBarScoreboard(for: match)
        }

        switch style {
        case "minimal":
            return match.state == .live ? "🏏 🟢" : "🏏"
        case "compact":
            return match.menuBarTitleString
        case "full":
            return match.titleString
        default:
            return match.menuBarTitleString
        }
    }

    private func finishedMenuBarScoreboard(for match: Match) -> String {
        let scoredInnings = match.innings.prefix(2).map { innings in
            "\(innings.teamShortName) \(innings.scoreText)"
        }

        guard !scoredInnings.isEmpty else {
            return match.statusText
        }

        return scoredInnings.joined(separator: " · ")
    }
    
    /// Static helper to check if a match is an IPL match or involving IPL franchises
    static func isIPLMatch(
        homeName: String, homeAbbr: String,
        awayName: String, awayAbbr: String,
        leagueName: String
    ) -> Bool {
        let home = homeName.lowercased()
        let away = awayName.lowercased()
        let league = leagueName.lowercased()
        
        return league.contains("ipl") || league.contains("premier league") || league.contains("indian premier") ||
               home.contains("indians") || away.contains("indians") || // MI
               home.contains("super kings") || away.contains("super kings") || // CSK
               home.contains("challengers") || away.contains("challengers") || // RCB
               home.contains("knight riders") || away.contains("knight riders") || // KKR
               home.contains("capitals") || away.contains("capitals") || // DC
               home.contains("royals") || away.contains("royals") || // RR
               home.contains("kings") || away.contains("kings") || // PBKS
               home.contains("sunrisers") || away.contains("sunrisers") || // SRH
               home.contains("titans") || away.contains("titans") || // GT
               home.contains("super giants") || away.contains("super giants") // LSG
    }
    
    /// Static helper to check if a match is an International match between major national teams
    static func isInternationalMatch(
        homeName: String, homeAbbr: String,
        awayName: String, awayAbbr: String,
        leagueName: String
    ) -> Bool {
        let home = homeName.lowercased()
        let away = awayName.lowercased()
        let league = leagueName.lowercased()
        
        let nationalTeams = [
            "australia", "england", "new zealand", "south africa", "pakistan",
            "west indies", "sri lanka", "bangladesh", "zimbabwe", "ireland",
            "afghanistan", "scotland", "netherlands", "nepal", "uae", "namibia",
            "oman", "canada", "usa", "united states", "papua new guinea", "png",
            "uganda", "kenya", "jersey", "hong kong", "netherlands women",
            "australia women", "england women", "new zealand women", "south africa women",
            "pakistan women", "west indies women", "sri lanka women", "bangladesh women",
            "india women", "india", "scotland women", "ireland women", "thailand women",
            "zimbabwe women", "papua new guinea women", "usa women", "netherlands women"
        ]
        
        let nationalAbbrs = [
            "AUS", "ENG", "NZ", "SA", "PAK", "WI", "SL", "BAN", "ZIM", "IRE",
            "AFG", "SCO", "NED", "NEP", "UAE", "NAM", "OMA", "CAN", "USA", "PNG",
            "UGA", "KEN"
        ]
        
        let isHomeNational = nationalTeams.contains { home.contains($0) } || nationalAbbrs.contains { homeAbbr.uppercased().hasPrefix($0) }
        let isAwayNational = nationalTeams.contains { away.contains($0) } || nationalAbbrs.contains { awayAbbr.uppercased().hasPrefix($0) }
        
        if isHomeNational && isAwayNational {
            return true
        }
        
        if league.contains("world cup") || league.contains("asia cup") ||
           league.contains("champions trophy") || league.contains("ashes") ||
           league.contains("test championship") || league.contains("bilateral") ||
           league.contains("international") {
            return true
        }
        
        return false
    }
    
    /// Static helper to determine if a match is a major match (IPL, India game, or major international fixture)
    static func isMajorMatch(
        homeName: String, homeAbbr: String,
        awayName: String, awayAbbr: String,
        leagueName: String
    ) -> Bool {
        let home = homeName.lowercased()
        let away = awayName.lowercased()
        let homeAbbrUpper = homeAbbr.uppercased()
        let awayAbbrUpper = awayAbbr.uppercased()
        
        // 1. India games (National, A, Women, U19, etc.)
        if home.contains("india") || away.contains("india") ||
           homeAbbrUpper.hasPrefix("IND") || awayAbbrUpper.hasPrefix("IND") {
            return true
        }
        
        // 2. IPL games
        if isIPLMatch(homeName: homeName, homeAbbr: homeAbbr, awayName: awayName, awayAbbr: awayAbbr, leagueName: leagueName) {
            return true
        }
        
        // 3. International Men's and Women's Games
        if isInternationalMatch(homeName: homeName, homeAbbr: homeAbbr, awayName: awayName, awayAbbr: awayAbbr, leagueName: leagueName) {
            return true
        }
        
        return false
    }
    
    /// Helper to filter raw matches based on the current matchFilterMode setting in UserDefaults
    private func filterMatches(_ matches: [APIMatch]) -> [APIMatch] {
        let filterMode = UserDefaults.standard.string(forKey: "matchFilterMode") ?? "major"
        switch filterMode {
        case "all":
            return matches
        case "ipl":
            return matches.filter { apiMatch in
                MatchService.isIPLMatch(
                    homeName: apiMatch.homeTeam.name,
                    homeAbbr: apiMatch.homeTeam.abbreviation,
                    awayName: apiMatch.awayTeam.name,
                    awayAbbr: apiMatch.awayTeam.abbreviation,
                    leagueName: apiMatch.league?.name ?? ""
                )
            }
        case "intl":
            return matches.filter { apiMatch in
                MatchService.isInternationalMatch(
                    homeName: apiMatch.homeTeam.name,
                    homeAbbr: apiMatch.homeTeam.abbreviation,
                    awayName: apiMatch.awayTeam.name,
                    awayAbbr: apiMatch.awayTeam.abbreviation,
                    leagueName: apiMatch.league?.name ?? ""
                )
            }
        case "major":
            fallthrough
        default:
            return matches.filter { apiMatch in
                MatchService.isMajorMatch(
                    homeName: apiMatch.homeTeam.name,
                    homeAbbr: apiMatch.homeTeam.abbreviation,
                    awayName: apiMatch.awayTeam.name,
                    awayAbbr: apiMatch.awayTeam.abbreviation,
                    leagueName: apiMatch.league?.name ?? ""
                )
            }
        }
    }
    
    // MARK: - User Notifications & Launch at Login Helpers
    
    /// Requests local notification permissions on app launch
    private func requestNotificationAuthorization() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                print("MatchService: Notification authorization failed: \(error)")
            } else {
                print("MatchService: Notification authorization status: \(granted)")
            }
        }
    }
    
    /// Triggers a native macOS local notification immediately
    private func sendNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = UNNotificationSound.default
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil // Deliver immediately
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("MatchService: Failed to deliver notification: \(error)")
            }
        }
    }
    
    /// Updates launch at login status natively via SMAppService
    private func updateLaunchAtLogin(enabled: Bool) {
        if #available(macOS 13.0, *) {
            let service = SMAppService.mainApp
            if enabled {
                if service.status != .enabled {
                    do {
                        try service.register()
                        print("MatchService: Registered launch at login successfully.")
                    } catch {
                        print("MatchService: Failed to register launch at login: \(error)")
                    }
                }
            } else {
                if service.status == .enabled {
                    do {
                        try service.unregister()
                        print("MatchService: Unregistered launch at login successfully.")
                    } catch {
                        print("MatchService: Failed to unregister launch at login: \(error)")
                    }
                }
            }
        } else {
            print("MatchService: Launch at login via SMAppService requires macOS 13.0 or later.")
        }
    }
}
