import PhotosUI
import SwiftUI

struct PlayerEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: AppStore

    let player: Player?

    @State private var name: String
    @State private var height: String
    @State private var weight: String
    @State private var number: String
    @State private var photoData: Data?
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var nicknames: [String]
    @State private var newNickname = ""

    init(player: Player?) {
        self.player = player
        _name = State(initialValue: player?.name ?? "")
        _height = State(initialValue: player?.height ?? "")
        _weight = State(initialValue: player?.weight ?? "")
        _number = State(initialValue: player?.number ?? "")
        _photoData = State(initialValue: player?.photoData)
        _nicknames = State(initialValue: player?.nicknames ?? [])
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 16) {
                        preview
                        PhotosPicker(selection: $selectedPhoto, matching: .images) {
                            Label(LocalizedStringKey("label_select_photo"), systemImage: "photo")
                        }
                    }

                    if photoData != nil {
                        Button(role: .destructive) {
                            photoData = nil
                        } label: {
                            Label(LocalizedStringKey("label_remove_photo"), systemImage: "trash")
                        }
                    }
                }

                Section(LocalizedStringKey("section_basic_info")) {
                    TextField(LocalizedStringKey("placeholder_name_required"), text: $name)
                    TextField(LocalizedStringKey("placeholder_number"), text: $number)
                        .keyboardType(.numberPad)
                    TextField(LocalizedStringKey("placeholder_height_cm"), text: $height)
                        .keyboardType(.decimalPad)
                        .padding(.trailing, 36)
                        .overlay(alignment: .trailing) {
                            Text(UnitSettings.editorHeightUnitLabel())
                                .foregroundStyle(.secondary)
                        }
                    TextField(LocalizedStringKey("placeholder_weight_kg"), text: $weight)
                        .keyboardType(.decimalPad)
                        .padding(.trailing, 36)
                        .overlay(alignment: .trailing) {
                            Text(UnitSettings.editorWeightUnitLabel())
                                .foregroundStyle(.secondary)
                        }
                }

                Section {
                    ForEach(nicknames, id: \.self) { nick in
                        HStack {
                            Image(systemName: "mic.fill")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(nick)
                            Spacer()
                            Button { nicknames.removeAll { $0 == nick } } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    HStack {
                        TextField(LocalizedStringKey("placeholder_nicknames"), text: $newNickname)
                        Button { addNickname() } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(.green)
                        }
                        .disabled(newNickname.trimmingCharacters(in: .whitespaces).isEmpty)
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text(LocalizedStringKey("section_voice_nicknames"))
                } footer: {
                    Text(LocalizedStringKey("section_voice_nicknames_footer"))
                }

                Section(LocalizedStringKey("section_uuid")) {
                    Text(player?.id.uuidString ?? NSLocalizedString("text_generated_after_save", comment: "Generated after save"))
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }
            .navigationTitle(player == nil ? NSLocalizedString("nav_new_player", comment: "New player") : NSLocalizedString("nav_edit_player", comment: "Edit player"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizedStringKey("button_cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(LocalizedStringKey("button_save")) { save() }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .task(id: selectedPhoto) {
                guard let selectedPhoto,
                      let data = try? await selectedPhoto.loadTransferable(type: Data.self) else { return }
                photoData = compressedPhotoData(from: data)
            }
        }
    }

    private var preview: some View {
        Group {
            if let photoData, let image = UIImage(data: photoData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Circle().fill(.quaternary)
                    Image(systemName: "person.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: 72, height: 72)
        .clipShape(Circle())
    }

    private func addNickname() {
        let trimmed = newNickname.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !nicknames.contains(trimmed) else { return }
        nicknames.append(trimmed)
        newNickname = ""
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let next = Player(
            id: player?.id ?? UUID(),
            name: trimmedName,
            height: height.trimmingCharacters(in: .whitespacesAndNewlines),
            weight: weight.trimmingCharacters(in: .whitespacesAndNewlines),
            number: number.trimmingCharacters(in: .whitespacesAndNewlines),
            photoData: photoData,
            nicknames: nicknames
        )

        if player == nil {
            store.addPlayer(next)
        } else {
            store.updatePlayer(next)
        }
        dismiss()
    }

    private func compressedPhotoData(from data: Data) -> Data {
        guard let image = UIImage(data: data) else { return data }

        let maxDimension: CGFloat = 720
        let resized = resizedImage(image, maxDimension: maxDimension)

        return resized.jpegData(compressionQuality: 0.8) ?? data
    }

    private func resizedImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let originalSize = image.size
        let longestSide = max(originalSize.width, originalSize.height)

        guard longestSide > maxDimension else { return image }

        let ratio = maxDimension / longestSide
        let targetSize = CGSize(
            width: originalSize.width * ratio,
            height: originalSize.height * ratio
        )

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1

        return UIGraphicsImageRenderer(size: targetSize, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}
