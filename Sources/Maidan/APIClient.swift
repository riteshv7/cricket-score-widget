import Foundation

struct FetchResult {
    let matches: [Match]
    let rawMatches: [APIMatch]
    let rateLimitRemaining: Int?
}

class APIClient {
    private let session: URLSession
    
    init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 10.0 // 10 seconds request timeout
        self.session = URLSession(configuration: configuration)
    }
    
    func fetchMatches(for date: Date = Date()) async throws -> FetchResult {
        // 1. Format date in user's local timezone
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        let dateStr = formatter.string(from: date)
        
        // 2. Build URL
        guard var urlComponents = URLComponents(string: Config.apiBaseURL) else {
            throw URLError(.badURL)
        }
        
        // Ensure path is /matches
        if urlComponents.path.hasSuffix("/") {
            urlComponents.path += "matches"
        } else {
            urlComponents.path = "/matches"
        }
        
        urlComponents.queryItems = [
            URLQueryItem(name: "date", value: dateStr),
            URLQueryItem(name: "limit", value: "50")
        ]
        
        guard let url = urlComponents.url else {
            throw URLError(.badURL)
        }
        
        // 3. Create Request
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        // Headers
        let storedKey = UserDefaults.standard.string(forKey: "apiKey") ?? ""
        let activeKey = storedKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Config.highlightlyAPIKey : storedKey
        request.setValue(activeKey, forHTTPHeaderField: "x-rapidapi-key")
        
        if Config.useRapidAPI {
            let host = URL(string: Config.apiBaseURL)?.host ?? "cricket-highlights-api.p.rapidapi.com"
            request.setValue(host, forHTTPHeaderField: "x-rapidapi-host")
        }
        
        // 4. Perform network call
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        // 5. Extract Rate Limit header
        var rateLimitRemaining: Int? = nil
        if let remainingStr = httpResponse.value(forHTTPHeaderField: "x-ratelimit-requests-remaining"),
           let remainingInt = Int(remainingStr) {
            rateLimitRemaining = remainingInt
        }
        
        // Check for HTTP errors
        guard (200...299).contains(httpResponse.statusCode) else {
            let bodyString = String(data: data, encoding: .utf8) ?? ""
            print("API Error: HTTP Status \(httpResponse.statusCode). Response: \(bodyString)")
            throw URLError(.badServerResponse)
        }
        
        // 6. Decode API Response
        let decoder = JSONDecoder()
        let apiResponse = try decoder.decode(APIResponse.self, from: data)
        let domainMatches = apiResponse.data.map { $0.toDomain() }
        
        return FetchResult(
            matches: domainMatches,
            rawMatches: apiResponse.data,
            rateLimitRemaining: rateLimitRemaining
        )
    }
    
    func fetchMatchesForToday() async throws -> FetchResult {
        let today = Date()
        let primary = try await fetchMatches(for: today)
        
        guard primary.rawMatches.isEmpty else {
            return primary
        }
        
        let calendar = Calendar.current
        var rawMatchesByID: [String: APIMatch] = [:]
        var rateLimitRemaining = primary.rateLimitRemaining
        
        for match in primary.rawMatches {
            rawMatchesByID[match.id] = match
        }
        
        for offset in [-1, 1] {
            guard let date = calendar.date(byAdding: .day, value: offset, to: today) else {
                continue
            }
            
            do {
                let fallback = try await fetchMatches(for: date)
                rateLimitRemaining = fallback.rateLimitRemaining ?? rateLimitRemaining
                
                for match in fallback.rawMatches where match.occurs(onLocalDay: today, calendar: calendar) {
                    rawMatchesByID[match.id] = match
                }
            } catch {
                print("APIClient: Fallback fixture lookup for offset \(offset) failed: \(error)")
            }
        }
        
        let rawMatches = rawMatchesByID.values.sorted { $0.startTime < $1.startTime }
        return FetchResult(
            matches: rawMatches.map { $0.toDomain() },
            rawMatches: rawMatches,
            rateLimitRemaining: rateLimitRemaining
        )
    }
    
    func fetchMatchDetail(id: String) async throws -> DetailedInfo {
        // 1. Build URL
        guard var urlComponents = URLComponents(string: Config.apiBaseURL) else {
            throw URLError(.badURL)
        }
        
        let cleanPath = urlComponents.path.hasSuffix("/") ? String(urlComponents.path.dropLast()) : urlComponents.path
        urlComponents.path = cleanPath + "/matches/\(id)"
        
        guard let url = urlComponents.url else {
            throw URLError(.badURL)
        }
        
        // 2. Create Request
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        // Headers
        let storedKey = UserDefaults.standard.string(forKey: "apiKey") ?? ""
        let activeKey = storedKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Config.highlightlyAPIKey : storedKey
        request.setValue(activeKey, forHTTPHeaderField: "x-rapidapi-key")
        
        if Config.useRapidAPI {
            let host = URL(string: Config.apiBaseURL)?.host ?? "cricket-highlights-api.p.rapidapi.com"
            request.setValue(host, forHTTPHeaderField: "x-rapidapi-host")
        }
        
        // 3. Perform network call
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        // Check for HTTP errors
        guard (200...299).contains(httpResponse.statusCode) else {
            let bodyString = String(data: data, encoding: .utf8) ?? ""
            print("API Match Detail Error: HTTP Status \(httpResponse.statusCode). Response: \(bodyString)")
            throw URLError(.badServerResponse)
        }
        
        // 4. Decode API Response (detailed endpoint returns an array)
        let decoder = JSONDecoder()
        let detailedMatches = try decoder.decode([APIDetailedMatch].self, from: data)
        
        guard let detailedMatch = detailedMatches.first else {
            throw URLError(.badServerResponse)
        }
        
        return detailedMatch.toDetailedDomain()
    }
}
