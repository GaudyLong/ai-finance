import SwiftUI

struct ChatView: View {
    @EnvironmentObject var network: NetworkManager
    @State private var messageText = ""
    @State private var messages: [ChatMessage] = [
        ChatMessage(role: "assistant", content: "你好！我是你的 AI 财务管家。你可以直接打字告诉我你的消费，例如：\n“中午吃烤肉花了120元微信付的”\n或者问我一些理财建议，我会自动帮你整理账单并解析！")
    ]
    @State private var isSending = false
    @State private var confirmedTransactions = Set<UUID>() // Tracks which parsed transaction cards have been confirmed

    var body: some View {
        NavigationView {
            VStack {
                // --- 1. CHAT MESSAGE LIST ---
                ScrollViewReader { scrollView in
                    ScrollView {
                        LazyVStack(spacing: 15) {
                            ForEach(messages) { msg in
                                ChatBubble(
                                    message: msg,
                                    isConfirmed: confirmedTransactions.contains(msg.id),
                                    onConfirm: { txn in
                                        Task {
                                            let success = await network.addTransaction(txn)
                                            if success {
                                                withAnimation {
                                                    confirmedTransactions.insert(msg.id)
                                                }
                                            }
                                        }
                                    }
                                )
                                .id(msg.id)
                            }
                            
                            if isSending {
                                HStack {
                                    ProgressView()
                                        .padding(.trailing, 5)
                                    Text("AI 正在思考并解析账单...")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                    Spacer()
                                }
                                .padding(.horizontal)
                                .id("typing_indicator")
                            }
                        }
                        .padding(.vertical)
                    }
                    .onChange(of: messages.count) { _ in
                        withAnimation {
                            if let lastId = messages.last?.id {
                                scrollView.scrollTo(lastId, anchor: .bottom)
                            }
                        }
                    }
                    .onChange(of: isSending) { newValue in
                        if newValue {
                            withAnimation {
                                scrollView.scrollTo("typing_indicator", anchor: .bottom)
                            }
                        }
                    }
                }
                
                // --- 2. INPUT BAR ---
                HStack(spacing: 10) {
                    TextField("输入消费记录或财务咨询...", text: $messageText)
                        .padding(12)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(20)
                        .onSubmit {
                            sendMessage()
                        }
                    
                    Button(action: {
                        sendMessage()
                    }) {
                        Image(systemName: "paperplane.fill")
                            .foregroundColor(.white)
                            .padding(10)
                            .background(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray : Color.purple)
                            .clipShape(Circle())
                    }
                    .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            .navigationTitle("AI 记账助手")
        }
    }
    
    private func sendMessage() {
        let trimmed = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        let userMsg = ChatMessage(role: "user", content: trimmed)
        messages.append(userMsg)
        messageText = ""
        
        isSending = true
        
        Task {
            let result = await network.sendChatMessage(message: trimmed, chatHistory: messages)
            
            await MainActor.run {
                isSending = false
                let aiMsg = ChatMessage(role: "assistant", content: result.reply, parsedTransaction: result.parsedTxn)
                messages.append(aiMsg)
            }
        }
    }
}

// --- MESSAGE BUBBLE CELL ---
struct ChatBubble: View {
    let message: ChatMessage
    let isConfirmed: Bool
    let onConfirm: (Transaction) -> Void
    
    var isUser: Bool {
        message.role == "user"
    }
    
    var body: some View {
        HStack {
            if isUser { Spacer() }
            
            VStack(alignment: isUser ? .trailing : .leading, spacing: 8) {
                // Text bubble
                Text(message.content)
                    .font(.body)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 11)
                    .foregroundColor(isUser ? .white : .primary)
                    .background(
                        isUser ? 
                        LinearGradient(colors: [.purple, Color(.systemPurple)], startPoint: .topLeading, endPoint: .bottomTrailing) :
                        LinearGradient(colors: [Color(.secondarySystemBackground), Color(.secondarySystemBackground)], startPoint: .top, endPoint: .bottom)
                    )
                    .cornerRadius(18)
                    .frame(maxWidth: 280, alignment: isUser ? .trailing : .leading)
                
                // Parsed transaction confirmation card
                if let txn = message.parsedTransaction {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            ZStack {
                                Circle()
                                    .fill(categoryColor(txn.category).opacity(0.15))
                                    .frame(width: 32, height: 32)
                                Image(systemName: txn.categoryIcon)
                                    .foregroundColor(categoryColor(txn.category))
                                    .font(.footnote)
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(txn.categoryChinese)
                                    .font(.system(size: 13, weight: .bold))
                                Text(txn.description ?? "账单记录")
                                    .font(.system(size: 11))
                                    .foregroundColor(.gray)
                            }
                            
                            Spacer()
                            
                            Text("¥\(String(format: "%.2f", txn.amount))")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(txn.type == "expense" ? .red : .green)
                        }
                        
                        Divider().background(Color.gray.opacity(0.3))
                        
                        HStack {
                            Text("支付方式: \(txn.paymentMethodChinese)")
                                .font(.system(size: 11))
                                .foregroundColor(.gray)
                            Spacer()
                            Text("日期: \(txn.date)")
                                .font(.system(size: 11))
                                .foregroundColor(.gray)
                        }
                        
                        if isConfirmed {
                            HStack {
                                Spacer()
                                Label("已成功记账", systemImage: "checkmark.circle.fill")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.green)
                                Spacer()
                            }
                            .padding(.vertical, 5)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(8)
                        } else {
                            Button(action: {
                                onConfirm(txn)
                            }) {
                                HStack {
                                    Spacer()
                                    Image(systemName: "checkmark")
                                    Text("确认一键记账")
                                    Spacer()
                                }
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.vertical, 8)
                                .background(Color.purple)
                                .cornerRadius(8)
                            }
                        }
                    }
                    .padding(12)
                    .background(Color(.tertiarySystemBackground))
                    .cornerRadius(14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(isConfirmed ? Color.green.opacity(0.4) : Color.purple.opacity(0.3), lineWidth: 1)
                    )
                    .frame(width: 260)
                    .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 3)
                }
            }
            
            if !isUser { Spacer() }
        }
        .padding(.horizontal)
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
