# Tolaco

Zoomなどの会議アプリの音声をリアルタイムで文字起こしし、多言語に翻訳するmacOS アプリケーションです。

## 機能

- **リアルタイム文字起こし**: 会議の音声をSwiftUIで即座に表示
- **翻訳機能**: Claude APIを使用した高精度な多言語翻訳
- **会議管理**: 過去の会議を保存・検索・管理
- **転写物エクスポート**: テキスト形式で転写物をエクスポート
- **キーチェーン連携**: APIキーを安全に保管

## システム要件

- macOS 26.0 以上
- Swift 6.0

## インストール

### 前提条件

1. Xcodeをインストール
2. Claude APIキーを取得（https://console.anthropic.com）

### ビルド

```bash
# 依存関係をインストール
xcodebuild build

# または Xcode を開いて ⌘B でビルド
open Tolaco.xcodeproj
```

## 使い方

### 初期設定

1. アプリを起動
2. 設定画面（⚙️）でClaude APIキーを入力
3. マイクと画面収録の権限を許可

### ライブ文字起こし

1. 「ライブ」タブを選択
2. 「録音開始」をクリック
3. Zoomなどの会議アプリで共有を開始
4. リアルタイムで文字起こしと翻訳が表示されます

### 会議の管理

- **表示**: サイドバーから保存済み会議を選択
- **エクスポート**: 「エクスポート」ボタンでテキストファイルに保存
- **削除**: 不要な会議を削除

## ファイル構成

```
Tolaco/
├── Services/           # ビジネスロジック
│   ├── TranscriptionService.swift     # 文字起こし処理
│   ├── TranslationService.swift       # 翻訳処理
│   ├── ClaudeTranslationService.swift # Claude API連携
│   ├── AudioCaptureService.swift      # 音声取得
│   ├── MeetingStore.swift             # 会議データ管理
│   ├── TranscriptExporter.swift       # 転写物エクスポート
│   └── KeychainStore.swift            # 認証情報管理
├── Views/              # UI コンポーネント
│   ├── ContentView.swift           # メイン画面
│   ├── LiveTranscriptView.swift    # ライブ文字起こし画面
│   ├── MeetingDetailView.swift     # 会議詳細画面
│   ├── MeetingSidebarView.swift    # サイドバー
│   ├── SettingsView.swift          # 設定画面
│   └── CopyMenus.swift             # コピー機能
└── Models/             # データモデル
    ├── Meeting.swift           # 会議データモデル
    ├── TranscriptSegment.swift # 転写セグメントモデル
    └── TranscriptStore.swift   # 転写データストア
```

## 環境変数

APIキーはキーチェーン経由で管理されます。設定画面から入力してください。

## 開発

### 依存関係

- SwiftUI（iOS/macOS標準）
- Anthropic Claude SDK

### コード規約

- Swift 6.0の厳格な並行処理チェック（minimal）を有効化
- SwiftUIのベストプラクティスに従う

### ビルド設定

- **Bundle ID**: `org.nexaspark.tolaco`
- **Deployment Target**: macOS 26.0
- **Code Signing**: 自動署名

## セキュリティ

- アプリサンドボックス: 無効（API呼び出しのため）
- マイク入力: 許可
- ネットワークアクセス: 許可（Claude API通信用）
- 画面収録: 許可（会議音声キャプチャ用）

## トラブルシューティング

### 「権限が拒否されました」エラー

システム設定から以下の権限を許可してください：
- マイクへのアクセス
- 画面収録

### APIキーエラー

キーチェーン設定が正しいことを確認し、設定画面でAPIキーを再入力してください。

## ライセンス

MIT License。詳細は [LICENSE](LICENSE) を参照してください。

## 法務ドキュメント

- [プライバシーポリシー](docs/PRIVACY.md)（公開ページ: <https://kimuson.github.io/tolaco/> ）
- [利用規約](docs/TERMS.md)

## 著者

NEXASPARK Inc.（株式会社NEXASPARK）

## 更新履歴

- v0.1.0: 初版リリース
