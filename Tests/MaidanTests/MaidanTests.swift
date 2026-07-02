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

@Test func detailedScorecardUsesInningsStatsInsteadOfBestPlayerAggregates() throws {
    let json = """
    [{
      "id": "53985192",
      "format": "ODI",
      "startTime": "2026-07-01T09:00:00.000Z",
      "homeTeam": {
        "name": "England A Women",
        "abbreviation": "EN-AW",
        "logo": null
      },
      "awayTeam": {
        "name": "India A Women",
        "abbreviation": "IN-AW",
        "logo": null
      },
      "state": {
        "description": "Finished",
        "report": "ENG-A Women won by 125 runs",
        "teams": {
          "home": { "score": "298/5", "info": null },
          "away": { "score": "173", "info": "42.3/50 ov, T:299" }
        }
      },
      "statistics": [{
        "team": {
          "name": "England A Women",
          "abbreviation": "EN-AW",
          "logo": null,
          "inningBatsmen": [{
            "runs": 59,
            "balls": 56,
            "battingStrikeRate": 105.35,
            "player": { "name": "Grace Scrivens" }
          }, {
            "runs": 97,
            "balls": 127,
            "battingStrikeRate": 76.37,
            "player": { "name": "Jodi Grewcock" }
          }],
          "inningBowlers": [{
            "overs": 10,
            "wickets": 1,
            "concededRuns": 50,
            "economy": 5.0,
            "player": { "name": "Minnu Mani" }
          }]
        }
      }, {
        "team": {
          "name": "India A Women",
          "abbreviation": "IN-AW",
          "logo": null,
          "inningBatsmen": [{
            "runs": 87,
            "balls": 94,
            "battingStrikeRate": 92.55,
            "player": { "name": "Priya Punia" }
          }],
          "inningBowlers": [{
            "overs": 10,
            "wickets": 4,
            "concededRuns": 34,
            "economy": 3.4,
            "player": { "name": "Sophia Smale" }
          }]
        }
      }],
      "bestBatsmen": [{
        "team": {
          "name": "England A Women",
          "abbreviation": "EN-AW",
          "logo": null
        },
        "players": [{
          "name": "Grace Scrivens",
          "statistics": {
            "runs": 321,
            "battingStrikeRate": 66.32
          }
        }]
      }],
      "bestBowlers": [{
        "team": {
          "name": "England A Women",
          "abbreviation": "EN-AW",
          "logo": null
        },
        "players": [{
          "name": "Grace Potts",
          "statistics": {
            "balls": 330,
            "wickets": 6,
            "concededRuns": 302,
            "economy": 5.49
          }
        }]
      }]
    }]
    """

    let matches = try JSONDecoder().decode([APIDetailedMatch].self, from: Data(json.utf8))
    let details = try #require(matches.first).toDetailedDomain()

    #expect(details.topBatsmen.contains { $0.name == "Grace Scrivens" && $0.runs == 59 && $0.balls == 56 })
    #expect(details.topBatsmen.contains { $0.name == "Jodi Grewcock" && $0.runs == 97 && $0.balls == 127 })
    #expect(details.topBatsmen.contains { $0.name == "Priya Punia" && $0.runs == 87 && $0.teamAbbreviation == "IN-AW" })
    #expect(!details.topBatsmen.contains { $0.name == "Grace Scrivens" && $0.runs == 321 })

    #expect(details.topBowlers.contains { $0.name == "Minnu Mani" && $0.teamAbbreviation == "IN-AW" && $0.wickets == 1 && $0.runsConceded == 50 })
    #expect(details.topBowlers.contains { $0.name == "Sophia Smale" && $0.teamAbbreviation == "EN-AW" && $0.wickets == 4 && $0.runsConceded == 34 })
    #expect(!details.topBowlers.contains { $0.name == "Grace Potts" && $0.runsConceded == 302 })
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
