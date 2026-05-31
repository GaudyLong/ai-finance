import SwiftUI

struct TransactionListView: View {
    @EnvironmentObject var network: NetworkManager
    @State private var selectedTypeFilter = "all" // "all", "expense", "income"
    @State private var searchQuery = ""
    @State private var showingAddModal = false

    var filteredTransactions: [Transaction] {
        network.transactions.filter { txn in
            let matchesType = selectedTypeFilter == "all" || txn.type == selectedTypeFilter
            let matchesSearch = searchQuery.isEmpty || 
                (txn.description?.localizedCaseInsensitiveContains(searchQuery) ?? false) ||
                txn.categoryChinese.localizedCaseInsensitiveContains(searchQuery)
            return matchesType && matchesSearch
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // --- 1. TYPE SELECTOR (ALL / EXPENSE / INCOME) ---
                Picker("过滤", selection: $selectedTypeFilter) {
                    Text("全部").tag("all")
                    Text("支出").tag("expense")
                    Text("收入").tag("income")
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                // --- 2. SEARCH BAR ---
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("搜索账目、分类...", text: $searchQuery)
                        .font(.subheadline)
                    if !searchQuery.isEmpty {
                        Button(action: { searchQuery = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(8)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(10)
                .padding(.horizontal)
                .padding(.bottom, 10)

                // --- 3. TRANSACTION LIST ---
                if filteredTransactions.isEmpty {
                    VStack(spacing: 15) {
                        Spacer()
                        Image(systemName: "tray.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.gray.opacity(0.5))
                        Text(network.isFetchingTransactions ? "正在加载数据..." : "暂无账单明细")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        Spacer()
                    }
                } else {
                    List {
                        ForEach(filteredTransactions) { txn in
                            TransactionRow(transaction: txn)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        if let id = txn.id {
                                            Task {
                                                _ = await network.deleteTransaction(id: id)
                                            }
                                        }
                                    } label: {
                                        Label("删除", systemImage: "trash")
                                    }
                                }
                        }
                    }
                    .listStyle(PlainListStyle())
                    .refreshable {
                        await network.fetchTransactions()
                        await network.fetchStats()
                    }
                }
            }
            .navigationTitle("账单明细")
            .navigationBarItems(
                trailing: Button(action: {
                    showingAddModal = true
                }) {
                    Image(systemName: "plus")
                        .font(.title3)
                        .foregroundColor(.purple)
                }
            )
            .sheet(isPresented: $showingAddModal) {
                AddTransactionView()
                    .environmentObject(network)
            }
            .onAppear {
                network.refreshData()
            }
        }
    }
}

// --- TRANSACTION ROW COMPONENT ---
struct TransactionRow: View {
    let transaction: Transaction
    
    var body: some View {
        HStack(spacing: 15) {
            // Category Icon
            ZStack {
                Circle()
                    .fill(categoryColor(transaction.category).opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: transaction.categoryIcon)
                    .foregroundColor(categoryColor(transaction.category))
                    .font(.headline)
            }
            
            // Text contents
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.description ?? transaction.categoryChinese)
                    .font(.body)
                    .fontWeight(.semibold)
                
                HStack(spacing: 8) {
                    Text(transaction.categoryChinese)
                        .font(.caption)
                        .foregroundColor(.purple)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.purple.opacity(0.1))
                        .cornerRadius(4)
                    
                    Text(transaction.paymentMethodChinese)
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Text(transaction.date)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            // Amount
            Text(transaction.type == "expense" ? "-¥\(String(format: "%.2f", transaction.amount))" : "+¥\(String(format: "%.2f", transaction.amount))")
                .font(.system(.body, design: .rounded))
                .fontWeight(.bold)
                .foregroundColor(transaction.type == "expense" ? .red : .green)
        }
        .padding(.vertical, 4)
    }
    
    private func categoryColor(_ cat: String) -> Color {
        switch cat {
        case "Food": return .orange
        case "Transport": return .blue
        case "Shopping": return .purple
        case "Salary": return .green
        case "Entertainment": return .pink
        case "Utilities": return .yellow
        case "Medical": return .red
        case "Education": return .teal
        default: return .gray
        }
    }
}
