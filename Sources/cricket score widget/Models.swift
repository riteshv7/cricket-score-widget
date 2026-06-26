import Foundation

// MARK: - Domain Models

enum MatchState: String, Codable {
    case scheduled
    case live
    case onBreak       // stumps / tea / innings break, etc.
    case finished
    case noData
}

struct Innings: Codable {
    let teamShortName: String   // from homeTeam/awayTeam.abbreviation, e.g. "IND"
    let scoreText: String       // raw "181/5" (or "261 & 8/1" for Tests) — display as-is in v1
    let infoText: String?       // raw "19.4/20 ov, T:181" — display as-is in v1
}

struct Match: Codable, Identifiable {
    let id: String
    let name: String            // build from homeTeam.name + " vs " + awayTeam.name
    let format: String          // "T20", "ODI", "TEST"
    let statusText: String      // state.report (fallback to state.description)
    let innings: [Innings]      // home + away
    let state: MatchState

    /// Helper to find the active batting/live team's innings
    var activeInnings: Innings? {
        guard innings.count >= 2 else { return innings.first }
        let home = innings[0]
        let away = innings[1]
        
        let homeHasInfo = home.infoText != nil && !home.infoText!.isEmpty
        let awayHasInfo = away.infoText != nil && !away.infoText!.isEmpty
        
        if homeHasInfo && !awayHasInfo {
            return home
        } else if awayHasInfo && !homeHasInfo {
            return away
        }
        
        let homeHasOvers = home.infoText?.lowercased().contains("ov") ?? false
        let awayHasOvers = away.infoText?.lowercased().contains("ov") ?? false
        
        if homeHasOvers && !awayHasOvers {
            return home
        } else if awayHasOvers && !homeHasOvers {
            return away
        }
        
        // If we still can't tell, check if home has a score and away doesn't
        let homeHasScore = home.scoreText != "-" && home.scoreText != "null"
        let awayHasScore = away.scoreText != "-" && away.scoreText != "null"
        
        if homeHasScore && !awayHasScore {
            return home
        } else if awayHasScore && !homeHasScore {
            return away
        }
        
        return home
    }

