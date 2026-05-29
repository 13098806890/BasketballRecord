# Copilot Instructions for BasketballRecord

## Project Overview
- **BasketballRecord** is a SwiftUI-based iOS app for recording basketball games, player stats, and team management, targeting casual and team use.
- The codebase is organized under `BasketballRecord/` (main app), `BasketballRecordTests/` (unit tests), and `BasketballRecord.xcodeproj/` (Xcode project).

## Architecture & Key Components
- **State Management:** Uses SwiftUI state and custom store patterns (see `AppStore.swift`).
- **Views:** Each major feature (game recording, roster, team editor, player editor, Bluetooth sync, AI analysis) has a dedicated SwiftUI view file (e.g., `GameView.swift`, `RosterView.swift`).
- **Models:** Centralized in `Models.swift` for teams, players, and games. Data flows via observable objects and bindings.
- **Bluetooth Sync:** Managed by `BluetoothSyncManager.swift` and related files for device-to-device data transfer.
- **AI Analysis:** Integrates with DeepSeek API (see `DeepSeekService.swift`), with API keys stored securely in Keychain (`DeepSeekKeychain.swift`).
- **Import/Export:** Data transfer logic is in `TransferCodec.swift` and UI in `TransferUI.swift`.

## Developer Workflows
- **Build & Run:**
  1. Open `BasketballRecord.xcodeproj` in Xcode 17+.
  2. Select the `BasketballRecord` scheme and run on iOS 17.6+ simulator/device.
- **Testing:**
  - Tests are in `BasketballRecordTests/`. Run via Xcode's test navigator or ⌘U.
- **Debugging:**
  - Use Xcode's debugger. No custom scripts required.
- **App Store Assets & Docs:**
  - App Store and compliance docs are in `docs/appstore/`.

## Project-Specific Conventions
- **UI Patterns:**
  - Selected player avatars are highlighted and scaled; unselected are 80% opacity.
  - Action buttons use color cues: green for success, red for fouls.
- **Data Grouping:**
  - Game history is grouped by year/month; team/player stats are grouped and collapsible.
- **Import/Export:**
  - All data import is via a single entry point; type selection and preview are required before confirming import.
- **Feedback:**
  - Copy/import actions provide immediate UI feedback (e.g., "已复制").

## Integration & External Dependencies
- **DeepSeek API:** For AI-powered game analysis. API key is user-configurable and stored securely.
- **Bluetooth:** For local device sync (see Bluetooth* files).
- **No third-party package managers** (e.g., CocoaPods, SPM) are referenced in the visible structure.

## Examples & References
- See `GameView.swift` for main game logic and UI patterns.
- See `AppStore.swift` for state management conventions.
- See `TransferCodec.swift` for data serialization/import/export.
- See `DeepSeekService.swift` for external API integration.

---

**If you are an AI agent:**
- Follow the above conventions for new features and refactoring.
- When in doubt, reference the main view/model/service files for examples.
- Ask for clarification if a workflow or pattern is unclear.
