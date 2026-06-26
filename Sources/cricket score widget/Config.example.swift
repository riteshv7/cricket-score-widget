import Foundation

enum Config {
    static let highlightlyAPIKey = ""
    static let apiBaseURL = "https://cricket.highlightly.net" // or "https://cricket-highlights-api.p.rapidapi.com"
    static let pollInterval: TimeInterval = 120
    
    // Set this to true if you are using the RapidAPI endpoint
    // which requires sending the 'x-rapidapi-host' header.
    static let useRapidAPI = false
}
