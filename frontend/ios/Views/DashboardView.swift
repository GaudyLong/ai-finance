import SwiftUI
import Charts

struct DashboardView: View {
    @EnvironmentObject var network: NetworkManager
    @State private var showingAddModal = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    
                    // --- 1. OVERVIEW CARD WITH GRADIENT ---
                    VStack(alignment: .leading, spacing: 15) {
                        Text("当前总资产 (净储蓄)")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                        
                        let savings = network.stats?.net_savings ?? 0.0
                        Text("¥\(String(format: "%.2f", savings))")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        HStack {
                            VStack(alignment: .leading) {
                                Label("总收入", systemImage: "arrow.down.right.circle.fill")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.8))
                                Text("¥\(String(format: "%.2f", network.stats?.total_income ?? 0.0))")
                                    .font(.headline)
                                    .foregroundColor(.white)
                            }
                            Spacer()
                            VStack(alignment: .trailing) {
                                Label("总支出", systemImage: "arrow.up.left.circle.fill")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.8))
                                Text("¥\(String(format: "%.2f", network.stats?.total_expense ?? 0.0))")
                                    .font(.headline)
                                    .foregroundColor(.white)
                            }
                        }
                        .padding(.top, 10)
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 24)
                            .fill(LinearGradient(
                                colors: [Color.purple, Color.blue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .shadow(color: Color.purple.opacity(0.3), radius: 10, x: 0, y: 5)
                    )
                    .padding(.horizontal)

                    // --- 2. 7-DAY SPENDING TREND CHART ---
                    VStack(alignment: .leading, spacing: 12) {
                        Text("近7日收支趋势")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        if let trend = network.stats?.daily_trend, !trend.isEmpty {
                            Chart {
                                ForEach(trend) { day in
                                    // Split parsing for month/day to label X-axis cleanly
                                    let cleanDate = formatShortDate(day.date)
                                    
                                    if day.income > 0 {
                                        BarMark(
                                            x: .value("日期", cleanDate),
                                            y: .value("金额", day.income)
                                        )
                                        .foregroundStyle(Color.green.gradient)
                                        .position(by: .value("类型", "收入"))
                                    }
                                    
                                    if day.expense > 0 {
                                        BarMark(
                                            x: .value("日期", cleanDate),
                                            y: .value("金额", day.expense)
                                        )
                                        .foregroundStyle(Color.red.gradient)
                                        .position(by: .value("类型", "支出"))
                                    }
                                }
                            }
                            .frame(height: 180)
                            .padding(.horizontal, 10)
                        } else {
                            VStack {
                                Text("暂无趋势数据")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                            .frame(height: 180)
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.vertical, 15)
                    .background(RoundedRectangle(cornerRadius: 20).fill(Color.uiSecondaryBackground))
                    .padding(.horizontal)

                    // --- 3. CATEGORY EXPENSES LIST ---
                    VStack(alignment: .leading, spacing: 15) {
                        HStack {
                            Text("消费分类占比")
                                .font(.headline)
                            Spacer()
                            Text("共 \(network.stats?.category_expenses.count ?? 0) 类")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .padding(.horizontal)
                        
                        if let expenses = network.stats?.category_expenses, !expenses.isEmpty {
                            VStack(spacing: 12) {
                                ForEach(expenses) { cat in
                                    let mockTxn = Transaction(amount: cat.amount, type: "expense", category: cat.category, date: "")
                                    
                                    HStack(spacing: 15) {
                                        // Icon
                                        ZStack {
                                            Circle()
                                                .fill(categoryColor(cat.category).opacity(0.15))
                                                .frame(width: 40, height: 40)
                                            Image(systemName: mockTxn.categoryIcon)
                                                .foregroundColor(categoryColor(cat.category))
                                        }
                                        
                                        // Label + Progress Bar
                                        VStack(alignment: .leading, spacing: 4) {
                                            HStack {
                                                Text(mockTxn.categoryChinese)
                                                    .font(.subheadline)
                                                    .fontWeight(.medium)
                                                Spacer()
                                                Text("¥\(String(format: "%.1f", cat.amount))")
                                                    .font(.subheadline)
                                                    .fontWeight(.bold)
                                            }
                                            
                                            // Progress Bar
                                            GeometryReader { geo in
                                                ZStack(alignment: .leading) {
                                                    RoundedRectangle(cornerRadius: 3)
                                                        .fill(Color.gray.opacity(0.2))
                                                        .frame(height: 6)
                                                    
                                                    RoundedRectangle(cornerRadius: 3)
                                                        .fill(categoryColor(cat.category))
                                                        .frame(width: geo.size.width * CGFloat(cat.percentage / 100.0), height: 6)
                                                }
                                            }
                                            .frame(height: 6)
                                        }
                                        
                                        // Percent
                                        Text("\(String(format: "%.0f", cat.percentage))%")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                            .frame(width: 35, alignment: .trailing)
                                    }
                                    .padding(.horizontal)
                                }
                            }
                        } else {
                            Text("尚无记账支出分类数据")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                    .padding(.vertical, 15)
                    .background(RoundedRectangle(cornerRadius: 20).fill(Color.uiSecondaryBackground))
                    .padding(.horizontal)

                    Spacer().frame(height: 20)
                }
            }
            .navigationTitle("AI Finance")
            .navigationBarItems(
                leading: Button(action: {
                    network.refreshData()
                }) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.purple)
                },
                trailing: Button(action: {
                    showingAddModal = true
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.purple)
                }
            )
            .sheet(isPresented: $showingAddModal) {
                AddTransactionView()
                    .environmentObject(network)
            }
        }
    }
    
    // Helpers
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
    
    private func formatShortDate(_ dateStr: String) -> String {
        // "2026-05-31" -> "05/31"
        let parts = dateStr.split(separator: "-")
        if parts.count >= 3 {
            return "\(parts[1])/\(parts[2])"
        }
        return dateStr
    }
}
