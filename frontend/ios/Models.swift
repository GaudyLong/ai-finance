import Foundation

struct Transaction: Codable, Identifiable, Hashable {
    var id: Int?
    var amount: Double
    var type: String // "income" or "expense"
    var category: String
    var description: String?
    var date: String // "YYYY-MM-DD"
    var payment_method: String?
    var raw_text: String?
    
    // Conformance to Identifiable
    var uuid: UUID {
        return UUID()
    }
}

struct ChatMessage: Identifiable, Codable {
    var id = UUID()
    var role: String // "user" or "assistant"
    var content: String
    var parsedTransaction: Transaction?
    var date = Date()
    
    enum CodingKeys: String, CodingKey {
        case role
        case content
    }
}

struct CategorySummary: Codable, Identifiable, Hashable {
    var id: String { category }
    var category: String
    var amount: Double
    var percentage: Double
}

struct DailySummary: Codable, Identifiable, Hashable {
    var id: String { date }
    var date: String
    var income: Double
    var expense: Double
}

struct StatsSummary: Codable {
    var total_income: Double
    var total_expense: Double
    var net_savings: Double
    var category_expenses: [CategorySummary]
    var category_incomes: [CategorySummary]
    var daily_trend: [DailySummary]
}

// Extension to map English categories to Chinese and system icons
extension Transaction {
    var categoryChinese: String {
        switch category {
        case "Food": return "餐饮食品"
        case "Transport": return "交通出行"
        case "Shopping": return "购物日用"
        case "Salary": return "工资收入"
        case "Entertainment": return "娱乐游戏"
        case "Utilities": return "水电房租"
        case "Medical": return "医疗健康"
        case "Education": return "教育图书"
        default: return "其他支出"
        }
    }
    
    var categoryIcon: String {
        switch category {
        case "Food": return "fork.knife"
        case "Transport": return "car.fill"
        case "Shopping": return "bag.fill"
        case "Salary": return "dollarsign.circle.fill"
        case "Entertainment": return "gamecontroller.fill"
        case "Utilities": return "bolt.fill"
        case "Medical": return "pills.fill"
        case "Education": return "book.closed.fill"
        default: return "creditcard.fill"
        }
    }
    
    var categoryColorName: String {
        switch category {
        case "Food": return "orange"
        case "Transport": return "blue"
        case "Shopping": return "purple"
        case "Salary": return "green"
        case "Entertainment": return "pink"
        case "Utilities": return "yellow"
        case "Medical": return "red"
        case "Education": return "teal"
        default: return "gray"
        }
    }
    
    var paymentMethodChinese: String {
        switch payment_method {
        case "WeChat Pay": return "微信支付"
        case "Alipay": return "支付宝"
        case "Credit Card": return "信用卡"
        case "Cash": return "现金"
        default: return "其他"
        }
    }
}
