# Tolaco

A macOS application that transcribes audio from meeting apps such as Zoom in real time and translates it into multiple languages.

## Features

- **Real-time transcription**: Instantly displays meeting audio with SwiftUI
- **Translation**: High-accuracy multilingual translation powered by the Claude API
- **Meeting management**: Save, search, and manage past meetings
- **Transcript export**: Export transcripts in text format
- **Keychain integration**: Securely store your API key

## System Requirements

- macOS 26.0 or later
- Swift 6.0

## Installation

### Prerequisites

1. Install Xcode
2. Obtain a Claude API key (https://console.anthropic.com)

### Build

```bash
# Install dependencies
xcodebuild build

# Or open Xcode and build with ⌘B
open Tolaco.xcodeproj
```

## Usage

### Initial Setup

1. Launch the app
2. Enter your Claude API key in the settings screen (⚙️)
3. Grant microphone and screen recording permissions

### Live Transcription

1. Select the "Live" tab
2. Click "Start Recording"
3. Start sharing in a meeting app such as Zoom
4. Transcription and translation are displayed in real time

### Managing Meetings

- **View**: Select a saved meeting from the sidebar
- **Export**: Save to a text file with the "Export" button
- **Delete**: Remove meetings you no longer need

## Project Structure

```
Tolaco/
├── Services/           # Business logic
│   ├── TranscriptionService.swift     # Transcription processing
│   ├── TranslationService.swift       # Translation processing
│   ├── ClaudeTranslationService.swift # Claude API integration
│   ├── AudioCaptureService.swift      # Audio capture
│   ├── MeetingStore.swift             # Meeting data management
│   ├── TranscriptExporter.swift       # Transcript export
│   └── KeychainStore.swift            # Credential management
├── Views/              # UI components
│   ├── ContentView.swift           # Main screen
│   ├── LiveTranscriptView.swift    # Live transcription screen
│   ├── MeetingDetailView.swift     # Meeting detail screen
│   ├── MeetingSidebarView.swift    # Sidebar
│   ├── SettingsView.swift          # Settings screen
│   └── CopyMenus.swift             # Copy functionality
└── Models/             # Data models
    ├── Meeting.swift           # Meeting data model
    ├── TranscriptSegment.swift # Transcript segment model
    └── TranscriptStore.swift   # Transcript data store
```

## Environment Variables

The API key is managed via the Keychain. Enter it from the settings screen.

## Development

### Dependencies

- SwiftUI (standard for iOS/macOS)
- Anthropic Claude SDK

### Coding Conventions

- Enable Swift 6.0 strict concurrency checking (minimal)
- Follow SwiftUI best practices

### Build Settings

- **Bundle ID**: `org.nexaspark.tolaco`
- **Deployment Target**: macOS 26.0
- **Code Signing**: Automatic signing

## Security

- App Sandbox: Disabled (for API calls)
- Microphone input: Allowed
- Network access: Allowed (for Claude API communication)
- Screen recording: Allowed (for capturing meeting audio)

## Troubleshooting

### "Permission denied" error

Grant the following permissions in System Settings:
- Microphone access
- Screen recording

### API key error

Verify that the Keychain settings are correct, and re-enter your API key in the settings screen.

## License

MIT License. See [LICENSE](LICENSE) for details.

## Legal Documents

- [Privacy Policy](docs/PRIVACY.md) (public page: <https://kimuson.github.io/tolaco/>)
- [Terms of Service](docs/TERMS.md)


