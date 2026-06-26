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

struct Match: Codable {
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
}


// MARK: - API Codable Models

struct APIResponse: Codable {
    let data: [APIMatch]
}

struct APIMatch: Codable {
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
