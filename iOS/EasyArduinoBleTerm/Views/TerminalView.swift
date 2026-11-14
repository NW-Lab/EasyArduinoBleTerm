import SwiftUI

struct TerminalView: View {
    @ObservedObject var bleManager: BLEManager
    @State private var showTimestamp: Bool = true
    @State private var inputText: String = ""
    @State private var autoScroll: Bool = true
    @FocusState private var inputIsFocused: Bool

    // 最後にスクロールした行数。同じ行数なら再スクロールしない
    @State private var lastScrolledCount: Int = 0

    private let timestampFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Toggle(isOn: $showTimestamp) {
                    Label("時刻表示", systemImage: "clock")
                        .font(.caption)
                }
                .toggleStyle(.button)
                .buttonStyle(.bordered)

                Spacer()

                Toggle(isOn: $autoScroll) {
                    Label("自動スクロール", systemImage: "arrow.down.to.line")
                        .font(.caption)
                }
                .toggleStyle(.button)
                .buttonStyle(.bordered)

                Button(role: .destructive) {
                    bleManager.receivedMessages.removeAll()
                    lastScrolledCount = 0
                } label: {
                    Label("クリア", systemImage: "trash")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(UIColor.secondarySystemBackground))

            Divider()

            // Message list
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(bleManager.receivedMessages) { msg in
                            HStack(alignment: .top, spacing: 4) {
                                if showTimestamp {
                                    Text(timestampFormatter.string(from: msg.timestamp))
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                        .fixedSize()
                                }
                                Text(msg.text)
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundColor(.primary)
                                    .textSelection(.enabled)
                            }
                            .padding(.horizontal, 8)
                            .id(msg.id)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .onChange(of: bleManager.receivedMessages.count) { _, newCount in
                    // 行数が変わっていない場合や自動スクロールOFFの場合はスキップ
                    guard autoScroll, newCount != lastScrolledCount,
                          let last = bleManager.receivedMessages.last else { return }
                    lastScrolledCount = newCount
                    // アニメーションなしでスクロール（CPUコスト削減）
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
            .background(Color(UIColor.systemBackground))

            Divider()

            // Input bar
            HStack {
                TextField("送信テキストを入力", text: $inputText)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .focused($inputIsFocused)

                Button {
                    guard !inputText.isEmpty else { return }
                    bleManager.send(inputText + "\n")
                    inputText = ""
                } label: {
                    Image(systemName: "paperplane.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(bleManager.connectedPeripheral == nil || inputText.isEmpty)

                Button {
                    inputIsFocused = false
                } label: {
                    Image(systemName: "keyboard.chevron.compact.down")
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("キーボードを閉じる")
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color(UIColor.secondarySystemBackground))
        }
    }
}
