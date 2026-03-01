import SwiftUI

struct TerminalView: View {
    @ObservedObject var bleManager: BLEManager
    @State private var showTimestamp: Bool = true
    @State private var inputText: String = ""
    @State private var autoScroll: Bool = true

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
                .onChange(of: bleManager.receivedMessages.count) { _ in
                    if autoScroll, let last = bleManager.receivedMessages.last {
                        withAnimation(.none) {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
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

                Button {
                    guard !inputText.isEmpty else { return }
                    bleManager.send(inputText + "\n")
                    inputText = ""
                } label: {
                    Image(systemName: "paperplane.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(bleManager.connectedPeripheral == nil || inputText.isEmpty)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color(UIColor.secondarySystemBackground))
        }
    }
}
