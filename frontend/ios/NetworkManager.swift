import Foundation
import Combine

class NetworkManager: ObservableObject {
    static let shared = NetworkManager()
    
    // Default URL pointing to the FastAPI backend (works inside Simulator as localhost)
    @Published var baseURL: String = "http://127.0.0.1:8000"
    
    @Published var transactions: [Transaction] = []
    @Published var stats: StatsSummary? = nil
    @Published var isFetchingTransactions = false
    @Published var isFetchingStats = false
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Automatically load initial data
        refreshData()
    }
    
    func refreshData() {
        Task {
            await fetchTransactions()
            await fetchStats()
        }
    }
    
    @MainActor
    func fetchTransactions() async {
        isFetchingTransactions = true
        defer { isFetchingTransactions = false }
        
        guard let url = URL(string: "\(baseURL)/api/transactions") else { return }
        
        try? await Task.sleep(nanoseconds: 300_000_000) // Visual buffer for smooth animation
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                let decoder = JSONDecoder()
                let fetchedTxns = try decoder.decode([Transaction].self, from: data)
                self.transactions = fetchedTxns
            }
        } catch {
            print("Failed to fetch transactions: \(error)")
        }
    }
    
    @MainActor
    func fetchStats() async {
        isFetchingStats = true
        defer { isFetchingStats = false }
        
        guard let url = URL(string: "\(baseURL)/api/stats") else { return }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                let decoder = JSONDecoder()
                let fetchedStats = try decoder.decode(StatsSummary.self, from: data)
                self.stats = fetchedStats
            }
        } catch {
            print("Failed to fetch stats: \(error)")
        }
    }
    
    @MainActor
    func addTransaction(_ txn: Transaction) async -> Bool {
        guard let url = URL(string: "\(baseURL)/api/transactions") else { return false }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let encoder = JSONEncoder()
            let body = try encoder.encode(txn)
            request.httpBody = body
            
            let (data, response) = try await URLSession.shared.upload(for: request, from: body)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                let decoder = JSONDecoder()
                let savedTxn = try decoder.decode(Transaction.self, from: data)
                // Prepend locally for immediate UX feedback, then refresh
                self.transactions.insert(savedTxn, at: 0)
                await fetchStats()
                return true
            }
        } catch {
            print("Failed to add transaction: \(error)")
        }
        return false
    }
    
    @MainActor
    func deleteTransaction(id: Int) async -> Bool {
        guard let url = URL(string: "\(baseURL)/api/transactions/\(id)") else { return false }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 204 {
                self.transactions.removeAll(where: { $0.id == id })
                await fetchStats()
                return true
            }
        } catch {
            print("Failed to delete transaction: \(error)")
        }
        return false
    }
    
    // Core AI Interaction endpoints
    
    struct AIChatPayload: Codable {
        let message: String
        let history: [[String: String]]
    }
    
    struct AIChatResponse: Codable {
        let reply: String
        let parsed_transaction: Transaction?
    }
    
    func sendChatMessage(message: String, chatHistory: [ChatMessage]) async -> (reply: String, parsedTxn: Transaction?) {
        guard let url = URL(string: "\(baseURL)/api/chat") else {
            return ("网络地址错误", nil)
        }
        
        // Map native ChatMessage array to backend {"role": "...", "content": "..."} format
        let historyPayload = chatHistory.suffix(10).map { msg in
            ["role": msg.role, "content": msg.content]
        }
        
        let payload = AIChatPayload(message: message, history: historyPayload)
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let body = try JSONEncoder().encode(payload)
            request.httpBody = body
            
            let (data, response) = try await URLSession.shared.upload(for: request, from: body)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                let aiResponse = try JSONDecoder().decode(AIChatResponse.self, from: data)
                return (aiResponse.reply, aiResponse.parsed_transaction)
            }
        } catch {
            print("Chat API call failed: \(error)")
        }
        
        return ("抱歉，我现在连接不上后台大模型服务，请检查后端运行状态或网络连接。", nil)
    }
}
