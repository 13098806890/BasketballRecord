import SwiftUI

struct PlayerAvatarView: View {
    var player: Player
    var size: CGFloat = 56
    var isSelected: Bool = false

    var body: some View {
        Group {
            if let data = player.photoData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Circle().fill(isSelected ? GamePalette.selectedBorder.opacity(0.16) : Color.primary.opacity(0.08))
                    Text(initials)
                        .font(.headline)
                        .foregroundStyle(isSelected ? GamePalette.selectedBorder : .primary)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(.separator, lineWidth: 0.5))
    }

    private var initials: String {
        String(player.name.prefix(2))
    }
}
