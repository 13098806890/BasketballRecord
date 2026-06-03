# App Review Notes

## 审核备注（提交时填写到 App Store Connect → App Review Information → Notes）

Hello App Review Team,

This app "Basketball Career" (篮球生涯) is an offline basketball scorekeeping and stat tracking tool.

### Core Features

1. Create players and teams
2. Record game stats (2PT/3PT/FT, rebounds, assists, fouls, etc.)
3. View game history and player career statistics
4. Import/export data for backup and migration

### Account & Login

- No registration or login required.

### Local Network Permission

The app requests local network access via `NSLocalNetworkUsageDescription` and `NSBonjourServices` because it uses **Multipeer Connectivity (Bonjour over Bluetooth/WiFi)** for the Bluetooth sync feature:

- **Service Type**: `_bskrecord-sync._tcp`
- **How to find it**: Go to Settings → scroll down → "Sync via Bluetooth" (this is a Pro feature)
- **What it does**: Allows two nearby devices to discover each other and sync player/team/game data wirelessly

Without this permission, the Bluetooth sync feature cannot discover nearby devices. The app handles the case gracefully even if permission is denied.

### Photo Permission

- The app may request photo library access ONLY when the user chooses to set an avatar for a player.
- This is optional; the app works fully without it.

### Contact

If you have any questions, please contact: classicalxie@163.com
