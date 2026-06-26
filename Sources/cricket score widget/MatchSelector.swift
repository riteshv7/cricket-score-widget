import Foundation

class MatchSelector {
    /// Selects the match to display according to the v1 specification rules:
    /// 1. Pick the first match classified as `live`.
    /// 2. If none, fall back to the most recent `finished` match.
    /// 3. If none, return nil.
    static func selectMatch(from apiMatches: [APIMatch]) -> Match? {
        // 1. Filter for live matches
        let liveMatches = apiMatches.filter { classify($0.state.description) == .live }
        
        // Separate live matches into those with a score and those without
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
            return firstLiveWithScore.toDomain()
        }
        
        // Then live-without-score
        if let firstLiveWithoutScore = liveWithoutScore.first {
            return firstLiveWithoutScore.toDomain()
        }
        
        // 2. Fall back to the most recent finished match
        let finishedMatches = apiMatches.filter { classify($0.state.description) == .finished }
        
        // Since startTime is an ISO8601 string, lexicographical sorting correctly sorts chronologically.
        // We sort descending to get the most recent first.
        let sortedFinished = finishedMatches.sorted { $0.startTime > $1.startTime }
        
        if let mostRecentFinished = sortedFinished.first {
            return mostRecentFinished.toDomain()
        }
        
        return nil
    }
    
    /// Helper to classify the match state description based on the v1 spec
    private static func classify(_ description: String) -> MatchState {
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
