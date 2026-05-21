import SwiftUI

struct ButtonMappingEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var store = ButtonMappingStore()

    var body: some View {
        Form {
            ForEach($store.mappings) { $item in
                VStack(alignment: .leading) {
                    Text(item.label)
                    HStack {
                        Text(item.id)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(minWidth: 110, alignment: .leading)
                        Picker("キー", selection: $item.key) {
                            ForEach(ButtonMappingStore.supportedKeys, id: \.self) { key in
                                Text(key).tag(key)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }
            }
        }
        .navigationTitle("ボタン設定")
        .onAppear {
            store.load()
        }
        .onChange(of: store.mappings) { _, _ in
            store.save()
            store.applyToPlayer()
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("閉じる") {
                    dismiss()
                }
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button("保存") {
                    store.save()
                    store.applyToPlayer()
                }
                Button("リセット") {
                    store.reset()
                    PlayerBridge.resetButtonMappings()
                    store.applyToPlayer()
                }
            }
        }
    }
}
