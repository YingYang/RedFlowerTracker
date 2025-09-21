import SwiftUI
import SwiftData
import PhotosUI

// MARK: - Data Model
@Model
class Transaction {
    var id: UUID
    var date: Date
    var amount: Int
    var reason: String
    var type: TransactionType
    var photoData: Data?
    
    init(amount: Int, reason: String, type: TransactionType, photoData: Data? = nil) {
        self.id = UUID()
        self.date = Date()
        self.amount = amount
        self.reason = reason
        self.type = type
        self.photoData = photoData
    }
}

enum TransactionType: String, CaseIterable, Codable {
    case earning = "奖励"
    case spending = "花费"
    case penalty = "扣除"
    
    var color: Color {
        switch self {
        case .earning: return .green
        case .spending: return .blue
        case .penalty: return .red
        }
    }
    
    var symbol: String {
        switch self {
        case .earning: return "+"
        case .spending: return "-"
        case .penalty: return "-"
        }
    }
}

// MARK: - Main Content View
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var transactions: [Transaction]
    @State private var showingAddTransaction = false
    @State private var showingExportSheet = false
    @State private var csvContent = ""
    @Environment(\.scenePhase) private var scenePhase
    
    private var currentBalance: Int {
        transactions.reduce(0) { balance, transaction in
            switch transaction.type {
            case .earning:
                return balance + transaction.amount
            case .spending, .penalty:
                return balance - transaction.amount
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Dashboard
                DashboardView(balance: currentBalance)
                
                // Manual Export Button
                Button("手动导出CSV") {
                    generateCSV()
                }
                .frame(height: 60)
                .frame(maxWidth: .infinity)
                .background(Color.red)
                .foregroundColor(.white)
                .font(.system(size: 32))
                .cornerRadius(12)
                .padding(.horizontal)
                
                // Transaction List
                List {
                    ForEach(transactions.sorted(by: { $0.date > $1.date })) { transaction in
                        TransactionRowView(transaction: transaction)
                    }
                    .onDelete(perform: deleteTransactions)
                }
            }
            .navigationTitle("小红花")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("添加", systemImage: "plus") {
                        showingAddTransaction = true
                    }
                    .font(.system(size: 32))
                }
            }
            .sheet(isPresented: $showingAddTransaction) {
                AddTransactionView()
            }
            .sheet(isPresented: $showingExportSheet) {
                CSVExportView(csvContent: csvContent)
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .inactive {
                    // App is closing/backgrounding - auto-backup
                    autoBackupToCSV()
                }
            }
        }
    }
    
    private func deleteTransactions(offsets: IndexSet) {
        let sortedTransactions = transactions.sorted(by: { $0.date > $1.date })
        for index in offsets {
            modelContext.delete(sortedTransactions[index])
        }
    }
    
    private func generateCSV() {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm:ss"
        
        var csvString = "Type,Amount,Reason,Date,Time\n"
        
        let sortedTransactions = transactions.sorted(by: { $0.date < $1.date })
        
        for transaction in sortedTransactions {
            let type = transaction.type.rawValue
            let amount = String(transaction.amount)
            let reason = "\"" + transaction.reason.replacingOccurrences(of: "\"", with: "\"\"") + "\""
            let date = dateFormatter.string(from: transaction.date)
            let time = timeFormatter.string(from: transaction.date)
            
            csvString += "\(type),\(amount),\(reason),\(date),\(time)\n"
        }
        
        csvContent = csvString
        showingExportSheet = true
    }
    
    private func autoBackupToCSV() {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm:ss"
        
        var csvString = "Type,Amount,Reason,Date,Time\n"
        
        let sortedTransactions = transactions.sorted(by: { $0.date < $1.date })
        
        for transaction in sortedTransactions {
            let type = transaction.type.rawValue
            let amount = String(transaction.amount)
            let reason = "\"" + transaction.reason.replacingOccurrences(of: "\"", with: "\"\"") + "\""
            let date = dateFormatter.string(from: transaction.date)
            let time = timeFormatter.string(from: transaction.date)
            
            csvString += "\(type),\(amount),\(reason),\(date),\(time)\n"
        }
        
        // Save to Documents folder
        saveCSVToDocuments(csvString)
    }
    
    private func saveCSVToDocuments(_ csvContent: String) {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory,
                                                               in: .userDomainMask).first else {
            return
        }
        
        let timestamp = DateFormatter().apply {
            $0.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        }.string(from: Date())
        
        let fileURL = documentsDirectory.appendingPathComponent("xiaohonghua_backup_\(timestamp).csv")
        
        do {
            try csvContent.write(to: fileURL, atomically: true, encoding: .utf8)
            print("Backup saved to: \(fileURL.path)")
        } catch {
            print("Failed to save backup: \(error)")
        }
    }
}

