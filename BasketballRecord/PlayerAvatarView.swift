import SwiftUI

struct PlayerAvatarView: View {
    var player: Player
    var size: CGFloat = 56

    var body: some View {
        Group {
            if let data = player.photoData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Circle().fill(Color.accentColor.opacity(0.16))
                    Text(initials)
                        .font(.headline)
                        .foregroundStyle(Color.accentColor)
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
