import Foundation

class MatchSelector {
    /// Selects the match to display based on Phase 6 rules:
    /// 1. If a user-selected match ID is set and still live, return it.
    /// 2. If no valid user selection (or user selection ended/dropped off), perform auto-select:
    ///    A. If a favorite team is playing live, select that match.
    ///    B. Otherwise, fall back to the live-with-score -> live-without-score -> most recent finished rule.
    /// 3. Returns the selected Match and whether the stale user selection should be cleared in UserDefaults.
    static func selectMatch(
        from apiMatches: [APIMatch],
        selectedMatchID: String,
        favoriteTeam: String
    ) -> (selectedMatch: Match?, clearedStaleSelection: Bool) {
        // 1. Get all live matches
        let liveMatches = apiMatches.filter { classify($0.state.description) == .live }
        
        // 2. If the user has a selected match ID, check if it is still live
        if !selectedMatchID.isEmpty {
            if let userMatch = liveMatches.first(where: { $0.id == selectedMatchID }) {
                return (userMatch.toDomain(), false)
            }
            // The selected match is either no longer live, or has dropped off the list entirely.
            // We will clear the stale selection and fall back to auto-select.
        }
        
        // 3. Auto-select:
        // A. Check if a favorite team is playing live
        let trimmedFav = favoriteTeam.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedFav.isEmpty {
            let favLower = trimmedFav.lowercased()
            if let favMatch = liveMatches.first(where: { match in
                match.homeTeam.name.lowercased().contains(favLower) ||
                match.homeTeam.abbreviation.lowercased().contains(favLower) ||
                match.awayTeam.name.lowercased().contains(favLower) ||
                match.awayTeam.abbreviation.lowercased().contains(favLower)
            }) {
                return (favMatch.toDomain(), !selectedMatchID.isEmpty)
            }
        }
        
        // B. Fall back to v1 rule: live-with-score -> live-without-score
        let liveWithScore = liveMatches.filter { match in
            let homeScore = match.state.teams?.home?.score
            let awayScore = match.state.teams?.away?.score
            
            let hasHomeScore = homeScore != nil && !homeScore!.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && homeScore != "null"
            let hasAwayScore = awayScore != nil && !awayScore!.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && awayScore != "null"
            
            return hasHomeScore || hasAwayScore
        }
        
        let liveWithoutScore = liveMatches.filter { match in
            let homeScore = match.state.teams?.home?.score
            let awayScore = match.state.teams?.away?.score
            
            let hasHomeScore = homeScore != nil && !homeScore!.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && homeScore != "null"
            let hasAwayScore = awayScore != nil && !awayScore!.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && awayScore != "null"
            
            return !(hasHomeScore || hasAwayScore)
        }
        
        // Prefer live-with-score first
        if let firstLiveWithScore = liveWithScore.first {
            return (firstLiveWithScore.toDomain(), !selectedMatchID.isEmpty)
        }
        
        // Then live-without-score
        if let firstLiveWithoutScore = liveWithoutScore.first {
            return (firstLiveWithoutScore.toDomain(), !selectedMatchID.isEmpty)
        }
        
        // C. Fall back to the most recent finished match
        let finishedMatches = apiMatches.filter { classify($0.state.description) == .finished }
        let sortedFinished = finishedMatches.sorted { $0.startTime > $1.startTime }
        
        if let mostRecentFinished = sortedFinished.first {
            return (mostRecentFinished.toDomain(), !selectedMatchID.isEmpty)
        }
        
        return (nil, !selectedMatchID.isEmpty)
    }
    
    /// Helper to classify the match state description
    static func classify(_ description: String) -> MatchState {
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
