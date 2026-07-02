import Testing
import Foundation
@testable import Maidan

@Test func selectedScheduledMatchRemainsSelected() async throws {
    let scheduledMatch = makeAPIMatch(
        id: "scheduled-1",
        startTime: "2026-07-01T21:30:00.000Z",
        homeName: "Los Angeles Knight Riders",
        homeAbbr: "LAKR",
        awayName: "Washington Freedom",
        awayAbbr: "WSH",
        state: "Scheduled"
    )
    
    let liveMatch = makeAPIMatch(
        id: "live-1",
        startTime: "2026-07-01T18:00:00.000Z",
        homeName: "India A Women",
        homeAbbr: "IND-A",
        awayName: "England A Women",
        awayAbbr: "ENG-A",
        state: "In Play"
    )
    
    let result = MatchSelector.selectMatch(
        from: [liveMatch, scheduledMatch],
        selectedMatchID: "scheduled-1",
        favoriteTeam: ""
    )
    
    #expect(result.selectedMatch?.id == "scheduled-1")
    #expect(result.clearedStaleSelection == false)
}

@Test func utcFixtureCanOccurOnLocalToday() async throws {
    let match = makeAPIMatch(
        id: "night-match",
        startTime: "2026-07-02T01:30:00.000Z",
        homeName: "Los Angeles Knight Riders",
        homeAbbr: "LAKR",
        awayName: "Washington Freedom",
        awayAbbr: "WSH",
        state: "Scheduled"
    )
    
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "America/New_York")!
    
    var components = DateComponents()
    components.calendar = calendar
    components.timeZone = calendar.timeZone
    components.year = 2026
    components.month = 7
    components.day = 1
    components.hour = 12
    
    #expect(match.occurs(onLocalDay: components.date!, calendar: calendar))
}

private func makeAPIMatch(
    id: String,
    startTime: String,
    homeName: String,
    homeAbbr: String,
    awayName: String,
    awayAbbr: String,
    state: String
) -> APIMatch {
    APIMatch(
        id: id,
        format: "T20",
        startTime: startTime,
        homeTeam: APITeam(name: homeName, abbreviation: homeAbbr, logo: nil),
        awayTeam: APITeam(name: awayName, abbreviation: awayAbbr, logo: nil),
        league: APILeague(name: "Test League", season: 2026),
        state: APIMatchState(
            description: state,
            report: nil,
            teams: APITeamsState(
                home: APITeamState(score: nil, info: nil),
                away: APITeamState(score: nil, info: nil)
            )
        )
    )
}
