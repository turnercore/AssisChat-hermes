# DaisyChat

DaisyChat is becoming a Hermes-first native client for iPhone and iPad.

The goal is simple: make your Hermes backend feel like a real Apple-native mobile app, not a generic API wrapper. It should let you chat with Hermes, inspect backend health, browse sessions, watch runs progress, and approve or stop work from your iPad or iPhone.

macOS is intentionally out of scope because Hermes already has a separate macOS app.

## Product Direction

This fork is focused on:

- A first-class Hermes backend experience for iOS and iPadOS.
- Private bring-your-own-server usage with credentials stored in Keychain.
- Hermes API Server support through the OpenAI-compatible chat endpoint as the first path.
- Rich Hermes dashboard support for health, capabilities, models, sessions, messages, and runs.
- Modern Apple-native UI patterns with iPad-friendly navigation.
- Two themes: a clean modern default and a Hermes Nous Research-flavored theme.

OpenAI and Anthropic direct-provider setup has been removed from the product path for now. This fork is intentionally Hermes-first.

## Hermes Backend

Default Hermes setup targets a personal Hermes API server:

- Base URL: `http://<host>:8642`
- OpenAI-compatible API base: `/v1`
- Default model: `hermes-agent`
- Auth: `Authorization: Bearer <API_SERVER_KEY>`
- Health: `GET /health`
- Capabilities: `GET /v1/capabilities`
- Session headers: `X-Hermes-Session-Id` and `X-Hermes-Session-Key`

The app includes an initial Hermes dashboard for checking connection state, discovering capabilities/models, listing sessions, reading session messages, and starting/stopping runs when the backend exposes those features.

## Privacy Posture

This fork is privacy-first before real credentials are used.

- Provider secrets are stored in Keychain, not shared defaults.
- Legacy API keys are migrated out of shared defaults when possible.
- StoreKit purchase code has been removed.
- CloudKit sync and push notification entitlements have been removed.
- Keyboard and share extension UI has been removed from the main product path.

Prompts and selected chat history still go to the backend you configure. For Hermes, that should be a server you control.

## Current Status

Implemented:

- Hermes-only settings and adapter.
- Hermes health/capabilities/models/session/run client APIs.
- Keychain-backed provider secrets and migration.
- Hermes dashboard foundation.
- Modern default and Hermes Nous theme support.
- StoreKit/CloudKit/push cleanup.
- Upstream developer identity removed from app branding and bundle IDs.

Still needs real-device smoke testing against a live Hermes server.

## Build

Open `AssisChat.xcodeproj` in Xcode and build the `AssisChat` scheme.

Current fork identity:

- App bundle ID: `com.turnercore.AssisChatHermes`
- App group: `group.com.turnercore.AssisChatHermes`
- Keychain group: `BWDKW435B4.com.turnercore.AssisChatHermes.shared`

For physical iPhone/iPad testing, Xcode must have an active Apple developer account for the configured team and must create a provisioning profile for the app.

## Credits And License

This fork is based on the MIT-licensed AssisChat project. The original MIT license notice is preserved in `LICENSE`.

Third-party packages include LDSwiftEventSource, Splash, and MarkdownUI.
