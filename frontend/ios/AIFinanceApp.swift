import SwiftUI

@main
struct AIFinanceApp: App {
    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
    }
}

struct MainTabView: View {
    @State private var selectedTab = 0
    @StateObject private var networkManager = NetworkManager.shared

    init() {
        // Customize appearance of tab bar and navigation bars to look premium
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(named: "CardBackground") ?? .systemBackground
        
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    Label("看板", systemImage: "chart.pie.fill")
                }
                .tag(0)
            
            ChatView()
                .tabItem {
                    Label("AI记账", systemImage: "sparkles.bubble.fill")
                }
                .tag(1)
            
            TransactionListView()
                .tabItem {
                    Label("明细", systemImage: "list.bullet.rectangle.portrait.fill")
                }
                .tag(2)
        }
        .accentColor(Color.purple) // Premium color brand
        .environmentObject(networkManager)
    }
}

// Global color definitions to support Dark Mode and sleek styles
extension Color {
    static let brandBackground = Color("BrandBackground")
    static let cardBackground = Color("CardBackground")
    static let textPrimary = Color("TextPrimary")
    static let textSecondary = Color("TextSecondary")
    
    // Fallback UI Colors
    static let uiBackground = Color(UIColor.systemBackground)
    static let uiSecondaryBackground = Color(UIColor.secondarySystemBackground)
    static let uiCard = Color(UIColor.tertiarySystemBackground)
}
