import SwiftUI

struct SettingsView: View {
    @Bindable var service: ClaudeTranslationService
    @Environment(\.dismiss) private var dismiss

    @State private var apiKeyInput: String = ""
    @State private var showingSavedToast = false

    private var hasAPIKey: Bool { service.apiKey?.isEmpty == false }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker(selection: $service.targetLanguage) {
                        ForEach(TargetLanguage.allCases) { lang in
                            Text(lang.displayName).tag(lang)
                        }
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "globe")
                                .font(.body)
                                .foregroundStyle(.white)
                                .frame(width: 26, height: 26)
                                .background(.teal.gradient, in: RoundedRectangle(cornerRadius: 6))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("翻訳先の言語")
                                    .font(.headline)
                                Text("文字起こししたテキストをこの言語に翻訳します")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } header: {
                    Text("翻訳")
                }

                Section("翻訳エンジン") {
                    SettingToggle(
                        isOn: $service.enabled,
                        systemImage: "sparkles",
                        tint: .purple,
                        title: "Claude Haiku で本訳",
                        subtitle: "Apple Translation の仮訳を、文脈を考慮した高精度訳に置き換えます"
                    )
                    .disabled(service.offlineOnly)

                    SettingToggle(
                        isOn: $service.offlineOnly,
                        systemImage: "airplane",
                        tint: .indigo,
                        title: "オフライン専用モード",
                        subtitle: "外部 API へのリクエストを一切発行しません。Apple Translation の仮訳のみで完結します。",
                        footnote: "※ Apple Translation の言語パックを事前にダウンロードしておく必要があります。"
                    )
                }

                if service.enabled {
                    Section {
                        HStack {
                            SecureField("sk-ant-...", text: $apiKeyInput)
                                .textFieldStyle(.roundedBorder)
                            Button("保存", action: saveAPIKey)
                                .disabled(trimmedInput.isEmpty)
                            if hasAPIKey {
                                Button(role: .destructive) {
                                    service.apiKey = nil
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .help("保存済みのキーを削除")
                            }
                        }

                        HStack(spacing: 6) {
                            Image(systemName: hasAPIKey ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                                .foregroundStyle(hasAPIKey ? .green : .orange)
                            Text(hasAPIKey ? "Keychain に保存済み" : "未設定")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if showingSavedToast {
                                Text("保存しました")
                                    .font(.caption)
                                    .foregroundStyle(.tint)
                                    .transition(.opacity)
                            }
                        }
                    } header: {
                        Text("Anthropic API キー")
                    } footer: {
                        Text("Claude による本訳を使うには API キーが必要です。キーは Keychain に安全に保管されます。")
                    }
                }

                Section {
                    TextEditor(text: $service.glossary)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 120)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(.separator)
                        )
                } header: {
                    Text("用語集")
                } footer: {
                    Text("会議の専門用語や固有名詞を「English = 訳語」の形式で1行ずつ入れると、訳の安定性が大幅に上がります。\n例： Kubernetes = クバネティス")
                }

                if let err = service.lastError {
                    Section {
                        Label(err, systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("設定")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") { dismiss() }
                        .keyboardShortcut(.escape)
                }
            }
        }
        .frame(width: 520, height: 600)
        .animation(.default, value: showingSavedToast)
        .animation(.default, value: service.enabled)
    }

    private var trimmedInput: String {
        apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func saveAPIKey() {
        service.apiKey = trimmedInput
        apiKeyInput = ""
        showingSavedToast = true
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            showingSavedToast = false
        }
    }
}

/// セクション内で使う、アイコン付きの説明文つきトグル行。
private struct SettingToggle: View {
    @Binding var isOn: Bool
    let systemImage: String
    let tint: Color
    let title: String
    let subtitle: String
    var footnote: String? = nil

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: systemImage)
                    .font(.body)
                    .foregroundStyle(.white)
                    .frame(width: 26, height: 26)
                    .background(tint.gradient, in: RoundedRectangle(cornerRadius: 6))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if let footnote {
                        Text(footnote)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .toggleStyle(.switch)
    }
}
