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

    init(player: Player?) {
        self.player = player
        _name = State(initialValue: player?.name ?? "")
        _height = State(initialValue: player?.height ?? "")
        _weight = State(initialValue: player?.weight ?? "")
        _number = State(initialValue: player?.number ?? "")
        _photoData = State(initialValue: player?.photoData)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 16) {
                        preview
                        PhotosPicker(selection: $selectedPhoto, matching: .images) {
                            Label("选择照片", systemImage: "photo")
                        }
                    }

                    if photoData != nil {
                        Button(role: .destructive) {
                            photoData = nil
                        } label: {
                            Label("移除照片", systemImage: "trash")
                        }
                    }
                }

                Section("基本信息") {
                    TextField("姓名（必填）", text: $name)
                    TextField("号码", text: $number)
                        .keyboardType(.numberPad)
                    TextField("身高 cm", text: $height)
                        .keyboardType(.decimalPad)
                    TextField("体重 kg", text: $weight)
                        .keyboardType(.decimalPad)
                }
            }
            .navigationTitle(player == nil ? "新建球员" : "编辑球员")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .task(id: selectedPhoto) {
                guard let selectedPhoto,
                      let data = try? await selectedPhoto.loadTransferable(type: Data.self) else { return }
                photoData = data
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

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let next = Player(
            id: player?.id ?? UUID(),
            name: trimmedName,
            height: height.trimmingCharacters(in: .whitespacesAndNewlines),
            weight: weight.trimmingCharacters(in: .whitespacesAndNewlines),
            number: number.trimmingCharacters(in: .whitespacesAndNewlines),
            photoData: photoData
        )

        if player == nil {
            store.addPlayer(next)
        } else {
            store.updatePlayer(next)
        }
        dismiss()
    }
}
