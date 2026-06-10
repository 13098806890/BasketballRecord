import SwiftUI

struct SelectablePlayerAvatarButton: View {
    var player: Player
    var isSelected: Bool
    var badge: String?
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                ZStack(alignment: .bottom) {
                    PlayerAvatarView(player: player, size: 58)
                        .overlay {
                            Circle().stroke(isSelected ? GamePalette.selectedBorder : Color.white.opacity(0.9), lineWidth: isSelected ? 3 : 1)
                        }
                    if let badge {
                        Text(badge)
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(GamePalette.make, in: Capsule())
                            .offset(y: 8)
                    }
                }
                Text(player.number.isEmpty ? player.name : "\(player.number)号 \(player.name)")
                    .font(.caption)
                    .lineLimit(1)
                    .frame(width: 72)
            }
            .foregroundStyle(GamePalette.text)
        }
        .buttonStyle(.plain)
    }
}