// MARK: - Dashboard View
struct DashboardView: View {
    let balance: Int
    
    var body: some View {
        VStack(spacing: 24) {
            Text("当前数量")
                .font(.system(size: 36, weight: .medium))
                .foregroundColor(.secondary)
            
            Text("🌺 \(balance)")
                .font(.system(size: 96, weight: .bold, design: .rounded))
                .foregroundColor(balance >= 0 ? .green : .red)
        }
        .padding(32)
        .frame(maxWidth: .infinity)
        .background(Color(.systemGray6))
        .cornerRadius(16)
        .padding(.horizontal)
    }
}

// MARK: - Transaction Row View
struct TransactionRowView: View {
    let transaction: Transaction
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(transaction.type.rawValue)
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundColor(transaction.type.color)
                    
                    Spacer()
                    
                    Text("\(transaction.type.symbol)\(transaction.amount)")
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundColor(transaction.type.color)
                }
                
                Text(transaction.reason)
                    .font(.system(size: 32))
                    .lineLimit(2)
                
                Text(transaction.date, style: .date)
                    .font(.system(size: 24))
                    .foregroundColor(.secondary)
                
                Text(transaction.date, style: .time)
                    .font(.system(size: 24))
                    .foregroundColor(.secondary)
            }
            
            if let photoData = transaction.photoData,
               let uiImage = UIImage(data: photoData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 120, height: 120)
                    .cornerRadius(12)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Add Transaction View
struct AddTransactionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var amount: String = ""
    @State private var reason: String = ""
    @State private var transactionType: TransactionType = .earning
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var photoData: Data?
    
    var body: some View {
        NavigationStack {
            Form {
                Section("记录详情") {
                    Picker("类型", selection: $transactionType) {
                        ForEach(TransactionType.allCases, id: \.self) { type in
                            Text(type.rawValue)
                                .font(.system(size: 32))
                                .tag(type)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    
                    HStack {
                        Text("🌺")
                            .font(.system(size: 32))
                        TextField("数量", text: $amount)
                            .keyboardType(.numberPad)
                            .font(.system(size: 32))
                    }
                    
                    TextField("原因", text: $reason, axis: .vertical)
                        .lineLimit(3...6)
                        .font(.system(size: 32))
                }
                
                Section("照片 (可选)") {
                    PhotosPicker(selection: $selectedPhoto,
                               matching: .images,
                               photoLibrary: .shared()) {
                        if let photoData = photoData,
                           let uiImage = UIImage(data: photoData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(height: 400)
                                .cornerRadius(16)
                        } else {
                            Label("选择照片", systemImage: "photo.on.rectangle")
                                .font(.system(size: 32))
                                .frame(height: 200)
                        }
                    }
                    .onChange(of: selectedPhoto) { _, newItem in
                        Task {
                            if let data = try? await newItem?.loadTransferable(type: Data.self) {
                                photoData = data
                            }
                        }
                    }
                    
                    if photoData != nil {
                        Button("删除照片", role: .destructive) {
                            photoData = nil
                            selectedPhoto = nil
                        }
                        .font(.system(size: 28))
                    }
                }
            }
            .navigationTitle("添加记录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                    .font(.system(size: 32))
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveTransaction()
                    }
                    .font(.system(size: 32))
                    .disabled(amount.isEmpty || reason.isEmpty)
                }
            }
        }
    }
    
    private func saveTransaction() {
        guard let amountValue = Int(amount), amountValue > 0 else { return }
        
        let transaction = Transaction(
            amount: amountValue,
            reason: reason,
            type: transactionType,
            photoData: photoData
        )
        
        modelContext.insert(transaction)
        dismiss()
    }
}

// MARK: - CSV Export View
struct CSVExportView: View {
    @Environment(\.dismiss) private var dismiss
    let csvContent: String
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 40) {
                Text("CSV 数据")
                    .font(.system(size: 36, weight: .semibold))
                
                Text("复制下面的内容并粘贴到 Google Sheets")
                    .font(.system(size: 28))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                ScrollView {
                    Text(csvContent)
                        .font(.system(size: 24, design: .monospaced))
                        .textSelection(.enabled)
                        .padding(24)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                }
                
                Button("复制到剪贴板") {
                    UIPasteboard.general.string = csvContent
                }
                .buttonStyle(.borderedProminent)
                .font(.system(size: 32))
                .frame(height: 60)
                
                Spacer()
            }
            .padding(32)
            .navigationTitle("导出 CSV")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                    .font(.system(size: 32))
                }
            }
        }
    }
}

// MARK: - Extensions
extension DateFormatter {
    func apply(_ closure: (DateFormatter) -> Void) -> DateFormatter {
        closure(self)
        return self
    }
}

// MARK: - Preview
#Preview {
    ContentView()
        .modelContainer(for: Transaction.self, inMemory: true)
}
