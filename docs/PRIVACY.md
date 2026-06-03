# Privacy Policy

**Application:** Tolaco
**Provider:** NEXASPARK Inc. (株式会社NEXASPARK) ("we", "us", "our")
**Contact:** <yuta.kimura@nexaspark.org>
**Effective date:** 2026-06-02
**Last updated:** 2026-06-02

> This is a plain-language policy. It is a drafting template and not legal advice; we
> recommend a legal review before publication.

## 1. Summary

Tolaco is a privacy-first, local-first macOS application for transcribing and
translating meeting audio. **We do not operate any server, account system, or analytics,
and we do not collect, receive, store, or sell any of your personal data.** Your audio,
transcripts, and translations stay on your Mac, except for the optional Claude
translation feature you can turn on, which sends text directly to Anthropic using **your
own** Anthropic API key (see Section 4).

## 2. What Tolaco does on your device

All of the following happens **entirely on your Mac** and is never transmitted to
NEXASPARK:

- **Audio capture.** With your permission, Tolaco captures system/meeting audio using
  Apple's ScreenCaptureKit (and, where you enable it, microphone input for your own
  voice). Audio is processed in real time and is not uploaded to us.
- **Transcription.** Speech is converted to text on-device using Apple's Speech
  framework. Audio used for transcription does not leave your Mac.
- **Translation (on-device).** The first-pass ("tentative") translation uses Apple's
  on-device Translation framework. No text is sent to us for this.

## 3. What is stored on your Mac

Tolaco stores data locally on your device only:

- **Meetings and transcripts** — saved as files in
  `~/Library/Application Support/Tolaco/Meetings/`. These contain the transcribed text
  and translations of your sessions.
- **Settings** — your preferences (e.g. target language, glossary, feature toggles) are
  stored in the app's local preferences (UserDefaults).
- **Anthropic API key** — if you provide one, it is stored securely in the macOS
  Keychain and is never sent to NEXASPARK.

This data is under your control and is not transmitted to us. See Section 7 for how to
review and delete it.

## 4. Optional third-party processing: Anthropic (Claude)

Tolaco includes an **optional** "Claude translation" feature that produces a higher-
quality translation. This feature is **off by default** and only operates when **all** of
the following are true: you enable it, you are not in Offline-only mode, and you have
entered your **own** Anthropic API key.

When enabled, Tolaco sends the following directly from your Mac to Anthropic's API
(`https://api.anthropic.com/v1/messages`):

- the text segment to be translated;
- up to the last 5 transcript segments (source text and prior translation) for context;
- your glossary entries, if you have configured any.

Important points:

- This uses **your own Anthropic account and API key**. Your relationship for that
  service is directly between you and Anthropic, and your data is handled under
  **Anthropic's** terms and privacy policy, not ours.
- We never receive this data and have no access to your Anthropic account or usage.
- You are responsible for any content you send and for the cost of your Anthropic usage.

Please review Anthropic's privacy policy: <https://www.anthropic.com/legal/privacy> and
their commercial/API terms: <https://www.anthropic.com/legal/commercial-terms>

If you do not want any text to leave your device, do not enable Claude translation, or
turn on **Offline-only mode**.

## 5. Apple frameworks

Transcription and tentative translation rely on Apple's on-device Speech and Translation
frameworks, and audio capture relies on Apple's ScreenCaptureKit. Your use of these
operating-system features is also subject to Apple's privacy practices. See Apple's
Privacy Policy: <https://www.apple.com/legal/privacy/>

## 6. Permissions Tolaco requests

- **Screen Recording** — required to capture audio from meeting apps (e.g. Zoom). Tolaco
  does not use or store video.
- **Microphone** — used only if you choose to capture your own voice.
- **Speech Recognition** — used for on-device transcription.

You can grant or revoke these at any time in **System Settings → Privacy & Security**.

## 7. Data retention, control, and deletion

- **Transcripts/meetings:** delete individual meetings from within the app at any time.
- **API key:** remove it at any time in the app's Settings; this deletes it from your
  Keychain.
- **Everything else:** uninstalling Tolaco and removing its Application Support folder
  (`~/Library/Application Support/Tolaco/`) deletes its local data. If you used an
  earlier version that saved audio recordings, any files under a `Recordings/` subfolder
  can be deleted manually.

Because we hold none of your data, there is no server-side copy for us to delete.

## 8. No analytics, tracking, or advertising

Tolaco contains no analytics, telemetry, crash-reporting, advertising, or third-party
tracking SDKs. We do not track you across apps or websites, and we do not sell or share
personal data.

## 9. Children

Tolaco is not directed to children and is intended for general business/productivity use.

## 10. International data transfers

We do not transfer your data internationally because we do not collect it. If you enable
Claude translation, your data is transmitted to Anthropic and may be processed in other
countries under Anthropic's terms.

## 11. Changes to this policy

We may update this policy from time to time. Material changes will be reflected by an
updated "Last updated" date and, where appropriate, noted in the app or release notes.

## 12. Contact

Questions about privacy: <yuta.kimura@nexaspark.org>