    /// Title string formatted for the menu bar and console output, e.g. "GT 181/5 (19.4/20 ov, T:181)"
    /// If there is no active score, displays abbreviation with status, e.g. "SL-E · In play"
    var titleString: String {
        guard let active = activeInnings else {
            return "No live score"
        }
        
        let hasScore = active.scoreText != "-" && !active.scoreText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        
        if !hasScore {
            return "\(active.teamShortName) · \(statusText)"
        }
        
        if let info = active.infoText, !info.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "\(active.teamShortName) \(active.scoreText) (\(info))"
        } else {
            return "\(active.teamShortName) \(active.scoreText)"
        }
    }

    /// Short title string for the menu bar label, e.g. "IND-A 395/5" or "SL-E · In play"
    /// Keeps it short by only showing abbreviation + score, omitting overs/format.
    var menuBarTitleString: String {
        guard let active = activeInnings else {
            return "No live score"
        }
        
        let hasScore = active.scoreText != "-" && !active.scoreText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        
        if !hasScore {
            return "\(active.teamShortName) · \(statusText)"
        }
        
        return "\(active.teamShortName) \(active.scoreText)"
    }

    // MARK: - Phase 4 Chase Math & Hero Number

    // Parse runs from a score string like "181/5" or "180"
    static func parseRuns(from scoreText: String) -> Int? {
        let clean = scoreText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard clean != "-" && clean != "null" && !clean.isEmpty else { return nil }
        let components = clean.split(separator: "/")
        if let first = components.first, let runs = Int(first.trimmingCharacters(in: .whitespacesAndNewlines)) {
            return runs
        }
        return nil
    }

    // Extract the active overs double from info string, e.g. "19.4/20 ov, T:181" -> 19.4
    static func parseOvers(from infoText: String) -> Double? {
        let cleanInfo = infoText.lowercased()
        var oversPart = cleanInfo
        if let ovRange = cleanInfo.range(of: "ov") {
            oversPart = String(cleanInfo[..<ovRange.lowerBound])
        }
        if let slashRange = oversPart.range(of: "/") {
            oversPart = String(oversPart[..<slashRange.lowerBound])
        }
        let trimmed = oversPart.trimmingCharacters(in: .whitespacesAndNewlines)
        return Double(trimmed)
    }

    // Extract the target from info string, e.g. "T:181" -> 181
    static func parseTarget(from infoText: String) -> Int? {
        let cleanInfo = infoText.lowercased()
        guard let tRange = cleanInfo.range(of: "t:") else { return nil }
        let afterT = cleanInfo[tRange.upperBound...]
        var digitString = ""
        for char in afterT {
            if char.isNumber {
                digitString.append(char)
            } else if !digitString.isEmpty {
                break
            }
        }
        return Int(digitString)
    }

    // Extract total overs limit from info string, e.g. "19.4/20 ov" -> 20
    static func parseOversLimit(from infoText: String) -> Int? {
        let cleanInfo = infoText.lowercased()
        guard let ovRange = cleanInfo.range(of: "ov") else { return nil }
        let beforeOv = String(cleanInfo[..<ovRange.lowerBound])
        guard let slashRange = beforeOv.range(of: "/") else { return nil }
        let afterSlash = beforeOv[slashRange.upperBound...]
        var digitString = ""
        for char in afterSlash {
            if char.isNumber {
                digitString.append(char)
            } else if !digitString.isEmpty {
                break
            }
        }
        return Int(digitString)
    }

    // Calculate balls bowled from overs double using base-6
    static func ballsBowled(from overs: Double) -> Int {
        let wholeOvers = Int(overs)
        let decimalPart = Int(round((overs - Double(wholeOvers)) * 10))
        return (wholeOvers * 6) + decimalPart
    }

    /// Determines if it's a chase
    var isChase: Bool {
        if target != nil { return true }
        
        guard innings.count >= 2 else { return false }
        let home = innings[0]
        let away = innings[1]
        
        let homeHasScore = home.scoreText != "-" && home.scoreText != "null"
        let awayHasScore = away.scoreText != "-" && away.scoreText != "null"
        
        let homeActive = home.infoText?.lowercased().contains("ov") ?? false
        let awayActive = away.infoText?.lowercased().contains("ov") ?? false
        
        if homeHasScore && awayHasScore {
            return homeActive || awayActive
        }
        return false
    }

    /// Gets or computes the target score (e.g. 181)
    var target: Int? {
        for inn in innings {
            if let info = inn.infoText, let t = Match.parseTarget(from: info) {
                return t
            }
        }
        
        guard innings.count >= 2 else { return nil }
        let home = innings[0]
        let away = innings[1]
        
        let homeActive = home.infoText?.lowercased().contains("ov") ?? false
        let awayActive = away.infoText?.lowercased().contains("ov") ?? false
        
        if homeActive && !awayActive {
            if let awayRuns = Match.parseRuns(from: away.scoreText) {
                return awayRuns + 1
            }
        } else if awayActive && !homeActive {
            if let homeRuns = Match.parseRuns(from: home.scoreText) {
                return homeRuns + 1
            }
        }
        return nil
    }

    /// The hero number / chase status / run rate string to display prominently
    var heroNumberString: String {
        // Rule 1: Never run chase/run-rate math on a TEST match
        if format == "TEST" {
            return statusText
        }
        
        // Rule 2: Completed / Finished -> state.report (statusText)
        if state == .finished {
            return statusText
        }
        
        // Check if we have active innings and can parse scores
        guard let active = activeInnings else {
            return statusText
        }
        
        let isLive = state == .live || state == .onBreak
        guard isLive else {
            return statusText
        }
        
        let runs = Match.parseRuns(from: active.scoreText)
        let overs = active.infoText.flatMap { Match.parseOvers(from: $0) }
        
        let targetVal = target
        let isChasing = isChase
        
        if isChasing, let targetVal = targetVal {
            let currentRuns = runs ?? 0
            let runsNeeded = targetVal - currentRuns
            
            if let info = active.infoText,
               let oversVal = overs,
               let limit = Match.parseOversLimit(from: info) {
                let totalBalls = limit * 6
                let bowled = Match.ballsBowled(from: oversVal)
                let ballsRemaining = max(0, totalBalls - bowled)
                
                let rrr: String
                if ballsRemaining > 0 {
                    let rrrVal = Double(runsNeeded) * 6.0 / Double(ballsRemaining)
                    rrr = String(format: "%.2f", rrrVal)
                } else {
                    rrr = "—"
                }
                
                return "Need \(runsNeeded) (\(ballsRemaining) balls) · RRR: \(rrr)"
            }
            return "Need \(runsNeeded) runs · Target: \(targetVal)"
        }
        
        let desc = statusText.lowercased()
        if desc.contains("innings break") || desc.contains("break") {
            if let targetVal = targetVal {
                return "Target: \(targetVal)"
            }
        }
        
        if let runsVal = runs, let oversVal = overs {
            let bowled = Match.ballsBowled(from: oversVal)
            if bowled > 0 {
                let crrVal = Double(runsVal) * 6.0 / Double(bowled)
                let crrStr = String(format: "%.2f", crrVal)
                return "CRR: \(crrStr)"
            }
        }
        return statusText
    }
}


// MARK: - API Codable Models

struct APIResponse: Codable {
    let data: [APIMatch]
}

struct APIMatch: Codable {
    let id: String
    let format: String
    let startTime: String
    let homeTeam: APITeam
    let awayTeam: APITeam
    let league: APILeague?
    let state: APIMatchState
}

struct APITeam: Codable {
    let name: String
    let abbreviation: String
    let logo: String?
}

struct APILeague: Codable {
    let name: String
    let season: Int
}

struct APIMatchState: Codable {
    let description: String
    let report: String?
    let teams: APITeamsState?
}

struct APITeamsState: Codable {
    let home: APITeamState?
    let away: APITeamState?
}

struct APITeamState: Codable {
    let score: String?
    let info: String?
}

// MARK: - Mapping Logic

extension APIMatch {
    func toDomain() -> Match {
        let matchName = "\(homeTeam.name) vs \(awayTeam.name)"
        let status = reportText()
        
        let homeInnings = Innings(
            teamShortName: homeTeam.abbreviation,
            scoreText: state.teams?.home?.score ?? "-",
            infoText: state.teams?.home?.info
        )
        
        let awayInnings = Innings(
            teamShortName: awayTeam.abbreviation,
            scoreText: state.teams?.away?.score ?? "-",
            infoText: state.teams?.away?.info
        )
        
        let matchState = APIMatch.classify(description: state.description)
        
        return Match(
            id: id,
            name: matchName,
            format: format.uppercased(),
            statusText: status,
            innings: [homeInnings, awayInnings],
            state: matchState
        )
    }
    
    private func reportText() -> String {
        if let report = state.report, !report.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return report
        }
        return state.description
    }
    
    private static func classify(description: String) -> MatchState {
        let desc = description.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        switch desc {
        case "in play", "live", "innings break":
            return .live
        case "stumps", "tea", "lunch", "dinner", "drinks":
            return .onBreak
        case "finished", "abandoned", "no result":
            return .finished
        case "not started", "scheduled":
            return .scheduled
        default:
            return .scheduled
        }
    }
}
