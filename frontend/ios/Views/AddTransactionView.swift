import SwiftUI

struct AddTransactionView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var network: NetworkManager
    
    @State private var amountString = ""
    @State private var type = "expense" // "expense" or "income"
    @State private var category = "Food"
    @State private var description = ""
    @State private var date = Date()
    @State private var paymentMethod = "WeChat Pay"
    @State private var isSaving = false
    
    // Categories matching backend definitions
    let expenseCategories = [
        ("餐饮食品", "Food"), ("交通出行", "Transport"), 
        ("购物日用", "Shopping"), ("娱乐游戏", "Entertainment"), 
        ("水电房租", "Utilities"), ("医疗健康", "Medical"), 
        ("教育图书", "Education"), ("其他支出", "Other")
    ]
    
    let incomeCategories = [
        ("工资收入", "Salary"), ("其他收入", "Other")
    ]
    
    let paymentMethods = [
        ("微信支付", "WeChat Pay"), ("支付宝", "Alipay"), 
        ("信用卡", "Credit Card"), ("现金", "Cash"), ("其他", "Other")
    ]
    
    var body: some View {
        NavigationView {
            Form {
                // --- 1. AMOUNT INPUT ---
                Section(header: Text("账目金额")) {
                    HStack {
                        Text("¥")
                            .font(.title2)
                            .fontWeight(.bold)
                        TextField("0.00", text: $amountString)
                            .keyboardType(.decimalPad)
                            .font(.title2)
                            .fontWeight(.semibold)
                    }
                }
                
                // --- 2. BASIC TYPE ---
                Section(header: Text("类型与分类")) {
                    Picker("收支类型", selection: $type) {
                        Text("支出").tag("expense")
                        Text("收入").tag("income")
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .onChange(of: type) { newValue in
                        if newValue == "expense" {
                            category = "Food"
                        } else {
                            category = "Salary"
                        }
                    }
                    
                    Picker("具体分类", selection: $category) {
                        if type == "expense" {
                            ForEach(expenseCategories, id: \.1) { name, code in
                                Text(name).tag(code)
                            }
                        } else {
                            ForEach(incomeCategories, id: \.1) { name, code in
                                Text(name).tag(code)
                            }
                        }
                    }
                }
                
                // --- 3. LOGISTICAL DETAILS ---
                Section(header: Text("记账详情")) {
                    TextField("简短说明(如: 麦当劳午餐)", text: $description)
                    
                    Picker("支付方式", selection: $paymentMethod) {
                        ForEach(paymentMethods, id: \.1) { name, code in
                            Text(name).tag(code)
                        }
                    }
                    
                    DatePicker("记账日期", selection: $date, displayedComponents: .date)
                }
            }
            .navigationTitle("手动记账")
            .navigationBarItems(
                leading: Button("取消") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button(action: saveTransaction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Text("保存")
                            .fontWeight(.bold)
                            .foregroundColor(isValid ? .purple : .gray)
                    }
                }
                .disabled(!isValid || isSaving)
            )
        }
    }
    
    var isValid: Bool {
        guard let amount = Double(amountString), amount > 0 else { return false }
        return true
    }
    
    private func saveTransaction() {
        guard let amount = Double(amountString) else { return }
        
        isSaving = true
        
        let formatter = DateFormatter()
        formatter.dateFormat = "YYYY-MM-DD"
        let dateString = formatter.string(from: date)
        
        let desc = description.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanDesc = desc.isEmpty ? nil : desc
        
        let newTxn = Transaction(
            amount: amount,
            type: type,
            category: category,
            description: cleanDesc,
            date: dateString,
            payment_method: paymentMethod
        )
        
        Task {
            let success = await network.addTransaction(newTxn)
            await MainActor.run {
                isSaving = false
                if success {
                    presentationMode.wrappedValue.dismiss()
                }
            }
        }
    }
}
