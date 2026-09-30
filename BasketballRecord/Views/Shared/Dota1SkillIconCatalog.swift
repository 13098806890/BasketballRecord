import UIKit

enum Dota1SkillIconCatalog {
    struct Item: Identifiable {
        let id: Int
        let column: Int
        let row: Int

        var cropRect: CGRect {
            CGRect(x: CGFloat(column * 70 + 4), y: CGFloat(row * 80 + 4), width: 62, height: 72)
        }
    }

    static let items: [Item] = [
        Item(id: 1, column: 0, row: 1),
        Item(id: 2, column: 2, row: 1),
        Item(id: 3, column: 3, row: 1),
        Item(id: 4, column: 4, row: 1),
        Item(id: 5, column: 5, row: 1),
        Item(id: 6, column: 6, row: 1),
        Item(id: 7, column: 7, row: 1),
        Item(id: 8, column: 8, row: 1),
        Item(id: 9, column: 0, row: 2),
        Item(id: 10, column: 1, row: 2),
        Item(id: 11, column: 2, row: 2),
        Item(id: 12, column: 3, row: 2),
        Item(id: 13, column: 4, row: 2),
        Item(id: 14, column: 5, row: 2),
        Item(id: 15, column: 6, row: 2),
        Item(id: 16, column: 7, row: 2),
        Item(id: 17, column: 8, row: 2),
        Item(id: 18, column: 0, row: 3),
        Item(id: 19, column: 1, row: 3),
        Item(id: 20, column: 2, row: 3)
    ]

    static func image(for item: Item) -> UIImage? {
        guard let source = UIImage(named: "Dota1SkillIcons"),
              let cgImage = source.cgImage,
              let croppedImage = cgImage.cropping(to: item.cropRect) else { return nil }
        return UIImage(cgImage: croppedImage, scale: source.scale, orientation: source.imageOrientation)
    }

    static func data(for item: Item) -> Data? {
        image(for: item)?.jpegData(compressionQuality: 0.9)
    }

    static func matchingID(for data: Data?) -> Int? {
        guard let data else { return nil }
        return items.first(where: { self.data(for: $0) == data })?.id
    }

    static func isLegacyIconData(_ data: Data?) -> Bool {
        matchingID(for: data) != nil
    }
}
