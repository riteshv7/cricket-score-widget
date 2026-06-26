import Foundation
import Observation

@Observable
class MatchService {
    var menuBarTitle: String = "Loading..."
    var currentMatch: Match? = nil
    var rateLimitRemaining: Int? = nil
    var isFetching: Bool = false
    
    private let client = APIClient()
    private var timer: Timer? = nil
    private let pollInterval: TimeInterval = Config.pollInterval
    
    init() {
        startPolling()
    }
    
    /// Starts the background polling timer
    func startPolling() {
        // Stop any existing timer
        stopPolling()
        
        // Fetch immediately
        Task {
            await fetchUpdates()
        }
        
        // Setup repeating timer (runs on main thread)
        timer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
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
    
    /// Performs the fetch and updates the state
    func fetchUpdates() async {
        guard !isFetching else { return }
        
        await MainActor.run {
            isFetching = true
        }
        
        do {
            let result = try await client.fetchMatches()
            let selected = MatchSelector.selectMatch(from: result.rawMatches)
            
            await MainActor.run {
                self.rateLimitRemaining = result.rateLimitRemaining
                self.currentMatch = selected
                
                if let selected = selected {
                    self.menuBarTitle = selected.menuBarTitleString
                } else {
                    self.menuBarTitle = "No live match"
                }
                self.isFetching = false
            }
        } catch {
            print("MatchService: Fetch failed with error: \(error)")
            
            await MainActor.run {
                self.isFetching = false
                // If we don't have a current match, show "—"
                // Otherwise, keep the last value as per specification
                if self.currentMatch == nil {
                    self.menuBarTitle = "—"
                }
            }
        }
    }
}
