import PhotosUI
import SwiftUI

struct PlayerEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: AppStore

    let player: Player?

    @State private var name: String
    @State private var height: String
    @State private var heightUnit: HeightUnit
    @State private var weight: String
    @State private var weightUnit: WeightUnit
    @State private var number: String
    @State private var position: String
    @State private var photoData: Data?
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var nicknames: [String]
    @State private var newNickname = ""

    init(player: Player?) {
        self.player = player
        _name = State(initialValue: player?.name ?? "")
        let initialHeightUnit = player?.heightUnit ?? UnitSettings.defaultHeightUnit
        let initialWeightUnit = player?.weightUnit ?? UnitSettings.defaultWeightUnit
        _heightUnit = State(initialValue: initialHeightUnit)
        _weightUnit = State(initialValue: initialWeightUnit)
        _height = State(initialValue: player.map { UnitSettings.editorHeightValue($0.height, unit: initialHeightUnit) } ?? "")
        _weight = State(initialValue: player.map { UnitSettings.editorWeightValue($0.weight, unit: initialWeightUnit) } ?? "")
        _number = State(initialValue: player?.number ?? "")
        _position = State(initialValue: player?.position ?? "")
        _photoData = State(initialValue: player?.photoData)
        _nicknames = State(initialValue: player?.nicknames ?? [])
    }

    var body: some View {
        NavigationStack {
            List {
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
                } header: {
                    Text(LocalizedStringKey("label_select_photo"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(EditorialDesign.navy)
                }
                .listRowBackground(EditorialDesign.card)

                Section {
                    TextField(LocalizedStringKey("placeholder_name_required"), text: $name)
                    TextField(LocalizedStringKey("placeholder_number"), text: $number)
                        .keyboardType(.numberPad)
                    Picker(LocalizedStringKey("label_position"), selection: $position) {
                        Text(LocalizedStringKey("position_unspecified")).tag("")
                        ForEach(PlayerPosition.allCases) { position in
                            Text(position.rawValue).tag(position.rawValue)
                        }
                    }
                    HStack(spacing: 8) {
                        TextField(
                            heightUnit == .cm ? LocalizedStringKey("placeholder_height_cm") : LocalizedStringKey("placeholder_height_ft_in"),
                            text: $height
                        )
                        .keyboardType(heightUnit == .cm ? .decimalPad : .numbersAndPunctuation)

                        Picker(LocalizedStringKey("label_height"), selection: $heightUnit) {
                            ForEach(HeightUnit.allCases, id: \.rawValue) { unit in
                                Text(unit.displayName).tag(unit)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .accessibilityLabel(LocalizedStringKey("label_height"))
                    }
                    HStack(spacing: 8) {
                        TextField(
                            weightUnit == .kg ? LocalizedStringKey("placeholder_weight_kg") : LocalizedStringKey("placeholder_weight_lbs"),
                            text: $weight
                        )
                        .keyboardType(.decimalPad)

                        Picker(LocalizedStringKey("label_weight"), selection: $weightUnit) {
                            ForEach(WeightUnit.allCases, id: \.rawValue) { unit in
                                Text(unit.displayName).tag(unit)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .accessibilityLabel(LocalizedStringKey("label_weight"))
                    }
                } header: {
                    Text(LocalizedStringKey("section_basic_info"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(EditorialDesign.navy)
                }
                .listRowBackground(EditorialDesign.card)

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
                .listRowBackground(EditorialDesign.card)

                Section {
                    Text(player?.id.uuidString ?? NSLocalizedString("text_generated_after_save", comment: "Generated after save"))
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                } header: {
                    Text(LocalizedStringKey("section_uuid"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(EditorialDesign.navy)
                }
                .listRowBackground(EditorialDesign.card)
            }
            .editorialListStyle()
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
            .onChange(of: heightUnit) { oldUnit, newUnit in
                height = UnitSettings.editorHeightValue(UnitSettings.canonicalHeight(height, unit: oldUnit), unit: newUnit)
            }
            .onChange(of: weightUnit) { oldUnit, newUnit in
                weight = UnitSettings.editorWeightValue(UnitSettings.canonicalWeight(weight, unit: oldUnit), unit: newUnit)
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
            height: UnitSettings.canonicalHeight(height, unit: heightUnit),
            weight: UnitSettings.canonicalWeight(weight, unit: weightUnit),
            heightUnit: heightUnit,
            weightUnit: weightUnit,
            number: number.trimmingCharacters(in: .whitespacesAndNewlines),
            position: position.trimmingCharacters(in: .whitespacesAndNewlines),
            photoData: photoData,
            playerGroupIDs: player?.playerGroupIDs ?? [],
            badges: player?.badges ?? [],
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
